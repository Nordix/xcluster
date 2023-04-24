#! /bin/sh
##
## etcd.sh --
##
##   Help script for the xcluster ovl/etcd.
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
##   env
##     Print environment.
cmd_env() {
	test "$env" = "yes" && return 0
	env=yes

	urlbase=https://github.com/coreos/etcd/releases/download
	etcd_ver=v3.5.8

	if test "$cmd" = "env"; then
		set | grep -E '^(urlbase|etcd_ver)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   download
cmd_download() {
	cmd_env
	local ar=etcd-$etcd_ver-linux-amd64.tar.gz
	if findf $ar; then
		log "Already downloaded at [$f]"
		return 0
	fi
	curl -L $urlbase/$etcd_ver/$ar > $f || die "Download failed"
}
##   etcd [out-dir]
##     Extract etcdctl and etcd
cmd_etcd() {
	cmd_env
	local o=.
	test -n "$1" && o=$1
	test -d $o || die "Not a directory [$o]"
	findf etcd-$etcd_ver-linux-amd64.tar.gz || die "Not found [$f]"
	mkdir -p $tmp
	local d=etcd-$etcd_ver-linux-amd64
	tar -C $tmp -xf $f $d/etcdctl $d/etcd
	cp $tmp/$d/* $o
}
##   archive
##     Print the tar-file path or die
cmd_archive() {
	cmd_env
	findf etcd-$etcd_ver-linux-amd64.tar.gz || die "Not found [$f]"
	echo $f
}
##
##   test [--xterm] [--no-stop] test <test-name> [ovls...] > $log
##   test [--xterm] [--no-stop] > $log   # default test
##     Exec tests
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
		t=$1
		shift
        test_$t $@
    else
        test_basic
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test [--ipv6] start
##     Start cluster
test_start() {
	test -n "$__nvm" || __nvm=1
	test -n "$__nrouters" || __nrouters=0
	test -n "$__ipv6" && export __ipv6
	export TEST=yes
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology . $@
	otc 1 version
}
##   test basic (default)
##     Just start and stop
test_basic() {
	test_start $@
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
