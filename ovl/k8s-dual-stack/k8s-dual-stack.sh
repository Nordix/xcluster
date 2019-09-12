#! /bin/sh
##
## k8s-dual-stack.sh --
##
##   Help script for the xcluster ovl/k8s-dual-stack.
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
        for t in basic4; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_basic4() {
	tlog "=== dual-stack; ipv4 base cluster"

	xcluster_prep dual-stack
	xcluster_start

	otc 1 check_namespaces
	otc 1 start_alpine
	otc 1 check_nodes
	otc 2 check_coredns
	otc 3 check_podcidrs
	otc 2 check_alpine
	otc 3 check_podips

	otc 3 start_mconnect
	otc 3 create_ipv6_svc
	otc 3 ipv4_traffic
	otc 3 ipv6_traffic
	otc 3 ipv4_traffic_dn
	otc 3 ipv6_traffic_dn

	otc 201 external_ipv6_traffic

	otc 3 ipv6_svc_lb
	otc 201 external_ipv6_traffic_lb
	
	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
    $XCLUSTER stop
}


xcstart() {
	tcase "Cluster start"
    $XCLUSTER $start || tdie
    sleep 2
    tcase "VM connectivity"
    tex check_vm || tdie
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
