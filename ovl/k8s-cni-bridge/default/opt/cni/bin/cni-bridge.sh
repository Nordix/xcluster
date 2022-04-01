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
test -n "$KUBECONFIG" || KUBECONFIG=/etc/kubernetes/kubeconfig.token
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

logf=/var/log/k8s-cni-bridge.log
log() {
	#echo "$(date) $prg: $*" >&2
	echo "$(date) $prg: $*" >> $logf
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
	local cnt=$(cat $tmp/expected | wc -l)
	log "Expected-route count = $cnt"
	if test $cnt -le 1; then
		log "Ignoring update. Fault or single-node"
		return 0
	fi
	cmd_found_routes | sort > $tmp/found
	diff $tmp/expected $tmp/found > /dev/null && return 0
	log "Expected routes;"
	cat $tmp/expected >> $logf
	log "Found routes;"
	cat $tmp/found >> $logf
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
	local cnt=$(cat $tmp/expected | wc -l)
	log "Expected-route count = $cnt"
	if test $cnt -le 1; then
		log "Ignoring clean. Fault or single-node"
		return
	fi
	cmd_found_routes | sort > $tmp/found
	local a
	for a in $(diff $tmp/found $tmp/expected | grep '^-1' | tr -d -); do
		# NEVER delete a route to the own cbr0 !!!
		log "Deleted route [$a]"
		if echo $a | grep -q : ; then
			if echo $a | grep -q "1100::${__node}00"; then
				log "Omit cbr0 route; $a"
				continue
			fi
			ip -6 route del $a
		else
			if echo $a | grep -Fq "192.168.$__node."; then
				log "Omit cbr0 route; $a"
				continue
			fi
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
		sleep 15
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
