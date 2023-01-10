#! /bin/sh
##
## k8s-app-upgrade.sh --
##
##   Help script for the xcluster ovl/k8s-app-upgrade.
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$
test -n "$PREFIX" || PREFIX=fd00:
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

## Commands;
##

##   env
##     Print environment.
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   check_ctraffic_stats <file>
##     Analyze stats from ctraffic
cmd_check_ctraffic_stats() {
	test -n "$1" || die "No stats"
	test -r "$1" || die "Not readable [$1]"
	which ctraffic > /dev/null || die "Can't find ctraffic"
	local stats=$1
	ctraffic -analyze hosts -stat_file $stats >&2
	local k v rc=0
	for k in FailedConnections FailedConnects; do
		v=$(cat $stats | jq -r .$k)
		if test $v -ne 0; then
			log "$k: $v"
			rc=1
		fi
	done
	return $rc
}
ctraffic_plot() {
	test -n "$1" || die "No stats"
	test -r "$1" || die "Not readable [$1]"
	local stats=$1
	shift
	which ctraffic > /dev/null || die "Can't find ctraffic"
	local d=$GOPATH/src/github.com/Nordix/ctraffic
	test -x $d/scripts/plot.sh || die "$d/scripts/plot.sh"
	$d/scripts/plot.sh $@ < $stats > /tmp/ctraffic.svg
	eog /tmp/ctraffic.svg &	
}
##   throughput_plot <file>
##     Plot a throughput graph from stats from ctraffic
cmd_throughput_plot() {
	test -n "$1" || die "No stats"
	ctraffic_plot $1 throughput
}
##   connection_plot <file>
##     Plot a connection graph from stats from ctraffic
cmd_connection_plot() {
	test -n "$1" || die "No stats"
	ctraffic_plot $1 connections
}

##
## Tests;
##   test [--xterm] [--no-stop] [test] [ovls...] > logfile
##     Exec tests
##
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
		local t=$1
		shift
        test_$t $@
    else
		test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}
##   test [--scheduler=] start_empty
##     Start empty cluster
test_start_empty() {
	export xcluster_PREFIX=fd00:
	export xcluster_SCHEDULER=$__scheduler
	cd $dir
	test -n "$__nrouters" || export __nrouters=1
	xcluster_start . $@
	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
}
##   test [--replicas=] [--maxUnavailable=] [--maxSurge=] start
##     Start cluster with ovl functions
test_start() {
	test_start_empty $@
	otc 1 "start_mserver --replicas=$__replicas --maxUnavailable=$__maxUnavailable --maxSurge=$__maxSurge"
}
##   test [--ver=local] [--ecmp] upgrade_image
##     Upgrade the mserver image with ctraffic
test_upgrade_image() {
	test "$__ver" || __ver=local
	test_start k8s-test $@
	test "$__ecmp" != "yes" && otcr "vip_route 192.168.1.2"
	otc 201 "start_ctraffic $PREFIX:10.0.0.52"
	tcase "Sleep 6 ..."; sleep 6
	otc 1 "image $__ver"
	tcase "Sleep 6 ..."; sleep 6
	otc 201 stop_ctraffic
	tcase "Get /tmp/ctraffic.out"
	rcp 201 /tmp/out /tmp/ctraffic.out
	xcluster_stop
	cmd_check_ctraffic_stats /tmp/ctraffic.out
	cmd_connection_plot /tmp/ctraffic.out
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
