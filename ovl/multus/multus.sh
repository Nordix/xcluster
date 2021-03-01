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

	test -n "$__cniver" || __cniver=v0.8.7
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
		__mode=dual-stack
		test_start
		push __no_stop yes
		__no_start=yes
		test_basic
		pop __no_stop
		xcluster_stop
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	# Pre-checks
	test -x $ARCHIVE/multus-cni || die "Not executable [$ARCHIVE/multus-cni]"
	local ar=$ARCHIVE/cni-plugins-linux-amd64-$__cniver.tgz
	test -r "$ar" || die "Not readable [$ar]"
	export __cniver
	tlog "Using cni-plugins $__cniver"
	test -n "$__mode" || __mode=dual-stack
	export xcluster___mode=$__mode
	export TOPOLOGY=multilan
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_prep $__mode
	xcluster_start k8s-test multus

	otcprog=k8s-test_test
	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
	unset otcprog
	otc 1 start_multus
}

test_basic() {
	test -n "$__mode" || __mode=dual-stack
	tlog "=== multus: Basic test on $__mode"
	test_start
	xcluster_stop
}


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
