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
##
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi

	repo=registry.nordix.org/cloud-native
	images=$($XCLUSTER ovld images)/images.sh
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   build_sriov_images [--local]
##     Build sriov-cni and sriov-network-device-plugin images.
##     Clone if necessary. --local builds sriov-network-device-plugin
##     with a local Dockerfile.
cmd_build_sriov_images() {
	cmd_env
	cmd_clone_sriov
	cd $SRIOV_CNI_DIR
	make || dir "Make sriov-cni"
	local tag=$repo/sriov-cni:latest
	docker build . -t $repo/sriov-cni:latest
	$images lreg_upload --force --strip-host $tag
	if test "$__local" = "yes"; then
		cmd_build_local_dev_plugin
		return
	fi
	cd $SRIOV_DP_DIR
	tag=$repo/sriov-network-device-plugin:latest
	make TAG=$tag image || die "make sriov-network-device-plugin"
	$images lreg_upload --force --strip-host $tag
}
cmd_build_local_dev_plugin() {
	cmd_env
	if ! test -n "$SRIOV_DP_DIR"; then
		cd $dir
		. ./Envsettings.k8s
	fi
	cd $SRIOV_DP_DIR
	make build || die "make-device-plugin build"
	if ! test -x build/ddptool; then
		cd build
		tar xf ../images/ddptool-1.0.1.12.tar.gz
		make || die "make ddptool"
		cd $SRIOV_DP_DIR
	fi
	local tag=$repo/sriov-network-device-plugin:latest
	docker build -f $dir/config/Dockerfile.device-plugin -t $tag . || die "docker build"
	$images lreg_upload --force --strip-host $tag
}
##   clone_sriov
##     These will be cloned if needed;
##     - github.com/k8snetworkplumbingwg/sriov-cni
##     - github.com/k8snetworkplumbingwg/sriov-network-device-plugin
cmd_clone_sriov() {
	cd $dir
	. ./Envsettings.k8s
	test -d $SRIOV_CNI_DIR || git clone --depth 1 \
		https://github.com/k8snetworkplumbingwg/sriov-cni.git $SRIOV_CNI_DIR
	test -d $SRIOV_DP_DIR || git clone --depth 1 \
		https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin.git $SRIOV_DP_DIR
}

##
##   test --list
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
cmd_test() {
	if test "$__list" = "yes"; then
        grep '^test_' $me | cut -d'(' -f1 | sed -e 's,test_,,'
        return 0
    fi

	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
        for t in $@; do
            test_$t
        done
    else
		test_vfs
		test_packet_handling
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Starts an empty cluster. Prerequisite; . ./Envsettings
test_start_empty() {
	test -n "$__kvm" -a -n "$__net_setup" -a -n "$__kvm_opt" || \
		tdie "Not sourced; . ./Envsettings"
	export __image=$XCLUSTER_HOME/hd.img
	test -n "$__nvm" || __nvm=2
	test -n "$__nrouters" || __nrouters=0
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start lspci iptools iperf qemu-sriov
}

##   test start_k8s
##     Starts an k8s environment with two pods using emulated VFs.
test_start_k8s() {
	. ./Envsettings.k8s
	test -n "$__kvm" -a -n "$__net_setup" -a -n "$__kvm_opt" || \
		tdie "Not sourced; . ./Envsettings.k8s"

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
}

##   test start
##     Starts a cluster with igb modules loaded . Prerequisite; . ./Envsettings
test_start() {
	test_start_empty
	otcw "modprobe eth1"
}

##   test vfs
##     Create VFs
test_vfs() {
	tlog "=== Create VFs"
	test_start
	otc 1 "create_vfs"
	xcluster_stop
}

##   test packet_handling
##     Bring eth1 up on vm-001 and vm-002 and test traffic
##     NOTE; this doesn't work yet!
test_packet_handling() {
	tlog "=== Bring eth1 up on vm-001 and vm-002 and test traffic"
	test_start
	otc 1 "ifup_addr eth1 192.168.1.1"
	otc 1 "wait_for_link_up eth1"
	otc 2 "ifup_addr eth1 192.168.1.2"
	otc 2 "wait_for_link_up eth1"
	otc 1 "wait_for_ping 192.168.1.2"
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
