#! /bin/sh
##
## calico.sh --
##
##   Start of the Calico CNI-plugin on xcluster.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$
. /etc/profile

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

##   env
##     Print environment.
cmd_env() {
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}
##   operator
##     Install the Tigera operator
cmd_operator() {
	kubectl create -f /etc/kubernetes/calico/tigera-operator.yaml
}
##   legacy
##     Start with the calico.yaml manifest
cmd_legacy() {
	kubectl create -f /etc/kubernetes/calico/calico.yaml
}
##   install [item]
##     Install Calico. Requires the operator.
cmd_install() {
	local item
	if test -n "$1"; then
		item=/etc/kubernetes/calico/install-$1
	else
		item=/etc/kubernetes/calico/$(echo "$CALICO_BACKEND" | grep -Eo 'install-[a-z]+')
	fi
	kubectl create -f $item.yaml
}
##   start
##     This function is called when K8s is ready. Load the calico
##     cni-plugin. The $CALICO_BACKEND variable controls the startup.
cmd_start() {
	test -n "$CALICO_BACKEND" || CALICO_BACKEND=legacy
	echo "$CALICO_BACKEND" | grep -q legacy && cmd_legacy
	echo "$CALICO_BACKEND" | grep -q operator && cmd_operator
	echo "$CALICO_BACKEND" | grep -q install- && cmd_install
}

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
