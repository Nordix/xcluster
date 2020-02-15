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


cmd_mark() {
	test -n "$__mark_file" || __mark_file=/tmp/$USER/mark
	if test "$1" = "clean"; then
		rm -f "$__mark_file"
		mkdir -p $(dirname $__mark_file)
		return 0
	fi
	test -r "$__mark_file" || echo "$(date +%s:%F-%T): Begin" > "$__mark_file"
	local begin=$(head -1 $__mark_file | cut -d: -f1)
	local now=$(date +%s)
	local elapsed=$((now-begin))
	echo "$(printf "%-4d" $elapsed):$(date +%F-%T): $@" >> "$__mark_file"
}

##   build_base <workspace>
##     Builds the base xcluster workspace from scratch (more or less).
##     This is both a test and a release procedure.
##
cmd_build_base() {
	cmd_mark clean
	cmd_mark "Build xcluster"

	test -n "$1" || die "No workspace"
	test -e "$1" && die "Already exist [$1]"
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'

	local workdir=$(readlink -f $1)
	mkdir -p "$workdir" ||  die "Could not create [$workdir]"

	# Pre-check
	for ar in diskim-$__diskimver.tar.xz $__kver.tar.xz $__bbver.tar.bz2 \
		dropbear-$__dropbearver.tar.bz2 iproute2-$__ipver.tar.xz \
		; do
		test -r $ARCHIVE/$ar || die "Not readable [$ARCHIVE/$ar]"
	done

	# Setup env
	export XCLUSTER_WORKSPACE=$workdir
	mkdir -p $XCLUSTER_WORKSPACE
	eval $($XCLUSTER env)
	export __image=$XCLUSTER_HOME/hd.img

	if ! test -x $DISKIM; then
		ar=$ARCHIVE/diskim-$__diskimver.tar.xz
		tar -C $XCLUSTER_WORKSPACE -xf $ar
	fi
	# Work-arounds for diskim;
	if ! which pxz > /dev/null; then
		test -d $HOME/bin || die "Not executable [pxz]. Make a link to xz"
		ln -s $(which xz) $HOME/bin/pxz
		which pxz > /dev/null || die "Not executable [pxz]"
	fi
	sed -i -e 's,-j4,-j$(nproc),' $DISKIM
	cmd_mark "Diskim installed"

	$XCLUSTER kernel_build || die "Failed to build kernel"
	cmd_mark "Kernel built"

	$XCLUSTER busybox_build || die "Failed to build busybox"
	cmd_mark "Busybox built"

	$XCLUSTER dropbear_build || die "Failed to build dropbear"
	cmd_mark "Dropbear built"

	$XCLUSTER iproute2_build || die "Failed to build iproute2"
	cmd_mark "Iproute2 built"

	$XCLUSTER mkimage --size=8G || die "Failed to build image"
	cmd_mark "Image built"

	cat $__mark_file
}

cmd_cache_refresh() {
	$XCLUSTER cache --clear
	local o
	for o in iptools xnet images; do
		log "Caching ovl [$o]"
		$XCLUSTER cache $o
	done
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

	cmd_mkworkspace $T/workspace

	cd $tmp
	ar=/tmp/xcluster-$__version.tar
	tar --group=0 --owner=0 -cf $ar xcluster
	cd
	log "Created [$ar]"
}

cmd_mkworkspace() {
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	local d W H S
	d=$(dirname $XCLUSTER)
	d=$(readlink -f $d)

	test -n "$1" || die "No target"
	test -e "$1" && die "Already exists [$1]"
	mkdir -p "$1" || die "Mkdir failed [$1]"
	local W=$(readlink -f "$1")
	log "Creating workspace at [$W]"

	H=$W/xcluster
	mkdir -p $H
	for n in bzImage cache hd.img base-libs.txt; do
		cp -r $XCLUSTER_HOME/$n $H
	done
	chmod 444 $H/hd.img
	cat > $H/dns-spoof.txt <<EOF
docker.io
registry-1.docker.io
k8s.gcr.io
gcr.io
registry.nordix.org
EOF

	H=$W/$__bbver
	f=$XCLUSTER_WORKSPACE/$__bbver/busybox
	mkdir -p $H
	cp $f $H

	f=$XCLUSTER_WORKSPACE/iproute2-$__ipver/ip/ip
	H=$W/iproute2-$__ipver/ip
	mkdir -p $H
	cp $f $H

	H=$W/diskim-$__diskimver
	mkdir -p $H/tmp
	cp $DISKIM $H
	S=$(dirname $DISKIM)/tmp
	cp $S/bzImage $S/initrd.cpio $H/tmp

	mkdir -p $W/bin
	for f in mconnect coredns kubectl; do
		test -x $GOPATH/bin/$f || die "Not executable [$GOPATH/bin/$f]"
		cp $GOPATH/bin/$f $W/bin
	done
}

##   workspace_ar <file>
##     Builds a xcluster "workspace" archive for a binary release.
##     Use; "./xcadmin.sh workspace_ar - | tar t" to test
##
cmd_workspace_ar() {
	test -n "$1" || die "No ar"
	test "$__force" = "yes" && rm -f $1
	test -e "$1" && die "Already exists [$1]"
	touch "$1" || die "Can't create [$1]"
	mkdir -p $tmp
	cmd_mkworkspace $tmp/workspace
	tar -C $tmp --group=0 --owner=0 -cf "$1" workspace
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
