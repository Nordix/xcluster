#! /bin/sh
##
## cni-bridge.sh --
##
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$
. /etc/profile
export KUBECONFIG

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
	echo "$(date) $prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__node" || __node=$(hostname | cut -d- -f2 | sed -re 's,^0+,,')
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}

##  expected_routes
cmd_expected_routes() {
	local n i
	for n in $(kubectl get nodes -o name | sed -e 's,node/,,' | sort); do
		i=$(echo $n | cut -d- -f2 | sed -re 's,^0+,,')
		echo "11.0.$i.0/24"
		echo "1100::${i}00/120"
	done
}
##  found_routes
cmd_found_routes() {
	ip -j ro show | jq -r .[].dst | grep -E '11\.0\..*/24'
	ip -6 -j ro show | jq -r .[].dst | grep -E '1100::[0-9]+/120'
}
##  routes_ok
cmd_routes_ok() {
	mkdir -p $tmp
	cmd_expected_routes | sort > $tmp/expected
	cmd_found_routes | sort > $tmp/found
	diff $tmp/expected $tmp/found > /dev/null && return 0
	log "Routes differ"
	echo "Expected;"
	cat $tmp/expected
	echo "Found;"
	cat $tmp/found
	return 1
}
##  update_routes
cmd_update_routes() {
	cmd_env
	local n i
	for n in $(kubectl get nodes -o name | sed -e 's,node/,,' | sort); do
		i=$(echo $n | cut -d- -f2 | sed -re 's,^0+,,')
		test $i -eq $__node && continue
		ip ro replace 11.0.$i.0/24 via 192.168.1.$i
		ip -6 ro replace 1100::${i}00/120 via 1000::1:192.168.1.$i
	done
}
##  clean_routes
cmd_clean_routes() {
	mkdir -p $tmp
	cmd_expected_routes | sort > $tmp/expected
	cmd_found_routes | sort > $tmp/found
	local a
	for a in $(diff $tmp/found $tmp/expected | grep '^-1' | tr -d -); do
		if echo $a | grep -q : ; then
			ip -6 route del $a
		else
			ip route del $a
		fi
	done
}
##  monitor
cmd_monitor() {
	log "Monitor bridge routes"
	# Routes to all VMs ($__vms) are setup by the start script.
	# Delay here to avoid unnecessary delete/setup during start.
	sleep 20
	while true; do
		sleep 5
		cmd_routes_ok && continue
		log "Updating routes"
		cmd_update_routes
		cmd_clean_routes
	done
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
