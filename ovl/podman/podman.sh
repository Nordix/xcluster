#! /bin/sh
##
## podman.sh --
##
##   Help script for the xcluster ovl/podman.
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$
test -n "$PREFIX" || PREFIX=1000::1

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

## Commands;
##

##   env
##     Print environment.
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$xcluster_DOMAIN" || xcluster_DOMAIN=xcluster
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

download() {
	local pkg ver url rfile file
	pkg=$1
	ver=$(version $pkg) || die "Can't find the version for [$pkg]"
	case $pkg in
		conmon)
			rfile=$pkg.amd64
			file=$pkg-$ver;;
		crun)
			rfile=$pkg-$ver-linux-amd64
			file=$pkg-v$ver;;
		aardvark)
			pkg=aardvark-dns
			rfile=$pkg.gz
			file=$pkg-$ver.gz;;
		netavark)
			rfile=$pkg.gz
			file=$pkg-$ver.gz;;
		podman)
			url=https://github.com/containers/$pkg/archive/refs/tags/$ver.tar.gz
			file=$pkg-$ver.tar.gz;;
	esac
	if test "$__dryrun" = "yes"; then
		echo $file
		return 0
	fi
	if test -r $file; then
		test "$__quiet" = "yes" || echo "Already downloaded [$file]"
	else
		test -n "$url" || url=https://github.com/containers/$pkg/releases/download/$ver/$rfile
		curl -L $url > $file || die "Failed to download [$url]"
		echo "Downloaded [$file]"
	fi
}

install() {
	cmd_env
	local pkg ver file
	pkg=$1
	ver=$(version $pkg) || die "Can't find the version for [$pkg]"
	dest=$2
	case $pkg in
		conmon)
			file=$pkg-$ver;;
		crun)
			file=$pkg-v$ver;;
		aardvark)
			pkg=aardvark-dns
			file=$XCLUSTER_WORKSPACE/sys/usr/bin/$pkg-$ver
			gunzip -c $pkg-$ver.gz > $file;;
		netavark)
			file=$XCLUSTER_WORKSPACE/sys/usr/bin/$pkg-$ver
			gunzip -c $pkg-$ver.gz > $file;;
		podman)
			# podman binary doesn't seem to be available in github releases
			# we either have to install via distro package manager or build
			# it manually.
			s=$XCLUSTER_WORKSPACE/$pkg-4.6.2
			d=$XCLUSTER_WORKSPACE/sys
			if test -d $s; then
				echo "Already unpacked [$s]"
			else
				tar -C $XCLUSTER_WORKSPACE -xf $pkg-$ver.tar.gz
			fi
			file=$d/usr/bin/$pkg
			if test -f $f; then
				echo "Already built [$file]"
			else
				make -C $s BUILDTAGS="selinux seccomp" PREFIX=/usr > /dev/null 2>&1 || die "podman make failed"
				make -C $s install DESTDIR=$d PREFIX=/usr > /dev/null 2>&1 || die "podman make install failed"
			fi;;
	esac

	cp $file $dest/$pkg || die "$pkg install failed"
	chmod +x $dest/$pkg
	echo "Installed $pkg version [$ver]"
}

conmon_ver=v2.1.8
crun_ver=1.9
aardvark_ver=v1.7.0
netavark_ver=v1.7.0
podman_ver=v4.6.2
version() {
	eval "echo \$${1}_ver"
}

##   items
##     List items handled by this script
cmd_items() {
	grep -E '^.+_ver\=' $me | sed -re 's,_ver\=.*,,'
}

##   versions
cmd_versions() {
	local pkg
	for pkg in $(cmd_items); do
		echo "$pkg=$(version $pkg)"
	done
}

##   download
cmd_download() {
	cd $ARCHIVE
	if test -n "$1"; then
		for pkg in $@; do
			download $pkg
		done
	else
		for pkg in $(cmd_items); do
			download $pkg
		done
	fi
}

##   install <dir>
##     Install in the specified dir (must exist)
cmd_install() {
	test -n "$1" || die "No dir"
	local dest=$1
	shift
	test -d "$dest" || die "Not a directory [$dest]"

	cd $ARCHIVE
	if test -n "$1"; then
		for pkg in $@; do
			install $pkg $dest
		done
	else
		for pkg in $(cmd_items); do
			install $pkg $dest
		done
	fi
}

##
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
