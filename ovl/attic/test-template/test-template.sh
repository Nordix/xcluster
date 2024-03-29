#! /bin/sh
##
## test-template.sh --
##
##   Help script for the xcluster ovl/test-template.
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

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   test --list
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
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
		test_basic
	fi		

	now=$(date +%s)
	tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Start a K8s cluster and setup routes
test_start_empty() {
	cd $dir
	xcluster_start . $@
	otc 1 check_namespaces
	otc 1 check_nodes
	otcr set_vip_routes
}
##   test start
##     Start a K8s cluster with test servers
test_start() {
	test_start_empty $@
	otc 1 start_servers
	otc 1 check_servers
}
##   test basic (default)
##     Basic K8s tests
test_basic() {
	tlog "=== test-template: Basic K8s test"
	test_start $@

	otc 1 check_pod_addresses
	otc 3 "nslookup www.google.se"
	otc 2 "nslookup mconnect.default.svc.$xcluster_DOMAIN"
	otc 1 pod_nslookup

	otc 3 internal_mconnect
	otc 201 external_mconnect
	otc 1 outgoing_connect
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
