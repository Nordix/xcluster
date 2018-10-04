#! /bin/sh
##
## xcadmin.sh --
##
##   Admin scrit for Xcluster.
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


##   relese --vestion=ver
##     Create a release tar archive.
##
cmd_release() {
	test -n "$__version" || die 'No version'
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	local d T f n ar H
	d=$(dirname $XCLUSTER)
	d=$(readlink -f $d)

	T=$tmp/xcluster
	mkdir -p $T
	cp -R $d/* $T
	rm -rf $T/.git

	H=$T/workspace/xcluster
	mkdir -p $H
	for n in bzImage cache hd.img hd-k8s.img; do
		cp -r $XCLUSTER_HOME/$n $H
	done

	H=$T/workspace/dropbear-$__dropbearver
	mkdir -p $H
	n=$XCLUSTER_WORKSPACE/dropbear-$__dropbearver
	for f in dropbear scp dbclient; do
		test -x $n/$f || die "Not executable [$n/$f]"
		cp $n/$f $H
	done
	H=$T/workspace/$__bbver
	f=$XCLUSTER_WORKSPACE/$__bbver/busybox
	mkdir -p $H
	cp $f $H
	f=$XCLUSTER_WORKSPACE/iproute2-$__ipver/ip/ip
	H=$T/workspace/iproute2-$__ipver/ip
	mkdir -p $H
	cp $f $H

	mkdir -p $T/bin
	for f in mconnect coredns; do
		cp $GOPATH/bin/$f $T/bin
	done
	cd $tmp
	ar=/tmp/xcluster-$__version.tar
	tar -cf $ar xcluster
	cd
	echo "Created [$ar]"
}


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
