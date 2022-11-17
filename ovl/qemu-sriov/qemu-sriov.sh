#! /bin/sh
##
## qemu-sriov.sh --
##
##   Help script for the xcluster ovl/qemu-sriov.
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

##   env
##     Print environment.
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
		test_vfs
		test_packet_handling
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Starts an empty cluster. Prerequisite; . ./Envsettings
test_start_empty() {
	test -n "$__kvm" -a -n "$__net_setup" -a -n "$__kvm_opt" || \
		tdie "Not sourced; . ./Envsettings"
	export __image=$XCLUSTER_HOME/hd.img
	test -n "$__nvm" || __nvm=2
	test -n "$__nrouters" || __nrouters=0
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start lspci iptools qemu-sriov
}

##   test start
##     Starts a cluster with igb modules loaded . Prerequisite; . ./Envsettings
test_start() {
	test_start_empty
	otcw modprobe
}

##   test vfs
##     Create VFs
test_vfs() {
	tlog "=== Create VFs"
	test_start
	otc 1 "create_vfs"
	xcluster_stop
}

##   test packet_handling
##     Bring eth1 up on vm-001 and vm-002 and test traffic
##     NOTE; this doesn't work yet!
test_packet_handling() {
	tlog "=== Bring eth1 up on vm-001 and vm-002 and test traffic"
	test_start
	otc 1 "ifup eth1 192.168.1.1"
	otc 1 "wait_for_link_up eth1"
	otc 2 "ifup eth1 192.168.1.2"
	otc 2 "wait_for_link_up eth1"
	otc 1 "ping 192.168.1.2"
	xcluster_stop
}

##
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
