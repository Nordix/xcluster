#! /bin/sh
##
## metallb.sh --
##
##   Test script for metallb.
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

##   test --list
##   test [--xterm] [test...] > logfile
##     Test metallb
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

	# Remove overlays
	rm -f $XCLUSTER_TMP/cdrom.iso
	
	if test -n "$1"; then
		for t in $@; do
			test_$t
		done
	else
		for t in basic basic_ipv6 local local_ipv6 controller_ready_time_ipv4 \
			controller_ready_time_ipv6 ipv4_dual_stack; do
			test_$t
		done
	fi	

	now=$(date +%s)
	tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

test_basic() {
	tlog "--- Basic tests with ipv4"
	SETUP=metallb-test $XCLUSTER mkcdrom private-reg test gobgp metallb
	xcstart

	otc 4 nodes "config default" start "start_mconnect svc1" \
		"lbip mconnect 10.0.0.2" "lbip mconnect-udp 10.0.0.2"
	otc 201 "peers 192.168.1." "route 10.0.0.2" "mconnect 10.0.0.2"

	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_basic_ipv6() {
	tlog "--- Basic tests with ipv6"
	SETUP=metallb-test,ipv6 $XCLUSTER mkcdrom \
		etcd private-reg test gobgp metallb k8s-config
	xcstart

	otc 4 nodes "config default-ipv6"
	otc 4 start "start_mconnect svc1-ipv6"
	otc 4 "lbip mconnect 1000::2"
	otc 4 "lbip mconnect-udp 1000::2"
	otc 201 configure_routes
	otc 201 "peers 1000::1:c0a8:10"
	otc 201 "route 1000::2"
	otc 201 "mconnect [1000::2]"

	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_local() {
	tlog "--- externalTrafficPolicy: local ipv4"
	SETUP=metallb-test $XCLUSTER mkcdrom \
		k8s-config private-reg test gobgp metallb
	xcstart

	otc 4 nodes "config default" start "start_mconnect svc-local" \
		"lbip mconnect-local 10.0.0.0" "lbip mconnect-udp-local 10.0.0.0"
	otc 201 "peers 192.168.1." "route 10.0.0.0" "mconnect 10.0.0.0" \
		"tplocal 10.0.0.0"

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_local_ipv6() {
	tlog "--- externalTrafficPolicy: local ipv6"
	SETUP=metallb-test,ipv6 $XCLUSTER mkcdrom \
		etcd private-reg test gobgp metallb k8s-config
	xcstart

	otc 4 nodes
	otc 4 "config default-ipv6"
	otc 4 start
	otc 4 "start_mconnect svc-local"
	otc 4 "lbip mconnect-local 1000::"
	otc 4 "lbip mconnect-udp-local 1000::"
	otc 201 "peers 1000::1:c0a8:10"
	
	# If the ipv6 patch for metallb is not applied we must set the
	# routes manually
	otc 201 configure_routes

	otc 201 "route 1000::"
	otc 201 "tplocal [1000::]"
	
	local adr6=8000::/96
	otc 1 "lroute $adr6"
	otc 2 "lroute $adr6"
	otc 3 "lroute $adr6"
	otc 4 "lroute $adr6"
	otc 201 "multiaddr $adr6"
	otc 201 "multi_mconnect [1000::] $adr6"

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_ipv4_dual_stack() {
	tlog "--- Dual-stack in an ipv4 cluster"
	SETUP=default,metallb-test $XCLUSTER mkcdrom \
		k8s-dual-stack private-reg test metallb
	xcstart

	otc 1 check_namespaces
	otc 1 nodes
	otc 2 check_coredns

	otc 2 start_dual_stack
	otc 2 start_mconnect_dual_stack
	otc 2 check_svc_dual_stack

	otc 201 configure_l2_routing
	otc 201 ping_vips
	otc 201 check_connectivity
	otc 201 external_ipv4
	otc 201 external_ipv6

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_controller_ready_time_ipv4() {
	test -n "$__controller_version" || __controller_version=v0.7.4-nordix-alpha2
	tlog "--- Test readiness time of the controller in an IPv4 cluster"
	SETUP=default,metallb-test $XCLUSTER mkcdrom private-reg test metallb
	xcstart

	otc 1 check_namespaces
	otc 1 nodes
	otc 2 check_coredns

	otc 4 "start_mconnect svc"
	otc 4 "config default"

	otc 2 "start_controller_version $__controller_version"	
	otc 2 controller_ready
	otc 2 lbip_assigned

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_controller_ready_time_ipv6() {
	test -n "$__controller_version" || __controller_version=v0.7.4-nordix-alpha2
	tlog "--- Test readiness time of the controller in an IPv6 cluster"
	SETUP=metallb-test,ipv6 $XCLUSTER mkcdrom private-reg test metallb k8s-config
	xcstart

	otc 1 check_namespaces
	otc 1 nodes
	otc 2 check_coredns

	otc 4 "start_mconnect svc"
	otc 4 "config default-ipv6"

	otc 2 "start_controller_version $__controller_version"	
	otc 2 controller_ready
	otc 2 lbip_assigned

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_start_controller_version() {
	test -n "$__controller_version" || __controller_version=v0.7.4-nordix-alpha2
	tlog "--- Starting controller version [$__controller_version]"

	SETUP=default,metallb-test $XCLUSTER mkcdrom private-reg test metallb
	xcstart

	otc 1 check_namespaces
	otc 1 nodes
	otc 2 check_coredns
	otc 2 "start_controller_version $__controller_version"	
}


xcstart() {
	$XCLUSTER $start
	sleep 2
	tcase "VM connectivity"
	tex check_vm || tdie
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
