#! /bin/sh
##
## xcluster.sh --
##
##   Xcluster is a fast and highly configurable environment for
##   cluster and network testing.
##
##   Main functions;
##
##    * Create a Linux netns for testing
##    * Build a disk image
##    * Start/stop a VM test-cluster with brigded networks
##
##   Xcluster consists of a number of (kvm) VMs with identical
##   disks. The disk image is shared by all VMs and the qemu
##   "backing_file" is used to allow individual updates by the VMs.
##
##   The VMs will have a host name like "vm-201" and the number is
##   used to give the VMs a "role". Used roles are;
##
##     001-200   Cluster Nodes
##     201-220   Routers
##     221-240   Testers
##     250-      Reserved
##
##   To install SW an very simple "overlay" function is provided. A
##   number of tar-files are stored on a cd-image and are unpacked on
##   system root ("/") at start-up. This works as a primitive "package
##   manager".
##
##   The xcluster should execute inside a Linux network
##   namespace. Functions for creating a netns are provided but
##   requires "sudo" access.
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
	test -n "$XCLUSTER_HOOK" -a -r "$XCLUSTER_HOOK" && \
		grep '^##' $XCLUSTER_HOOK | cut -c3-
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

test -n "$xcluster_PREFIX" || xcluster_PREFIX=1000::1

# This function is only here to be replaced in a $XCLUSTER_HOOK.
# It should contain custom preparations for different commands.
prepare() {
	# Check the $cmd variable and make appropriate preparations
	test $cmd = "env" && true
}

##   env
##     Show settings.
##
cmd_env() {
	test "$envread" = "yes" && return
	envread=yes
	prepare

	test -n "$XCLUSTER_WORKSPACE" || die 'Not set [$XCLUSTER_WORKSPACE]'
	test -n "$XCLUSTER" || export XCLUSTER=$me
	test -n "$XCLUSTER_HOME" || XCLUSTER_HOME=$XCLUSTER_WORKSPACE/xcluster
	if test -z "$XCLUSTER_TMP"; then
		local mynetns=$(ip netns id)
		if test -n "$mynetns"; then
			XCLUSTER_TMP="/tmp/$USER/xcluster/$mynetns/tmp"
		else
			XCLUSTER_TMP="/tmp/$USER/xcluster/tmp"
		fi
	fi
	test -n "$XCLUSTER_MONITOR_BASE" || XCLUSTER_MONITOR_BASE=4000
	test -n "$XCLUSTER_OVLPATH" || XCLUSTER_OVLPATH=$dir/ovl
	test -n "$ARCHIVE" || ARCHIVE=$HOME/Downloads
	test -n "$KERNELDIR" || KERNELDIR=$HOME/tmp/linux
	export ARCHIVE

	test -n "$__kver" || __kver=linux-6.5
	test -n "$__kobj" || __kobj=$XCLUSTER_HOME/obj-$__kver
	if test -z "$__kbin"; then
		__kbin=$XCLUSTER_HOME/bzImage-$__kver
		test -r $__kbin || __kbin=$XCLUSTER_HOME/bzImage
	fi
	test -n "$__kcfg" || __kcfg=$dir/config/$__kver
	test -n "$__bbver" || __bbver=busybox-1.36.1
	test -n "$__kvm" || __kvm=kvm
	test -n "$__image" || __image=$XCLUSTER_HOME/hd.img
	test -n "$__cdrom" || __cdrom=$XCLUSTER_TMP/cdrom.iso
	test -n "$__mem" || __mem=128
	test -n "$__smp" || __smp=2
	test -n "$__ipv4_base" || __ipv4_base=172.30.0.0/24
	test -n "$__ipv6_prefix" || __ipv6_prefix=fd00:1723::
	test -n "$__loader" || __loader=/lib64/ld-linux-x86-64.so.2
	test -n "$__cached" || __cached=$XCLUSTER_HOME/cache
	test -n "$__nets_vm" || __nets_vm=0,1
	test -n "$__nets_router" || __nets_router=0,1,2
	test -n "$__base_libs" || __base_libs=$XCLUSTER_HOME/base-libs.txt

	__ipver=6.3.0
	__dropbearver=2022.83
	__diskimver=1.0.0
	test -n "$DISKIM" || DISKIM=$XCLUSTER_WORKSPACE/diskim-$__diskimver/diskim.sh

	if test "$cmd" = "env"; then
		set | grep -E '^(__.+=|XCLUSTER|ARCHIVE=|DISKIM=|KERNELDIR=)' | sort
	else
		mkdir -p $XCLUSTER_HOME || die "Failed mkdir [$XCLUSTER_HOME]"
		mkdir -p $XCLUSTER_TMP || die "Failed mkdir [$XCLUSTER_TMP]"
	fi
}
cmd_completion() {
	grep -oE "^cmd_[a-zA-Z_0-9]+" $me | grep "cmd_$1" | sed -e 's,cmd_,,'
}


