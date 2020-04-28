#! /bin/sh
##
## mtu.sh --
##
##   Help script for the xcluster ovl/mtu.
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
        for t in jumbo; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	xcluster_prep dual-stack
	xcluster_start mtu

	otc 1 check_namespaces
	otc 1 check_nodes
}


test_jumbo() {
	export __mtu=9000
	tlog "=== mtu: Jumbo-frame test, eth mtu=$__mtu"
	test "$__no_start" = "yes" || test_start

	otc 1 "tracepath_node $__mtu"
	otc 1 start_mserver
	otc 1 "tracepath_pod $__mtu"

	xcluster_stop
}


test_startc() {
	tlog "Start MTU chain without K8s"
	if ip netns id $$ | grep -q xcluster; then
		# We need xcbr3 and xcbr4
		ip link show xcbr3 > /dev/null || tdie "Do [xc br_setup 3]"
		ip link show xcbr4 > /dev/null || tdie "Do [xc br_setup 4]"
	fi
	cmd_env
	export __image=$XCLUSTER_HOME/hd.img
	export __nrouters=3
	export __ntesters=1
	export __nets201=0,1,3
	export __nets202=0,3,4
	export __nets203=0,4,2
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start iptools mtu

	local i
	for i in $(seq 1 4); do
		otc $i "xnet 1"
	done
	otc 201 "xnet 1 3:1450"
	otc 202 "xnet 3:1450 4:1400"
	otc 203 "xnet 4:1400 2:1500"
	otc 221 "xnet 2:1500"

	for i in $(seq 1 4); do
		otc $i "route 192.168.2.0 192.168.1.201"
	done
	otc 201 "route 192.168.2.0 192.168.3.202"
	otc 202 "route 192.168.2.0 192.168.4.203"
	otc 202 "route 192.168.1.0 192.168.3.201"
	otc 203 "route 192.168.1.0 192.168.4.202"
	otc 221 "route 192.168.1.0 192.168.2.203"
}

test_vip_setup() {
	test_startc
	
	local i
	for i in $(seq 1 4); do otc $i "assign_cidr 10.0.0.0"; done
	for i in $(seq 1 4); do otc $i start_mconnect; done
	otc 201 ecmp_route
	otc 202 "route 10.0.0.0 192.168.3.201"
	otc 203 "route 10.0.0.0 192.168.4.202"
	otc 221 "route 10.0.0.0 192.168.2.203"

	otc 221 "assign_cidr 20.0.0.0"
	for i in $(seq 1 4); do
		otc $i "route 20.0.0.0 192.168.1.201"
	done
	otc 201 "route 20.0.0.0 192.168.3.202"
	otc 202 "route 20.0.0.0 192.168.4.203"
	otc 203 "route 20.0.0.0 192.168.2.221"
}

test_ecmp() {
	tlog "==== ECMP test"
	test_vip_setup

	sleep 1
	otc 221 "mconnect 10.0.0.0"
	sleep 2
	otc 221 "mconnect '[1000::1:10.0.0.1]'"

	xcluster_stop
}

test_http_vanilla() {
	tlog "==== Http test without any precautions"
	test_vip_setup
	sleep 1

	otc 221 "http http://[1000::1:10.0.0.0]/"
	otc 221 "http http://10.0.0.0/"

	xcluster_stop
}

test_http_limit_mtu() {
	tlog "==== Http test with limited MTU"
	test_vip_setup
	sleep 1

	local i
	for i in $(seq 1 4); do otc $i limit_mtu; done

	otc 221 "http http://[1000::1:10.0.0.0]/"
	otc 221 "http http://10.0.0.0/"

	xcluster_stop
}

test_http_pmtud() {
	tlog "==== Http test with pmtud"
	test_vip_setup

	local i
	for i in $(seq 1 4); do otc $i start_pmtud; done
	sleep 1

	otc 221 "http http://[1000::1:10.0.0.0]/"
	otc 221 "http http://10.0.0.0/"

	for i in $(seq 1 4); do otc $i stop_pmtud; done
	sleep 1

	# Collect pmtud logs
	local f=/tmp/pmtu.log
	rm -f $f
	for i in $(seq 1 4); do
		rsh $i cat /var/log/pmtud.log >> $f
	done
	cat $f
	local n
	n=$(grep '^192.168.' $f | wc -l)
	tlog "Re-sent ipv4 packets; $n"
	n=$(grep '^1000::1:' $f | wc -l)
	tlog "Re-sent ipv6 packets; $n"
	
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
