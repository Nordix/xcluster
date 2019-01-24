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
		for t in basic basic_ipv6 local local_ipv6; do
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

	otc 4 nodes "config default-ipv6" start "start_mconnect svc1-ipv6" \
		"lbip mconnect 1000::2" "lbip mconnect-udp 1000::2"
	otc 201 "peers 1000::1:c0a8:10" "route 1000::2" "mconnect [1000::2]"

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

	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_local_ipv6() {
	tlog "--- externalTrafficPolicy: local ipv6"
	SETUP=metallb-test,ipv6 $XCLUSTER mkcdrom \
		etcd private-reg test gobgp metallb k8s-config
	xcstart

	otc 4 nodes "config default-ipv6" start "start_mconnect svc-local" \
		"lbip mconnect-local 1000::" "lbip mconnect-udp-local 1000::"
	otc 201 "peers 1000::1:c0a8:10" "route 1000::" "tplocal [1000::]"

	local adr6=8000::/96
	otc 1 "lroute $adr6"
	otc 2 "lroute $adr6"
	otc 3 "lroute $adr6"
	otc 4 "lroute $adr6"
	otc 201 "multiaddr $adr6"
	otc 201 "multi_mconnect [1000::] 8000:"

	tcase "Stop xcluster"
	$XCLUSTER stop
}

# On-line test-case
otc() {
	local tc vm
	vm=$1
	shift
	for tc in "$@"; do
		rsh $vm metallb_test tcase_$tc || tdie
	done
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
