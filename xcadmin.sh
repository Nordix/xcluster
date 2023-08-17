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

##   env
##     Print environment.
cmd_env() {
	test -n "$__corednsver" || __corednsver=1.8.1
	test -n "$__k8sver" || __k8sver=v1.18.3
	test -n "$GOPATH" || export GOPATH=$HOME/go
	test -n "$ARCHIVE" || ARCHIVE=$HOME/Downloads
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}
##   env_check
##     Perform basic checks.
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
		ar=$(cmd_find_ar mconnect.xz) || return 1
		xz -d -c $ar > $f
		chmod a+x $f
	fi

	f=$bindir/assign-lb-ip
	if ! test -x $f; then
		ar=$(cmd_find_ar assign-lb-ip.xz) || return 1
		xz -d -c $ar > $f
		chmod a+x $f
	fi
}

##
##   prepulled_images
##     Print pre-pulled images (needed for "mkimages_ar")
##   mkcache_ar
##     Create a "$ARCHIVE/xcluster-cache.tar" file. This requires "sudo"!!
##
cmd_prepulled_images() {
	echo docker.io/library/alpine:latest
	echo registry.nordix.org/cloud-native/mconnect:latest
	$($XCLUSTER ovld crio)/crio.sh pause_image
}
cmd_mkcache_ar() {
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	local ar=$ARCHIVE/xcluster-cache.tar
	rm -f $ar
	local images="$($XCLUSTER ovld images)/images.sh"
	$images make $(cmd_prepulled_images) || die
	cmd_cache_refresh
	eval $($XCLUSTER env | grep __cached)
	cd $__cached
	tar cf $ar *
	cd - > /dev/null
}

##   ovlindex [--src=.]
##     Print a overlay-index on stdout.
##
cmd_ovlindex() {
	test -n "$__src" || __src=.
	test -d "$__src" || die "Not a directory [$__src]"
	cat <<EOF
# Overlay index

EOF
	mkdir -p $tmp
	find "$__src" -maxdepth 2 -mindepth 2 -name README.md > $tmp/ovls
	local f n
	for f in $(sort < $tmp/ovls); do
		n=$(echo $f | sed -s 's,/README.md,,')
		n=$(basename $n)
		echo " * [$n]($f) - $(slogan $f)"
	done
}
slogan() {
	# Assuming the second paragraph surrounded by '\n' is a slogan
	# (is there a better way to extract the paragraph?)
	head -24 $1 | sed -e 's,^$,\x0,' | tr '\n' ' ' | tail -z -n +2 | head -z -n 1
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
	echo $ARCHIVE/iproute2-$__ipver.tar.gz
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
	sed -i -e 's,-j4,-j$(nproc),' $DISKIM
	cmd_mark "Diskim installed"

	$XCLUSTER kernel_build || die "Failed to build kernel"
	cmd_mark "Kernel built"

	if test -n "$__xkernels"; then
		for __kver in $__xkernels; do
			export __kver
			$XCLUSTER kernel_build || die "Failed to build kernel $__kver"
			cmd_mark "Kernel built $__kver"
		done
	fi

	$XCLUSTER busybox_build || die "Failed to build busybox"
	cmd_mark "Busybox built"

	$XCLUSTER dropbear_build || die "Failed to build dropbear"
	cmd_mark "Dropbear built"

	$XCLUSTER iproute2_build || die "Failed to build iproute2"
	cmd_mark "Iproute2 built"

	__version=$__version $XCLUSTER mkimage --size=8G \
		|| die "Failed to build image"
	cmd_mark "Image built"

	cat $__mark_file
}

##   k8s_workspace
##     Extend a base $XCLUSTER_WORKSPACE for use with with K8s.
cmd_k8s_archives() {
	cmd_env
	$($XCLUSTER ovld cni-plugins)/cni-plugins.sh archive || die cni-plugins
	$($XCLUSTER ovld etcd)/etcd.sh archive || die etcd
	# TODO; Handle versions better!
	echo $ARCHIVE/kubernetes-server-$__k8sver-linux-amd64.tar.gz
	echo $ARCHIVE/mconnect.xz
	echo $ARCHIVE/xcluster-cache.tar
	echo $ARCHIVE/assign-lb-ip.xz
	echo $ARCHIVE/cri-o.amd64.v1.27.1.tar.gz
}