##  Network name-space commands;
##   nsadd_docker <index>
##   nsadd [--ipv4-base=172.30.0.0] [--ipv6-prefix=fd00:1723::] <index>
##   nsdel <index>
##   nsenter <index>
##
cmd_nsadd() {
	test -n "$1" || die 'No index'
	XCLUSTER_WORKSPACE=$tmp
	cmd_env
	local netns=${USER}_xcluster$1
	ip netns | grep -qe "^$netns " && die "Netns already exist [$netns]"
	sudo ip netns add $netns
	ip link add dev xcluster$1 type veth peer name host$1
	ip link set xcluster$1 up

	set_netns_ipv4_addresses $1
	ip addr add $ipv4_host/32 dev xcluster$1
	ip ro add $ipv4_ns/32 dev xcluster$1

	ip -6 addr add $__ipv6_prefix$ipv4_host/128 dev xcluster$1
	ip -6 ro add $__ipv6_prefix$ipv4_ns/128 dev xcluster$1

	ip link set host$1 netns $netns
	sudo ip netns exec $netns env xcluster_PREFIX=$xcluster_PREFIX \
		$me nssetup --ipv4-base=$__ipv4_base --ipv6-prefix=$__ipv6_prefix $1
	sudo $me masq --ipv4-base=$__ipv4_base

	mkrmtap
}
cmd_nsadd_docker() {
	test -n "$1" || die 'No index'
	XCLUSTER_WORKSPACE=$tmp
	cmd_env
	local netns=${USER}_xcluster$1
	ip netns | grep -qe "^$netns " && die "Netns already exist [$netns]"
	sudo ip netns add $netns
	ip link add dev xcluster$1 type veth peer name host$1
	ip link set xcluster$1 up
	ip link set dev xcluster$1 master docker0

	cmd_docker_net $1

	ip link set host$1 netns $netns
	sudo ip netns exec $netns env xcluster_PREFIX=$xcluster_PREFIX \
		$me nssetup --docker --adr4=$adr4 --gw4=$gw4 $1
	mkrmtap
}
cmd_docker_net() {
	test -n "$1" || die 'No index'
	local i=$1
	ip link show docker0 > /dev/null || die "Can't find docker0"
	mkdir -p $tmp
	local conf=$tmp/docker-bridge
	docker network inspect bridge > $conf || die "Failed; inspect bridge"
	local n
	for n in $(jq -r .[].IPAM.Config[].Subnet < $conf); do
		if echo $n | grep -q :; then
			cidr6=$n
		else
			cidr4=$n
		fi
	done
	for n in $(jq -r .[].IPAM.Config[].Gateway < $conf); do
		if echo $n | grep -q :; then
			gw6=$n
		else
			gw4=$n
		fi
	done
	dbg "Docker subnets; $cidr4 $cidr6, GWs; $gw4 $gw6"
	n=$(echo $cidr4 | cut -d/ -f2)
	test $n -gt 26 && die "Too narrow range; $cidr4"
	# Now we steal a docker address and *hope* it will not collide
	# with any address assigned to containers.
	local b0=$(echo $cidr4 | cut -d/ -f1 | cut -d. -f4)
	b0=$((b0 + 50 + i))
	adr4="$(echo $cidr4 | cut -d/ -f1 | cut -d. -f-3).$b0/$n"
	log "Xcluster netns; $adr4"
}
mkrmtap() {
	# Create /tmp/rmtap that will be called by qemu on VM-termination
	if ! test -x /tmp/rmtap; then
		cat > /tmp/rmtap <<"EOF"
#! /bin/sh
ip link del dev $1
EOF
		chmod a+x /tmp/rmtap
	fi
}
cmd_nsdel() {
	test -n "$1" || die 'No index'
	local netns=${USER}_xcluster$1
	ip netns | grep -qe "^$netns" || die "Netns does not exist [$netns]"
	sudo ip netns del $netns
	ip link del dev xcluster$1
}
cmd_nsenter() {
	test -n "$1" || die 'No index'
	local netns=${USER}_xcluster$1
	unset KUBECONFIG XCLUSTER
	exec ip netns exec $netns /bin/bash
}

cmd_nssetup() {
	test -n "$1" || die 'No index'
	ip link set lo up
	ip link set host$1 up
	if test "$__docker" = "yes"; then
		ip addr add $__adr4 dev host$1
		ip ro add default via $__gw4
	else
		set_netns_ipv4_addresses $1
		ip addr add $ipv4_ns/32 dev host$1
		ip ro add $ipv4_host/32 dev host$1
		ip ro add default via $ipv4_host
		ip -6 addr add $__ipv6_prefix$ipv4_ns/128 dev host$1
		ip -6 ro add $__ipv6_prefix$ipv4_host/128 dev host$1
		ip -6 ro add default via $__ipv6_prefix$ipv4_host
	fi
	iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o host$1 -j MASQUERADE
	ip6tables -t nat -A POSTROUTING -s $xcluster_PREFIX:192.168.0.0/120 -o host$1 -j MASQUERADE
	echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
	echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

	cmd_br_setup 0
	cmd_br_setup 1
	cmd_br_setup 2
}
cmd_masq() {
	set_netns_ipv4_addresses 0
	iptables -t nat -L -nv | grep -q "$ipv4_masq" && return 0
	echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
	echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
	iptables -t nat -A POSTROUTING -s $ipv4_masq -j MASQUERADE
	iptables -A FORWARD -s $ipv4_masq -j ACCEPT
	iptables -A FORWARD -d $ipv4_masq -j ACCEPT
}

