#! /bin/sh
##
## k8s-cni-calico.sh --
##
##   Help script for the xcluster ovl/k8s-cni-calico.
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

## Commands;
##

##   env
##     Print environment.
cmd_env() {
	test -n "$__nvm" || export __nvm=4
	test -n "$__nrouters" || export __nrouters=1

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##
## Tests;
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
		local t=$1
		shift
        test_$t $@
    else
		test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}
##   test start_empty
##     Start empty cluster. K8s nodes will be "NotReady".
test_start_empty() {
	test -n "$xcluster_CALICO_BACKEND" || export xcluster_CALICO_BACKEND=none
	tlog "CALICO_BACKEND=$xcluster_CALICO_BACKEND"
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology k8s-cni-calico $@
	otc 1 check_namespaces
	if echo "$xcluster_PROXY_MODE" | grep -qi disable; then
		kubectl create -n kube-system -f $dir/default/etc/kubernetes/calico/apiserver-configmap.yaml
		otcwp restart_kubelet
	fi
	otc 1 check_nodes
}
##   test start
##     Start cluster with Calico. The "linux" data-plane is default.
test_start() {
	test -n "$xcluster_CALICO_BACKEND" || export xcluster_CALICO_BACKEND=legacy
	test_start_empty $@
	otcr vip_routes
}
##   test start_vpp
##     Start cluster with the VPP data-plane
test_start_vpp() {
	#export xcluster_PROXY_MODE=disabled
	export xcluster_CALICO_BACKEND=operator+install-vpp
	export __mem=2G
	export __mem1=3G
	test_start_empty $@
	otcr vip_routes
}
##   test start_bpf
##     Start cluster with the eBPF data-plane. Kube-proxy is disabled.
test_start_bpf() {
	export xcluster_PROXY_MODE=disabled
	export xcluster_CALICO_BACKEND=bpf
	test_start_empty $@
	otcr vip_routes
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
