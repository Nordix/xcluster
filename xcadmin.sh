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
find_ar() {
	test -n "$1" || die "No file"
	ar=$ARCHIVE/$1
	test -r $ar || ar=$HOME/Downloads/$1
	test -r $ar || die "Not found [$1]"
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
##   build_base [workspace]
##     Builds the base xcluster workspace from scratch (more or less).
##     This is both a test and a release procedure.
##
cmd_base_archives() {
	cmd_env
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	echo diskim-$__diskimver.tar.xz
	echo $__kver.tar.xz
	echo $__bbver.tar.bz2
	echo dropbear-$__dropbearver.tar.bz2
	echo iproute2-$__ipver.tar.gz
	echo coredns_${__corednsver}_linux_amd64.tgz
}
cmd_build_base() {
	cmd_env
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)
	cmd_mark clean
	cmd_mark "Build xcluster"

	# Pre-check
	local f
	for f in $(cmd_base_archives); do
		find_ar $f
	done

	test -n "$1" && export XCLUSTER_WORKSPACE=$(readlink -f $1)
	test -e "$XCLUSTER_WORKSPACE" && die "Already exist [$XCLUSTER_WORKSPACE]"
	mkdir -p "$XCLUSTER_WORKSPACE" || die "Could not create [$XCLUSTER_WORKSPACE]"

	# Setup env
	export XCLUSTER_HOME=$XCLUSTER_WORKSPACE/xcluster
	export __image=$XCLUSTER_HOME/hd.img
	mkdir -p $XCLUSTER_WORKSPACE/bin

	ar=$ARCHIVE/coredns_${__corednsver}_linux_amd64.tgz
	tar -C $XCLUSTER_WORKSPACE/bin -xf $ar
	cmd_mark "Coredns  installed"

	if ! test -x $DISKIM; then
		find_ar diskim-$__diskimver.tar.xz
		tar -C $XCLUSTER_WORKSPACE -xf $ar
	fi
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

##   k8s_workspace [--k8sver=] [--workspace=]
##     Adds "kubectl" to the workspace
cmd_k8s_workspace() {
	cmd_env
	test -n "$__workspace" || __workspace=$XCLUSTER_WORKSPACE
	local f bindir=$__workspace/bin
	mkdir -p $bindir

	f=$bindir/kubectl
	if test -n "$__k8sver" -a "$__k8sver" != "master"; then
		find_ar kubernetes-server-$__k8sver-linux-amd64.tar.gz
		tar -C $bindir -O -xf $ar kubernetes/server/bin/kubectl > $f
		chmod a+x $f
	else
		local x=$GOPATH/src/k8s.io/kubernetes/_output/bin/kubectl
		test -x $x || die "Not executable [$x]"
		cp $x $f
	fi
}

##   k8s_build_images [--k8sver=...]
##     Build the hd-k8s-<k8sver>.img image. For backward compatibility
##     a hard-link to hd-k8s-xcluster-<k8sver>.img is created.
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
		find_ar kubernetes-server-$__k8sver-linux-amd64.tar.gz
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

	# Build the k8s image;
	local image base_image
	base_image=$XCLUSTER_HOME/hd.img
	test -r $base_image || die "Not readable [$base_image]"
	image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
	rm -rf $image
	cp -L $base_image $image
	chmod +w $image
	$XCLUSTER ximage --image=$image xnet etcd iptools crio kubernetes k8s-cni-bridge mconnect || die "ximage failed"
	rm -f $XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
	ln -s $image $XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
	chmod -w $image $XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
	echo "Created [$image]"
	echo "Soft link to [$XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img]"

	test -e $XCLUSTER_HOME/hd-k8s-xcluster.img || \
		ln -s $(basename $image) $XCLUSTER_HOME/hd-k8s-xcluster.img
	test -e $XCLUSTER_HOME/hd-k8s.img || \
		ln -s $(basename $image)  $XCLUSTER_HOME/hd-k8s.img
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
	export __image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
	test -r $__image || die "Not readable [$__image]"
	test -n "$__nvm" || __nvm=4
	export __nvm
	test -n "$__mem" || __mem=1536
	test -n "$__mem1" || __mem1=$((__mem + 512))
	export __mem __mem1

	if test -n "$__cni"; then
		export __cni
		export XOVLS="$XOVLS k8s-cni-$__cni"
	fi
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

##   release [--version=ver]
##     Create a release tar archive in pwd
cmd_release() {
	test -n "$__version" || __version=$(date +%Y.%m.%d | sed -e 's,\.0,\.,g')
	export __version
	log "Building xcluster-$__version"
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	eval $($XCLUSTER env)

	# Check that ovl/iptools is cached
	test -r $__cached/default/iptools.tar.xz || die "Ovl/iptools is not cached"

	# Copy the xcluster repo
	local d X
	d=$(dirname $XCLUSTER)
	d=$(readlink -f $d)
	X=$tmp/xcluster
	mkdir -p $tmp
	cp -R $d $X
	rm -rf $X/.git* $X/ovl/attic $X/*.tar $X/*.tar.xz $X/workspace

	# Create a new workspace
	mkdir -p $X/workspace
	cp -R $XCLUSTER_WORKSPACE/bin $X/workspace
	cp -R $(dirname $DISKIM) $X/workspace/diskim-$__diskimver

	# Create a new xcluster home
	mkdir -p $X/workspace/xcluster
	cp -L $XCLUSTER_HOME/base-libs.txt $XCLUSTER_HOME/bzImage-$__kver \
		$XCLUSTER_HOME/hd.img $X/workspace/xcluster
	mkdir -p $X/workspace/xcluster/cache/default
	cp $__cached/default/iptools.tar.xz $X/workspace/xcluster/cache/default

	local xctar=xcluster-$__version.tar
	rm -f $xctar $xctar.xz
	tar -C $tmp --group=0 --owner=0 -cf $xctar xcluster || die tar
	xz -T0 $xctar
	log "Created [$xctar.xz]"
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
