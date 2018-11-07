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
cmd_xcstart() {
	env
	tlog "Starting xcluster"
	$XCLUSTER mkcdrom metallb gobgp > /dev/null 2>&1 || tdie "mkcdrom"
	$XCLUSTER starts || tdie "starts"
	$xctest k8s_wait || tdie "k8s_wait"
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
