#! /bin/sh
##
## xcadmin.sh --
##
##   Admin script for Xcluster.
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

##   ovlindex --src=dir
##     Print a overlay-index on stdout.
##
cmd_ovlindex() {
	cat <<EOF
# Overlay index

EOF
	test -n "$__src" || return 0
	mkdir -p $tmp
	find "$__src" -maxdepth 2 -mindepth 2 -name README.md > $tmp/ovls
	local f n
	for f in $(sort < $tmp/ovls); do
		n=$(echo $f | sed -s 's,/README.md,,')
		n=$(basename $n)
		echo " * [$n]($f)"
	done
}


##   build_release <workdir>
##     Builds xcluster from scratch (more or less). This is both a
##     test and a release procedure.
##
cmd_build_release() {
	local begin now
	begin=$(date +%s)

	test -n "$1" || die "No workdir"
	test -e "$1" && die "Already exist [$1]"
	mkdir -p "$1" ||  die "Could not create [$1]"
	cd "$1"
	local workdir=$(readlink -f .)


	# Clone
	#local url=https://github.com/Nordix/xcluster.git
	local url=file:///$HOME/go/src/github.com/Nordix/xcluster
	git clone --depth 1 $url || die "Failed to clone xcluster"
	
	# Setup env
	export XCLUSTER_WORKSPACE=$workdir/workspace
	mkdir -p $XCLUSTER_WORKSPACE
	cd xcluster
	. ./Envsettings
	eval $($XCLUSTER env)

	# Install diskim
	ar=diskim-$__diskimver.tar.xz
	url=https://github.com/lgekman/diskim/releases/download/$__diskimver
	test -r $ARCHIVE/$ar || curl -L $url/$ar > $ARCHIVE/$ar || \
		die "Failed to dovnload diskim-$__diskimver"
	tar -I pxz -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar || \
		die "Failed to unpack diskim-$__diskimver"
	sed -ie "s,-j4,-j$(nproc)," $DISKIM

	# Create the base image
	$XCLUSTER kernel_build || die "kernel_build"
	$XCLUSTER busybox_build || die "busybox_build"
	$XCLUSTER iproute2_build || log "iproute2_build fails always, go on..."
	$XCLUSTER dropbear_build || die dropbear_build
	$XCLUSTER mkimage

	# Overlays;

	# Iptools
	cd $($XCLUSTER ovld iptools)
	./iptools.sh download
	./iptools.sh build

	# Etcd
	cd $($XCLUSTER ovld etcd)
	./etcd.sh download

	cmd_cache_refresh

	now=$(date +%s)
	echo "Elapsed time; $((now-begin)) sec"
}
cmd_cache_refresh() {
	$XCLUSTER cache --clear
	$XCLUSTER cache iptools
	SETUP=ipv6 $XCLUSTER cache iptools
	SETUP=ipv6 $XCLUSTER cache etcd
}

##   release --version=ver
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
	for n in bzImage cache hd.img base-libs.txt; do
		cp -r $XCLUSTER_HOME/$n $H
	done
	chmod 444 $H/hd*
	cat > $H/dns-spoof.txt <<EOF
docker.io
registry-1.docker.io
k8s.gcr.io
gcr.io
registry.nordix.org
EOF

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
	for f in mconnect coredns gobgp gobgpd; do
		test -x $GOPATH/bin/$f || die "Not executable [$GOPATH/bin/$f]"
		cp $GOPATH/bin/$f $T/bin
	done

	cd $tmp
	ar=/tmp/xcluster-$__version.tar
	tar --group=0 --owner=0 -cf $ar xcluster
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
