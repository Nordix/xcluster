#! /bin/sh
##
## metallb/test.sh --
##
##   Test script for "metallb" on Xcluster.
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
	echo "$(date +%T) $*" >&2
}
tcase() {
	now=$(date +%s)
	local msg="$(date +%T) ($((now-begin))): TEST CASE: $*"
	echo $msg
	echo $msg >&2
}
tdie() {
	local now=$(date +%s)
	echo "$(date +%T) ($((now-begin))): FAILED: $*" >&2
	rm -rf $tmp
	exit 1
}
rsh() {
	local vm=$1
	shift
	local sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
	if ip link show xcbr1 > /dev/null 2>&1; then
		ssh -q $sshopt root@192.168.0.$vm $@
	else
		ssh -q $sshopt -p $((12300+vm)) root@127.0.0.1 $@
	fi
}

env() {
	test -n "$begin" && return 0
	begin=$(date +%s)
	xctest="$(dirname $XCLUSTER)/test/xctest.sh"
	images="$($XCLUSTER ovld images)/images.sh"
}

cmd_test() {
	env
	cmd_build_img
	cmd_xcstart
	cmd_tcase tcase_metallb || tdie
	__vm=201; cmd_tcase tcase_noroutes || tdie; __vm=1
	cmd_tcase tcase_mconnect || tdie
	__vm=201; cmd_tcase tcase_routes || tdie; __vm=1
	cmd_tcase tcase_svc_rm || tdie
	__vm=201; cmd_tcase tcase_noroutes || tdie; __vm=1
	cmd_tcase tcase_mconnect || tdie
	__vm=201; cmd_tcase tcase_routes || tdie; __vm=1
	
	$XCLUSTER stop
	local now=$(date +%s)
	tlog "Stop. Elapsed time: $((now-begin))"
}

cmd_xcstart() {
	env
	tlog "Starting xcluster"
	if test "$__ipv6" = "yes"; then
		SETUP=ipv6 $XCLUSTER mkcdrom etcd coredns metallb gobgp private-reg \
			k8s-config > /dev/null 2>&1 || tdie "mkcdrom"
	else
		$XCLUSTER mkcdrom metallb gobgp private-reg \
			> /dev/null 2>&1 || tdie "mkcdrom"
	fi
	$XCLUSTER starts || tdie "starts"
	$xctest k8s_wait || tdie "k8s_wait"
}

cmd_build_img() {
	env
	$images mkimage --force ./image
	local img=library/metallb:0.7.3
	skopeo copy --dest-tls-verify=false \
		docker-daemon:$img docker://172.17.0.2:5000/$img
}

cmd_tcase() {
	test -n "$__vm" || __vm=1
	rsh $__vm /sbin/test.sh $@
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
