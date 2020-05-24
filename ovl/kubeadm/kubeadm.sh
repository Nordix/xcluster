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
	echo "$prg: $*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__nvm" || __nvm=4
	test -n "$__k8sver" || __k8sver=v1.18.2
	export __k8sver
	test -n "$__cni" || __cni=xcluster
	export __mem1=2048
	export __mem=1536
	export __cluster_domain=cluster.local
	export xcluster_DOMAIN=cluster.local
	if test "$cmd" = "env"; then
		set | grep -E '^(__.*|xcluster_.*)='
		return 0
	fi
	
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
	export KUBERNETESD=$HOME/tmp/kubernetes/kubernetes-$__k8sver/server/bin	
	kubeadm=$KUBERNETESD/kubeadm
	test -x $kubeadm || tdie "Not executable [$kubeadm]"
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
        for t in test_template; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	cmd_env
	cmd_cache_images 2>&1
	export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
	unset BASEOVLS
	unset XOVLS
	xcluster_start xnet crio images iptools kubeadm private-reg k8s-cni-$__cni $@
}

test_start_ipv4() {
	export SETUP=ipv4
	test_start $@
}

test_install() {
	tlog "=== kubeadm: Install k8s $__k8sver"
	test_start $@

	otc 1 "pull_images $__k8sver"
	otc 1 "init_dual_stack $__k8sver"
	otc 1 check_namespaces
	otc 1 rm_coredns_deployment
	otc 1 install_cni
	otc 1 coredns_k8s

	for i in $(seq 2 $__nvm); do
		otc $i join
		otc $i coredns_k8s
	done

	otc 1 "check_nodes $__nvm"
	otc 1 check_nodes_ready
	otc 1 untaint_master

	xcluster_stop
}

test_install_ipv4() {
	tlog "=== kubeadm: Install k8s ipv4-only $__k8sver"
	test_start_ipv4 $@

	otc 1 "pull_images $__k8sver"
	otc 1 "init_ipv4 $__k8sver"
	otc 1 check_namespaces
	otc 1 rm_coredns_deployment
	otc 1 install_cni
	otc 1 coredns_k8s
	
	for i in $(seq 2 $__nvm); do
		otc $i join
		otc $i coredns_k8s
	done

	otc 1 "check_nodes $__nvm"
	otc 1 check_nodes_ready
	otc 1 untaint_master

	xcluster_stop
}

test_test_template() {
	push __no_stop yes
	test_install test-template mconnect
	pop __no_stop
	subtest test-template basic_dual
}

test_test_template4() {
	push __no_stop yes
	test_install_ipv4 test-template mconnect
	pop __no_stop
	subtest test-template basic4
}

test_mserver() {
	push __no_stop yes
	test_install mserver mconnect
	pop __no_stop
	subtest mserver basic_dual
}

test_mserver4() {
	push __no_stop yes
	test_install_ipv4 mserver mconnect
	pop __no_stop
	subtest mserver basic4
}

subtest() {
	local ovl=$1
	shift
	local x=$($XCLUSTER ovld $ovl)/${ovl}.sh
	test -x $x || tdie "Not executable [$x]"
	$x test --cluster-domain=cluster.local --no-start --no-stop=$__no_stop $@
}

##   cache_images
##     Download the K8s release images to the local private registry.
##
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
