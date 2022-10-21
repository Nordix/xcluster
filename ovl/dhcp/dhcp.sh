#! /bin/sh
##
## dhcp.sh --
##
##   Help script for the xcluster ovl/dhcp.
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
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$ARCHIVE" || ARCHIVE=$HOME/Downloads
	test -n "$__iscver" || __iscver=4.4.3-P1
	test -n "$__radvdver" || __radvdver=2.19
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   radvd_download
cmd_radvd_download() {
	cmd_env
	local ar=radvd-$__radvdver.tar.xz
	if test -s $ARCHIVE/$ar; then
		echo "Already downloaded [$ARCHIVE/$ar]"
		return 0
	fi
	local base=https://github.com/radvd-project/radvd/releases/download
	local url=$base/v$__radvdver/$ar
	curl -L $url > $ARCHIVE/$ar || die curl
}
##   radvd_build
cmd_radvd_build() {
	cmd_env
	local d=$XCLUSTER_WORKSPACE/radvd-$__radvdver
	test "$__force" = "yes" && rm -rf $d
	local x=$d/sys/usr/local/sbin/radvd
	if test -x $x; then
		echo "Already built [$x]"
		return 0
	fi
	cmd_radvd_download
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/radvd-$__radvdver.tar.xz
	cd $d
	./configure || die configure
	make -j$(nproc) || die make
	make DESTDIR=$d/sys install || die "make install"
}
##   radvd_binary
cmd_radvd_binary() {
	cmd_env
	local d=$XCLUSTER_WORKSPACE/radvd-$__radvdver
	local x=$d/sys/usr/local/sbin/radvd
	test -x $x || die "Not executable [$x]"
	echo $x
}
##   radvd_man [page]
##     Displays a radvd man page
cmd_radvd_man() {
	cmd_env
	export MANPATH=$XCLUSTER_WORKSPACE/radvd-$__radvdver/sys/usr/local/share/man
	if test -n "$1"; then
		xterm -bg '#ddd' -fg '#222' -geometry 80x43 -T $1 -e man $1 &
		return 0
	fi
	local f
	mkdir -p $tmp
	for f in $(find $MANPATH -maxdepth 2 -mindepth 2); do
		basename $f >> $tmp/man
	done
	cat $tmp/man | sort | column			
}
##   isc_download
##     Download the ISC DHCP server
cmd_isc_download() {
	cmd_env
	local base=https://downloads.isc.org/isc/dhcp
	local url=$base/$__iscver/dhcp-$__iscver.tar.gz
	local ar=$ARCHIVE/dhcp-$__iscver.tar.gz
	if test -s $ar; then
		echo "Already downloaded [$ar]"
		return 0
	fi
	curl -L $url > $ar || die "curl -L $url"
}
##   isc_build [--force]
##     Download, unpack and build
cmd_isc_build() {
	cmd_env
	local dir=$XCLUSTER_WORKSPACE/dhcp-$__iscver
	test "$__force" = "yes" && rm -rf $dir
	local x=$dir/sys/usr/sbin/dhcpd
	if test -x $x; then
		echo "Already built [$x]"
		return 0
	fi
	if ! test -d $dir; then
		cmd_isc_download
		local ar=$ARCHIVE/dhcp-$__iscver.tar.gz
		tar -C $XCLUSTER_WORKSPACE -xf $ar || die
	fi
	cd $dir
	./configure || die configure
	make -j$(nproc) || die make
	make DESTDIR=$dir/sys install || die "make install"
}
##   isc_man [page]
##     Displays a ISC man page
cmd_isc_man() {
	cmd_env
	export MANPATH=$XCLUSTER_WORKSPACE/dhcp-$__iscver/sys/usr/share/man
	if test -n "$1"; then
		xterm -bg '#ddd' -fg '#222' -geometry 80x43 -T $1 -e man $1 &
		return 0
	fi
	local f
	mkdir -p $tmp
	for f in $(find $MANPATH -maxdepth 2 -mindepth 2); do
		basename $f >> $tmp/man
	done
	cat $tmp/man | sort | column			
}