# set_netns_ipv4_addresses <index>
#   Set the global variables; ipv4_host ipv4_ns ipv4_masq
set_netns_ipv4_addresses() {
	test -n "$1" || die "No index"
	test -n "$ipv4_host" && return 0
	test -n "$__ipv4_base" || cmd_env
	local i=$1
	
	# The __ipv4_base can be specified in 2 ways;
	#  Old-way; 172.30
	#  New-way: 127.30.0.0/28
	
	if echo $__ipv4_base | grep -qE '^[0-9]+\.[0-9]+$'; then
		# Old way (backward compatible)
		ipv4_host=$__ipv4_base.1.$1
		ipv4_ns=$__ipv4_base.0.$1
		ipv4_masq=$__ipv4_base.0.0/22
		return
	fi

	echo $__ipv4_base | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$' \
		|| die "Syntax err --ipv4-base=$__ipv4_base"

	ipv4_masq=$__ipv4_base
	local ipv4=$(echo $__ipv4_base | cut -d/ -f1)
	local b0=$(echo $ipv4 | cut -d. -f4)
	local pre=$(echo $ipv4 | cut -d. -f-3)

	ipv4_host=$pre.$((b0+1+i*2))
	ipv4_ns=$pre.$((b0+i*2))
}

cmd_br_setup() {
	test -n "$1" || die 'No index'
	local i=$1
	shift
	local dev=xcbr$i

	if ip link show dev $dev > /dev/null 2>&1; then
		log "Bridge already exists [$dev]"
		return 0
	fi

	test -n "$__mtu" || __mtu=1500
	# https://interestingtraffic.nl/2017/11/21/an-oddly-specific-post-about-group_fwd_mask/
	ip link add name $dev mtu $__mtu type bridge group_fwd_mask 0x4000 $@ || \
		die "Failed to create bridge [$dev]"

	ip link set $dev up
	ip addr add 192.168.$i.250/24 dev $dev
	ip -6 addr add $xcluster_PREFIX:192.168.$i.250/120 dev $dev
}

