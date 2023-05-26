#! /bin/sh
##
## mptcp.sh --
##
##   Help script for the xcluster ovl/mptcp.
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
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   build_ko
##     Build the systemtap module to enforce mptcp
cmd_build_ko() {
	cmd_env
	local tapd=$($XCLUSTER ovld systemtap)/_output
	local stap=$tapd/bin/stap
	test -x $stap || die "Systemtap not built"
	$stap -r $__kobj -R $tapd/share/systemtap/runtime -p4 -g \
		-m mptcpapp mptcp-app.stp

}

##
##   test [--xterm] [--no-stop] [test ovls...] > logfile
##     Exec tests
cmd_test() {
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
##     Start an empty cluster
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	unset XOVLS
	export TOPOLOGY=dual-path
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start iptools network-topology . $@
}
test_start() {
	test_start_empty $@
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
