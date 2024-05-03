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
	echo "$*" >&2
}
findf() {
	f=$ARCHIVE/$1
	test -r $f && return 0
	f=$HOME/Downloads/$1
	test -r $f
}

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__multus_ver" || __multus_ver=4.0.2
    test -n "$__tag" || __tag="registry.nordix.org/cloud-native/multus-installer"

	if test "$cmd" = "env"; then
		local opt="multus_ver|whereabouts_ver"
		set | grep -E "^(__($opt))="
		exit 0
	fi

	test -n "$long_opts" && export $long_opts
	multus_ar=multus-cni_${__multus_ver}_linux_amd64.tar.gz
	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   cparchives <dest>
##     Copy cni-plugin and multus archives to <dest>
cmd_cparchives() {
	test -n "$1" || die "No dest"
	test -d "$1" || die "Not a directory [$1]"
	local cnish=$($XCLUSTER ovld cni-plugins)/cni-plugins.sh
	test -x $cnish || die "Not executable [$cnish]"
	$cnish archive > /dev/null || die
	findf $multus_ar || die "Not found [$multus_ar]"
	cp $f $($cnish archive) $1
}
##   mkimage [--tag=]
##     Create the docker image and upload it to the local registry.
cmd_mkimage() {
    cmd_env
    local imagesd=$($XCLUSTER ovld images)
    $imagesd/images.sh mkimage --force --upload --tag=$__tag:$__multus_ver $dir/image
	docker tag $__tag:$__multus_ver $__tag:latest
	$imagesd/images.sh lreg_upload $__tag:latest
}

##
##   test --list
##   test [--xterm] [test...] > logfile
##     Exec tests
##
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
##   test [--cni=] default
##     Combo test
test_default() {
	export __cni
	$me test ipvlan $@ || die ipvlan
	$me test ipvlanl3 $@ || die ipvlanl3
}
##   test [--cni=] start
##     Start with Multus. If --cni= is specified the multus-install
##     method is used
test_start() {
	# Pre-checks
	findf $multus_ar || die "Not found [$multus_ar]"
	export TOPOLOGY=multilan-router
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	local cni_overlay
	export MULTUS_TEST=yes
	if test -n "$__cni"; then
		cni_overlay=k8s-cni-$__cni
		test "$__cni" != "bridge" && export MULTUS_TEST=image
		# (the xcluster specific "bridge" cni-plugin has no image)
	fi
	xcluster_start . network-topology $cni_overlay $@

	otc 1 check_namespaces
	test "$MULTUS_TEST" != "image" && otc 1 multus_crds
	otc 1 check_nodes
	otcr vip_routes
	otcwp "ifup eth2"
	otcwp "ifup eth3"
	otcwp "ifup eth4"
	test "$MULTUS_TEST" = "image" && otc 1 "image --ver=$__multus_ver"
}
##   test ipvlan
##     Test with pods with an extra "ipvlan1" interface
test_ipvlan() {
	test_start $@
	otc 1 crds
	otc 1 "deployment alpine-ipvlan"
	otc 1 "check_interfaces --label=alpine-ipvlan ipvlan1"
	otc 1 "collect_addresses --label=alpine-ipvlan ipvlan1"
	otc 1 "ping --label=alpine-ipvlan"
	xcluster_stop
}
##   test multiif
##     Test with multiple extra interfaces: ipvlan, macvlan and host-device
test_multiif() {
	test_start $@
	otc 1 crds
	otc 1 "daemonset multus-alpine"
	otc 1 "check_interfaces --label=multus-alpine net1 net2 net3"
	otc 1 "collect_addresses --label=multus-alpine net1"
	otc 1 "ping --label=multus-alpine"
	otc 1 "collect_addresses --label=multus-alpine net2"
	otc 1 "ping --label=multus-alpine"
	otc 1 "collect_addresses --label=multus-alpine net3"
	otc 1 "ping --label=multus-alpine"
	xcluster_stop
}
##   test bridge
##     Test with cni-plugin bridge and the "kube-node" ipam
test_bridge() {
	test_start $@
	otc 1 crds
	otcw "annotate --addr=16.0.0.0 --annotation=kube-node.nordix.org/bridge1"
	otc 1 "deployment multus-alpine-bridge"
	otc 1 "check_interfaces --label=multus-alpine-bridge net1"
	xcluster_stop
}
##   test ipvlanl3
##     Test with cni-plugin ipvlan in "l3" mode, and the "kube-node" ipam
test_ipvlanl3() {
	test_start $@
	otc 1 crds
	otcw "annotate --addr=17.0.0.0 --annotation=kube-node.nordix.org/ipvlanl3"
	otc 1 "deployment alpine-ipvlanl3"
	otc 1 "check_interfaces --label=alpine-ipvlanl3 net1"
	otc 1 "collect_addresses --label=alpine-ipvlanl3 net1"
	otcwp "local_ipvlan --addr=17.0.0.0"
	otcwp "node_addr --net=3 eth2"
	otcwp "node_routing --addr=17.0.0.0 --net=3 eth2"
	otc 1 "routing --label=alpine-ipvlanl3 net1"
	otc 1 "collect_addresses --label=alpine-ipvlanl3 net1"
	otc 1 "ping --label=alpine-ipvlanl3"
	xcluster_stop
}
##   test --cni= upgrade
##     Upgrade the multus-install image. --cni is mandatory
test_upgrade() {
	test -n "$__cni" || tdie "--cni must be specified"
	test_start
	otc 1 "image --ver=3.9.2"
	otc 1 "image --ver=latest"
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
