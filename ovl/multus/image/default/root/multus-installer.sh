#! /bin/sh
##
## multus-installer.sh --
##
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$

##   env
##     Print environment.
cmd_env() {
	test -n "$__multus_ver" || __multus_ver=unknown
	test -n "$__cgibin_ver" || __cgibin_ver=unknown

    if test "$cmd" = "env"; then
        set | grep -E '^(__.*)='
        return 0
    fi
}

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

##   install [--dest=/opt/cgi/bin]
##     Install multus and cgi-bin
cmd_install() {
	test -n "$__dest" || __dest=/opt/cgi/bin
	echo "Installing cgi-bin:$__cgibin_ver and multus:$__multus_ver in $__dest"
	test -d $__dest || die "Not a directory [$__dest]"
	local ar=multus-cni_${__multus_ver}_linux_amd64.tar.gz
	test -r "$dir/$ar" || die "Not readable [$ar]"
	tar -C $__dest --strip-components=1 -xf $dir/$ar multus-cni_${__multus_ver}_linux_amd64/multus-cni
	ar=cni-plugins-linux-amd64-${__cgibin_ver}.tgz
	test -r "$dir/$ar" || die "Not readable [$ar]"
	tar -C $__dest -xf $dir/$ar
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
