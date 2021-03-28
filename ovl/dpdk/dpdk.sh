#! /bin/sh
##
## dpdk.sh --
##
##   Help script for the xcluster ovl/dpdk.
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

	test -n "$__dpdk_ver" || __dpdk_ver=20.11
	if ! test -n "$__dpdk_src"; then
		__dpdk_src=$XCLUSTER_WORKSPACE/dpdk-stable-$__dpdk_ver
		test "$__dpdk_ver" = "20.11" && \
			__dpdk_src=$XCLUSTER_WORKSPACE/dpdk-$__dpdk_ver
	fi
	test -n "$__meson_ver" || __meson_ver=0.53.1
	test -n "$__meson_dir" || __meson_dir=$HOME/tmp/meson-$__meson_ver
	test -n "$__arm_url" || __arm_url=https://artifactory.nordix.org/artifactory
	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)

}


##   test --list
##   test [--xterm] [test...] > logfile
##     Exec tests
##
cmd_test() {
	if test "$__list" = "yes"; then
        grep '^test_' $me | cut -d'(' -f1 | sed -e 's,test_,,'
        return 0
    fi

	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
        for t in $@; do
            test_$t
        done
    else
        for t in start_basic; do
            test_$t
        done
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

# Start with the default xcluster network setup.
# vm-201 prepared for DPDK, vm's are supposed to be back-ends.
test_start() {
	export __image=$XCLUSTER_HOME/hd.img
	export XOVLS=$(echo $XOVLS | sed -e 's,private-reg,,')
	export __nrouters=1
	export __ntesters=1
	export __mem=256
	export __mem201=1024
	export __smp201=4
	export __append201="hugepages=128"
	# Avoid "Illegal instruction" error
	export __kvm_opt='-object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=80000 -cpu host'
	xcluster_start env network-topology iptools dpdk
}

# Start just 2 VMs connected via eth1 and eth2 for basic tests
test_start_basic() {
	export __image=$XCLUSTER_HOME/hd.img
	export XOVLS=$(echo $XOVLS | sed -e 's,private-reg,,')
	export __nvm=2
	export __nrouters=0
	export __ntesters=0
	export __mem=1024
	export __smp=4
	export __nets_vm=0,1,2
	export __append="hugepages=128"
	export xcluster_SETUP=basic
	# Avoid "Illegal instruction" error
	export __kvm_opt='-object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=80000 -cpu host'
	xcluster_start env iptools dpdk
}


##   libs <bin...>
cmd_libs() {
	cmd_env
	export LD_LIBRARY_PATH=$__dpdk_src/build/sys/usr/local/lib/x86_64-linux-gnu
	local f libs=$tmp/libs
	mkdir -p $tmp
	for f in $@; do
		test -x $f || continue
		ldd $f | grep '=> /' | sed -re 's,.*=> (/[^ ]+) .*,\1,' | \
			grep "$LD_LIBRARY_PATH" >> $libs
	done

	sort $libs | uniq
}

##   install_meson [--meson_ver=0.53.1] [meson_dir=$HOME/tmp/meson-<ver>]
cmd_install_meson() {
	cmd_env
	test -d $__meson_dir && return 0
	local ar=meson-$__meson_ver.tar.gz
	if ! test -r $ARCHIVE/$ar; then
		local baseurl=https://github.com/mesonbuild/meson/releases/download
		local url=$baseurl/$__meson_ver/$ar
		curl -L $url > $ARCHIVE/$ar
	fi
	local basedir=$(dirname $__meson_dir)
	mkdir -p $basedir
	tar -C $basedir -xf $ARCHIVE/$ar
	echo "Meson installed at [$__meson_dir]"
}

##   download_cache
cmd_download_cache() {
	cmd_env
	local ar=$__cached/default/dpdk.tar.xz
	if test -r $ar; then
		log "Already cached at [$ar]"
		return 0
	fi
	mkdir -p $__cached/default
	curl -L $__arm_url/cloud-native/xcluster/ovl-cache/dpdk.tar.xz > $ar
}

##   download_kernel
cmd_download_kernel() {
	cmd_env
	echo $__kbin | grep -q $__kver || __kbin=$XCLUSTER_HOME/bzImage-$__kver
	if test -r $__kbin; then
		log "Already downloaded [$__kbin]"
		return 0
	fi
	mkdir -p $(dirname $__kbin)
	local kbin=$(basename $__kbin)
	curl -L $__arm_url/cloud-native/xcluster/images/$kbin > $__kbin
}

##   download
cmd_download() {
	cmd_env
	local ar=dpdk-$__dpdk_ver.tar.xz
	if test -r $ARCHIVE/$ar; then
		log "Already downloaded [$ARCHIVE/$ar]"
		return 0
	fi
	curl -L https://fast.dpdk.org/rel/$ar > $ARCHIVE/$ar || die "download"
}

##   unpack [--force] [--dpdk-src=<dir>]
cmd_unpack() {
	cmd_env
	test "$__force" = "yes" && rm -rf $__dpdk_src
	if test -d $__dpdk_src; then
		echo "Already unpacked at [$__dpdk_src]"
		return 0
	fi
	local ar=$ARCHIVE/dpdk-$__dpdk_ver.tar.xz
	test -r $ar || die "Not readable [$ar]"
	local basedir=$(dirname $__dpdk_src)
	mkdir -p $basedir
	tar -C $basedir -xf $ar
	echo "Unpacked at [$__dpdk_src]"
}

##   build [--force]
cmd_build() {
	cmd_env
	test "$__force" = "yes" && rm -rf $__dpdk_src/build
	if test -d $__dpdk_src/build; then
		echo "Already built at [$__dpdk_src/build]"
		return 0
	fi

	__force=no
	cmd_unpack

	# The dpdk build system requires a "build/" dir in kernel_dir
	test -h $__kobj/build || ln -s . $__kobj/build

	cd $__dpdk_src
	$__meson_dir/meson.py -Dkernel_dir=$__kobj -Denable_kmods=true build || \
		die "Meson config failed"

	cd $__dpdk_src/build
	ninja || die "Ninja build failed"

	DESTDIR=$__dpdk_src/build/sys ninja install || die "Ninja install failed"

	cmd_fix_pkg_config
}
cmd_fix_pkg_config() {
	test -n "$PKG_CONFIG_PATH" || die 'Not set [$PKG_CONFIG_PATH]'
	test -d $PKG_CONFIG_PATH || die "Not a directory [$PKG_CONFIG_PATH]"
	local f
	for f in $(find $PKG_CONFIG_PATH -type f -name 'libdpdk*.pc'); do
		sed -i -e "s,prefix=/usr/local,prefix=$__dpdk_src/build/sys/usr/local," $f
	done
}
##   make [--force]
cmd_make() {
	cmd_env
	test "$__force" = "yes" && rm -rf $__dpdk_src/sys
	if test -d $__dpdk_src/sys; then
		echo "Already built at [$__dpdk_src/sys]"
		return 0
	fi

	__force=no
	cmd_unpack

	# The dpdk build system requires a "build/" dir in kernel_dir
	test -h $__kobj/build || ln -s . $__kobj/build

	cd $__dpdk_src
	DESTDIR=$__dpdk_src/sys make -j$(nproc) RTE_KERNELDIR=$__kobj T=x86_64-native-linuxapp-gcc install || tdie make
}

#  check_kobj
#    By default dpdk build with kernel /lib/modules/$(uname -r)/.
#    If another "kernel_dir" is specified (like we do) it must contain
#    a "build/" directory with similar kernel-headers.
cmd_check_kobj() {
	cmd_env
	echo "Creating link [$__kobj/build]"
	rm -rf $__kobj/build
	ln -s . $__kobj/build
	#make -C $__kobj INSTALL_HDR_PATH=. headers_install
}

. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''

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
