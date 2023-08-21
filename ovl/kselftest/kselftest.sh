#! /bin/sh
##
## kselftest.sh --
##
##   Help script for the xcluster ovl/kselftest.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$
netsniff_url=https://github.com/netsniff-ng/netsniff-ng/archive/refs/tags/
netsniff_ver=0.6.8
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

cmd_mz() {
	echo $XCLUSTER_WORKSPACE/netsniff-ng-$netsniff_ver/mausezahn/mausezahn
}

##  download
##    Download/unpack; mausezahn.
##
cmd_netsniff_download() {
	ar=netsniff-v$netsniff_ver.tar.gz
	url=$netsniff_url/v$netsniff_ver.tar.gz

	if [ -f $ARCHIVE/$ar ]; then
		log "Already downloaded"
	else
		curl -L $url > $ARCHIVE/$ar
	fi

	if [ -d $XCLUSTER_WORKSPACE/netsniff-ng-$netsniff_ver ]; then
		log "Already unpacked"
	else
		tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	fi
}

##  build
##    Build mausezahn
##
cmd_netsniff_build() {
	cmd_env

	d=$XCLUSTER_WORKSPACE/netsniff-ng-$netsniff_ver
	cd $d || die "Download netsniff first"
	if [ -f $d/mausezahn/mausezahn ]; then
		log "Already built"
	else
		export TOOLS="mausezahn"
		./configure
		make
	fi
}

##  env
##    Print environment.
##
cmd_env() {
	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
	sysd=$XCLUSTER_WORKSPACE/sys
	export PKG_CONFIG_PATH=$sysd/usr/lib/pkgconfig
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
	tlog "=== kselftest, kernel $__kbin"
	test -n "$__image" || export __image=$XCLUSTER_HOME/hd.img
	export __mem=512
	export __nrouters=0
	export __nvm=1

	if test -n "$TOPOLOGY"; then
		export xcluster_TOPOLOGY=$TOPOLOGY
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	fi
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	xcluster_start network-topology iptools linux-tools bash $@ kselftest
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
