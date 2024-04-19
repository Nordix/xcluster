#! /bin/sh
##
## kubeadm.sh --
##
##   Help script for the xcluster ovl/kubeadm.
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
	echo "$*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test "$envset" = "yes" && return 0
	envset=yes
	test -n "$__nvm" || __nvm=4
	test -n "$__nrouters" || __nrouters=1
	test -n "$__k8sver" || __k8sver=v1.30.0
	export __k8sver
	test -n "$__cni" || __cni=bridge
	export __mem1=2048
	export __mem=1536
	export xcluster_DOMAIN=cluster.local
	test -n "$PREFIX" || PREFIX=fd00:
	export xcluster_PREFIX=$PREFIX
	export xcluster_DOMAIN=cluster.local
	if test "$cmd" = "env"; then
		local opt="k8sver|nvm|nrouters|cni|mem|mem1"
		set | grep -E "^(__($opt)|xcluster_.*)="
		exit 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
	test -n "$KUBERNETESD" || \
		export KUBERNETESD=$HOME/tmp/kubernetes/kubernetes-$__k8sver/server/bin	
	kubeadm=$KUBERNETESD/kubeadm
	test -x $kubeadm || tdie "Not executable [$kubeadm]"
}
##   cache_images
##     Download the K8s release images to the local private registry.
cmd_cache_images() {
	cmd_env
	local i images
	images=$($XCLUSTER ovld images)/images.sh
	for i in $($kubeadm config images list --kubernetes-version $__k8sver); do
		if $images lreg_isloaded $i; then
			log "Already cached [$i]"
		else
			$images lreg_cache $i || die
			log "Cached [$i]"
		fi
	done
}

##
##   test [--xterm] [test...] > logfile
##     Exec tests
cmd_test() {
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
##     Just install and stop
test_default() {
	test_start
	xcluster_stop
}

##   test start_empty
##     Start an empty cluster, but with crio and kubeadm
test_start_empty() {
	cmd_env
	cmd_cache_images 2>&1
	export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
	unset BASEOVLS
	unset XOVLS
	if test "$__hugep" = "yes"; then
		local n
		for n in $(seq $FIRST_WORKER $__nvm); do
			eval export __append$n="hugepages=128"
		done
	fi
	xcluster_start network-topology test crio iptools private-reg k8s-cni-$__cni . $@
	test "$__hugep" = "yes" && otcwp mount_hugep
}
##   test [--k8sver] start 
##     Start a cluster and install K8s using kubeadm
test_start() {
	test_start_empty $@

	otc 1 "pull_images $__k8sver"
	otc 1 "init_dual_stack $__k8sver"
	otc 1 check_namespaces
	otc 1 rm_coredns_deployment
	otc 1 install_cni

	for i in $(seq 2 $__nvm); do
		otc $i join
		otc $i coredns_k8s
		otc $i get_kubeconfig
	done

	otc 1 "check_nodes $__nvm"
	otc 1 check_nodes_ready
}
##   test [--wait] start_app
##     Start with a tserver app. This requires ovl/k8s-test
test_start_app() {
	$XCLUSTER ovld k8s-test > /dev/null 2>&1 || tdie "No ovl/k8s-test"
	__nrouters=1
	__hugep=yes
	export KUBEADM_TEST=yes
	test_start k8s-test mconnect $@

	otcprog=k8s-test_test
	test "$__wait" = "yes" && otc 1 wait
	otc 1 "svc tserver 10.0.0.0"
	otc 1 "deployment --replicas=$__replicas tserver"
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
