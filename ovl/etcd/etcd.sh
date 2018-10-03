#! /bin/sh
##
## etcd.sh --
##
##   Help script for the "etcd" ekvm-ovl.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$

die() {
    echo "ERROR: $*" >&2
    rm -rf $tmp
    exit 1
}
help() {
    grep '^##' $0 | cut -c3-
	test -r $hook && grep '^##' $hook | cut -c3-
    rm -rf $tmp
    exit 0
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

urlbase=https://github.com/coreos/etcd/releases/download
etcd_ver=v3.2.11

##   download
##
cmd_download() {
	local ar=etcd-$etcd_ver-linux-amd64.tar.gz
	test -r $ARCHIVE/$ar && return 0
	curl -L $urlbase/$etcd_ver/$ar > $ARCHIVE/$ar || \
		die "Failed to download [$ar]"
}

##   etcd [out-dir]
##
cmd_etcd() {
	local o=.
	test -n "$1" && o=$1
	local d=etcd-$etcd_ver-linux-amd64
	local ar=$ARCHIVE/$d.tar.gz
	test -r $ar || die "Not readable [$ar]"
	test -d $o || die "Not a directory [$o]"
	mkdir -p $tmp
	tar -C $tmp -xf $ar $d/etcdctl $d/etcd
	cp $tmp/$d/* $o
}

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
