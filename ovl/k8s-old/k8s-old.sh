#! /bin/sh
##
## k8s-old.sh --
##
##
## Commands;
##

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

log() {
	echo "$prg: $*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	if test "$cmd" = "env"; then
		set | grep -E '^(__.*|ARCHIVE)='
		return 0
	fi
	test -n "$__k8sver" || die 'Not set [$__k8sver]'
}

##  build_crio [--criover=]
cmd_build_crio() {
	cmd_env
	test -n "$__criover" || __criover=$(echo $__k8sver | cut -f-2 -d. | cut -c2-)
	local criod=$GOPATH/src/github.com/cri-o/cri-o-$__criover
	if ! test -d $criod; then
		cd $(dirname $criod)
		git clone -b release-$__criover --depth 1 https://github.com/cri-o/cri-o.git cri-o-$__criover
	fi
	rm -f $GOPATH/src/github.com/cri-o/cri-o
	ln -s cri-o-$__criover $GOPATH/src/github.com/cri-o/cri-o
	cd $GOPATH/src/github.com/cri-o/cri-o
	make clean
	make -j$(nproc) binaries || die make
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
