#! /bin/sh
##
## metallb.sh --
##
##	 Test script for metallb.
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

##  test --list
##  test [--xterm] [test...] > logfile
##    Test metallb
##
cmd_test() {
	if test "$__list" = "yes"; then
		grep '^test_' $me | cut -d'(' -f1 | sed -e 's,test_,,'
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)

	start=starts
	test "$__xterm" = "yes" && start=start

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
	tlog "=== metallb; Basic tests with ipv4"

	xcluster_prep ipv4
	xcluster_start metallb gobgp
	otc 1 check_namespaces
	otc 1 check_nodes
	otc 2 check_coredns

	otc 2 start_metallb
	otc 2 "configure_metallb metallb-config.yaml"
	otc 2 start_mconnect
	otc 2 "lbip_assigned mconnect 10.0.0.0"

	otc 201 peers
	otc 201 "external_traffic 10.0.0.0"

	xcluster_stop
}

test_basic6() {
	tlog "=== metallb; Basic tests with ipv6"

	xcluster_prep ipv6
	xcluster_start metallb
	otc 1 check_namespaces
	otc 1 check_nodes
	otc 2 check_coredns

	otc 2 start_metallb
	otc 2 "configure_metallb metallb-config-ipv6-L2.yaml"
	otc 2 start_mconnect
	otc 2 "lbip_assigned mconnect 1000::"

	otc 201 configure_l2_routing
	otc 201 "external_traffic '[1000::]'"

	xcluster_stop
}


test_basic_dual() {
	tlog "=== metallb; Basic tests with dual-stack"

	xcluster_prep dual-stack
	xcluster_start metallb
	otc 1 check_namespaces
	otc 1 check_nodes
	otc 2 check_coredns

	otc 2 start_local_metallb
	otc 2 "configure_metallb metallb-config-dual-stack.yaml"

	otc 2 start_mconnect_dual_stack
	otc 2 "lbip_assigned mconnect-ipv4 10.0.0.0"
	otc 2 "lbip_assigned mconnect-ipv6 1000::"

	otc 201 configure_l2_routing
	otc 201 "external_traffic '[1000::]'"
	otc 201 "external_traffic 10.0.0.0"

	xcluster_stop
}

. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''


# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 || die "Invalid command [$cmd]"

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
