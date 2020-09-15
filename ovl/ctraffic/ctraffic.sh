#! /bin/sh
##
## ctraffic.sh --
##
##   Help script for the xcluster ovl/ctraffic.
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
		test_start
		push __no_stop yes
		__no_start=yes
		test_basic
		test_lossy
		pop __no_stop
		xcluster_stop
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	test -n "$__mode" || __mode=dual-stack
	xcluster_prep $__mode
	xcluster_start ctraffic

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 201 routes
	otc 1 start_ctraffic
}


test_basic() {
	tlog "=== ctraffic: Basic test"
	export __nrouters=1
	test_start

	otc 2 internal_traffic
	otc 201 external_traffic

	xcluster_stop
}

test_get_stats() {
	tlog "=== ctraffic: Get statistics"
	export __nrouters=1
	test_start

	otc 201 collect_stats
	rcp 201 /tmp/ctraffic.out /tmp/ctraffic.out

	xcluster_stop
}

test_lossy() {
	tlog "=== ctraffic: Lossy traffic"
	export __nrouters=1
	test_start

	otc 201 "start_traffic -nconn 40 -rate 500 -timeout 30s"
	sleep 10
	otc 201 "inject_packet_loss 0.10"
	sleep 10
	otc 201 remove_packet_loss
	otc 201 "wait --timeout=20"
	rcp 201 /tmp/ctraffic.out /tmp/ctraffic.out
	local drop=$(cat /tmp/ctraffic.out | jq .Dropped)
	local retrans=$(cat /tmp/ctraffic.out | jq .Retransmits)
	tlog "Retransmits=$retrans, Dropped=$drop"

	xcluster_stop

	local plot=$GOPATH/src/github.com/Nordix/ctraffic/scripts/plot.sh
	if test -x $plot; then
		$plot throughput < /tmp/ctraffic.out > /tmp/ctraffic.svg
		tlog "Plot in /tmp/ctraffic.svg"
	fi
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
