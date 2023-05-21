#! /bin/sh
##
## systemtap.sh --
##
##   Help script for the xcluster ovl/systemtap.
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

##   env [--srcd=$GOPATH/src/sourceware.org]
##     Print environment.
cmd_env() {

	if test "$cmd" = "env"; then
		set | grep -E '^(__.*)='
		retrun 0
	fi
	test -n "$__srcd" || __srcd=$GOPATH/src/sourceware.org
	
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	eval $($XCLUSTER env)
}
##   clone [--clean] [--srcd=$GOPATH/src/sourceware.org]
##     Clone elfutils and systemtap
cmd_clone() {
	cmd_env
	local x d=$__srcd
	test "$__clean" = "yes" && rm -rf $d
	mkdir -p $d
	cd $d
	for x in elfutils systemtap; do
		if test -d ./$x; then
			log "Already cloned [$x]"
			continue
		fi
		git clone --depth 1 git://sourceware.org/git/$x.git || die Clone
	done
}
##   configure
##     Configure elfutils and systemtap
cmd_configure() {
	cmd_env
	local d=$__srcd
	cd $d/elfutils || die
	autoreconf -i || die autoreconf
	./configure --disable-nls --prefix=/ || log "Failing seem to be OK"
	cd $d/systemtap || die
	./configure --with-elfutils=../elfutils --prefix=/ --exec-prefix=/ \
		--disable-libvirt --disable-monitor --disable-dependency-tracking --disable-nls --without-selinux --without-python2-probes || die configure
}
##   build
##     Build systemtap. Output to _output/
cmd_build() {
	cmd_env
	local d=$__srcd
	cd $d/systemtap
	make -j $(nproc) || die make
	make DESTDIR=$dir/_output install
}
##   man [page]
##   man [--grep=]
##     Show systemtap man page
cmd_man() {
	export MANPATH=$dir/_output/share/man
	local cache=/tmp/$USER/systemtap-man
	if ! test -d $cache; then
		local f
		mkdir -p $cache
		for f in $(find $MANPATH/ -type f); do
			basename $f >> $cache/man
		done
	fi
	if test -z "$1"; then
		if test -n "$__grep"; then
			grep $__grep $cache/man | sort | column
		else
			cat $cache/man | sort | column
		fi
		return 0
	fi
	xterm -bg '#ddd' -fg '#222' -geometry 80x43 -T $1 -e man $1 &
}

##
##   test [--xterm] [--no-stop] test <test-name> [ovls...] > $log
##   test [--xterm] [--no-stop] > $log   # default test
##     Exec tests
cmd_test() {
	cmd_env
	export SYSTEMTAP_TEST=yes
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
		t=$1
		shift
        test_$t $@
    else
        test_start_empty
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"
}

##   test start_empty
##     Start cluster
test_start_empty() {
	export __image=$XCLUSTER_HOME/hd.img
	unset XOVLS
	test -n "$__nrouters" || __nrouters=0
	test -n "$__nvm" || __nvm=1
	xcluster_start . $@
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
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
