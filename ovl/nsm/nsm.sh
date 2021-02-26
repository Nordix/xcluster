#! /bin/sh
##
## nsm.sh --
##
##   Test script for NSM in xcluster.
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

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   test --list
##   test [--xterm] [test...] > logfile
##     Test k3s
##
cmd_test() {
	if test "$__list" = "yes"; then
		grep '^test_' $me | cut -d'(' -f1 | sed -e 's,test_,,'
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)

	start=starts
	test "$__xterm" = "yes" && start=start

	# Remove overlays
	rm -f $XCLUSTER_TMP/cdrom.iso
	
	if test -n "$1"; then
		for t in $@; do
			test_$t
		done
	else
		for t in basic4 basic_dual; do
			test_$t
		done
	fi	

	now=$(date +%s)
	tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

test_basic4() {
	__mode=ipv4
	basic
}
test_basic_dual() {
	__mode=dual-stack
	basic
}

test_bridge_domain_dual() {
	__mode=dual-stack
	bridge_domain
}
test_bridge_domain_ipv4() {
	__mode=ipv4
	bridge_domain
}

test_start() {
	export __mem1=2048
	export __mem=1536
	test -n "$__mode" || __mode=dual-stack
	xcluster_prep $__mode
	xcluster_start nsm

	otc 1 check_namespaces
	otc 1 check_nodes

	tcase_helm_start
	otc 2 check_nsm
}

basic() {
	tlog "=== NSM; Basic test, mode=$__mode"
	test_start

	tcase_install_icmp_responder
	otc 1 check_icmp_responder
	tcase_nsc_ping_all

	xcluster_stop
}

bridge_domain() {
	tlog "=== NSM; Bridge-domain test, mode=$__mode"
	test_start

	otc 2 bridge_domain_install
	otc 2 bridge_domain_install_simple_client
	otc 2 bridge_domain_ping_simple_client

	otc 2 bridge_domain_install_ipv6
	otc 2 bridge_domain_install_simple_client_ipv6
	otc 2 bridge_domain_ping_simple_client_ipv6

	xcluster_stop
}


tcase_helm_start() {
	test -n "$__tag" || __tag=master
	tcase "Start NSM using helm (tag=$__tag)"
	kubectl create namespace spire
	cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
	helm install --generate-name --set tag=$__tag \
		--set spire.enable=false --set insecure=true deployments/helm/nsm || tdie
}

tcase_install_icmp_responder() {
	tcase "Install icmp-responder using helm"
	cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
	helm install --generate-name deployments/helm/icmp-responder
}

nsc_ping_all_ok() {
	NSM_NAMESPACE=default ./scripts/nsc_ping_all.sh 2>&1 | ogrep ERROR && return 1
	return 0
}

tcase_nsc_ping_all() {
	tcase "nsc_ping_all"
	cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
	tex nsc_ping_all_ok || tdie
}

test_start_base() {
	test -n "$__mode" || __mode=dual-stack
	export xcluster___mode=$__mode
	export __mem1=2048
	export __mem=1536
	xcluster_prep $__mode
	xcluster_start nsm

	otc 1 check_namespaces
	otc 1 check_nodes
	otcr vip_routes
	otc 1 start_spire
}
test_start_nextgen() {
	test_start_base
	otc 1 start_nsm_next_gen
}
test_basic_nextgen() {
	test_start_nextgen
	otc 1 start_nsc_nse
	test "$__get_logs" = "yes" && get_nsm_logs
	otc 1 check_interfaces
	xcluster_stop
}


. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''


# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 || die "Invalid command [$cmd]"

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
