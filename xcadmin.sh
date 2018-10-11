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

##   test [--xterm] [test...]
##     Test xcluster
##
cmd_test() {
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)

	start=starts
	test "$__xterm" = "yes" && start=start

	# Remove overlays
	rm -f $XCLUSTER_TMP/cdrom.iso
	
	# Go!
	begin=$(date +%s)
	tlog "Xcluster test started $(date +%F)"
	__timeout=10

	if test -n "$1"; then
		for t in $@; do
			test_$t
		done
	else
		for t in basic k8s k8s_ipv6 k8s_kube_router; do
			test_$t
		done
	fi	

	now=$(date +%s)
	tlog "Xcluster test ended. Elapsed time $((now-begin)) sec"
}

test_basic() {
	tcase "Start xcluster"

	# Use the standard image (not k8s)
	export __image=$XCLUSTER_HOME/hd.img

	$XCLUSTER $start
	sleep 2

	tcase "VM connectivity"
	test_vm || tdie

	tcase "Scale out to 8 vms"
	$XCLUSTER scaleout 5 6 7 8
	sleep 2
	test_vm 1 2 3 4 5 6 7 8 201 202 || tdie

	tcase "Scale in some vms"
	$XCLUSTER scalein 2 4 6 8 202
	sleep 0.5
	test_vm 1 3 5 7 201 || tdie
	test_novm 2 4 6 8 202

	tcase "Stop xcluster"
	$XCLUSTER stop
}
test_k8s() {
	# Kubernetes tests;
	export __image=$XCLUSTER_HOME/hd-k8s.img
	tcase "Start xcluster"
	$XCLUSTER mkcdrom externalip test
	$XCLUSTER $start
	sleep 2

	tcase "VM connectivity"
	test_vm || tdie

	tcase "Perform on-cluster tests"
	tlog "--------------------------------------------------"
	rsh 4 xctest k8s || tdie	
	rsh 201 xctest router_k8s || tdie
	tlog "--------------------------------------------------"

	tcase "Stop xcluster"
	$XCLUSTER stop
}
test_k8s_ipv6() {
	# Kubernetes tests with ipv6-only;
	export __image=$XCLUSTER_HOME/hd-k8s.img
	tcase "Start xcluster with k8s ipv6-only"
	SETUP=ipv6 $XCLUSTER mkcdrom etcd k8s-config externalip test
	$XCLUSTER $start
	sleep 2

	tcase "VM connectivity"
	test_vm || tdie

	tcase "Perform on-cluster tests"
	tlog "--------------------------------------------------"
	rsh 4 xctest k8s --ipv6 || tdie
	rsh 201 xctest router_k8s --ipv6 || tdie
	tlog "--------------------------------------------------"

	tcase "Stop xcluster"
	$XCLUSTER stop
}
test_k8s_kube_router() {
	# Kubernetes tests with kube-router;
	export __image=$XCLUSTER_HOME/hd-k8s.img
	tcase "Start xcluster with kube-router"
	$XCLUSTER mkcdrom gobgp kube-router test
	$XCLUSTER $start
	sleep 2

	tcase "VM connectivity"
	test_vm || tdie

	tcase "Perform on-cluster tests"
	tlog "--------------------------------------------------"
	rsh 4 xctest k8s_kube_router || tdie	
	rsh 201 xctest router_kube_router || tdie
	tlog "--------------------------------------------------"

	tcase "Stop xcluster"
	$XCLUSTER stop
}


tlog() {
	echo "$(date +%T) $*" >&2
}
tcase() {
	now=$(date +%s)
	local msg="$(date +%T) ($((now-begin))): TEST CASE: $*"
	echo $msg
	echo $msg >&2
}
tdie() {
	echo "$(date +%T) ($((now-begin))): FAILED: $*" >&2
	rm -rf $tmp
	exit 1
}
test_vm() {
	local vms='1 2 3 4 201 202'
	test -n "$1" && vms=$@
	local start=$(date +%s)
	now=$start
	local failed=yes
	while test "$failed" = "yes"; do
		failed=no
		for vm in $vms; do
			if ! rsh $vm hostname; then
				failed=yes
				break
			fi
		done
		test "$failed" = "no" && return 0
		test $((now-start)) -ge $__timeout && tdie Timeout
		sleep 1
		now=$(date +%s)
	done
	return 1
}
test_novm() {
	local vms='1 2 3 4 201 202'
	test -n "$1" && vms=$@
	for vm in $vms; do
		rsh $vm hostname && return 1
	done
	return 0
}
rsh() {
	local vm=$1
	shift
	local p=$((12300+vm))
	ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $p \
		root@127.0.0.1 $@
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
	local url=file:///home/uablrek/go/src/github.com/Nordix/xcluster
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
	go get -u github.com/coredns/coredns
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
	$XCLUSTER cache --clear


	# Overlay systemd
	cd $($XCLUSTER ovld systemd)
	./systemd.sh download
	./systemd.sh unpack
	cd $XCLUSTER_WORKSPACE/util-linux-2.31
	./configure; make -j$(nproc) || die util-linux-2.31
	cd -
	./systemd.sh make clean
	./systemd.sh make -j$(nproc) || die systemd
	$XCLUSTER cache systemd
	SETUP=ipv6 $XCLUSTER cache systemd

	# Iptools
	cd $($XCLUSTER ovld iptools)
	./iptools.sh download
	./iptools.sh build
	$XCLUSTER cache iptools
	SETUP=ipv6 $XCLUSTER cache iptools

	# Etcd
	cd $($XCLUSTER ovld etcd)
	./etcd.sh download
	$XCLUSTER cache etcd
	SETUP=ipv6 $XCLUSTER cache etcd

	# Gobgp
	cd $($XCLUSTER ovld gobgp)
	./gobgp.sh zdownload
	./gobgp.sh zbuild || die Zebra
	go get -u github.com/golang/dep/cmd/dep
	go get -u github.com/osrg/gobgp
	cd $GOPATH/src/github.com/osrg/gobgp
	dep ensure
	go install ./cmd/... || die gobgp
	$XCLUSTER cache gobgp
	SETUP=ipv6 $XCLUSTER cache gobgp

	# Cri-o
	go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
	cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
	make || die cri-o
	go get -u github.com/kubernetes-incubator/cri-o
	cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
	git checkout -b release-1.12
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

	# Skopeo
	$XCLUSTER cache skopeo
	SETUP=ipv6 $XCLUSTER cache skopeo

	# Kube-router
	go get -u github.com/cloudnativelabs/kube-router
	go get github.com/matryer/moq
	cd $GOPATH/src/github.com/cloudnativelabs/kube-router
	make clean; make || die Kube-router
	$XCLUSTER cache kube-router

	# Create the k8s image
	cd $workdir/xcluster
	. ./Envsettings.k8s
	$XCLUSTER mkimage
	$XCLUSTER ximage systemd etcd iptools kubernetes coredns mconnect images
	chmod 444 $__image		# To avoid users overwrite with "xc mkimage"

	now=$(date +%s)
	echo "Elapsed time; $((now-begin)) sec"
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
	rm -rf $T/.git $T/xcadmin.sh

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