##  Build functions;
##   kernel_build [--kver=linux-x.x.x] [--kobj=dir] [--kbin=file] \
##      [--kcfg=file] [--kpatch=file] [--menuconfig]
##   busybox_build [--menuconfig]
##   dropbear_build
##   iproute2_build
##
cmd_kernel_build() {
	cmd_env
	test "$__kbin" = "$XCLUSTER_HOME/bzImage" && __kbin="$__kbin-$__kver"
	$DISKIM kernel_download --kver=$__kver
	if test -f "$__kpatch"; then
		test -r "$__kpatch" || die "Kpatch not readable [$__kpatch]"
		rm -rf $KERNELDIR/$__kver
		$DISKIM kernel_unpack --kver=$__kver --kdir=$KERNELDIR/$__kver
		patch -d $KERNELDIR/$__kver -p1 < $__kpatch || die "Kpatch failed"
	fi
	mkdir -p $KERNELDIR $__kobj
	cmd_cpio_list $dir/image/initfs > $__kobj/cpio_list
	$DISKIM kernel_build --kdir=$KERNELDIR/$__kver --kernel=$__kbin \
		--kver=$__kver --kobj=$__kobj --kcfg=$__kcfg \
		--menuconfig=$__menuconfig \
		|| die "Kernel build failed [$__kver]"
	if grep -q cpio_list $__kcfg; then
		cmd_emit_cpio_list > $__kobj/cpio_list
		$DISKIM kernel_build --kdir=$KERNELDIR/$__kver --kernel=$__kbin \
			--kver=$__kver --kobj=$__kobj --kcfg=$__kcfg \
			|| die "Kernel build failed [$__kver]"
	fi
}
cmd_emit_cpio_list() {
	cmd_env
	test -n "$__tmp" || __tmp=$tmp
	mkdir -p $__tmp
	if grep -q "^CONFIG_MODULES=y" $__kcfg; then
		INSTALL_MOD_PATH=$__tmp make -C $__kobj modules_install 1>&2 > /dev/null \
			|| die "Failed to install modules from [$__kobj]"
	fi
	cmd_cpio_list $__tmp
	cmd_cpio_list $dir/image/initfs
	cat <<EOF
dir /dev 755 0 0
nod /dev/console 644 0 0 c 5 1
dir /bin 755 0 0
file /bin/busybox /bin/busybox 755 0 0
EOF
}
cmd_cpio_list() {
	test -n "$1" || return 0
	local n f p
	for n in $(find "$1" -mindepth 1); do
		f=$(echo $n | sed -e "s,$1,,")
		if test -d $n; then
			echo "dir $f 0755 0 0"
		elif test -f $n; then
			p=0544
			test -x $n && p=0755
			echo "file $f $n $p 0 0"
		else
			die "Unknown file [$n]"
		fi
	done
}
cmd_busybox_build() {
	cmd_env

	local ar=$ARCHIVE/$__bbver.tar.bz2
	if ! test -r $ar; then
		local url=http://busybox.net/downloads/$__bbver.tar.bz2
		curl -L $url > $ar || die "Could not download [$url]"
	fi

	local d=$XCLUSTER_WORKSPACE/$__bbver
	test "$__clean" = "yes" && rm -rf $d
	if ! test -d $d; then
		tar -C $XCLUSTER_WORKSPACE -xf $ar || die "Failed to unpack [$ar]"
		patch -d $d -p1 < $dir/config/busybox.patch
	fi

	local bbcfg=$dir/config/$__bbver
	if test -r $bbcfg; then
		cp $bbcfg $d/.config
	else
		make -C $d allnoconfig
		__menuconfig=yes
	fi

	if test "$__menuconfig" = "yes"; then
		make -C $d menuconfig
		cp $d/.config $bbcfg
	else
		make -C $d oldconfig
	fi

	make -C $d -j$(nproc)
}
cmd_iproute2_build() {
	cmd_env
	local url=https://www.kernel.org/pub/linux/utils/net/iproute2/
	d=$XCLUSTER_WORKSPACE/iproute2-$__ipver
	test "$__clean" = "yes" && rm -rf $d
	if ! test -d $d; then
		ar=$ARCHIVE/iproute2-$__ipver.tar.xz
		test -r $ar || wget -O $ar $url/$(basename $ar)
		tar -C $(dirname $d) -xf $ar || die "Failed to unpack [$ar]"
	fi

	local kdir=$KERNELDIR/$__kver
	test -d "$kdir" || die "Not a directory [$kdir]"
	cd $kdir/tools/lib/bpf || die cd
	make -j$(nproc) || die "Make libbpf"
	make DESTDIR=$XCLUSTER_WORKSPACE/sys prefix=/usr install \
		|| die "Make libbpf install sys"

	if ! test -x $d/ip/ip; then
		cd $d
		./configure --libbpf_dir=$XCLUSTER_WORKSPACE/sys
		KERNEL_INCLUDE=$__kobj/include \
			make -j $(nproc) || die "Make iproute2 failed"
	fi
}
cmd_dropbear_build() {
	cmd_env
	local ar=dropbear-$__dropbearver.tar.bz2
	local arpath=$ARCHIVE/$ar
	if ! test -r $arpath; then
		local url=https://matt.ucc.asn.au/dropbear/releases/$ar
		curl -L $url > $arpath || die "Download failed [$DROPBEAR_AR]"
	fi
	local d=$XCLUSTER_WORKSPACE/dropbear-$__dropbearver
	test "$__clean" = "yes" && rm -rf $d
	test -x $d/dropbear && die "Already built at [$d]"
	tar -C $XCLUSTER_WORKSPACE -xf $arpath
	cd $d
	echo '#define DEFAULT_PATH "/usr/bin:/bin:/sbin:/usr/sbin"' > localoptions.h
	./configure || die configure
	print_compiler_flags
	make -j $(nproc) PROGRAMS='dropbear scp dbclient' || die make
	strip $d/dropbear $d/scp $d/dbclient
}

##  Image functions;
##   mkimage [--image=file] [--bootable] [--format=qcow2] [--size=2G]
##   cache [--clear] [--list] [ovl|tar...]
##   ximage [--image=file] [--script=file] [ovl|tar...]
##   mkcdrom [--label=label] [--script=file] [--cidata=dir] [ovl|tar...]
##   install_prog [--base-libs=file] --dest=dir [prog...]
##   cplib [--base-libs=file] --dest=dir
##   libs [--base-libs=file]
##   cploader --dest=dir
cmd_mkimage() {
	cmd_env
	test -r $__kbin || die "Kernel not built [$__kbin]"
	test -x $XCLUSTER_WORKSPACE/$__bbver/busybox || cmd_busybox_build
	test -x $XCLUSTER_WORKSPACE/iproute2-$__ipver/ip/ip || cmd_iproute2_build
	test -x $XCLUSTER_WORKSPACE/dropbear-$__dropbearver/dropbear || cmd_dropbear_build

	test -n "$__version" || __version=$(date +%Y.%m.%d)
	__version=$__version $DISKIM mkimage --image=$__image --bootable=$__bootable \
		--format=$__format --size=$__size $dir/image

	# Update base-libs
	rm -f $__base_libs
	if ! test -r $__base_libs; then
		for l in $($dir/image/tar - | tar t | grep -E '.*/lib.*\.so\.'); do
			echo "/$l" >> $__base_libs
		done
	fi

	# Ubuntu 19 work-around; libpcre.so.3 doesn't exist;
	sed -i -e '/libpcre.so.3/d' $__base_libs
}
cmd_cache() {
	cmd_env
	if test "$__list" = "yes"; then
		echo "Cache dir [$__cached];"
		find "$__cached" -type f | sed -e "s,$__cached/,,"
		return 0
	fi
	test "$__clear" = "yes" && rm -rf "$__cached"
	local d n dest
	dest="$__cached/default"
	if test -n "$SETUP"; then
		echo "$SETUP" | grep -q , && die "SETUP has many items [$SETUP]"
		dest="$__cached/$SETUP"
	fi
	mkdir -p $dest
	for n in $@; do
		d=$(cmd_ovld $n) || die "Can't find ovl [$n]"
		test -x $d/tar || die "Not executable [$d/tar]"
		$d/tar "$dest/$n.tar"
		rm -f "$dest/$n.tar.xz"
		xz -T0 "$dest/$n.tar"
	done
}
cmd_cached_tar() {
	test -n "$1" || return 1
	cmd_env
	local n
	for n in $(echo "$SETUP" | tr ',' ' ') default; do
		if test -r $__cached/$n/$1.tar.xz; then
			echo $__cached/$n/$1.tar.xz
			return 0
		fi
	done
	return 1
}