cmd_k8s_workspace() {
	cmd_env

	for ar in $(cmd_k8s_archives); do
		test -r $ar || die "Not readable [$ar]"
	done

	cmd_bin_add $GOPATH/bin
	cmd_build_iptools || die "FAILED: build_iptools"
	cmd_cache_refresh
}
cmd_build_iptools() {
	local iptools="$($XCLUSTER ovld iptools)/iptools.sh"
	test -x $iptools || die "Not executable [$iptools]"
	$iptools download
	$iptools build
}

##   cache_refresh
##     From "$ARCHIVE/xcluster-cache.tar" if it exists otherwise
##     build. Build requires "sudo"!
cmd_cache_refresh() {
	local ar=$ARCHIVE/xcluster-cache.tar
	if test -r $ar; then
		log "cache_refresh from $ar"
		eval $($XCLUSTER env | grep __cached)
		rm -rf $__cached
		mkdir -p  $__cached
		tar -C $__cached -xvf $ar || die
		return 0
	fi
	log "cache_refresh rebuild"
	$XCLUSTER cache --clear
	local o
	for o in iptools images crio containerd; do
		log "Caching ovl [$o]"
		$XCLUSTER cache $o || die "Failed"
	done
}
##   k8s_build_images [--k8sver=...]
##     Build images hd-k8s-<k8sver>.img and hd-k8s-xcluster-<k8sver>.img
##     Soft-links; hd-k8s.img hd-k8s-xcluster.img are updated.
cmd_k8s_build_images() {
	cmd_env
	eval $($XCLUSTER env)
	if test -z "$KUBERNETESD"; then
		export KUBERNETESD=$XCLUSTER_WORKSPACE/kubernetes-$__k8sver/server/bin
		if test "$__k8sver" = "master"; then
			export KUBERNETESD=$GOPATH/src/k8s.io/kubernetes/_output/bin
			test -x $KUBERNETESD/kubelet || die "K8s not built locally"
		fi
	fi
	if ! test -d $KUBERNETESD; then
		local ar=$(cmd_find_ar kubernetes-server-$__k8sver-linux-amd64.tar.gz)
		test -n "$ar" || die "No archive for version [$__k8sver]"
		test -r $ar || die "Not readable [$ar]"
		rm -rf $XCLUSTER_WORKSPACE/kubernetes
		tar -C $XCLUSTER_WORKSPACE -xf $ar
		mv $XCLUSTER_WORKSPACE/kubernetes $XCLUSTER_WORKSPACE/kubernetes-$__k8sver
	fi
	echo "K8s binaries from [$KUBERNETESD/]"

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
	$XCLUSTER ximage --image=$image xnet etcd iptools crio kubernetes mconnect images || die "ximage failed"
	chmod -w $image
	test -e $XCLUSTER_HOME/hd-k8s-xcluster.img || \
		ln -s $(basename $image)  $XCLUSTER_HOME/hd-k8s-xcluster.img
	echo "Created [$image]"
	
	# Build the legacy k8s image;
	local limage=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
	rm -rf $limage
	cp $image $limage
	chmod +w $limage
	$XCLUSTER ximage --image=$limage k8s-cni-bridge || die "ximage failed"
	chmod -w $limage
	test -e $XCLUSTER_HOME/hd-k8s.img || \
		ln -s $(basename $limage)  $XCLUSTER_HOME/hd-k8s.img
	echo "Created [$limage]"

}

