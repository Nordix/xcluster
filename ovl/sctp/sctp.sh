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

	test -n "$__tag" || __tag="registry.nordix.org/cloud-native/sctp-test:latest"

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

test_start_k8s() {
	test -n "$__mode" || __mode=dual-stack
	export xcluster___mode=$__mode
	export TOPOLOGY=dual-path
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	
	xcluster_prep $__mode
	xcluster_start sctp iptools network-topology

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 1 start_servers
	otc 201 vip_ecmp_route
	otc 203 "vip_route 192.168.3.201"
}

test_start() {
	export TOPOLOGY=dual-path
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start iptools network-topology sctp

	otc 201 vip_ecmp_route
	otc 203 "vip_route 192.168.3.201"
	otc 202 "vip_ecmp_route 4"
	otc 204 "vip_route 192.168.5.202"
}


test_nfqlb() {
	test_start
	otc 201 nfqlb_setup
	otc 202 nfqlb_setup
	xcluster_stop
}

##   nfqlb_download
##     Download a nfqlb release to $HOME/Downloads
cmd_nfqlb_download() {
	eval $(make -s -C $dir/src ver)
	local ar=nfqlb-$NFQLB_VER.tar.xz
	local f=$HOME/Downloads/$ar
	if test -r $f; then
		log "Already downloaded [$f]"
	else
		local url=https://github.com/Nordix/nfqueue-loadbalancer
		curl -L $url/releases/download/$NFQLB_VER/$ar > $f
	fi
}

##   pcap2html <file.pcap>
##     Convert pcap to html on stdout
cmd_pcap2html() {
	test -n "$1" || die "No file"
	test -r "$1" || die "Not readable [$1]"
	local xsl=/usr/share/wireshark/pdml2html.xsl
	test -r $xsl || die "Not readable [$xsl]"
	mkdir -p $tmp
	tshark -I -T pdml -r "$1" | xsltproc $xsl - | \
		sed -e "s,<title>.*<,<title>$1<,"
}

##   mkimage [--tag=registry.nordix.org/cloud-native/sctp-test:latest]
##     Create the docker image and upload it to the local registry.
##
cmd_mkimage() {
	cmd_env
	mkdir -p $dir/image/default/bin
	make -C $dir/src clean
	make -j$(nproc) -C $dir/src X=$dir/image/default/bin/sctpt static
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
