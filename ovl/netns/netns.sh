#! /bin/sh
##
## netns.sh --
##
##   Help script for the xcluster ovl/netns.
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

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   test --list
##   test [--xterm] [--no-stop] [test...] > logfile
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
        test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Start cluster
test_start_empty() {
	test -n "$__nrouters" || export __nrouters=0
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools netns $@
	otc 1 version
}

##   test start (default)
##     Start cluster and setup
test_start() {
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	test_start_empty
}

##   test cni_bridge
##     Create PODs and assign net with CNI-bridge and test with ping
test_cni_bridge() {
	tlog "=== Test CNI-bridge"
	test_start
	otcw cni_bridge_configure
	otcw cni_bridge_start
	otcw cni_bridge_ping
	xcluster_stop
}

##   test bridge
##     Create PODs connected to a Linux bridge and test with ping
test_bridge() {
	tlog "=== Test Linux bridge"
	test_start
	otcw create_with_addresses
	otcw linux_bridge
	otcw bridge_ping
	xcluster_stop
}

##   test L2
##     Create an L2 network with all PODS.
##     WARNING: Doesn't work with xcluster in main netns!
test_L2() {
	tlog "=== Test L2 network"
	export xcluster_RNDADR=yes
	test_start
	otcw create_with_addresses
	otcw linux_bridge
	otcw attach_eth_to_bridge
	otc 1 ping_all_random
	xcluster_stop
}

##   test L3
##     Create an L3 network with all PODS.
test_L3() {
	tlog "=== Test L3 network"
	test_start
	otcw forward
	otcw create_with_addresses
	otcw linux_bridge
	otcw default_route
	otcw setup_routes
	otc 1 ping_all_pods
	xcluster_stop
}

. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''

##
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
