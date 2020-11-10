#! /bin/sh
##
## istio.sh --
##
##   Help script for the xcluster ovl/istio.
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

##  env
##    Print environment.
##
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

##   test --list
##   test [--xterm] [test...] > logfile
##     Exec tests
##
cmd_test() {
	if test "$__list" = "yes"; then
        grep '^test_' $me | cut -d'(' -f1 | sed -e 's,test_,,'
        return 0
    fi

	cmd_env
    start=starts
    test "$__xterm" = "yes" && start=start
    rm -f $XCLUSTER_TMP/cdrom.iso

    if test -n "$1"; then
        for t in $@; do
            test_$t
        done
    else
		__mode=dual-stack
		test_start
		push __no_stop yes
		__no_start=yes
		test_basic
		pop __no_stop
		xcluster_stop
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start() {
	test -n "$__mode" || __mode=dual-stack
	export xcluster___mode=$__mode
	export xcluster_DOMAIN=cluster.local
	export __mem1=2048
	export __mem=1536
	xcluster_prep $__mode
	xcluster_start k8s-test istio

	otc 1 check_namespaces
	otc 1 check_nodes
	otc 201 vip_route
}

test_basic_local() {
	test -n "$__mode" || __mode=dual-stack
	tlog "=== istio: Basic test with local images on $__mode"
	test_start

	otc 1 install_local
	otc 1 prometheus

	# Call test-cases from ovl/k8s-test
	otcprog=k8s-test_test
	otc 1 start_servers

	unset otcprog
	otc 201 external_http

	xcluster_stop
}
test_ipv4() {
	__mode=ipv4
	test_basic
}
test_ipv6() {
	__mode=ipv6
	test_basic
}

cmd_otc() {
	test -n "$__vm" || __vm=2
	otc $__vm $@
}

##   mkimage [--tag=registry.nordix.org/cloud-native/istio:latest]
##     Create the docker image and upload it to the local registry.
##
cmd_mkimage() {
	cmd_env
	local imagesd=$($XCLUSTER ovld images)
	$imagesd/images.sh mkimage --force --upload --strip-host --tag=$__tag $dir/image
}

##   go_build
##     Build local go program. Output to ./image/default/bin
##
cmd_go_build() {
	mkdir -p $dir/image/default/bin
	cd $dir/go
	GO111MODULE=on CGO_ENABLED=0 GOOS=linux go build \
		-ldflags "-extldflags '-static' -X main.version=$(date +%F:%T)" \
		-o ../image/default/bin/list-nodes ./cmd/list-nodes/main.go
	strip ../image/default/bin/list-nodes
}

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
