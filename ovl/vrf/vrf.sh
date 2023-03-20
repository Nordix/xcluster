#! /bin/sh
##
## vrf.sh --
##
##   Help script for the xcluster ovl/vrf.
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
		t=$1
		shift
        test_$t $@
    else
		test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Start cluster with TOPOLOGY=multilan-router
test_start_empty() {
	export xcluster_PREFIX=$PREFIX
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export TOPOLOGY=multilan-router
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools . $@
	otc 1 version
}
##   test start (default)
##     Start multilan-router cluster with addresses on interfaces.
##     Default route on workers set to vm-201. vm-202 is configured
##     with a local 20.0.0.0/x range
test_start() {
	export xcluster_XLAN_TEMPLATE=192.168.0.0/16/24
	test_start_empty $@
	otc 201 "route default"		# Remove default route
	otc 202 "route default"		# Remove default route
	otc 202 "ifdown eth1 eth2 eth4 eth5"
	otcw "ifdown eth3 eth4"
	otc 202 "local_addresses 20.0.0.0"
	otcw "route default 192.168.1.201"
}
##   test start_demo
##     Start the demo setup. Same as "start" but with additional local
##     ranges on VMs and vm-201
test_start_demo() {
	test -n "$__nvm" || __nvm=1
	test_start $@
	otc 201 "local_addresses 30.0.0.0"
	otc 201 "route 10.0.0.0/24 192.168.1.1"
	otc 202 "route 10.0.0.0/24 192.168.3.1"
	otcw "local_addresses 10.0.0.0"
}
##   test ecmp4
##     Start server with VIP address on lo and check connectivity.
##     Linux does not regard ports for ECMP for IPv6, so only IPv4 is tested
test_ecmp4() {
	test_start_demo $@
	otc 202 "route 10.0.0.1 192.168.3.1 192.168.3.2 192.168.3.3 192.168.3.4"
	otcw mconnect_server
	otc 202 "mconnect 10.0.0.1:5001 100 4 80"
	#otc 202 "mconnect [$PREFIX:10.0.0.1]:5001 100 4 80"
	xcluster_stop
}



. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''

##
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
