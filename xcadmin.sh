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

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__corednsver" || __corednsver=1.6.7
	test -n "$__k8sver" || __k8sver=v1.17.2
	test -n "$__mconnectver" || __mconnectver=v2.0
	test -n "$GOPATH" || export GOPATH=$HOME/go
	test -n "$ARCHIVE" || ARCHIVE=$HOME/Downloads
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}

cmd_find_ar() {
	test -n "$1" || die "No file"
	local d
	for d in $ARCHIVE $HOME/Downloads; do
		if test -r $d/$1; then
			echo $d/$1
			return 0
		fi
	done
	die "Not found [$1]"
}
cmd_bin_add() {
	test -n "$1" || die "No bin-dir"
	cmd_env
	local ar f
	local bindir=$1

	mkdir -p $bindir
	f=$bindir/coredns
	if ! test -x $f; then
		ar=$(cmd_find_ar coredns_${__corednsver}_linux_amd64.tgz) || return 1
		tar -C $bindir -xf $ar
	fi

	f=$bindir/kubectl
	if ! test -x $f; then
		ar=$(cmd_find_ar kubernetes-server-$__k8sver-linux-amd64.tar.gz) || return 1
		tar -C $bindir -O -xf $ar kubernetes/server/bin/kubectl > $f
		chmod a+x $f
	fi

	f=$bindir/mconnect
	if ! test -x $f; then
		ar=$(cmd_find_ar mconnect-$__mconnectver.gz) || return 1
		gzip -d -c $ar > $f
		chmod a+x $f
	fi
}

