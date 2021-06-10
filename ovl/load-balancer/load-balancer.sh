#! /bin/sh
##
## load-balancer.sh --
##
##   Help script for the xcluster ovl/load-balancer.
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
	test -n "$__nrouters" || __nrouters=2
	test -n "$__nvm" || __nvm=4
	plot=$GOPATH/src/github.com/Nordix/ctraffic/scripts/plot.sh
	ctraffic=$GOPATH/src/github.com/Nordix/ctraffic/image/ctraffic
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
		test_ecmp
		test_ipvs
		test_nfqueue
		test_dpdk
    fi

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	export __image=$XCLUSTER_HOME/hd.img
	export __ntesters=1
	unset __mem1 __mem201 __mem202 __mem203
	export __mem=256
	if test -n "$TOPOLOGY"; then
		export xcluster_TOPOLOGY=$TOPOLOGY
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	fi
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools $@ load-balancer
}


scale_lb() {
	test -n "$__scale" || die "__scale not set"
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 20s"
	sleep 5
	otc 221 "scale_lb $__scale"
	otcw "scale_lb $__scale"
	sleep 10
	otc 221 "scale_lb"
	otcw "scale_lb"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale_lb.out
	xcluster_stop
	$plot connections --stats=/tmp/scale_lb.out > /tmp/scale_lb.svg
	$ctraffic -analyze hosts -stat_file /tmp/scale_lb.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg
}

# ecmp ----------------------------------------------------------------
test_start_ecmp() {
	export SETUP=ecmp
	export __kver=linux-5.4.35
	test_start
}

test_ecmp() {
	tlog "=== load-balancer: ECMP test"
	test_start_ecmp
	otc 221 "mconnect 10.0.0.0:5001"
	otc 221 "mconnect [1000::]:5001"
	xcluster_stop
}
test_ecmp_scale_lb() {
	test -n "$__scale" || __scale=201
	tlog "=== load-balancer: ECMP scale LBs [$__scale]"
	test_start_ecmp
	scale_lb
}
test_ecmp_scale() {
	test -n "$__scale" || __scale=1
	tlog "=== load-balancer: ECMP scale in/out [$__scale]"
	test_start_ecmp
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 20s"
	sleep 5
	otcr "ecmp_scale $__scale"
	sleep 10
	otcr "ecmp_scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	xcluster_stop

	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg	
}

test_ecmp_scale_out() {
	test -n "$__scale" || __scale=1
	tlog "=== load-balancer: ECMP scale out [$__scale]"
	test_start_ecmp
	otcr "ecmp_scale $__scale"
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 10s"
	sleep 4
	otcr "ecmp_scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	xcluster_stop

	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg	
}

test_ecmp_scale_in() {
	test -n "$__scale" || __scale=1
	tlog "=== load-balancer: ECMP scale in [$__scale]"
	test_start_ecmp
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 10s"
	sleep 4
	otcr "ecmp_scale $__scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	xcluster_stop

	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg	
}

# nfqueue ----------------------------------------------------------------

test_start_nfqueue() {
	export SETUP=nfqueue
	export TOPOLOGY=evil_tester
	export xcluster_DISABLE_MASQUERADE=yes
	test_start $@
	otcr nfqueue_activate_all
}
test_nfqueue() {
	tlog "=== load-balancer: NFQUEUE test"
	test_start_nfqueue
	otc 221 "mconnect 10.0.0.0:5001"
	otc 221 "mconnect [1000::]:5001"
	test "$__scale_lb" = "yes" && scale_lb
	xcluster_stop
	if test "$__view" = "yes"; then
		test "$__scale_lb" = "yes" && inkview /tmp/scale_lb.svg
	fi
}
test_nfqueue_scale_lb() {
	test -n "$__scale" || __scale=201
	tlog "=== load-balancer: NFQUEUE scale LBs [$__scale]"
	test_start_nfqueue
	scale_lb
}

test_nfqueue_scale() {
	test -n "$__scale" || __scale=1
	tlog "=== load-balancer: NFQUEUE scale in/out [$__scale]"
	test_start_nfqueue
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 20s"
	sleep 5
	otcr "nfqueue_scale_in $__scale"
	sleep 10
	otcr "nfqueue_scale_out $__scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	xcluster_stop
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg
}

