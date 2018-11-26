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

	test -n "$KUBERNETESD" || export KUBERNETESD=$ARCHIVE/kubernetes/server/bin
	test -x $KUBERNETESD/kubelet || die "No k8s in [$KUBERNETESD]"

	test -n "$1" || die "No workdir"
	test -e "$1" && die "Already exist [$1]"
	mkdir -p "$1" ||  die "Could not create [$1]"
	cd "$1"
	local workdir=$(readlink -f .)


	# Clone
	#local url=https://github.com/Nordix/xcluster.git
	local url=file:///$HOME/go/src/github.com/Nordix/xcluster
	git clone $url || die "Failed to clone xcluster"

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

	# Build the image overlay early to get the "sudo" over with
	go get github.com/coredns/coredns
	cd $GOPATH/src/github.com/coredns/coredns
	make || die "make coredns"
	mkdir -p $GOPATH/bin
	mv coredns $GOPATH/bin
	docker rmi example.com/coredns:0.1
	local images=$($XCLUSTER ovld images)/images.sh
	$images make coredns docker.io/nordixorg/mconnect:0.2 || \
		die "images make"

	# Create the base image
	$XCLUSTER kernel_build || die "kernel_build"
	$XCLUSTER busybox_build || die "busybox_build"
	$XCLUSTER iproute2_build || log "iproute2_build fails always, go on..."
	$XCLUSTER dropbear_build || die dropbear_build
	$XCLUSTER mkimage

	# Overlays;

	# Overlay systemd
	cd $($XCLUSTER ovld systemd)
	./systemd.sh download
	./systemd.sh unpack
	cd $XCLUSTER_WORKSPACE/util-linux-2.31
	./configure; make -j$(nproc) || die util-linux-2.31
	cd -
	./systemd.sh make clean
	./systemd.sh make -j$(nproc) || die systemd

	# Iptools
	cd $($XCLUSTER ovld iptools)
	./iptools.sh download
	./iptools.sh build

	# Etcd
	cd $($XCLUSTER ovld etcd)
	./etcd.sh download

	# Gobgp
	cd $($XCLUSTER ovld gobgp)
	./gobgp.sh zdownload
	./gobgp.sh zbuild || die Zebra
	go get github.com/golang/dep/cmd/dep
	go get github.com/osrg/gobgp
	cd $GOPATH/src/github.com/osrg/gobgp
	# **NOTE** 'master* does NOT work!!!
	git checkout v1.33
	dep ensure
	go install ./gobgp/... ./gobgpd/... || die gobgp

	# Cri-o
	go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
	cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
	make || die cri-o
	go get -u github.com/kubernetes-incubator/cri-o
	cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
	make install.tools || die cri-o
	make || die cri-o
	strip bin/*

	# Plugins
	go get github.com/containernetworking/plugins/
	cd $GOPATH/src/github.com/containernetworking/plugins
	./build.sh || die Plugins
	strip bin/*

	# Kubernetes
	strip $KUBERNETESD/*
	cd $($XCLUSTER ovld kubernetes)
	./kubernetes.sh runc_download

	# Kube-router
	$me build_kube_router

	cmd_cache_refresh

	# Create the k8s image
	cd $workdir/xcluster
	. ./Envsettings.k8s
	$XCLUSTER mkimage
	$XCLUSTER ximage systemd etcd iptools kubernetes coredns mconnect images

	now=$(date +%s)
	echo "Elapsed time; $((now-begin)) sec"
}
cmd_build_kube_router() {
	export GOROOT=$HOME/bin/go-1.10.4
	export PATH=$GOROOT/bin:$PATH
	go get -u github.com/cloudnativelabs/kube-router
	go get github.com/matryer/moq
	cd $GOPATH/src/github.com/cloudnativelabs/kube-router
	make clean; make || die Kube-router
}
cmd_cache_refresh() {
	$XCLUSTER cache --clear
	$XCLUSTER cache systemd
	SETUP=ipv6 $XCLUSTER cache systemd
	$XCLUSTER cache iptools
	SETUP=ipv6 $XCLUSTER cache iptools
	$XCLUSTER cache etcd
	SETUP=ipv6 $XCLUSTER cache etcd
	$XCLUSTER cache gobgp
	SETUP=ipv6 $XCLUSTER cache gobgp
	$XCLUSTER cache skopeo
	SETUP=ipv6 $XCLUSTER cache skopeo
	$XCLUSTER cache kube-router
	$XCLUSTER cache wireguard
	SETUP=test $XCLUSTER cache wireguard
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
	for n in bzImage cache hd.img hd-k8s.img; do
		cp -r $XCLUSTER_HOME/$n $H
	done
	chmod 444 $H/hd*

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
