#! /bin/sh
##
## bash.sh --
##
##   Help script for the xcluster ovl/bash.
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$
bash_url=https://ftp.acc.umu.se/mirror/gnu.org/gnu/bash
bash_ver=bash-5.2.15

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

cmd_bash() {
	echo $XCLUSTER_WORKSPACE/$bash_ver
}

##  download
##    Download/unpack; bash.
##
cmd_download() {
	ar=$bash_ver.tar.gz
	url=$bash_url/$ar

	if [ -f $ARCHIVE/$ar ]; then
		log "Already downloaded"
	else
		curl -L $url > $ARCHIVE/$ar
	fi

	if [ -d $XCLUSTER_WORKSPACE/$bash_ver ]; then
		log "Already unpacked"
	else
		tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/$ar
	fi
}

##  build
##    Build bash
##
cmd_build() {
	d=$XCLUSTER_WORKSPACE/$bash_ver
	cd $d || die "Download bash first"
	if [ -f $d/bash ]; then
		log "Already built"
	else
		./configure
		make
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
