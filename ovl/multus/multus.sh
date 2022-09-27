#! /bin/sh
##
## multus.sh --
##
##   Help script for the xcluster ovl/multus.
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
	test -n "$__multus_ver" || __multus_ver=3.9
    test -n "$__tag" || __tag="registry.nordix.org/cloud-native/multus-installer:$__multus_ver"

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   version
##     Print multus version
cmd_version() {
	cmd_env
	echo $__multus_ver
}
##   archive
##     Prints the multus archive (or fail).
cmd_archive() {
	cmd_env
	local ar=multus-cni_${__multus_ver}_linux_amd64.tar.gz
	if test -r $ARCHIVE/$ar; then
		echo $ARCHIVE/$ar
		return 0
	fi
	test -r $HOME/Downloads/$ar || die "Not found [$ar]"
	echo $HOME/Downloads/$ar
}
##   cparchives <dest>
##     Copy cni-plugin and multus archives to <dest>
cmd_cparchives() {
	test -n "$1" || die "No dest"
	test -d "$1" || die "Not a directory [$1]"
	cmd_archive > /dev/null
	local cnish=$($XCLUSTER ovld cni-plugins)/cni-plugins.sh
	test -x $cnish || die "Not executable [$cnish]"
	$cnish archive > /dev/null || die

	local ar=$(cmd_archive)
	cp $(cmd_archive) $($cnish archive) $1
}
##   mkimage [--tag=]
##     Create the docker image and upload it to the local registry.
cmd_mkimage() {
    cmd_env
    local imagesd=$($XCLUSTER ovld images)
    $imagesd/images.sh mkimage --force --upload --strip-host --tag=$__tag $dir/image
}

##
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
		test_basic
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

##   test start_empty
##     Start without PODs
test_start_empty() {
	# Pre-checks
	cmd_archive > /dev/null
	export TOPOLOGY=multilan-router
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start multus

	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
}
##   test start
##     Start with Alpine POD
test_start() {
	test_start_empty
	otcw "ifup eth2"
	otcw "ifup eth3"
	otcw "ifup eth4"
	otc 1 start_multus
}
##   test start_server
##     Start with multus_proxy and multus_service_controller
test_start_server() {
	test_start
	otc 2 multus_service_controller
	otcw multus_proxy
	otc 1 multus_server
}

##   test basic (default)
##     Execute basic tests
test_basic() {
	tlog "=== multus: Basic test"
	test_start
	otc 1 alpine
	otc 1 check_interfaces
	otc 1 ping
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
