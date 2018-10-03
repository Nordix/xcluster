#! /bin/sh
##
## systemd.sh --
##   Help script for building systemd locally.
##
## Commands;
##

#https://github.com/systemd/systemd/issues/6477

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
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


ver=238

cmd_d() {
	echo $XCLUSTER_WORKSPACE/systemd-$ver/obj
}

##  download [--meson]
##  unpack [--meson]
##    Download/unpack; systemd, meson, ninja and util-linux.
##
cmd_download() {
	local u ar v
	v=$ver
	# Find it via; https://github.com/systemd/systemd/tags
	u=https://github.com/systemd/systemd/archive/v$v.tar.gz
	ar=systemd-$v.tar.gz
	if test -r $ARCHIVE/$ar; then
		test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
	else
		echo "Downloaded [$ar]"
		curl -L $u > $ARCHIVE/$ar
	fi

	if test "$__meson" = "yes"; then
		v=1.8.2
		ar=ninja-linux.zip
		u=https://github.com/ninja-build/ninja/releases/download/v$v/$ar
		if test -r $ARCHIVE/$ar; then
			test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
		else
			echo "Downloaded [$ar]"
			curl -L $u > $ARCHIVE/$ar
		fi

		v=0.44.0
		ar=meson-$v.tar.gz
		u=https://github.com/mesonbuild/meson/releases/download/$v/$ar
		if test -r $ARCHIVE/$ar; then
			test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
		else
			echo "Downloaded [$ar]"
			curl -L $u > $ARCHIVE/$ar
		fi
	fi

	v=2.31
	ar=util-linux-$v.tar.gz
	u=https://www.kernel.org/pub/linux/utils/util-linux/v$v/$ar
	if test -r $ARCHIVE/$ar; then
		test "$__quiet" = "yes" || echo "Already downloaded [$ar]"
	else
		curl -L $u > $ARCHIVE/$ar
		echo "Downloaded [$ar]"
	fi	
}

cmd_unpack() {
	local v ar d p
	ar=$ARCHIVE/systemd-$ver.tar.gz
	test -r $ar || die "Not readable [$ar]"
	d=$XCLUSTER_WORKSPACE/systemd-$ver
	if ! test -d $d; then
		tar -C $XCLUSTER_WORKSPACE -xf $ar
		p=$dir/$ver.patch
		test -r $p && patch -b -d $d -p0 < $p
	fi
	if test "$__meson" = "yes"; then
		v=0.44.0
		ar=$ARCHIVE/meson-$v.tar.gz
		d=$XCLUSTER_WORKSPACE/meson-$v
		if ! test -d $d; then
			tar -C $XCLUSTER_WORKSPACE -xf $ar
			ar=$ARCHIVE/ninja-linux.zip
			cd $d
			unzip $ar
			cp meson.py meson
		fi
	fi

	v=2.31
	d=$XCLUSTER_WORKSPACE/util-linux-$v
	ar=$ARCHIVE/util-linux-$v.tar.gz
	test -d $d || tar -C $XCLUSTER_WORKSPACE -xf $ar
}


##  build
##    Build systemd using it's build system (meson)
##
cmd_build() {
	local v ar d
	export PATH=$PATH:$XCLUSTER_WORKSPACE/meson-0.44.0
	d=$XCLUSTER_WORKSPACE/systemd-$ver
	cd $d
	./configure
}

##  make [make-params]
##    Make systemd using an own makefile.
##
cmd_make() {
	local d ar
	ar=$ARCHIVE/systemd-$ver.tar.gz
	d=$XCLUSTER_WORKSPACE/systemd-$ver
	test -d $d || tar -C $XCLUSTER_WORKSPACE -xf $ar
	make -f $dir/Systemd.make S=$d/src O=$d/obj C=$dir/config.h $@
}


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
