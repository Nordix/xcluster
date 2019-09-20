#! /bin/sh
##
## k8s-sctp.sh --
##
##   Help script for the xcluster ovl/k8s-sctp.
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
		retrun 0
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
        for t in basic4 basic6 basic_dual; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_basic4() {
	basic46 ipv4
}

test_basic6() {
	basic46 ipv6
}

test_basic_dual() {
	basic_dual
}

basic46() {
	tlog "=== k8s-sctp: Basic test on $1"
	local n first_worker=1

	xcluster_prep $1
	xcluster_start k8s-sctp

	test $__nvm -gt 4 && first_worker=2
	for n in $(seq $first_worker $__nvm); do
		otc $n set_default_route
	done

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 2 check_coredns
	otc 2 "start_ncat $1"
	otc 2 check_ncat
	otc 2 "nslookup ncat-$1-sctp.default.svc.xcluster"
	otc 2 "internal_sctp $1"
	otc 2 "assign_lb_ip $1"
	otc 201 set_vip_routes
	otc 201 "external_sctp $1"

	xcluster_stop
}

basic_dual() {
	tlog "=== k8s-sctp: Basic test on dual-stack"
	local n first_worker=1

	xcluster_prep dual-stack
	xcluster_start k8s-sctp

	test $__nvm -gt 4 && first_worker=2
	for n in $(seq $first_worker $__nvm); do
		otc $n set_default_route
	done

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 2 check_coredns
	otc 2 "start_ncat dual-stack"
	otc 2 check_ncat
	otc 2 "nslookup ncat-ipv4-sctp.default.svc.xcluster"
	otc 2 "nslookup ncat-ipv6-sctp.default.svc.xcluster"
	otc 2 "internal_sctp ipv4"
	otc 2 "internal_sctp ipv6"
	otc 2 "assign_lb_ip ipv4"
	otc 2 "assign_lb_ip ipv6"
	otc 201 set_vip_routes
	otc 201 "external_sctp ipv4"
	otc 201 "external_sctp ipv6"

	xcluster_stop
}


cmd_otc() {
	test -n "$__vm" || __vm=2
	otc $__vm $@
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