##   isc_binary
##     Print the "dhcpd" binary or die trying
cmd_isc_binary() {
	cmd_env
	local dir=$XCLUSTER_WORKSPACE/dhcp-$__iscver
	local x=$dir/sys/usr/sbin/dhcpd
	test -x $x || die "Not executable [$x]"
	echo $x
}

##
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
        for t in $@; do
            test_$t
        done
    else
        test_basic
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	export TOPOLOGY=multilan-router
	. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools dhcp $@
	otc 1 version
}

##   test start
##     Start cluster and setup
test_start() {
	test_start_empty $@
	otc 202 "ifup eth3 eth4 eth5"
	otcw "ifup eth2 eth3 eth4"
}
##   test udhcp
##     Setup a udhcpd on vm-202 and acquire IPv4 address
test_udhcp() {
	tlog "=== Setup a udhcpd on vm-202 and acquire IPv4 address"
	test_start
	otc 202 "udhcpd4 eth3"
	otc 1 "acquire4 eth2"
	xcluster_stop
}
##   test [--mask=120] basic (default)
##     Setup a ISC dhcpd on vm-202 and acquire addresses
test_basic() {
	tlog "=== Setup a ISC dhcpd on vm-202 and acquire addresses"
	test_start
	test -n "$__mask" || __mask=120
	otc 202 "dhcpd --mask=$__mask eth3"
	otc 1 "acquire4 eth2"
	#$XCLUSTER tcpdump --start 2 eth2; sleep 1
	otc 2 "acquire6 --mask=$__mask eth2"
	#sleep 1; $XCLUSTER tcpdump --get 2 eth2 >&2
	xcluster_stop
}
##   test all_nets
##     Setup a ISC dhcpd and acquire addresses on all networks
test_all_nets() {
	tlog "=== Setup a ISC dhcpd and acquire addresses on all networks"
	test_start
	otc 202 "dhcpd --mask=120 eth3"
	otc 202 "dhcpd --mask=120 eth4"
	otc 202 "dhcpd --mask=120 eth5"
	otcw "acquire4 eth2"
	otcw "acquire6 --mask=120 eth2"
	otcw "acquire4 eth3"
	otcw "acquire6 --mask=120 eth3"
	otcw "acquire4 eth4"
	otcw "acquire6 --mask=120 eth4"
	xcluster_stop
}
##   test radvd
##     Use radvd to send router advertisement
test_radvd() {
	tlog "=== Use radvd to send router advertisement"
	test_start
	otc 202 "radvd_start --mask=64 eth4"
	otcw "slaac eth3"
	xcluster_stop
}
##   test dhcpv6
##     Use DHCPv6 and RA to setup /120 addresses
test_dhcpv6() {
	tcase "Use DHCPv6 and RA to setup /120 addresses"
	test_start
	test -n "$__mask" || __mask=120
	otc 202 "radvd_start --mask=$__mask eth3"
	tcase "Sleep 2..."; sleep 2
	otc 202 "dhcpd --mask=$__mask eth3"
	otc 1  "acquire6 eth2"
	xcluster_stop
}
##   test cni_bridge
##     DHCP and SLAAC with the bridge CNI-plugin
test_cni_bridge() {
	tcase "DHCP and SLAAC with the bridge CNI-plugin"
	test_start netns
	otc 202 "radvd_start --mask=64 eth3"
	otc 202 "dhcpd eth3"
	otc 1 netns
	otc 1 "bridge_create eth2"
	otc 1 "bridge_config eth2"
	otc 1 "bridge_start eth2"
	otc 1 "bridge_check_slaac eth2"
	xcluster_stop
}


. $($XCLUSTER ovld test)/default/usr/lib/xctest
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
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
