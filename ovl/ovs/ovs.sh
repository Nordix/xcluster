#! /bin/sh
##
## ovs.sh --
##
##   Help script for xcluster ovl/ovs.
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
##
cmd_env() {

	test -n "$SYSD" || SYSD=$XCLUSTER_WORKSPACE/sys
	if test "$cmd" = "env"; then
		set | grep -E '^(__.*|SYSD)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   build [--dest=$GOPATH/src/github.com/openvswitch]
##     Clone/pull and build OVS.
cmd_build() {
	cmd_env
	test -n "$__dest" || __dest=$GOPATH/src/github.com/openvswitch
	if test -d $__dest/ovs; then
		cd $__dest/ovs
		git pull
	else
		mkdir -p $__dest || die "mkdir $__dest"
		cd $__dest
		git clone --depth 1 https://github.com/openvswitch/ovs.git \
			|| die "git clone"
		cd $__dest/ovs
	fi

	local bpflibd=$(readlink -f $__kobj/source)/tools/lib/bpf/root/usr
	./boot.sh
	if test -d $bpflibd; then
		LDFLAGS=-L$bpflibd/lib64 CPPFLAGS=-I$bpflibd/include \
			./configure --enable-afxdp
	else
		./configure
	fi
	make -j$(nproc) || die make
	make DESTDIR=$SYSD install || die "make install"
	if test -d $bpflibd; then
		log "Building with XDP support"
	else
		log "Building WITHOUT XDP support"
	fi
}

##   man [command]
##     Show a ovs man-page. List if no command is specified.
cmd_man() {
	cmd_env
	MANPATH=$SYSD/usr/local/share/man
	if test -z "$1"; then
		local f
		mkdir -p $tmp
		for f in $(find $MANPATH -type f); do
			basename $f >> $tmp/man
		done
		cat $tmp/man | sort | column
		return 0
	fi
	export MANPATH
	xterm -bg '#ddd' -fg '#222' -geometry 80x45 -T $1 -e man $1 &
}

##
##   test --list
##   test [--xterm] [--no-stop] [test...] > logfile
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
##   test start_empty - Start an empty cluster
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	test -n "$__nrouters" || export __nrouters=0
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools netns ovs
	otc 1 version
}
##   test start (default) - Start with PODs, and veth's (no bridge)
test_start() {
	test_start_empty
	otcw create_netns
	otcw create_veth
}
##   test L2 - Setup an L2 network without VETH's and test with ping
test_L2() {
	tlog "=== ovs: L2 network without VETH's"
	test -n "$xcluster_PODIF" || export xcluster_PODIF=hostname
	test_start_empty
	otcw create_bridge
	otcw create_netns
	otcw add_ports
	otc 1 ping_all
	xcluster_stop
}

##   test basic_flow - Setup OpenFlow between 2 PODs on vm-001
test_basic_flow() {
	tlog "=== ovs: Basic OpenFlow"
	test -n "$__nvm" || export __nvm=1
	test_start
	otc 1 "noarp --mac=0:0:0:0:0:1 vm-001-ns01"
	otc 1 "noarp --mac=0:0:0:0:0:1 vm-001-ns02"
	$XCLUSTER tcpdump --start 1 vm-001-ns01
	$XCLUSTER tcpdump --start 1 vm-001-ns02
	otc 1 create_ofbridge
	otc 1 attach_veth
	otc 1 "ping_negative --pod=vm-001-ns02 172.16.1.1"
	tcase "Sleep 4s ..."; sleep 4
	otc 1 "flow_connect_pods vm-001-ns01 vm-001-ns02"
	otc 1 "ping --pod=vm-001-ns02 172.16.1.1"
	otc 1 "ping --pod=vm-001-ns02 1000::1:172.16.1.1"
	tcase "Sleep 1s ..."; sleep 1
	$XCLUSTER tcpdump --get 1 vm-001-ns01 >&2
	$XCLUSTER tcpdump --get 1 vm-001-ns02 >&2
	xcluster_stop
}

##   test load_balancing - Setup and test load-balancing with OpenFlow
test_load_balancing() {
	tlog "=== ovs: OpenFlow load-balancing"
	test -n "$__nvm" || export __nvm=1
	test_start
	otc 1 "create_ofbridge --configure --mac=0:0:0:0:0:1"
	otc 1 "attach_veth --noarp --mac=0:0:0:0:0:1"
	otc 1 "add_vip 10.0.0.0"
	otc 1 add_lbgroup
	otc 1 flow_pod_to_bridge
	otc 1 mconnect_server
	otc 1 "mconnect 10.0.0.0"
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
