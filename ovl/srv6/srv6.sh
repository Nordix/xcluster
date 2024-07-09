#! /bin/sh
##
## srv6.sh --
##
##   Help script for the xcluster ovl/srv6.
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
	test "$envset" = "yes" && return 0
	envset=yes
	eset \
		__nvm=1 \
		PREFIX=fd00:

	export xcluster_PREFIX=$PREFIX
	if test "$cmd" = "env"; then
		set | grep -E "^($opts|xcluster_.*)="
		exit 0
	fi

	test -n "$long_opts" && export $long_opts
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
# Set variables unless already defined. Vars are collected into $opts
eset() {
	local e k
	for e in $@; do
		k=$(echo $e | cut -d= -f1)
		opts="$opts|$k"
		test -n "$(eval echo \$$k)" || eval $e
	done
}

##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
##
cmd_test() {
	cd $dir
	start=starts
	test "$__xterm" = "yes" && start=start
	rm -f $XCLUSTER_TMP/cdrom.iso

	local t=simple
	if test -n "$1"; then
		local t=$1
		shift
	fi		

	if test -n "$__log"; then
		mkdir -p $(dirname "$__log")
		date > $__log || die "Can't write to log [$__log]"
		test_$t $@ >> $__log
	else
		test_$t $@
	fi

	now=$(date +%s)
	log "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster and flush routes on all routers
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export TOPOLOGY=diamond
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools . $@
	otc 1 version
	otcr flush_routes
}
##   test start
##      Start cluster and setup srv6
test_start() {
	test_start_empty $@
	otcr enable_srv6
}

# Setup default SR
default_sr() {
	otc 203 intermediate
	otc 204 intermediate
	otc 201 decapsulate
	otc 202 decapsulate
	# vms->testers takes the "odd" path
	otc 201 "sr 192.168.2.0 203 202"
	# testers->vms takes the "even" path
	otc 202 "sr 192.168.1.0 204 201"
}

##   test simple (default)
##     Setup sr for ipv4 and ipv6 and test with "ping"
test_simple() {
	tlog "=== Simple SR routing"
	test_start
	default_sr
	otc 1 "ping $PREFIX:192.168.2.221"
	otc 1 "ping 192.168.2.221"
	xcluster_stop
}
##   test mtu1400
##     Setup sr and mtu 1400 and check with curl on >1400 payload
test_mtu1400() {
	tlog "=== Test with limited mtu"
	test_start
	default_sr
	otcw "default_route 192.168.1.201 mtu 1400"
	otct "default_route 192.168.2.202 mtu 1400"
	otc 221 "http 192.168.1.1"
	xcluster_stop
}

test -z "$__nvm" && __nvm=X
. $($XCLUSTER ovld test)/default/usr/lib/xctest
test "$__nvm" = "X" && unset __nvm
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
cmd_env
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
