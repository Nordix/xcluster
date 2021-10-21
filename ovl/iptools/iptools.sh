#! /bin/sh
##
## iptools.sh --
##   Iptools scriptlets for xcluster.
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

netfilter_url=https://netfilter.org/projects

cmd_env() {
	eval $($XCLUSTER env)
	sysd=$XCLUSTER_WORKSPACE/sys
	export PKG_CONFIG_PATH=$sysd/usr/lib/pkgconfig	
	pkg_config_fix
	kernel_fix
}
kernel_fix() {
	# For kernels >= 5.9
	local f=$KERNELDIR/$__kver/include/linux/compiler.h
	test -r $f || return 0
	sed -i -e '/rwonce.h/d' $f
}
pkg_config_fix() {
	local n
	for n in $(find $PKG_CONFIG_PATH -name '*.pc'); do
		grep -q 'prefix=/usr' $n && \
			sed -ie "s,prefix=/usr,prefix=$sysd/usr," $n
	done
}
la_fix() {
	local n
	for n in $(find $sysd -name '*.la'); do
		sed -ie "s, /usr, $sysd/usr," $n
	done
}

build() {
	cmd_env
	local v ar d n
	n=$1
	local v=$(ver $n)
	test "$n" = "conntrack_tools" && n=conntrack-tools
	d=$XCLUSTER_WORKSPACE/$n-$v
	test "$__clean" = "yes" && rm -r $d
	if test -d "$d"; then
		test "$__quiet" = "yes" || echo "Already built at [$d]"
		return 0
	fi
	if test "$1" = "ipvsadm"; then
		build_ipvsadm $n-$v
		return
	fi
	if test "$1" = "iproute2"; then
		build_iproute2 $n-$v
		return
	fi
	ar=$n-$v.tar.bz2
	test -r $ARCHIVE/$ar || ar=$n-$v.tar.gz
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	cd $d
	if test "$n" = "iptables" -o "$n" = "ipset"; then
		./configure --prefix=/usr \
			--with-kbuild=$__kobj --with-ksource=$KERNELDIR/$__kver
	else
		./configure --prefix=/usr
	fi
	test "$n" = "nftables" && sed -ie 's,\tdoc,,' Makefile
	la_fix
	make -j$(nproc) || die "Make failed"
	make DESTDIR=$sysd install || die "Install failed"
	echo "Built at [$d]"
}
build_ipvsadm() {
	cmd_env
	local ar d libs
	d=$XCLUSTER_WORKSPACE/$1
	rm -fr $d
	ar=$1.tar.xz
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	cd $d
	make || die make
	cp $d/ipvsadm $sysd/usr/sbin
	echo "Built at [$d]"
}
build_iproute2() {
	cmd_env
	local ar d libs
	d=$XCLUSTER_WORKSPACE/$1
	test -d $__kobj/sys/include || cmd_build_kernel_headers
	return
	rm -fr $d
	ar=$1.tar.gz
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar || die tar
	cd $d
	make KERNEL_INCLUDE=$__kobj/sys/include || die make
	make DESTDIR=$d/sys install || die "make install"
	echo "Built at [$d]"
}

download() {
	local n v u ar
	n=$1
	v=$(ver $n) || die "Can't find the version for [$n]"
	test "$n" = "conntrack_tools" && n=conntrack-tools
	case $n in
		ipvsadm)
			ar=$n-$v.tar.xz
			u=https://mirrors.edge.kernel.org/pub/linux/utils/kernel/ipvsadm/$ar;;
		ipset)
			ar=$n-$v.tar.bz2
			u=http://ipset.netfilter.org/$ar;;
		iproute2)
			ar=iproute2-$v.tar.gz
			u=https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/snapshot/$ar;;
		*)
			ar=$n-$v.tar.bz2
			u=$netfilter_url/$n/files/$ar;;
	esac
	if test "$__dryrun" = "yes"; then
		echo $ar
		return 0
	fi
	if test -r $ar; then
		test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
	else
		curl -L $u > $ar || die "Failed to download [$u]"
		echo "Downloaded [$ar]"
	fi
}

libmnl_ver=1.0.4
libnftnl_ver=1.1.9
iptables_ver=1.8.7
nftables_ver=0.9.8
libnfnetlink_ver=1.0.1
libnetfilter_cttimeout_ver=1.0.0
libnetfilter_conntrack_ver=1.0.7
libnetfilter_cthelper_ver=1.0.0
libnetfilter_queue_ver=1.0.3
conntrack_tools_ver=1.4.5
ipvsadm_ver=1.31
ipset_ver=7.15
iproute2_ver=5.13.0
ver() {
	eval "echo \$${1}_ver"
}

# ----------------------------------------------------------------------
#

cmd_build_kernel_headers() {
	eval $($XCLUSTER env | grep -E '__kver|__kobj|KERNELDIR')
	cd $__kobj
	make INSTALL_HDR_PATH=$(readlink -f .)/sys headers_install || die make
}

##   items
##     List items handled by this script
cmd_items() {
	grep -E '^.+_ver\=' $me | sed -re 's,_ver\=.*,,'
}

##   versions
cmd_versions() {
	local n
	for n in $(cmd_items); do
		echo "$n=$(ver $n)"
	done
}

##   download
cmd_download() {
	cd $ARCHIVE
	if test -n "$1"; then
		for n in $@; do
			download $n
		done
	else
		for n in $(cmd_items); do
			download $n
		done
	fi
}

##   build [items...]
##
cmd_build() {
	if test -n "$1"; then
		for n in $@; do
			build $n
		done
	else
		for n in $(cmd_items); do
			build $n
		done
	fi
}


# Check the hook
if test -r $hook; then
	. $hook
else
	hook=''
fi

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
#mkdir -p $tmp
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