##   k8s_test [--cni=[xcluster|calico|cilium|flannel|antrea]] --k8sver=v1.23.1 \
##     [--list] [--no-stop] <ovl> [args]
##     Execute k8s test with xcluster.
##
cmd_k8s_test() {
	test -n "$1" || die "No ovl to test"
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	cmd_env
	eval $($XCLUSTER env | grep XCLUSTER_HOME)
	if test -n "$__cni"; then
		# Test with k8s-xcluster;
		__image=$XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
		test -r $__image || __image=$XCLUSTER_HOME/hd-k8s-xcluster.img
		test "$__cni" != "None" && export XOVLS="k8s-cni-$__cni private-reg $XXOVLS"
		export __cni
	else
		# Test on "normal" xcluster
		__image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
		test -r $__image || __image=$XCLUSTER_HOME/hd-k8s.img
		export XOVLS="private-reg $XXOVLS"
	fi
	test -r $__image || die "Not readable [$__image]"
	export __image
	test -n "$__nvm" || __nvm=4
	export __nvm

	test -n "$__mem" || __mem=1536
	test -n "$__mem1" || __mem1=$((__mem + 512))
	export __mem __mem1

	if test "$__cni" = "cilium"; then
		# Cilium is a horrible memory-hog and emulates kube-proxy
		__mem=$((__mem + 1024))
		__mem1=$((__mem + 512))
		export __mem __mem1
		export xcluster_PROXY_MODE=disabled
	fi
	if test "$__cni" = "antrea"; then
		# Antrea uses openvswitch
		export XOVLS="$XOVLS ovs"
	fi

	local ovld="$($XCLUSTER ovld $1)"
	test -n "$ovld" || die "Invalid ovl [$1]"
	local script="$ovld/$1.sh"
	test -x $script || die "Not executable [$script]"
	shift

	export __list __no_stop __no_start
	echo "$@" | grep -q start && export __mode
	$script test $@
}



##   release --version=ver [--dest=/tmp]
##     Create a release tar archive.
cmd_release() {
	test -n "$__version" || die 'No version'
	export __version
	test -n "$__dest" || __dest=/tmp
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	local d T ar
	d=$(dirname $XCLUSTER)
	d=$(readlink -f $d)

	T=$tmp/xcluster
	mkdir -p $T
	cp -R $d/* $T
	rm -rf $T/.git $T/workspace

	cmd_mkworkspace $T/workspace

	cd $tmp
	ar=$__dest/xcluster-$__version.tar
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
	for n in $__kver $__xkernels; do
		cp $XCLUSTER_HOME/bzImage-$n $H
	done
	for n in cache hd.img base-libs.txt; do
		cp -Lr $XCLUSTER_HOME/$n $H
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
cmd_workspace_ar() {
	test -n "$1" || die "No ar"
	test "$__force" = "yes" && rm -f $1
	test -e "$1" && die "Already exists [$1]"
	touch "$1" || die "Can't create [$1]"
	mkdir -p $tmp
	cmd_mkworkspace $tmp/workspace
	tar -C $tmp --group=0 --owner=0 -cf "$1" workspace
}
cmd_env_check() {
	mkdir -p $tmp
	local x
	for x in netstat kvm xterm screen telnet; do
		which $x > /dev/null || die "Not executable [$x]"
	done
	if which kvm-ok > /dev/null; then
		kvm-ok > $tmp/out || die "Failed [kvm-ok]"
		if ! grep -q "acceleration can be used" $tmp/out; then
			cat $tmp/out
			die "No acceleration?"
		fi
	fi
	id | grep -Fq '(kvm)' || die "Not member of group [kvm]"
}

##
##   mkovl [--template=<ovl>] [--ovldir=<dir>] <name>
##     Create and initiate an ovl directory. By default "template-k8s" is
##     used and ovldir $HOME/tmp/ovl/
cmd_mkovl() {
	test -n "$1" || die "No ovl name"
	local ovl=$1
	test -n "$__template" || __template=template-k8s
	test -n "$__ovldir" || __ovldir=$HOME/tmp/ovl
	local d=$__ovldir/$ovl
	test -e $d && die "Already exists [$d]"
	mkdir -p $__ovldir || die "mkdir [$__ovldir]"
	local templated
	if test -d "$__template"; then
		templated=$(readlink -f $__template)
		__template=$(basename $templated)
	else
		local xc=$dir/xcluster.sh
		$xc ovld $__template > /dev/null || return 1
		templated=$($xc ovld $__template)
	fi
	cp -R $templated $d

	local f n
	sed -i -e "s,$__template,$ovl,g" $d/README.md
	for f in $(find $d -type d -name "*$__template*"); do
		n=$(echo $f | sed -e "s,$__template,$ovl,")
		mv $f $n
	done
	for f in $(find $d -type f -name "*$__template*"); do
		n=$(echo $f | sed -e "s,$__template,$ovl,")
		mv $f $n
		sed -i -e "s,$__template,$ovl,g" $n
	done
}

##
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
