#! /bin/sh
##
## spire.sh --
##
##   Help script for the xcluster ovl/spire.
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

	test -n "$__tag" || __tag="registry.nordix.org/cloud-native/spire:latest"

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
		test_default
    fi      

    now=$(date +%s)
    tlog "Xcluster test ended. Total time $((now-begin)) sec"

}

test_start_empty() {
	test -n "$__nrouters" || export __nrouters=0
	xcluster_start k8s-test spire
	otc 1 check_namespaces
	otc 1 check_nodes
}
test_start_registrar() {
	test_start_empty
	otc 1 start_spire_registrar
}

test_default() {
	tlog "=== spire: Basic test"
	test_start_registrar
	xcluster_stop
}

##   Older ways of loading spire;
##   generate_manifests [--version=1.0.2]
##     Generate manifests from helm charts.
##   kustomize
##
cmd_generate_manifests() {
        local dst=$dir/default/etc/kubernetes/spire
		test -n "$__version" || __version=1.0.2
		test -d "$dir/helm/$__version" || die "Version not found [$__version]"
        mkdir -p $dst
		helm template $dir/helm/$__version --generate-name --namespace spire \
			--create-namespace > $dst/spire.yaml 2> /dev/null || die helm
}

cmd_kustomize() {
    local dst=$dir/default/etc/kubernetes/spire
	local url=https://github.com/spiffe/spire-tutorials/k8s/quickstart
    mkdir -p $dst
	kubectl kustomize $url > $dst/spire.yaml
	sed -i -e 's,1.0.0,1.0.2,' $dst/spire.yaml
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
