#! /bin/sh
##
## containerd.sh --
##
##   Help script for the xcluster ovl/containerd.
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

##   env
##     Print environment.
cmd_env() {
	test -n "$__containerd_ver" || __containerd_ver=1.7.0
	test -n "$__containerd_ar" || __containerd_ar=containerd-$__containerd_ver-linux-amd64.tar.gz

	test -n "$__crictl_ver" || __crictl_ver=v1.27.1
	test -n "$__crictl_ar" ||  __crictl_ar=crictl-$__crictl_ver-linux-amd64.tar.gz

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   version
##     Print the containerd version
cmd_version() {
	cmd_env
	echo $__containerd_ver
}
##   archive
##     Print the containerd archive or die trying
cmd_archive() {
	cmd_env
	local ar=$ARCHIVE/$__containerd_ar
	test -r $ar || ar=$HOME/Downloads/$__containerd_ar
	test -r $ar || die "Not found [$__containerd_ar]"
	echo $ar
}
##   install <dir>
##     Install in the specified dir (must exist)
cmd_install() {
	test -n "$1" || die "No dir"
	local dest=$1
	test -d "$dest" || die "Not a directory [$dest]"
	cmd_archive > /dev/null
	log "Installing containerd [$__containerd_ver]"
	local ar=$(cmd_archive)
	tar --strip-components=1 -C $dest -xf $ar || die tar
}
##   install_crictl <dir>
##     Install "crictl" in the specified dir (must exist)
cmd_install_crictl() {
	test -n "$1" || die "No dir"
	local dest=$1
	test -d "$dest" || die "Not a directory [$dest]"
	cmd_env
	ar=$ARCHIVE/$__crictl_ar
	test -r $ar || ar=$HOME/Downloads/$__crictl_ar
	test -r $ar || die "Not found [$__crictl_ar]"
	log "Installing crictl [$__crictl_ver]"
	tar -C $dest -xf $ar || die tar
}
##   download
cmd_download() {
	cmd_env
	local url ar
	
	if ! (cmd_archive) > /dev/null 2>&1; then
		url=https://github.com/containerd/containerd/releases/download
		ar=$ARCHIVE/$__containerd_ar
		mkdir -p $ARCHIVE
		curl -L $url/v$__containerd_ver/$__containerd_ar > $ar
	fi
	cmd_archive
	ar=$ARCHIVE/$__crictl_ar
	if ! test -r $ar; then
		url=https://github.com/kubernetes-sigs/cri-tools/releases/download
		curl -L $url/$__crictl_ver/$__crictl_ar > $ar
	fi
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
        for t in $@; do
            test_$t
        done
    else
        test_start
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	unset XOVLS
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export CONTAINERD_TEST=yes
	xcluster_start network-topology iptools private-reg k8s-cni-bridge containerd $@
	otc 1 version
}

##   test start (default)
##     Start cluster and setup
test_start() {
	test -n "$__nrouters" || export __nrouters=0
	test_start_empty
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
