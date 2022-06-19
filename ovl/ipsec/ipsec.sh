#! /bin/sh
##
## sctp.sh --
##
##   Help script for the xcluster ovl/sctp.
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
	test -n "$__strongswan_ver" || __strongswan_ver=strongswan-5.9.6
	test -n "$__tag" || __tag="registry.nordix.org/cloud-native/ipsec:latest"
	test -n "$STRONGSWAN_WORKSPACE" || STRONGSWAN_WORKSPACE=/tmp/$USER/strongswan

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
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
	rm -f $($XCLUSTER ovld ipsec)/captures/*.pcap
	#export xcluster_PROXY_MODE=iptables

    if test -n "$1"; then
        for t in $@; do
            test_$t
        done
    else
		test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	. ./network-topology/Envsettings

	__image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
	test -r $__image || __image=$XCLUSTER_HOME/hd-k8s.img
	export __image
	test -r $__image || die "Not readable [$__image]"

	xcluster_start iptools network-topology ipsec

	otc 1 check_namespaces
	otc 1 check_nodes

	otc 1 "start_tcpdump eth1"
	otc 2 "start_tcpdump eth1"
	otc 221 "start_tcpdump eth1"

	# Setup ECMP routes to load balance traffic towards 
	# worker VMs (vm001 and vm002)
	otc 201 "vip_route 192.168.1.2"
	otc 1 deploy_ipsec_pods
	otc 221 initiate
	local __wait=120
	tlog "Wait $__wait seconds for IKE/CHILD SAs to be setup"
	sleep $__wait
	otc 221 initiator_list_sas
	otc 2 responder_list_sas

	otc 1 stop_all_tcpdump
	otc 2 stop_all_tcpdump
	otc 221 stop_all_tcpdump

	rcp 1 /var/log/*.pcap captures/
	rcp 2 /var/log/*.pcap captures/
	rcp 221 /var/log/*.pcap captures/
}

##
##   STRONGSWAN_WORKSPACE=/tmp/$USER/strongswan [--force] build
##     Unpack and build strongswan at $STRONGSWAN_WORKSPACE
cmd_build() {
	cmd_env
	test "$__force" = "yes" && rm -rf $STRONGSWAN_WORKSPACE
	mkdir -p "$STRONGSWAN_WORKSPACE" || die mkdir
	if test -x $STRONGSWAN_WORKSPACE/usr/local/sbin/ipsec; then
		log "Already built [$STRONGSWAN_WORKSPACE/usr/local/]"
		return 0
	fi
	local ar=$ARCHIVE/$__strongswan_ver.tar.gz
	test -r $ar || ar=$HOME/Downloads/$__strongswan_ver.tar.gz
	test -r $ar || die "Not readable [$ar]"
	tar -C $STRONGSWAN_WORKSPACE -xf $ar || die tar
	cd $STRONGSWAN_WORKSPACE/$__strongswan_ver
	./configure --enable-static-bin --disable-systemd \
		--with-systemdsystemunitdir=no  || die configure
	make -j$(nproc) || die make
	DESTDIR=$STRONGSWAN_WORKSPACE make install
}

##   mkimage [--tag=registry.nordix.org/cloud-native/ipsec:latest]
##     Create the docker image and upload it to the local registry.
cmd_mkimage() {
	cmd_env
	local imagesd=$($XCLUSTER ovld images)
	$imagesd/images.sh mkimage --force --upload --strip-host --tag=$__tag $dir/image
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
