#! /bin/sh
##
## iperf.sh --
##
##   Help script for the xcluster ovl/iperf.
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
	test -n "$__iperf_ver" || __iperf_ver=iperf-2.1.6
	test -n "$__tag" || __tag="registry.nordix.org/cloud-native/iperf:local"
	test -n "$IPERF_WORKSPACE" || IPERF_WORKSPACE=/tmp/$USER/iperf

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   test --list
##   test [--xterm] [test...] > logfile
##     Exec tests
##
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
		test_connect
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start
##     Start cluster and the iperf deployment
test_start_empty() {
	test -n "$__nrouters" || export __nrouters=1
	xcluster_prep dual-stack
	xcluster_start iperf

	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
}
test_start() {
	test_start_empty
	otc 1 iperf_start
}

##   test connect (default)
##     Simple connect test over the VIP addresses
test_connect() {
	tlog "=== iperf: Connect to VIP addresses"
	test_start
	otc 201 connect
	xcluster_stop
}

##   test k8s_bandwidth
##     Test bandwidth egress limitation in Kubernetes
test_k8s_bandwidth() {
	tlog "=== iperf: Test bandwidth egress limitation in K8s"
	test_start
	xcluster_stop
}

##
##   IPERF_WORKSPACE=/tmp/$USER/iperf [--force] build
##     Unpack and build iperf at $IPERF_WORKSPACE
cmd_build() {
	cmd_env
	mkdir -p "$IPERF_WORKSPACE" || die mkdir
	test "$__force" = "yes" && \
		rm -rf $IPERF_WORKSPACE/$__iperf_ver $IPERF_WORKSPACE/bin
	if test -x $IPERF_WORKSPACE/bin/iperf; then
		log "Already built [$IPERF_WORKSPACE/bin/iperf]"
		return 0
	fi
	local ar=$ARCHIVE/$__iperf_ver.tar.gz
	test -r $ar || ar=$HOME/Downloads/$__iperf_ver.tar.gz
	test -r $ar || die "Not readable [$ar]"
	tar -C $IPERF_WORKSPACE -xf $ar || die tar
	cd $IPERF_WORKSPACE/$__iperf_ver
	./configure --enable-static-bin || die configure
	make -j$(nproc) || die make
	mkdir -p $IPERF_WORKSPACE/bin
	cp $IPERF_WORKSPACE/$__iperf_ver/src/iperf $IPERF_WORKSPACE/bin
	strip $IPERF_WORKSPACE/bin/iperf
}

##   mkimage [--tag=registry.nordix.org/cloud-native/iperf:local]
##     Create the docker image and upload it to the local registry.
cmd_mkimage() {
	cmd_env
	local imagesd=$($XCLUSTER ovld images)
	$imagesd/images.sh mkimage --force --upload --strip-host --tag=$__tag $dir/image
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
