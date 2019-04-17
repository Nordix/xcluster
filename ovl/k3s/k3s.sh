#! /bin/sh
##
## k3s.sh --
##
##   Test script for k3s in xcluster.
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

##   mkpreload [--tar=file] [images...]
##     Create a tar-file with images to be pre-loaded (air-gap).
##
cmd_mkpreload() {
	eval $($XCLUSTER env)
	test -n "$__tar" || __tar=$XCLUSTER_TMP/k3s-preload.tar
	docker save -o $__tar \
		k8s.gcr.io/pause:3.1 docker.io/coredns/coredns:1.3.0 \
		docker.io/library/alpine:3.8 $@
	echo "Created; $__tar"
}

##   mkhd [--k3s-image=file]
##     Create an xcluster image with k3s.
##
cmd_mkhd() {
	test -n "$__k3s_image" || __k3s_image=/tmp/tmp/hd-k3s.img
	export __image=$__k3s_image
	rm -f $__image
	cmd_mkpreload || die
	export __tar
	$XCLUSTER mkimage || die
	$XCLUSTER ximage xnet iptools k3s externalip || die
	echo "Use; xc start --image=$__image"
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
	export __image=$XCLUSTER_HOME/hd.img

	start=starts
	test "$__xterm" = "yes" && start=start

	# Remove overlays
	rm -f $XCLUSTER_TMP/cdrom.iso
	
	if test -n "$1"; then
		for t in $@; do
			test_$t
		done
	else
		for t in basic ipv6; do
			test_$t
		done
	fi	

	now=$(date +%s)
	tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

test_basic() {
	if test -n "$__k3s_image" -a -r "$__k3s_image"; then
		# We have a pre-built image. Install only test programs
		tcase "Build system with pre-installed image"
		export __image=$__k3s_image
		K3S_TEST=only $XCLUSTER mkcdrom test k3s k3s-private-reg mserver k3s
	else
		tcase "Build system"
		K3S_TEST=yes $XCLUSTER mkcdrom \
			test xnet iptools k3s k3s-private-reg externalip mserver
	fi

	tcase "Start system"
	$XCLUSTER $start
	sleep 2
	tex check_vm || tdie

	otc 1 check_k3s_server
	otc 2 check_k3s_agent
	otc 3 check_k3s_agent
	otc 4 check_k3s_agent

	otc 2 "check_coredns 10.43.0.10 10.43.0.1"

	otc 1 start_mserver

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
}

test_ipv6() {
	tcase "Build system for ipv6"
	K3S_TEST=test SETUP=ipv6 $XCLUSTER mkcdrom \
		test xnet iptools k3s k3s-private-reg externalip mserver

	tcase "Start system"
	$XCLUSTER $start
	sleep 2
	tex check_vm || tdie

	otc 1 check_k3s_server
	otc 2 check_k3s_agent
	otc 3 check_k3s_agent
	otc 4 check_k3s_agent

	otc 2 "check_coredns fd00:4000::10 fd00:4000::1"

	otc 1 start_mserver

	test "$__no_stop" = "yes" && return 0
	tcase "Stop xcluster"
	$XCLUSTER stop
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
