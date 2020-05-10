#! /bin/sh
##
## wireguard.sh --
##
##   Help script for the xcluster ovl/wireguard.
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

	wg=$GOPATH/src/git.zx2c4.com/wireguard-tools/src/wg
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
        for t in start_mesh; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start_mesh() {
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export __nrouters=0
	export __mem=512
	test -n "$__nvm" || export __nvm=8
	xcluster_start xnet iptools wireguard
	otc 1 wg_support
	otcvm "mesh --nvm=$__nvm"
}

test_mesh() {
	tlog "==== Test full mesh"
	test_start_mesh
	otcvm "ping_all_vms --nvm=$__nvm"
	xcluster_stop
}

otcvm() {
	local i
	for i in $(seq 1 $__nvm); do
		otc $i "$1"
	done
}

cmd_generate_keys() {
	cmd_env
	test -x $wg || die "Not executable [$wg]"
	local i

	test -n "$__nvm" || __nvm=4
	for i in $(seq 1 $__nvm); do
		echo "key$i=$($wg genkey)"
		echo "psk$i=$($wg genpsk)"
	done

	test -n "$__nrouters" || __nrouters=2
	for i in $(seq 201 $((__nrouters+200))); do
		echo "key$i=$($wg genkey)"
		echo "psk$i=$($wg genpsk)"
	done

	test -n "$__ntesters" || __ntesters=0
	for i in $(seq 221 $((__ntesters+220))); do
		echo "key$i=$($wg genkey)"
		echo "psk$i=$($wg genpsk)"
	done
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
