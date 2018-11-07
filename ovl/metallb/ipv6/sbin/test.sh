#! /bin/sh
##
## test.sh --
##
##   On-cluster test script for "metallb" on Xcluster.
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

tlog() {
	echo "  $(date +%T) $*" >&2
}
tcase() {
	now=$(date +%s)
	local msg="$(date +%T) ($((now-begin))): TEST CASE: $*"
	echo "  $msg"
	echo "  $msg" >&2
}
tdie() {
	echo "  $(date +%T) ($((now-begin))): FAILED: $*" >&2
	rm -rf $tmp
	exit 1
}

env() {
	. /etc/profile
	begin=$(date +%s)
	__timeout=10
}

cmd_tcase_mconnect() {
	env
	tcase "Start mconnect"
	kubectl apply -f /etc/kubernetes/mconnect.yaml || tdie
	local now start=$(date +%s)
	while ! kubectl get pods | grep -E '^mconnect.*Running'; do
		now=$(date +%s)
		test $((now-start)) -gt $__timeout && tdie TIMEOUT
		sleep 1
	done
	return 0
}

cmd_tcase_metallb() {
	env
	__timeout=120
	tcase "Start metallb"
	kubectl apply -f /etc/kubernetes/metallb-config-internal.yaml || tdie
	kubectl apply -f /etc/kubernetes/metallb.yaml || tdie
	kubectl apply -f /etc/kubernetes/metallb-speaker.yaml || tdie
	local now start=$(date +%s)
	while ! kubectl get pods | grep -E '^metallb-speaker.*Running'; do
		now=$(date +%s)
		test $((now-start)) -gt $__timeout && tdie TIMEOUT
		sleep 1
	done
	return 0
}

cmd_tcase_routes() {
	env
	tcase "Ipv6 routes"
	local now start=$(date +%s)
	while ! ip -6 ro | grep -E '^1000:: proto zebra'; do
		now=$(date +%s)
		test $((now-start)) -gt $__timeout && tdie TIMEOUT
		sleep 1
	done
	return 0	
}
cmd_tcase_noroutes() {
	env
	tcase "No ipv6 routes"
	local now start=$(date +%s)
	while ip -6 ro | grep -E '1000:: '; do
		now=$(date +%s)
		test $((now-start)) -gt $__timeout && tdie TIMEOUT
		sleep 1
	done
	return 0	
}

cmd_tcase_svc_rm() {
	env
	tcase "Delete svc mconnect"
	kubectl delete svc mconnect || tdie
}

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
