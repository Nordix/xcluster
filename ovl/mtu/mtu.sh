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

	test -n "$xcluster_FIRST_WORKER" || export xcluster_FIRST_WORKER=1
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
##   test start
##     Start cluster with K8s
test_start() {
	cd $dir
	xcluster_start .
	otc 1 check_namespaces
	otc 1 check_nodes
}
##   test jumbo
##     Test jumbo-frames (mtu=9000) with K8s
test_jumbo() {
	export __mtu=9000
	tlog "=== mtu: Jumbo-frame test, eth mtu=$__mtu"
	test "$__no_start" = "yes" || test_start

	otc 1 "tracepath_node $__mtu"
	otc 1 start_mserver
	otc 1 "tracepath_pod $__mtu"

	xcluster_stop
}
##   test startc
##     Start cluster without K8s
test_startc() {
	cd $dir
	cmd_env
	export TOPOLOGY=multihop
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export __image=$XCLUSTER_HOME/hd.img
	export __ntesters=1
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools .
	mtu_narrow
}

mtu_narrow() {
	tlog "Narrow the mtu path"
	otcw "mtu 1500"
	otc 201 "mtu 1500 1400"
	otc 202 "mtu 1400 1300"
	otc 203 "mtu 1300 1500"
	otc 221 "mtu 1500"
}

test_vip_setup() {
	test_startc
	otcw "assign_cidr 10.0.0.0"
	otcw start_mconnect
	otc 201 ecmp_route
	otc 202 "route 10.0.0.0 192.168.3.201"
	otc 203 "route 10.0.0.0 192.168.4.202"

	otc 221 "assign_cidr 20.0.0.0"
	otcw "route 20.0.0.0 192.168.1.201"
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

	otcw limit_mtu

	otc 221 "http http://[1000::1:10.0.0.0]/"
	otc 221 "http http://10.0.0.0/"

	xcluster_stop
}

test_http_pmtud() {
	tlog "==== Http test with pmtud"
	test_vip_setup

	otcw start_pmtud
	sleep 1

	otc 221 "http http://[1000::1:10.0.0.0]/"
	otc 221 "http http://10.0.0.0/"

	otcw stop_pmtud
	sleep 1

	cmd_collect_pmtu_logs

	xcluster_stop
}
cmd_collect_pmtu_logs() {
	local f=/tmp/pmtu.log
	rm -f $f
	if test "$xcluster_FIRST_WORKER" = "2"; then
		for i in $(seq 2 5); do
			rsh $i cat /var/log/pmtud.log >> $f
		done
	else
		for i in $(seq 1 4); do
			rsh $i cat /var/log/pmtud.log >> $f
		done
	fi
	cat $f
	local n
	n=$(grep '^192.168.' $f | wc -l)
	tlog "Re-sent ipv4 packets; $n"
	n=$(grep '^1000::1:' $f | wc -l)
	tlog "Re-sent ipv6 packets; $n"
	
}

test_backend_start() {
	tlog "Start K8s with TOPOLOGY=backend"
	cmd_env
	export TOPOLOGY=backend
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export __ntesters=1
	export __nrouters=1
	xcluster_start network-topology iptools mtu

	otc 1 check_namespaces
	otc 1 check_nodes
}

test_backend_start_limit_mtu() {
	tlog "Start K8s with TOPOLOGY=backend"
	cmd_env
	export TOPOLOGY=backend
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export __ntesters=1
	export __nrouters=1
	xcluster_start network-topology iptools mtu

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 1 start_mserver
	otc 1 http_svc
	otc 201 backend_vip_route
	otcw "mtu 1500 1400"
	otc 201 "mtu 1400 1500"
}

test_backend_http() {
	tlog "==== Http to POD via frontend network with mtu=1400"
	test_backend_start

	otc 1 start_mserver
	otc 1 http_svc
	otc 201 backend_vip_route
	otcw "mtu 1500 1400"
	otc 201 "mtu 1400 1500"

	otc 201 backend_http
	otc 221 backend_http

	xcluster_stop
}

test_multihop_start() {
	tlog "Start K8s with TOPOLOGY=multihop"
	cmd_env
	export TOPOLOGY=multihop
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export __ntesters=1
	xcluster_start network-topology iptools mtu
	otc 1 check_namespaces
	otc 1 check_nodes
	otc 202 "route 10.0.0.0 192.168.3.201"
	otc 203 "route 10.0.0.0 192.168.4.202"
	if test "$__no_ecmp" = "yes"; then
		otc 201 "route 10.0.0.0 192.168.1.3"
	else
		otc 201 ecmp_route
	fi
	test "$__narrow" = "no" || mtu_narrow
	otc 1 start_mserver
	otc 1 http_svc
	otc 1 mconnect_svc
	if test "$__pmtud" = "yes"; then
		otcw start_pmtud
		sleep 1
	fi
}

