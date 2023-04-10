#! /bin/sh
##
## cert-manager.sh --
##
##   Help script for the xcluster ovl/cert-manager.
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
		return 0
	fi
	ver=v1.11.1

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   download_manifest
##     Download installation manifest
cmd_download_manifest() {
	cmd_env
	local base=https://github.com/cert-manager/cert-manager/releases/download
	local url=$base/$ver/cert-manager.yaml
	curl -L $url > $dir/default/etc/kubernetes/load/cert-manager.yaml
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
		test_default
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

test_start() {
	xcluster_prep
	export __nrouters=0
	xcluster_start . $@
	otc 1 check_namespaces
	otc 1 check_nodes
	tcase "Sleep 4s..."; sleep 4
	otc 1 check_cert_manager
}

test_default() {
	tlog "=== cert-manager: Basic test"
	test_start
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