##   prepulled_images
##     Print pre-pulled images (needed for "mkimages_ar")
##   mkcache_ar
##     Create a "$ARCHIVE/xcluster-cache.tar" file. This requires "sudo"!!
##
cmd_prepulled_images() {
	echo docker.io/library/alpine:3.8
	echo docker.io/nordixorg/mconnect:v1.2
	echo k8s.gcr.io/metrics-server-amd64:v0.3.6
	echo k8s.gcr.io/pause:3.1
}
cmd_mkcache_ar() {
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	local ar=$ARCHIVE/xcluster-cache.tar
	rm -f $ar
	local images="$($XCLUSTER ovld images)/images.sh"
	$images make $(cmd_prepulled_images)
	cmd_cache_refresh
	eval $($XCLUSTER env | grep __cached)
	cd $__cached
	tar cf $ar *
	cd - > /dev/null
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

##   base_archives
##     Print the base archives.
##   build_base <workspace>
##     Builds the base xcluster workspace from scratch (more or less).
##     This is both a test and a release procedure.
##
cmd_base_archives() {
	cmd_env
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	echo $ARCHIVE/diskim-$__diskimver.tar.xz
	echo $ARCHIVE/$__kver.tar.xz
	echo $ARCHIVE/$__bbver.tar.bz2
	echo $ARCHIVE/dropbear-$__dropbearver.tar.bz2
	echo $ARCHIVE/iproute2-$__ipver.tar.xz
	echo $ARCHIVE/coredns_${__corednsver}_linux_amd64.tgz
}
cmd_build_base() {
	cmd_mark clean
	cmd_mark "Build xcluster"

	cmd_env
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)

	# Pre-check
	local ar
	for ar in $(cmd_base_archives); do
		test -r $ar || die "Not readable [$ar]"
	done

	test -n "$1" || die "No workspace"
	test -e "$1" && die "Already exist [$1]"

	local workdir=$(readlink -f $1)
	mkdir -p "$workdir" ||  die "Could not create [$workdir]"

	# Setup env
	export XCLUSTER_WORKSPACE=$workdir
	export __image=$XCLUSTER_HOME/hd.img
	mkdir -p $XCLUSTER_WORKSPACE/bin

	ar=$ARCHIVE/coredns_${__corednsver}_linux_amd64.tgz
	tar -C $XCLUSTER_WORKSPACE/bin -xf $ar
	cmd_mark "Coredns  installed"

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

##   k8s_workspace
##     Extend a base $XCLUSTER_WORKSPACE for use with with K8s.
##
cmd_k8s_archives() {
	cmd_env
	echo $ARCHIVE/coredns_${__corednsver}_linux_amd64.tgz
	echo $ARCHIVE/kubernetes-server-$__k8sver-linux-amd64.tar.gz
	echo $ARCHIVE/mconnect-$__mconnectver.gz
	echo $ARCHIVE/xcluster-cache.tar
}

cmd_k8s_workspace() {
	cmd_env

	for ar in $(cmd_k8s_archives); do
		test -r $ar || die "Not readable [$ar]"
	done

	cmd_bin_add $GOPATH/bin
	cmd_build_iptools
	cmd_cache_refresh
}
cmd_build_iptools() {
	local iptools="$($XCLUSTER ovld iptools)/iptools.sh"
	test -x $iptools || die "Not executable [$iptools]"
	$iptools download
	$iptools build
}


##   cache_refresh
##     From "$ARCHIVE/xcluster-cache.tar" if ti exists otherwise
##     build. Build requires "sudo"!
cmd_cache_refresh() {
	local ar=$ARCHIVE/xcluster-cache.tar
	if test -r $ar; then
		eval $($XCLUSTER env | grep __cached)
		rm -rf $__cached
		mkdir -p  $__cached
		tar -C $__cached -xf $ar || die
		return 0
	fi
	$XCLUSTER cache --clear
	local o
	for o in iptools xnet images crio; do
		log "Caching ovl [$o]"
		$XCLUSTER cache $o || die "Failed"
	done
}

##   k8s_build_images [--k8sver=...]
##     Build images hd-k8s-<k8sver>.img and hd-k8s-xcluster-<k8sver>.img
##     Soft-links; hd-k8s.img hd-k8s-xcluster.img are updated.
##
cmd_k8s_build_images() {
	cmd_env
	eval $($XCLUSTER env)
	test -n "$KUBERNETESD" || \
		export KUBERNETESD=$XCLUSTER_WORKSPACE/kubernetes-$__k8sver/server/bin
	if ! test -d $KUBERNETESD; then
		local ar=$(cmd_find_ar kubernetes-server-$__k8sver-linux-amd64.tar.gz)
		test -r $ar || die "Not readable [$ar]"
		rm -rf $XCLUSTER_WORKSPACE/kubernetes
		tar -C $XCLUSTER_WORKSPACE -xf $ar
		mv $XCLUSTER_WORKSPACE/kubernetes $XCLUSTER_WORKSPACE/kubernetes-$__k8sver
	fi

	# Pre checks
	local ovl="$($XCLUSTER ovld etcd)"
	$ovl/etcd.sh download || die "Etcd download"
	$ovl/tar - > /dev/null || die "etcd/tar failed"
	ovl="$($XCLUSTER ovld kubernetes)"
	$ovl/tar - > /dev/null || die "kubernetes/tar failed"
	ovl="$($XCLUSTER ovld k8s-xcluster)"
	$ovl/tar - > /dev/null || die "k8s-xcluster/tar failed"

	# Build the k8s-xcluster image;
	local image
	image=$XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
	rm -rf $image
	cp $__image $image
	chmod +w $image
	$XCLUSTER ximage --image=$image xnet etcd iptools crio k8s-xcluster mconnect images || die "ximage failed"
	chmod -w $image
	test -e $XCLUSTER_HOME/hd-k8s-xcluster.img || \
		ln -s $(basename $image)  $XCLUSTER_HOME/hd-k8s-xcluster.img
	echo "Created [$image]"
	
	# Build the legacy k8s image;
	image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
	rm -rf $image
	cp $__image $image
	chmod +w $image
	$XCLUSTER ximage --image=$image xnet etcd iptools crio kubernetes mconnect images || die "ximage failed"
	chmod -w $image
	test -e $XCLUSTER_HOME/hd-k8s.img || \
		ln -s $(basename $image)  $XCLUSTER_HOME/hd-k8s.img
	echo "Created [$image]"

}

##   release --version=ver
##     Create a release tar archive.
##
cmd_release() {
	test -n "$__version" || die 'No version'
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	local d T ar
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
	cmd_env
	eval $($XCLUSTER env)
	local d W H S f
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
	local bindir=$GOPATH/bin
	for f in mconnect coredns kubectl; do
		test -x $bindir/$f || die "Not executable [$bindir/$f]"
		cp $bindir/$f $W/bin
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
