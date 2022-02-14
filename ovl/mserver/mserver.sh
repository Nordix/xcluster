#! /bin/sh
##
## mserver.sh --
##
##   Help script for the xcluster ovl/mserver.
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

    test -n "$__tag" || __tag="registry.nordix.org/cloud-native/mserver:latest"

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
        test_connectivity
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start
##     Start the cluster and the mserver DaemonSet and services
test_start() {
	test -n "$__nrouters" || __nrouters=1
	xcluster_prep
	xcluster_start mserver
	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
	otc 1 start_daemonset
	otc 1 start_services
}

##   test connectivity (default)
##     Test external connectivity to all servers
test_connectivity() {
	log "==== test connectivity"
	test_start
	otc 201 mconnect
	otc 201 ctraffic
	otc 201 http
	xcluster_stop
}

##   test kahttp
##     Http access with kahttp
test_kahttp() {
	log "==== test kahttp"
	test_start
	otc 201 kahttp
	xcluster_stop
}

##   test sctpt
##     SCTP test with sctpt
test_sctpt() {
	log "==== test sctpt"
	test_start
	tcase "Sleep 4..."
	sleep 4
	otc 201 sctpt
	xcluster_stop
}

##
##   mkimage [--tag=registry.nordix.org/cloud-native/mserver:latest]
##     Create image and upload to local regisytry
cmd_mkimage() {
	cmd_env
	local images=$($XCLUSTER ovld images)/images.sh
	test -x $images || die "Not executable [$images]"
	test -n "$__version" || __version=latest
	$images mkimage --tag=$__tag --force --upload --strip-host ./image
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
