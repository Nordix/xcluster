#! /bin/sh
##
## template-k8s.sh --
##
##   Help script for the xcluster ovl/template-k8s.
##
##   Some influential environment variables:
##
##     xcluster_TZ="EST+5EDT,M3.2.0/2,M11.1.0/2"
##     xcluster_BASE_FAMILY=IPv6
##     xcluster_FEATURE_GATES=NFTablesProxyMode=true
##     xcluster_PROXY_MODE=iptables
##     xcluster_DOMAIN=cluster.local
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
	echo "$*" >&2
}

## Commands;
##

##   env
##     Print environment.
cmd_env() {
	test "$envset" = "yes" && return 0
	envset=yes

	test -n "$__nvm" || __nvm=4
	test -n "$__nrouters" || __nrouters=1
	test -n "$__replicas" || __replicas=4
	test -n "$xcluster_DOMAIN" || export xcluster_DOMAIN=xcluster
	test -n "$xcluster_PREFIX" || export xcluster_PREFIX=fd00:

	if test "$cmd" = "env"; then
		local opt="nvm|nrouters|replicas|cni|log"
		local xenv="DOMAIN|PREFIX|BASE_FAMILY"
		set | grep -E "^(__($opt)|xcluster_($xenv))="
		exit 0
	fi

	test -n "$long_opts" && export $long_opts
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##
##   test [--log=]   # Execute default tests
##   test [--log=] [--xterm] [--no-stop] <test-suite> [ovls...] > logfile
##     Exec tests
cmd_test() {
	cd $dir
	start=starts
	test "$__xterm" = "yes" && start=start
	rm -f $XCLUSTER_TMP/cdrom.iso

	local t=default
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
##   test default
##     A combo test that setup an environment and execute selected tests.
##     Intended for regression or CI testing
test_default() {
	$me test connectivity $@ || die "test connectivity"
}
##   test [--wait] [--taint] [--cni=] start_empty
##     Start empty cluster
test_start_empty() {
	if test -n "$TOPOLOGY"; then
		tlog "Using TOPOLOGY=$TOPOLOGY"
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	fi
	local cni
	test -n "$__cni" && cni=k8s-cni-$__cni
	if test "$__cni" = "cilium"; then
		# Cilium is a memory-hog and replaces kube-proxy
		export __mem=$((__mem + 1024))
		export __mem1=$((__mem1 + 1024))
		test -n "$xcluster_PROXY_MODE" || export xcluster_PROXY_MODE=disabled
	fi	

	xcluster_start network-topology $cni . $@
	otc 1 check_namespaces
	otc 1 check_nodes
	test "$__taint" = "yes" && kubectl taint nodes vm-001 \
		node-role.kubernetes.io/control-plane:NoSchedule
	test "$__wait" = "yes" && otc 1 wait
}
##   test [--replicas=] start
##     Start cluster with an mconnect server and service
test_start() {
	test_start_empty $@
	otcr vip_routes
	otc 1 "svc mconnect 10.0.0.0"
	otc 1 "deployment --replicas=$__replicas mconnect"
}
##   start_alpine
##     Start cluster with a minimal alpine based setup
test_start_alpine() {
	test_start_empty $@
	otcr "vip_routes 192.168.1.2"
	otc 1 "svc alpine 10.0.0.1"
	otc 1 "deployment --replicas=$__replicas alpine"
}
##   test connectivity
##     Basic connectivity via a service
test_connectivity() {
	test_start $@
	local nconn=$((__replicas * 25))
	# Use DN loadBalancerIP from main netns
	otc 2 "mconnect mconnect.default.svc $nconn $__replicas"
	otc 2 "mconnect 10.0.0.0 $nconn $__replicas"
	otc 2 "mconnect $xcluster_PREFIX:10.0.0.0 $nconn $__replicas"
	otc 201 "mconnect 10.0.0.0 $nconn $__replicas"
	otc 201 "mconnect $xcluster_PREFIX:10.0.0.0 $nconn $__replicas"
	xcluster_stop
}

##
# The "__nvm=X" is a work-around to prevent the "xctest" lib to set
# __nvm=4 as default. We want to set the default in the cmd_env() function.
test -z "$__nvm" && __nvm=X
. $($XCLUSTER ovld test)/default/usr/lib/xctest
test "$__nvm" = "X" && unset __nvm
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
	elif test "$1" = "--"; then
		shift
		break
	else
		o=$(echo "$1" | sed -e 's,-,_,g')
		eval "$o=yes"
	fi
	long_opts="$long_opts $o"
	shift
done
unset o v

# Execute command
trap "die Interrupted" INT TERM
cmd_env
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
