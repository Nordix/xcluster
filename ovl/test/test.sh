#! /bin/sh
##
## test.sh --
##
##   xcluster basic testing
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
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi
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

test_basic() {
	export __image=$XCLUSTER_HOME/hd.img
	export __ntesters=1
	unset XOVLS
	xcluster_start network-topology
	otc 1 version

	tcase "Ssh/scp to from host"
	local sshopt='-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
	rsh 1 'echo $PATH' | grep -q /sbin || tdie "ssh path"
	rcp 1 /etc/os-release /tmp/os-release || tdie "scp read"
	grep ID=xcluster /tmp/os-release || tdie "scp file corrupted"
	if test -n "$(ip netns id)"; then
		# Direct ssh only works if xcluster runs in a netns
		scp $sshopt $me root@192.168.0.1: || tdie "scp write"
		ssh $sshopt root@192.168.0.1 ls | grep $prg || tdie "scp write file"
	else
		tlog "SKIPPED: direct ssh tests (doesn't work in main netns)"
	fi
	otc 1 ssh

	otc 1 "nslookup www.google.se"
	otc 201 "nslookup www.google.se"
	otc 221 "nslookup www.google.se"

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