cmd_ximage() {
	cmd_env
	local c d ovls
	# Find ovls
	for d in $@; do
		if c=$(cmd_cached_tar $d); then
			echo "Use Cached [$c]"
			d=$c
		elif ! test -r $d; then
			d=$(cmd_ovld $d) || return
			test -x $d/tar || die "Not executable [$d/tar]"
		fi
		ovls="$ovls $d"
	done
	rm -f "$__cdrom"

	cmd_stop
	$DISKIM ximage --image=$__image --script=$__script $ovls || die "diskim failed"
}

cmd_install_prog() {
	test -n "$__root" && __dest=$__root		# backward compatibility
	test -n "$__dest" || die 'No --dest'
	mkdir -p $__dest/bin || die "Mkdir failed [$__dest/bin]"
	local n f files
	for n in $@; do
		if test -x $n; then
			f=$(readlink -f $n)
		else
			f=$(which $n)
			if ! test -n "$f" -a -x "$f"; then
				log "WARNING: Program not found [$n]"
				continue
			fi
		fi
		cp $f $__dest/bin
		files="$files $f"
	done
	cmd_cplib $files
}

cmd_cplib() {
	test -n "$__dest" || die 'No --dest'
	test -d "$__dest" || die "Not a directory [$__dest]"
	cmd_libs $@ | cpio -p --make-directories --dereference --quiet -u $__dest
}
cmd_libs() {
	cmd_env
	local f libs=$tmp/libs
	mkdir -p $tmp
	touch $libs
	for f in $@; do
		test -x $f || continue
		ldd $f | grep '=> /' | sed -re 's,.*=> (/[^ ]+) .*,\1,' | \
			grep -v "$XCLUSTER_WORKSPACE" >> $libs
	done

	if test -r $__base_libs; then
		for f in $(sort $libs | uniq); do
			grep -q $f $__base_libs || echo $f
		done
	else
		sort $libs | uniq
	fi
}

cmd_cploader() {
	test -n "$__dest" || die 'No --dest'
	test -d "$__dest" || die "Not a directory [$__dest]"
	cmd_env
	# TODO: Fix this!!
	mkdir -p $__dest/lib64
	cp -L /lib64/ld-linux-x86-64.so.2 $__dest/lib64
}

