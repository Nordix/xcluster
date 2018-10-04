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
	ar=$n-$v.tar.bz2
	test -r $ARCHIVE/$ar || ar=$n-$v.tar.gz
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	cd $d
	if test "$n" = "iptables" -o "$n" = "ipset"; then
		./configure --prefix=/usr \
			--with-kbuild=$__kobj --with-ksource=$ARCHIVE/$__kver
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
	rm -r $d
	ar=$1.tar.gz
	tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	cd $d
	libs="$(pkg-config --libs libnl-1)"
    make INCLUDE=-I$sysd/usr/include LIBS="$libs -lpopt" || die "Make failed"
	cp $d/ipvsadm $sysd/usr/sbin
	echo "Built at [$d]"
}

download() {
	local n v u ar
	n=$1
	v=$(ver $n) || die "Can't find the version for [$n]"
	test "$n" = "conntrack_tools" && n=conntrack-tools
	case $n in
		ipvsadm)
			ar=$n-$v.tar.gz
			u=http://www.linuxvirtualserver.org/software/kernel-2.6/$ar;;
		libnl)
			ar=$n-$v.tar.gz
			u=https://www.infradead.org/~tgr/libnl/files/$ar;;
		ipset)
			ar=$n-$v.tar.bz2
			u=http://ipset.netfilter.org/$ar;;
		*)
			ar=$n-$v.tar.bz2
			u=$netfilter_url/$n/files/$ar;;
	esac
	if test -r $ar; then
		test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
	else
		curl $u > $ar || die "Failed to download [$u]"
		echo "Downloaded [$ar]"
	fi
}


libmnl_ver=1.0.4
libnftnl_ver=1.0.9
iptables_ver=1.6.2
nftables_ver=0.8.3
libnfnetlink_ver=1.0.1
libnetfilter_cttimeout_ver=1.0.0
libnetfilter_conntrack_ver=1.0.6
libnetfilter_cthelper_ver=1.0.0
libnetfilter_queue_ver=1.0.3
conntrack_tools_ver=1.4.4
libnl_ver=1.1.4
ipvsadm_ver=1.26
ipset_ver=6.38
ver() {
	eval "echo \$${1}_ver"
}

# ----------------------------------------------------------------------
#

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
