#! /bin/sh
##
## cni-plugins.sh --
##
##   Help script for the xcluster ovl/cni-plugins.
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
	echo "$*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##   env
##     Print environment.
cmd_env() {

	test -n "$__cniver" || __cniver=v1.3.0
	test -n "$__cni_plugin_ar" || __cni_plugin_ar=cni-plugins-linux-amd64-$__cniver.tgz

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   version
##     Print the cni-plugin version.
cmd_version() {
	cmd_env
	echo $__cniver
}
##   archive
##     Print the archive or die trying. Search in $ARCHIVE and $HOME/Downloads
cmd_archive() {
	cmd_env
	local ar=$ARCHIVE/$__cni_plugin_ar
	test -r $ar || ar=$HOME/Downloads/$__cni_plugin_ar
	test -r $ar || die "Can't find [$__cni_plugin_ar]"
	echo $ar
}

##   install --dest=dir [plugins...]
##     Install cni-plugins.
cmd_install() {
	test -n "$__dest" || die "No dest"
	test -d "$__dest" || die "Not a directory [$__dest]"
	cmd_env
	cmd_archive > /dev/null
	log "Installing cni-plugins version [$__cniver]"
	local ar=$(cmd_archive)
	if test -n "$1"; then
		local p plugins
		for p in $@; do
			plugins="$plugins ./$p"
		done
		tar -C $__dest -xf $ar $plugins || tdie "tar"
	else
		tar -C $__dest -xf $ar || tdie "tar"
	fi
	strip $__dest/* > /dev/null 2>&1
	return 0
}
##   download
cmd_download() {
	cmd_env
	if ! (cmd_archive) > /dev/null 2>&1; then
		local ar=$ARCHIVE/$__cni_plugin_ar
		local url=https://github.com/containernetworking/plugins/releases/download
		curl -L $url/$__cniver/$__cni_plugin_ar > $ar
	fi
	cmd_archive
}
##
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
##
cmd_test() {
	cmd_env
	start=starts
	test "$__xterm" = "yes" && start=start
	rm -f $XCLUSTER_TMP/cdrom.iso

	if test -n "$1"; then
		local t=$1
		shift
		test_$t $@
	else
		test_start
	fi		

	now=$(date +%s)
	tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster without K8s
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	echo "$XOVLS" | grep -q private-reg && unset XOVLS
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export CNI_PLUGIN_TEST=yes
	xcluster_start network-topology iptools cni-plugins $@
	otc 1 version
}
##   test start (default)
##     Start a K8s cluster with trace on "bridge"
test_start() {
	export CNI_PLUGIN_TEST=yes
	export xcluster_CNI_PLUGIN_TRACE=bridge
	xcluster_start cni-plugins $@
	otc 1 check_namespaces
	otc 1 check_nodes
}

. $($XCLUSTER ovld test)/default/usr/lib/xctest
indent=''

##
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
