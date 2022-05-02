#! /bin/sh
##
## network-topology.sh --
##
##   Help script for the xcluster ovl/network-topology.
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

export TEST=yes

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
##   test [--xterm] [--no-stop] > logfile
##     Exec all tests
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
        for t in xnet dual_path multihop zones backend multilan evil_tester; do
			# Invoke $me rather than call the function to avoid
			# lingering Envsettings
            $me test $t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}
##   TOPOLOGY= ... test start
##     Start a cluster with the specified TOPOLOGY
test_start() {
	test -n "$TOPOLOGY" || tdie "TOPOLOGY not specified"
	local envsettings=$dir/$TOPOLOGY/Envsettings
	test -r $envsettings || die "Not readable [$envsettings]"
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	. $envsettings 
	xcluster_start iptools network-topology
}
##   test xnet
test_xnet() {
	tlog "=== network-topology test: xnet"
	export __ntesters=2
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start iptools network-topology
	base_test
	xcluster_stop
}
##   test dual_path
test_dual_path() {
	export TOPOLOGY=dual-path
	tlog "=== network-topology test: $TOPOLOGY"
	export __ntesters=2
	test_start
	base_test

	otc 1 "ping 192.168.6.221"
	otc 1 "ping 192.168.6.222"
	otc 221 "ping 192.168.4.1"
	otc 222 "ping 192.168.4.1"
	
	xcluster_stop
}
##   test multihop
test_multihop() {
	export TOPOLOGY=multihop
	tlog "=== network-topology test: $TOPOLOGY"
	export __ntesters=2
	test_start
	base_test
	xcluster_stop
}
##   test zones
test_zones() {
	export TOPOLOGY=zones
	tlog "=== network-topology test: $TOPOLOGY"
	export __ntesters=2
	test_start
	$XCLUSTER scaleout 10 11 20 21
	base_test

	otc 10 "ping 192.168.2.221"
	otc 1 "ping 192.168.3.10"
	otc 20 "ping 192.168.2.221"
	otc 1 "ping 192.168.4.20"

	otc 10 "nslookup www.google.se"
	otc 10 "wget http://www.google.se"
	otc 20 "nslookup www.google.se"
	otc 20 "wget http://www.google.se"

	export __nvm=30
	xcluster_stop
}
##   test backend
test_backend() {
	export TOPOLOGY=backend
	tlog "=== network-topology test: $TOPOLOGY"
	export __ntesters=2
	test_start
	otc 1 "ping 192.168.2.221"
	otc 1 "ping 192.168.2.222"
	otc 221 "ping 192.168.3.2"
	otc 222 "ping 192.168.3.2"
	otc 1 "nslookup www.google.se"
	otc 221 "nslookup www.google.se"
	otc 1 "wget http://www.google.se"
	otc 221 "wget http://www.google.se"
	xcluster_stop
}
##   test multilan
test_multilan() {
	export TOPOLOGY=multilan
	export __ntesters=2
	tlog "=== network-topology test: $TOPOLOGY"
	test_start
	base_test
	xcluster_stop
}
##   test multilan_router
test_multilan_router() {
	export TOPOLOGY=multilan-router
	export __ntesters=2
	tlog "=== network-topology test: $TOPOLOGY"
	test_start
	base_test
	xcluster_stop
}

##   test evil_tester
test_evil_tester() {
	export TOPOLOGY=evil_tester
	tlog "=== network-topology test: $TOPOLOGY"
	test_start
	base_test
	xcluster_stop
}

base_test() {
	otc 1 "ping 192.168.2.221"
	otc 1 "ping 192.168.2.222"
	otc 221 "ping 192.168.1.2"
	otc 222 "ping 192.168.1.2"
	otc 1 "nslookup www.google.se"
	otc 221 "nslookup www.google.se"
	otc 1 "wget http://www.google.se"
	otc 221 "wget http://www.google.se"
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
