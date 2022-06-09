#! /bin/sh
##
## multus.sh --
##
##   Help script for the xcluster ovl/multus.
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

##  env
##    Print environment.
##
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$__cniver" || __cniver=v1.0.1
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
		test_basic
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Start without PODs
test_start_empty() {
	# Pre-checks
	test -x $ARCHIVE/multus-cni || die "Not executable [$ARCHIVE/multus-cni]"
	local ar=$ARCHIVE/cni-plugins-linux-amd64-$__cniver.tgz
	test -r "$ar" || die "Not readable [$ar]"
	export __cniver
	tlog "Using cni-plugins $__cniver"
	export TOPOLOGY=multilan-router
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start multus

	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
	otcw "ifup eth2"
	otcw "ifup eth3"
	otcw "ifup eth4"
	otc 1 start_multus
}
##   test start
##     Start with Alpine POD
test_start() {
	test_start_empty
	otc 1 alpine
}
##   test start_server
##     Start with multus_proxy and multus_service_controller
test_start_server() {
	test_start_empty
	otc 2 multus_service_controller
	otcw multus_proxy
	otc 1 multus_server
}

##   test basic (default)
##     Execute basic tests
test_basic() {
	test -n "$__mode" || __mode=dual-stack
	tlog "=== multus: Basic test"
	test_start
	otc 1 check_interfaces
	otc 1 ping
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
