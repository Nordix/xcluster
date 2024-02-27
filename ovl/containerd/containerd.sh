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
	echo "$*" >&2
}
findf() {
	f=$ARCHIVE/$1
	test -r $f || f=$HOME/Downloads/$1
	test -r $f
}

##   env
##     Print environment.
cmd_env() {
	test -n "$__containerd_ver" || __containerd_ver=1.7.11
	test -n "$__containerd_ar" || __containerd_ar=containerd-$__containerd_ver-linux-amd64.tar.gz

	test -n "$__crictl_ver" || __crictl_ver=v1.29.0
	test -n "$__crictl_ar" ||  __crictl_ar=crictl-$__crictl_ver-linux-amd64.tar.gz

	if test "$cmd" = "env"; then
		local opt="containerd.*|crictl.*"
		set | grep -E "^(__($opt))="
		exit 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}

##   version
##     Print the containerd version
cmd_version() {
	echo $__containerd_ver
}
##   archive
##     Print the containerd archive or die trying
cmd_archive() {
	findf $__containerd_ar || die "Not found [$__containerd_ar]"
	echo $f
}
##   install [--containerd_ver=local] <dir>
##     Install in the specified dir (must exist). If containerd_ver=local
##     containerd is copied from $GOPATH/src/github.com/containerd/containerd
cmd_install() {
	test -n "$1" || die "No dir"
	local dest=$1
	test -d "$dest" || die "Not a directory [$dest]"
	if test "$__containerd_ver" = "local"; then
		log "Installing containerd from local build"
		local d=$GOPATH/src/github.com/containerd/containerd
		test -x $d/bin/containerd || die "Not buil't locally"
		cp $d/bin/* $dest
		return 0
	fi
	findf $__containerd_ar || die "Not found [$__containerd_ar]"
	log "Installing containerd [$__containerd_ver]"
	tar --strip-components=1 -C $dest -xf $f || die tar
}
##   install_crictl <dir>
##     Install "crictl" in the specified dir (must exist)
cmd_install_crictl() {
	test -n "$1" || die "No dir"
	local dest=$1
	test -d "$dest" || die "Not a directory [$dest]"
	findf $__crictl_ar || die "Not found [$__crictl_ar]"
	log "Installing crictl [$__crictl_ver]"
	tar -C $dest -xf $f || die tar
}
##   download
##     Download containerd and crictl from their github releases to $ARCHIVE
cmd_download() {
	local url ar
	if findf $__containerd_ar; then
		log "Already downloaded [$f]"
	else
		url=https://github.com/containerd/containerd/releases/download
		ar=$ARCHIVE/$__containerd_ar
		mkdir -p $ARCHIVE
		curl -L $url/v$__containerd_ver/$__containerd_ar > $ar
	fi
	if findf $__crictl_ar; then
		log "Already downloaded [$f]"
	else
		url=https://github.com/kubernetes-sigs/cri-tools/releases/download
		curl -L $url/$__crictl_ver/$__crictl_ar > $ar
	fi
}

##
##   test [--xterm] [--no-stop] [test...]
##     Exec tests
cmd_test() {
	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

	local t=start_empty
	if test -n "$1"; then
		local t=$1
		shift
	fi		

	if test -n "$__log"; then
		date > $__log || die "Can't write to log [$__log]"
		test_$t $@ >> $__log
	else
		test_$t $@
	fi

	now=$(date +%s)
	log "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster with containerd, but without K8s
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	unset XOVLS
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	export CONTAINERD_TEST=yes
	xcluster_start network-topology iptools private-reg k8s-cni-bridge containerd $@
	otc 1 version
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
cmd_env
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
