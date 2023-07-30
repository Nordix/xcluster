#! /bin/sh
##
## crio.sh --
##
##   Help script for the xcluster ovl/crio.
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

	test -n "$__criover" || __criover=cri-o.amd64.v1.27.1
	test -n "$__crioar" || __crioar=$ARCHIVE/$__criover.tar.gz
	test -n "$__pausever" || __pausever=3.9

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		return 0
	fi

	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   pause_image
##     Print the pause image url. Version should be taken from:
##     kubeadm config images list
cmd_pause_image() {
	cmd_env
	echo registry.k8s.io/pause:$__pausever
}
##   download
cmd_download() {
	cmd_env
	if test -r "$__crioar"; then
		log "Already downloaded"
		return 0
	fi
	local url=https://storage.googleapis.com/cri-o/artifacts
	mkdir -p $(dirname $__crioar)
	curl -L $url/$__criover.tar.gz > $__crioar
}
##   man [page]
##     Show a cri-o man-page from the current release
cmd_man() {
	cmd_env
	test -r $__crioar || die "Not readable [$__crioar]"
	MANPATH=/tmp/$USER/cri-o/man
	if ! test -d $MANPATH; then
		mkdir -p /tmp/$USER
		tar -C /tmp/$USER -xf $__crioar cri-o/man
	fi
	if test -z "$1"; then
		local f
		mkdir -p $tmp
		for f in $(find $MANPATH -type f); do
			basename $f >> $tmp/man
		done
		cat $tmp/man | sort | column
		return 0
	fi
	export MANPATH
	echo $MANPATH
	xterm -bg '#ddd' -fg '#222' -geometry 80x45 -T $1 -e man $MANPATH/$1 &
}

##
##   test [--xterm] [--no-stop] [test...] > logfile
##     Exec tests
##
cmd_test() {
	cmd_env
	test -r $__crioar || die "Not readable [$__crioar]"
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
	test -n "$__nvm" || export __nvm=1
	test -n "$__nrouters" || export __nrouters=0
	export CRIO_TEST=yes
	test -n "$TOPOLOGY" && \
		. $($XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
	xcluster_start network-topology iptools . $@
	otc 1 version
}
##   test start_no_private_reg
##     Start cluster without private_reg
test_start_no_private_reg() {
	unset XOVLS
	test_start_empty
}
##   test start (default)
##     Start cluster, use private_reg
test_start() {
	export XOVLS=private-reg
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
