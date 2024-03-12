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
	echo "$*" >&2
}

##   env
##     Print environment.
cmd_env() {

	test -n "$__repo" || __repo=registry.nordix.org/cloud-native
	test -n "$WHEREABOUTS_DIR" || WHEREABOUTS_DIR=$GOPATH/src/github.com/k8snetworkplumbingwg/whereabouts
	test -n "$SRIOV_DIR"|| SRIOV_DIR=$GOPATH/src/github.com/k8snetworkplumbingwg/sriov-cni
	if test "$cmd" = "env"; then
		local opt="repo|log|net_setup|machine"
		set | grep -E "^(__($opt)|WHEREABOUTS_DIR|SRIOV_DIR)="
		exit 0
	fi

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
	cmd_clone_sriov
	cd $SRIOV_CNI_DIR
	make || dir "Make sriov-cni"
	local tag=$__repo/sriov-cni:latest
	docker build . -t $__repo/sriov-cni:latest
	$images lreg_upload --force $tag
	if test "$__local" = "yes"; then
		cmd_build_local_dev_plugin
		return
	fi
	cd $SRIOV_DP_DIR
	tag=$__repo/sriov-network-device-plugin:latest
	make TAG=$tag image || die "make sriov-network-device-plugin"
	$images lreg_upload --force $tag
}
cmd_build_local_dev_plugin() {
	test -n "$SRIOV_DP_DIR" || . ./Envsettings
	cd $SRIOV_DP_DIR || die
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
	cd $dir
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

	local t=net3
	if test -n "$1"; then
		local t=$1
		shift
	fi		

	if test -n "$__log"; then
		mkdir -p $(dirname "$__log")
		date > $__log || die "Can't write to log [$__log]"
		test_$t $@ >> $__log
	else
		test_$t $@
	fi

	now=$(date +%s)
	log "Xcluster test ended. Total time $((now-begin)) sec"
}
##   test start_empty
##     Starts an empty cluster without K8s
test_start_empty() {
	. ./Envsettings
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export TOPOLOGY="multilan-router"
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology lspci iptools . $@
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
##     Extra network interfaces are up and have addresses. Local
##     "whereabouts" and "" CNI-plugins are required
test_start_multus() {
	test -d $WHEREABOUTS_DIR || die "No local whereabouts clone"
	test -x $WHEREABOUTS_DIR/bin/whereabouts || die "Whereabouts not built"
	test -d $SRIOV_DIR || die "No local sriov-cni clone"
	test -x $SRIOV_DIR/build/sriov || die "Sriov-cni not built"
	. ./Envsettings
	export TOPOLOGY="multilan-router"
	export xcluster_XLAN_TEMPLATE=192.168.0.0/16/24
	export PREFIX=fd00:
	export xcluster_PREFIX=fd00:	
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start lspci iptools network-topology multus . $@
	otc 1 check_namespaces
	otc 1 multus_crd
	otc 1 deploy_whereabouts
	otc 1 sriovcni
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
cmd_env
cd $dir
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
