#! /bin/sh
##
## qemu-sriov.sh --
##
##   Help script for the xcluster ovl/qemu-sriov.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$

die() {
    echo "ERROR: $*" >&2
    rm -rf $tmp
    exit 1
}
help() {
    grep '^##' $0 | cut -c3-
    rm -rf $tmp
    exit 0
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

log() {
	echo "$prg: $*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##   env
##     Print environment.
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi

	test -n "$__repo" || __repo=registry.nordix.org/cloud-native
	images=$($XCLUSTER ovld images)/images.sh
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   build_sriov_images [--repo=registry.nordix.org/cloud-native] [--local]
##     Build sriov-cni and sriov-network-device-plugin images.
##     Clone if necessary. --local builds sriov-network-device-plugin
##     with a local Dockerfile.
cmd_build_sriov_images() {
	cmd_env
	cmd_clone_sriov
	cd $SRIOV_CNI_DIR
	make || dir "Make sriov-cni"
	local tag=$__repo/sriov-cni:latest
	docker build . -t $__repo/sriov-cni:latest
	$images lreg_upload --force --strip-host $tag
	if test "$__local" = "yes"; then
		cmd_build_local_dev_plugin
		return
	fi
	cd $SRIOV_DP_DIR
	tag=$__repo/sriov-network-device-plugin:latest
	make TAG=$tag image || die "make sriov-network-device-plugin"
	$images lreg_upload --force --strip-host $tag
}
cmd_build_local_dev_plugin() {
	cmd_env
	if ! test -n "$SRIOV_DP_DIR"; then
		cd $dir
		. ./Envsettings
	fi
	cd $SRIOV_DP_DIR
	make build || die "make-device-plugin build"
	if ! test -x build/ddptool; then
		cd build
		tar xf ../images/ddptool-1.0.1.12.tar.gz
		make || die "make ddptool"
		cd $SRIOV_DP_DIR
	fi
	local tag=$__repo/sriov-network-device-plugin:latest
	docker build -f $dir/config/Dockerfile.device-plugin -t $tag . || die "docker build"
	$images lreg_upload --force --strip-host $tag
}
##   clone_sriov
##     These will be cloned to $SRIOV_CNI_DIR $SRIOV_DP_DIR if needed;
##     - github.com/k8snetworkplumbingwg/sriov-cni
##     - github.com/k8snetworkplumbingwg/sriov-network-device-plugin
cmd_clone_sriov() {
	cd $dir
	. ./Envsettings
	test -d $SRIOV_CNI_DIR || git clone --depth 1 \
		https://github.com/k8snetworkplumbingwg/sriov-cni.git $SRIOV_CNI_DIR
	test -d $SRIOV_DP_DIR || git clone --depth 1 \
		https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin.git $SRIOV_DP_DIR
}

##
##   test [--xterm] [--no-stop] [test [ovls...]] > logfile
##     Exec tests
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
		local t=$1
		shift
        test_$t $@
    else
		test_net3
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}
##   test start_empty
##     Starts an empty cluster without K8s
test_start_empty() {
	cd $dir
	. ./Envsettings
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export TOPOLOGY="multilan-router"
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology lspci iptools qemu-sriov $@
}
##   test start
##     Start a cluster without K8s but with igb modules loaded and
##     extra networks up with addresses assigned
test_start() {
	export xcluster_XLAN_TEMPLATE=192.168.0.0/16/24
	export PREFIX=fd00:
	export xcluster_PREFIX=fd00:
	test_start_empty
}
##   test start_multus
##     Start a K8s cluster with Multus, whereabouts and igb devices.
##     Extra network interfaces are up and have addresses.
test_start_multus() {
	. ./Envsettings
	export TOPOLOGY="multilan-router"
	export xcluster_XLAN_TEMPLATE=192.168.0.0/16/24
	export PREFIX=fd00:
	export xcluster_PREFIX=fd00:	
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start lspci iptools network-topology multus qemu-sriov $@
	otc 1 check_namespaces
	otc 1 multus_crd
	otc 1 deploy_whereabouts
	otc 1 check_nodes
}
##   test start_sriovdp
##     Start with "start_multus" and add the sriov device-plugin.
##     VFs are created on all extra networks as:
##     net3 - 2 VFs on each node
##     net4 - 1 VFs on each node
##     net5 - 1 VFs on node vm-002 and vm-004
test_start_sriovdp() {
	test_start_multus $@
	otcw "vf eth2 2"
	otcw "vf eth3 1"
	otc 2 "vf eth4 1"
	otc 4 "vf eth4 1"
	otc 1 sriovdp
	otcw allocatable
}
##   test k8s
##     Test in k8s environment with two pods using emulated VFs.
test_k8s() {
	cd $dir
	. ./Envsettings
	# Test with k8s-xcluster;
	__image=$XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
	test -r $__image || __image=$XCLUSTER_HOME/hd-k8s-xcluster.img
	export __image
	test -r $__image || die "Not readable [$__image]"
	export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
	export xcluster_FIRST_WORKER=2

	export TOPOLOGY="multilan"
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export __nets_vm=0,1,3
	export __nvm=3
	export __nrouters=0
	xcluster_start multus k8s-cni-calico lspci iptools network-topology iperf qemu-sriov

	otc 1 check_namespaces
	otc 1 check_nodes

	otcw "modprobe eth2"
	otc 2 "ifup_addr eth2 192.168.3.21"
	otc 2 "wait_for_link_up eth2"
	otc 3 "ifup_addr eth2 192.168.3.22"
	otc 3 "wait_for_link_up eth2"
	otc 2 "wait_for_ping 192.168.3.22"

	otc 2 "create_vfs"
	otc 3 "create_vfs"

	otc 1 deploy_whereabouts
	otc 1 deploy_multus
	otc 1 deploy_sriov_daemonsets

	otc 1 deploy_test_deployments
	otc 2 "wait_for_ping 192.168.3.22"
	xcluster_stop
}
##   test net3
##     Use the sriov cni-plugin to create net3 interfaces in PODs.
##     Ping the POD addresses from vm-202 (net3 is eth2 on nodes and eth3
##     on vm-202)
test_net3() {
	test_start_sriovdp $@
	otc 1 deploy_net3
	otc 202 ping_net3
	xcluster_stop
}

##
. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''

# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 $hook || die "Invalid command [$cmd]"

while echo "$1" | grep -q '^--'; do
    if echo $1 | grep -q =; then
	o=$(echo "$1" | cut -d= -f1 | sed -e 's,-,_,g')
	v=$(echo "$1" | cut -d= -f2-)
	eval "$o=\"$v\""
    else
	o=$(echo "$1" | sed -e 's,-,_,g')
	eval "$o=yes"
    fi
    shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