test_nfqueue_scale_out() {
	test -n "$__scale" || __scale="1"
	tlog "=== load-balancer: NFQUEUE scale out [$__scale]"
	test_start_nfqueue
	otcr "nfqueue_scale_in $__scale"
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 10s"
	sleep 4
	otcr nfqueue_activate_all
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	xcluster_stop
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg	
}

test_nfqueue_scale_in() {
	test -n "$__scale" || __scale="1"
	tlog "=== load-balancer: NFQUEUE scale in [$__scale]"
	test_start_nfqueue
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 10s"
	sleep 4
	otcr "nfqueue_scale_in $__scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	xcluster_stop
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg	
}

# ipvs ----------------------------------------------------------------

test_start_ipvs() {
	export SETUP=ipvs
	test -n "$xcluster_IPVS_SETUP" || xcluster_IPVS_SETUP=dsr
	test_start
}

test_ipvs() {
	test -n "$xcluster_IPVS_SETUP" || xcluster_IPVS_SETUP=dsr
	tlog "=== load-balancer: IPVS test mode=$xcluster_IPVS_SETUP"
	test_start_ipvs
	otc 221 "mconnect 10.0.0.0:5001"
	otc 221 "mconnect [1000::]:5001"
	xcluster_stop
}

test_ipvs_scale() {
	test -n "$__scale" || __scale=1
	tlog "=== load-balancer: IPVS scale in/out [$__scale]"
	test_start_ipvs
	otc 221 "ctraffic_start -address 10.0.0.0:5003 -nconn 100 -rate 100 -srccidr 50.0.0.0/16 -timeout 20s"
	sleep 5
	otcr "ipvs_scale_in $__scale"
	sleep 10
	otcr "ipvs_scale_out $__scale"
	otc 221 "ctraffic_wait --timeout=30"
	rcp 221 /tmp/ctraffic.out /tmp/scale.out
	$plot connections --stats=/tmp/scale.out > /tmp/scale.svg
	xcluster_stop
	$ctraffic -analyze hosts -stat_file /tmp/scale.out >&2
	test "$__view" = "yes" && inkview /tmp/scale.svg
}

# DPDK l2lb -----------------------------------------------------------

test_start_dpdk() {
	export SETUP=dpdk
	export __image=$XCLUSTER_HOME/hd.img
	export __ntesters=1
	export __nrouters=1
	unset __mem1
	export __mem=256
	export __mem201=2048
	export __smp201=4
    export __append201="hugepages=128"
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools dpdk load-balancer
}
test_dpdk() {
	tlog "=== load-balancer: DPDK l2lb test"
	test_start_dpdk
	otc 221 "mconnect 10.0.0.0:5001"
	xcluster_stop	
}

# XDP lb -----------------------------------------------------------

test_start_xdp() {
	export SETUP=xdp
	export __image=$XCLUSTER_HOME/hd.img
	export __ntesters=1
	unset __mem1
	export __mem=256
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools load-balancer
}
test_init_xdp() {
	test_start_xdp
	otcr xdp_init
}

test_xdp() {
	tlog "=== load-balancer: XDP lb test"
	test_init_xdp
	otcr xdp_start
	otc 221 "mconnect 10.0.0.0:5001"
	xcluster_stop	
}

##  src_build
cmd_src_build() {
	cmd_env
	local d=$XCLUSTER_WORKSPACE/libnetfilter_queue-1.0.3
	local f=$d/examples/.libs/nf-queue
	if test -x $f; then
		log "Already built; nf-queue"
		return 0
	fi
	make -C $d/examples nf-queue
	gcc src/lb.c -o /dev/null -lmnl -lnetfilter_queue
}

#  rexec [--expand=x|y] <cmd>
#    Exec command on routers in xterms.
cmd_rexec() {
	test -n "$1" || die "No cmd"
	test -n "$__nrouters" || __nrouters=2
	local rsh='ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
	local i geometry
	for i in $(seq 1 $__nrouters); do
		if test "$__expand" = "x"; then
			geometry=$($XCLUSTER geometry $i 1)
		else
			geometry=$($XCLUSTER geometry 1 $i)
		fi
		XXTERM=XCLUSTER xterm -T "Router $i $1" -bg '#400' $geometry -e \
			$rsh root@192.168.0.$((200 + i)) -- $1 &
	done
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