test_multihop_vanilla() {
	tlog "==== Http with narrow pmtu (no precaution)"
	test_multihop_start

	otc 201 backend_http
	otc 221 "backend_http --count=40"

	xcluster_stop
}

test_multihop_pmtud() {
	tlog "==== Http with narrow pmtu (with pmtud)"
	__pmtud=yes
	test_multihop_start

	otc 201 backend_http
	otc 221 "test_http --count=10"

	otcw stop_pmtud
	sleep 1
	cmd_collect_pmtu_logs

	xcluster_stop
}
test_multihop_limit_mtu() {
	tlog "==== Http with narrow pmtu (limit mtu on workers)"
	test_multihop_start

	otcw limit_mtu

	otc 201 backend_http
	otc 221 "backend_http --count=40"

	xcluster_stop
}

test_multihop_capture() {
	cmd_env
	tlog "==== Multihop http with tcpdump capture"
	rm -rf /tmp/$USER/pcap
	test_multihop_start
	test "$__limit_mtu" = "yes" && otcw limit_mtu_2

	cmd_start_tcpdump
	otc 201 start_tcpdump
	otcw start_tcpdump
	sleep 2

	otc 221 "http_attempt $__vip"

	sleep 2
	cmd_stop_tcpdump  # Must be first!
	otc 201 stop_tcpdump
	otcw stop_tcpdump

	sleep 2
	cmd_collect_tcpdump_pod_logs
	local lastw=$((xcluster_FIRST_WORKER + 3))
	for i in $(seq $xcluster_FIRST_WORKER $lastw) 201; do
		cmd_collect_tcpdump_log $i
	done

	xcluster_stop
}

test_multihop_capture_vm() {
	cmd_env
	test -n "$__vip" || __vip=10.0.0.2
	tlog "==== Multihop http to VM with tcpdump capture ($__vip)"
	rm -rf /tmp/$USER/pcap
	test_vip_setup
	sleep 1

	if test "$__pmtud" = "yes"; then
		otcw start_pmtud
		sleep 1
	fi
	test "$__limit_mtu" = "yes" && otcw limit_mtu_2

	otc 201 start_tcpdump
	otcw start_tcpdump
	sleep 2

	otc 221 "http_attempt $__vip"

	sleep 2
	otc 201 stop_tcpdump
	otcw stop_tcpdump

	sleep 2
	local lastw=$((xcluster_FIRST_WORKER + 3))
	for i in $(seq $xcluster_FIRST_WORKER $lastw) 201; do
		cmd_collect_tcpdump_log $i
	done

	if test "$__pmtud" = "yes"; then
		otcw stop_pmtud
		sleep 1
		cmd_collect_pmtu_logs
	fi

	xcluster_stop
}

test_start_squeeze() {
	export __image=$XCLUSTER_HOME/hd.img
	export XOVLS=$(echo $XOVLS | sed -e 's,private-reg,,')
	export TOPOLOGY=evil_tester
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools mtu
	otcw "assign_cidr 10.0.0.0"
	otc 221 "assign_cidr 20.0.0.0"
	otcw start_mconnect
	otc 201 ecmp_route
	otcr "route 20.0.0.0 192.168.3.222"
	otc 222 "route 20.0.0.0 192.168.2.221"
	otc 222 "squeeze_chain 10"
}

cmd_start_tcpdump() {
	tcase "Start tcpdump capture in all mserver-pods"
	local pod
	for pod in $($kubectl get pods -l app=mserver-daemonset -o name); do
		kubectl exec $pod -- sh -c \
			"tcpdump -ni eth0 -w /tmp/pcap > /dev/null 2>&1 &" || tdie
	done
}

cmd_stop_tcpdump() {
	tcase "Stop tcpdump in all mserver-pods"
	local pod
	for pod in $($kubectl get pods -l app=mserver-daemonset -o name); do
		kubectl exec $pod -- killall tcpdump || tdie
	done
}

cmd_collect_tcpdump_pod_logs() {
	tcase "Collect tcpdump logs from all mserver-pods"
	local dst=/tmp/$USER/pcap
	mkdir -p $dst
	local pod node
	for pod in $($kubectl get pods -l app=mserver-daemonset -o name); do
		node=$(kubectl get $pod -o json | jq -r .spec.nodeName)
		kubectl cp $(basename $pod):tmp/pcap $dst/mserver-$node
	done
}

cmd_collect_tcpdump_log() {
	local dst=/tmp/$USER/pcap
	mkdir -p $dst
	test -n "$__interface" || __interface=eth1
	local vm=$(printf "vm-%03d" $1)
	tlog "Collect tcpdump logs from $vm ($__interface)"
	sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
	scp $sshopt root@192.168.0.$1:/tmp/$__interface.pcap $dst/$vm-$__interface 2>&1
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