cmd_mkcdrom() {
	cmd_env

	if test -z "$1"; then
		rm -f $__cdrom
		return 0
	fi

	__dest=$tmp/cdrom
	mkdir -p $__dest
	cmd_collect_tar $@

	if test -n "$__cidata"; then
		test -n "$__label" || __label=cidata
		test -d "Cidata is not a directory [$__cidata]"
		cp -R $__cidata/* $__dest
	fi

	if test -n "$__script"; then
		test -s "$__script" || die "Not a file (or empty) [$__script]"
		cp "$__script" $__dest/script
	fi

	ls $__dest
	test -n "$__label" || __label=xcluster
	genisoimage -quiet -volid $__label -o $__cdrom -r -J $__dest
	rm -rf $__dest
	unset __dest
}

cmd_cat_tar() {
	test -n "$1" || return 0
	test -r "$1" || die "Not readable [$1]"
	local t="$(file $1)"
	if echo $t | grep -q 'POSIX tar'; then
		cat "$1"
	elif echo $t | grep -q 'bzip2 compressed'; then
		bzcat "$1"
	elif echo $t | grep -q 'XZ compressed'; then
		xz -cd "$1"
	elif echo $t | grep -q 'gzip compressed'; then
		pigz -cd "$1"
	fi
}

cmd_collect_tar() {
	test -n "$__dest" || die "No dest"
	test -d "$__dest" || die "Not a directory [$__dest]"
	local c d b i=0 collected=:
	for d in $@ $XOVLS; do
		echo $collected | grep -Fq ":$d:" && continue
		collected="$collected$d:"
		# Check the cache
		if c=$(cmd_cached_tar $d); then
			echo "Use Cached [$c]"
			d=$c
		fi
		if test -f $d; then
			b=$(basename $d | cut -d. -f1)
			cmd_cat_tar $d > "$__dest/$(printf "%02d$b.tar" $i)"
		elif test -x $d/tar; then
			b=$(basename $d)
			$d/tar "$__dest/$(printf "%02d$b.tar" $i)" || die "$d/tar failed"
		else
			b=$d
			d=$(cmd_ovld $d) || return
			test -x $d/tar || die "Not executable [$d/tar]"
			$d/tar "$__dest/$(printf "%02d$b.tar" $i)" || die "$d/tar failed"
		fi
		i=$((i+1))
	done
}

##   inject [--sudo=sudo] [--key=file] --addr=root@... [ovl...]
##     Install ovl's on a running target. The target does not have to be a
##     xcluster VM. Example inject on an AWS instance;
##
##       xc inject --sudo=sudo --key=$HOME/.ssh/aws-key.pem \
##         --addr=ubuntu@ec2-.....compute.amazonaws.com etcd
##
cmd_inject() {
	local ovl ovld
	local sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
	if test -n "$__key"; then
		test -r "$__key" || die "Not readable [$__key]"
		sshopt="$sshopt -i $__key"
	fi
	for ovl in $@; do
		ovld=$(cmd_ovld $ovl)
		$ovld/tar - | ssh $sshopt $__addr $__sudo tar -C / -x
	done
}

##  Utilities;
##   ovld ovl
##   rsh [--bg] <vm> command...
##   rcp <vm> <remote-file> <local-file>
##   tcpdump --start|get <vm> <interface> [opts...]
##   tcpdump --get <vm> <interface...>
##
cmd_ovld() {
	test -n "$1" || die "No ovl"
	cmd_env
	local d
	for d in $(echo $XCLUSTER_OVLPATH | tr : ' '); do
		if test -d $d/$1; then
			echo "$d/$1"
			return 0
		fi
	done
	die "Ovl not found [$1]"
}

sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
cmd_rsh() {
	test -n "$1" || die "No VM"
	local vm=$1
	shift
	local adr
	if ip link show xcbr1 > /dev/null 2>&1; then
		adr="root@192.168.0.$vm"
	else
		adr="-p $((12300+vm)) root@127.0.0.1"
	fi
	if test "$__bg" = "yes"; then
		ssh -q $sshopt $adr sh -c "'$@ > /dev/null 2>&1 &'"
	else
		ssh -q $sshopt $adr $@
	fi
}
cmd_rcp() {
	test -n "$2" || die "Too few parameters"
	local vm=$1
	shift
	if ip link show xcbr1 > /dev/null 2>&1; then
		scp -q $sshopt root@192.168.0.$vm:$1 $2
	else
		scp -q $sshopt -P $((12300+vm)) root@127.0.0.1:$1 $2
	fi
}
cmd_tcpdump() {
	test -n "$2" || die "Too few parameters"
	local vm=$1; shift
	local iface file
	if test "$__start" = "yes"; then
		__bg=yes
		iface=$1; shift
		file=$(printf "/tmp/vm-%03u-$iface.pcap" $vm)
		cmd_rsh $vm tcpdump -Z root -ni $iface -w $file $@
	elif test "$__get" = "yes"; then
		cmd_rsh $vm killall tcpdump
		sleep 0.5
		for iface in $@; do
			file=$(printf "/tmp/vm-%03u-$iface.pcap" $vm)
			cmd_rcp $vm $file $file && echo "wireshark $file &"
		done
	else
		die "Either --start or --get must be specified"
	fi
}


##  Cluster commands;
##   start [--nvm=4] [--nrouters=2] [--ntesters=0]
##   starts [--nvm=4] [--nrouters=2] [--ntesters=0]
##   stop
##   status
##   scaleout nodes...
##   scalein nodes...
##
cmd_boot_vm() {
	cmd_env
	test -n "$1" || die 'No nodeid'
	local nodeid=$1
	shift

	local mport=$((XCLUSTER_MONITOR_BASE+nodeid))
	local opt="-monitor telnet::$mport,server,nowait"
	test "$__graphic" = "yes" || opt="$opt -nographic"

	# Create an overlay-disk
	local hd=$XCLUSTER_TMP/hd-$nodeid.img
	qemu-img create -f qcow2 -o backing_file="$__image" -F qcow2 $hd

	local tvar
	eval tvar=\$__mem$nodeid
	test -n "$tvar" && __mem=$tvar
	eval tvar=\$__smp$nodeid
	test -n "$tvar" && __smp=$tvar
	echo "Memory: $__mem, smp: $__smp"
	rm -rf $tmp

	local kvmboot="-drive file=$hd,if=virtio -smp $__smp -k sv"
    test -r $__cdrom && kvmboot="$kvmboot -drive file=$__cdrom,if=virtio,media=cdrom"

	test -n "$__mtu" || __mtu=1500
	local n dev tap append tnets
	eval tnets=\$__nets$nodeid
	test -n "$tnets" && __nets=$tnets
	echo "nets=[$__nets]"
	for n in $(echo $__nets | tr , ' '); do

		# Customized network setup, e.g. for ovs
		if test -n "$__net_setup" -a -x "$__net_setup"; then
			echo "CUSTOM NET; $__net_setup"
			export __mtu
			export __kvm
			test "$__mtu" -ne 1500 && append="$append mtu$n=$__mtu"
			opt="$opt $($__net_setup $nodeid $n)" || return
			continue
		fi

		dev=xcbr$n
		ip link show dev $dev > /dev/null 2>&1 || \
			die "Bridge does not exists [$dev]"
		tap=${dev}_t$nodeid
		b1=$(printf "%02x" $n)

		test "$__mtu" -ne 1500 && append="$append mtu$n=$__mtu"

		if ip link show dev $tap > /dev/null 2>&1; then
			echo "Tap device already exist [$tap]"
		else
			ip tuntap add $tap mode tap user $USER
			ip link set mtu $__mtu dev $tap
			ip link set dev $tap master $dev
			ip link set up $tap
		fi

		local b0=$(printf '%02x' $nodeid)
		opt="$opt -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap"
		opt="$opt -device virtio-net-pci,netdev=net$n,mac=00:00:00:01:$b1:$b0"
	done

	# Allow ^C in the terminals without killing the entire VM
	stty intr '^]'

	if test "$__bootable" = "yes"; then
		exec $__kvm $kvmboot -m $__mem $opt $__kvm_opt
	else
		eval "__append=\"$__append \${__append$nodeid}\""
		exec $__kvm -kernel $__kbin $kvmboot -m $__mem $opt $__kvm_opt \
			-append "noapic root=/dev/vda rw init=/init $append $@ $__append"
	fi
}
cmd_svm() {
	cmd_env
	test -n "$1" || die 'No nodeid'
	local nodeid=$1
	test $nodeid -gt 0 || die "Invalid nodeid [$nodeid]"
	echo help | telnet 127.0.0.1 $((XCLUSTER_MONITOR_BASE+nodeid)) 2>&1 | \
	grep -q 'Connection refused' || die "Node already active [$nodeid]"

	local sfile=$XCLUSTER_TMP/screen/session
	test -r $sfile || die "Not readable [$sfile]"
	local hname=$(printf "vm-%03d" $nodeid)
	screen -S $(cat $sfile) -X screen -t $hname -L $nodeid \
		$me boot_vm --nets=$__nets --mem=$__mem --smp=$__smp $nodeid
}
cmd_xvm() {
	cmd_env
	test -n "$1" || die 'No nodeid'
	local nodeid=$1
	test $nodeid -gt 0 || die "Invalid nodeid [$nodeid]"
	echo help | telnet 127.0.0.1 $((XCLUSTER_MONITOR_BASE+nodeid)) 2>&1 | \
	grep -q 'Connection refused' || die "Node already active [$nodeid]"

	local x y base=$nodeid
	test $nodeid -gt 200 && base=$((base+4))
	test $nodeid -gt 220 && base=$((base+6))
	x=$(((base-1) / 4 % 2 + 1))
	y=$(((base-1) % 4 + 1))
	local geometry="$(cmd_geometry $x $y)"

	test -n "$__bg" || __bg='#040'
	nohup xterm -T "vm-$nodeid" -fg wheat -bg "$__bg" $xtermopt $geometry \
		-e $me boot_vm --nets=$__nets --mem=$__mem --smp=$__smp $nodeid \
		> /dev/null < /dev/null 2>&1 &
}
cmd_geometry() {
    eval ${XCLUSTER_LAYOUT:-"dx=550;dy=220;sz=80x12"}
    eval ${XCLUSTER_OFFSET:-"xo=20;yo=50"}
    test -n "$1" || die "No X position"
    test -n "$2" || die "No Y position"
    local x=$1
    local y=$2
    local X=$(((x-1)*dx+xo))
    local Y=$(((y-1)*dy+yo))
    echo "-geometry $sz+$X+$Y $xopt"
}
cmd_status() {
	cmd_env
	local nvm=8 nrouters=4 ntesters=2
	test -n "$__nvm" && test "$__nvm" -gt $nvm && nvm=$__nvm
	test -n "$__nrouters" && test $__nrouters -gt $nrouters && nrouters=$__nrouters
	test -n "$__ntesters" && test $__ntesters -gt $ntesters && ntesters=$__ntesters
	local n s alive=0 hvm=0
	for n in $(seq 1 $nvm) $(seq 201 $((200+nrouters))) \
		$(seq 221 $((220+ntesters))); do
		s=alive
		if echo help | telnet 127.0.0.1 $((XCLUSTER_MONITOR_BASE+n)) 2>&1 | \
			grep -q 'Connection refused'; then
			s="dead "
		else
			alive=$((alive+1))
			test $n -le 90 && hvm=$n
		fi
		test "$__quiet" != "yes" && echo "$s $n"
	done
	test "$__quiet" != "yes" && echo "Active VMs; $alive, Highest pl; $hvm"
	return $alive
}

cmd_start() {
	cmd_env
	local n dev
	if test -z "$__net_setup"; then
		for n in 0 1 2; do
			dev=xcbr$n
			ip link show dev $dev > /dev/null 2>&1 || \
				log "WARNING: Bridge not setup [$dev]"
		done
	fi

	test -n "$__nvm" || __nvm=4
	__quiet=yes
	if ! cmd_status; then
		cmd_stop
		sleep 1
	fi
	rm -rf $XCLUSTER_TMP/screen $XCLUSTER_TMP/*.img

	__nets=$__nets_vm
	for n in $(seq $__nvm); do
		cmd_xvm $n
	done

	test "$__nrouters" || __nrouters=2
	if test $__nrouters -gt 0; then
		__nets=$__nets_router
		__bg='#400'
		for n in $(seq 201 $((200+__nrouters))); do
			cmd_xvm $n
		done
	fi

	test "$__ntesters" || __ntesters=0
	if test $__ntesters -gt 0; then
		__nets=0,2
		__bg='#004'
		for n in $(seq 221 $((220+__ntesters))); do
			cmd_xvm $n
		done
	fi

}

cmd_starts() {
	cmd_env

	local n dev
	if test -z "$__net_setup"; then
		for n in 0 1 2; do
			dev=xcbr$n
			ip link show dev $dev > /dev/null 2>&1 || \
				log "WARNING: Bridge not setup [$dev]"
		done
	fi

	test -n "$__nvm" || __nvm=4
	__quiet=yes
	if ! cmd_status; then
		cmd_stop
		sleep 1
	fi
	rm -rf $XCLUSTER_TMP/screen $XCLUSTER_TMP/*.img

	# Create a screen session
	local T=$XCLUSTER_TMP/screen
	rm -rf $T
	mkdir -p $T
	local session=$(mktemp -u xcluster-XXXX)
	echo $session > $T/session
	local screen_rc=$T/screen.rc
	echo logfile "$T/screenlog.%t" > $screen_rc
	echo screen -t tmp -L 100 sleep 5 >> $screen_rc
	screen -d -m -c $screen_rc -S $session || die "Screen failed"

	__nets=$__nets_vm
	for n in $(seq $__nvm); do
		cmd_svm $n
	done

	test "$__nrouters" || __nrouters=2
	if test $__nrouters -gt 0; then
		local last=$((200+__nrouters))
		__nets=$__nets_router
		for n in $(seq 201 $last); do
			cmd_svm $n
		done
	fi

	test "$__ntesters" || __ntesters=0
	if test $__ntesters -gt 0; then
		local last=$((220+__ntesters))
		__nets=0,2
		for n in $(seq 221 $last); do
			cmd_svm $n
		done
	fi

	echo "Screen session [$session]"
}

cmd_stop() {
	cmd_env
	local nodeid port vms
	vms="$(livevms | sort -n | uniq)"
	#log "Stopping [$(echo $vms | tr '\n' ' ')]"
	for nodeid in $vms; do
		port=$((XCLUSTER_MONITOR_BASE+nodeid))
		echo quit | nc localhost $port > /dev/null 2>&1
	done
	kill $(grep -ls XXTERM=XCLUSTER /proc/*/environ | cut -d/ -f3) > /dev/null 2>&1
	# Don't do this! It breaks backward compatibility!
	#rm -f $XCLUSTER_TMP/hd-*.img $XCLUSTER_TMP/cdrom.iso
	return 0
}
livevms() {
	find $XCLUSTER_TMP -maxdepth 1 -type f -name 'hd-*.img' | sed -E 's,.*hd-([0-9]+)\.img,\1,'
	# Keep for backward compatibility (probably not necessary)
	local nvm=0 nrouters=0 ntesters=0
	test -n "$__nvm" && test "$__nvm" -gt $nvm && nvm=$__nvm
	test -n "$__nrouters" && test $__nrouters -gt $nrouters && nrouters=$__nrouters
	test -n "$__ntesters" && test $__ntesters -gt $ntesters && ntesters=$__ntesters
	local lastr=$((200+nrouters))
	local lastt=$((220+ntesters))
	seq $nvm
	seq 201 $lastr
	seq 221 $lastt
}
cmd_scaleout() {
	cmd_env
	local cmd=cmd_xvm
	test -r $XCLUSTER_TMP/screen/session && cmd=cmd_svm
	local n
	for n in $@; do
		__nets=$__nets_vm
		if test $n -gt 220; then
			# Tester
			__bg='#004'
			__nets=0,2
		elif test $n -gt 200; then
			# Router
			__bg='#400'
			__nets=$__nets_router
		fi
		$cmd $n
	done
}
cmd_scalein() {
	cmd_env
	local n port
	for n in $@; do
		port=$((XCLUSTER_MONITOR_BASE+n))
		echo quit | nc localhost $port > /dev/null 2>&1
	done
	return 0
}


# Check the XCLUSTER_HOOK
test -n "$XCLUSTER_HOOK" -a -r "$XCLUSTER_HOOK" && . $XCLUSTER_HOOK

# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 $XCLUSTER_HOOK || die "Invalid command [$cmd]"

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
