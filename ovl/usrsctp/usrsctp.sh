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

	test -n "$__tag" || __tag="registry.nordix.org/cloud-native/usrsctp-test:latest"

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

	xcluster_prep
	xcluster_start iptools network-topology usrsctp

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 221 start_server

	otc 201 vip_ecmp_route
	otc 202 "vip_ecmp_route 2"

	otc 2 "start_tcpdump eth1"
	otc 2 "start_tcpdump eth2"
	otc 221 "start_tcpdump eth1"
	otc 221 "start_tcpdump eth2"

	otc 1 deploy_test_pods
	tlog "Sleep for 30 seconds for the client to finish"
	sleep 30
	#otc 1 start_client_interactive

	otc 2 stop_all_tcpdump
	otc 221 stop_all_tcpdump

	sleep 10

	rcp 2 /var/log/*.pcap captures/
	rcp 221 /var/log/*.pcap captures/
}

##   nfqlb_download
##     Download a nfqlb release to $ARCHIVE
cmd_nfqlb_download() {
	eval $(make -s -C $dir/src ver)
	local ar=nfqlb-$NFQLB_VER.tar.xz
	local f=$ARCHIVE/$ar
	if test -r $f; then
		log "Already downloaded [$f]"
	else
		local url=https://github.com/Nordix/nfqueue-loadbalancer
		curl -L $url/releases/download/$NFQLB_VER/$ar > $f
	fi
}

##   mkimage [--tag=registry.nordix.org/cloud-native/sctp-test:latest]
##     Create the docker image and upload it to the local registry.
##
cmd_mkimage() {
	cmd_env
	mkdir -p $dir/image/default/bin
	make -C $dir/src clean
	make -j$(nproc) -C $dir/src X=$dir/image/default/bin/usrsctpt static
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
