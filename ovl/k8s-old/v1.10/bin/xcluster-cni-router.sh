#! /bin/sh
##
## xcluster-cni-router.sh --
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
	if test -z "$__log_file"; then
		echo "$prg: $*"
		return 0
	fi
	echo "$prg $(date +%T): $*" >> "$__log_file"
	return 0
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__info_file" || __info_file=/tmp/node-info
	test -n "$__addr_map" || __addr_map=/tmp/addr-map
	test -n "$K8S_NODE" || K8S_NODE=$(hostname)
	test "$cmd" = "env" && set | grep -E '^(__.*)='
}

cmd_link_local() {
	test -n "$1" || die "No MAC"
    local macaddr="$1"
    printf "%02x%s" $(( 0x${macaddr:0:2} ^ 2)) "${macaddr:2}"
}

##  info
##    Print a json array with name, address and podCIDR for all nodes
##
cmd_info() {
	list-nodes | jq '[.|{name: .metadata.name,podCIDR: .spec.podCIDR, addresses: [.status.addresses[]|select(.type == "InternalIP").address]}]|sort_by(.name)'
}

##  check_info [--info-file=/tmp/node-info]
##    Read info and returns ok (0) if the info is updated
##
cmd_check_info() {
	cmd_env

	mkdir -p $tmp
	if ! cmd_info > $tmp/node-info; then
		log "Failed to read node-info"
		rm -f $tmp/node-info
		return 0
	fi

	if ! test -r "$__info_file"; then
		log "First node-info read"
		cp $tmp/node-info "$__info_file"
		return 0
	fi
	
	if ! diff -q "$__info_file" $tmp/node-info > /dev/null; then
		log "Node-info updated"
		cp $tmp/node-info "$__info_file"
		return 0
	fi

	return 1
}

##  check_routes
##    Check routes to podCIDR's, update if needed.
##  monitor [--interval=5]
##    Sit in a loop doing "check_routes".
##
cmd_check_routes() {
	cmd_check_info || return 0
	cmd_update_routes
	return 0      # Must return ok!
}
cmd_monitor() {
	test -n "$__interval" || __interval=5
	if test "$TUNNEL_MODE" = "sit"; then
		# NOTE; Both sit0 and tunl0 must be up!
		# https://bugzilla.kernel.org/show_bug.cgi?id=205501
		if ! ip link set up dev sit0; then
			log "Can not set sit0 up. TUNNEL_MODE=sid disabled!"
			export TUNNEL_MODE=None
		else
			if ! ip link set up dev tunl0; then
				log "Can not set tunl0 up. TUNNEL_MODE=sid disabled!"
				export TUNNEL_MODE=None
			else
				log "Using sit tunnels"
			fi
		fi
	fi
	while true; do
		cmd_check_routes
		sleep $__interval
	done
}

##  remove_routes [--info-file=/tmp/node-info]
##    Remove routes
##
cmd_remove_routes() {
	cmd_env
	local n cidr
	for n in $(cat $__info_file | jq -r '.[].name'); do
		test "$n" = "$K8S_NODE" && continue
		for cidr in $(cat $__info_file | jq -r ".[]|select(.name == \"$n\")|.podCIDR"); do
			if echo $cidr | grep -q : ; then
				cmd_x ip -6 ro del $cidr
			else
				cmd_x ip ro del $cidr
			fi
		done
	done
	
}
##  update_routes [--info-file=/tmp/node-info]
##    Update routes to podCIDR's
##
cmd_update_routes() {
	cmd_env
	if ! test -r "$__info_file"; then
		log "Not readable [$__info_file]"
		return 0
	fi

	if test "$TUNNEL_MODE" = "sit"; then
		cmd_update_routes_sit
		return
	fi

	local n cidr
	for n in $(cat $__info_file | jq -r '.[].name'); do
		test "$n" = "$K8S_NODE" && continue
		get_addresses $n
		for cidr in $(echo $i | jq -r '.podCIDR'); do
			echo $cidr | grep -qi null | continue
			if echo $cidr | grep -q : ; then
				test -n "$a6" || continue
				if echo $a6 | grep -q % ; then
					# Link local address
					local a=$(echo $a6 | cut -d% -f1)
					local dev=$(echo $a6 | cut -d% -f2)
					cmd_x ip -6 ro replace $cidr via $a dev $dev
				else
					cmd_x ip -6 ro replace $cidr via $a6
				fi
			else
				test -n "$a4" && cmd_x ip ro replace $cidr via $a4
			fi
		done
	done
}

cmd_update_routes_sit() {
	local n cidr a i
	for n in $(cat $__info_file | jq -r '.[].name'); do
		test "$n" = "$K8S_NODE" && continue
		i=$(cat $__info_file | jq ".[]|select(.name == \"$n\")")

		# We only use ipv4 encapsulation so only ipv4 node-addresses are needed
		unset a4
		for a in $(echo $i | jq -r .addresses[]); do
			echo $a | grep -q : && continue
			a4=$a
			break
		done
		if test -z "$a4"; then
			# This must be an ipv6-only cluster. We can't use "sit"
			log "Disable sit tunnels in an ipv6-only cluster"
			export TUNNEL_MODE=None
			cmd_update_routes
			return
		fi

		for cidr in $(echo $i | jq -r '.podCIDR'); do
			echo $cidr | grep -qi null | continue
			if echo $cidr | grep -q : ; then
				cmd_x ip -6 route replace $cidr dev sit0 onlink via ::$a4
			else
				cmd_x ip route replace $cidr dev sit0 onlink via $a4
			fi
		done
	done
}

# Sets global variables; i a4 a6
get_addresses() {
	i=$(cat $__info_file | jq ".[]|select(.name == \"$1\")")
	unset a4 a6
	local a
	for a in $(echo $i | jq -r .addresses[]); do
		if echo $a | grep -q : ; then
			a6=$a
		else
			a4=$a
		fi
	done

	test -n "$a6" && return 0
	test -n "$a4" || return 0

	# We have an ipv4 address, but no ipv6.

	# 1. Check prefix
	if test -n "$IPV6_PREFIX"; then
		a6=$IPV6_PREFIX$a4
		return
	fi

	# 2. Check map addr->ipv6 (a'la /etc/hosts)
	if test -r $__addr_map && grep -q " $1\$" $__addr_map; then
		a6=$(grep " $1\$" $__addr_map | cut -d ' ' -f1)
		return
	fi

	# Try to find the link-local address from the ipv4 arp cache
	ping -W1 -c1 $a4 > /dev/null 2&>1 || return
	mac=$(ip neigh show $a4 | grep -Eo "lladdr [:0-9a-fA-F]+" | cut -d' ' -f2)
	test -n "$mac" || return

	# Get the interface for the ipv4 address
	local dev=$(ip ro get $a4 | grep -oE 'dev [a-z0-9]+' | sed -e 's,dev ,,')
	test -n "$dev" || return

	a6="$(cmd_link_local $mac)%$dev"

	# Update the map
	echo "$a6 $1" >> $__addr_map
}

cmd_link_local() {
	# Toggle bit 6
	local b0=0x$(echo $1 | cut -d: -f1)
	local t=0x$(echo $1 | cut -d: -f2- | sed -e 's,:, 0x,g')
	printf "fe80::%02x%02x:%02xff:fe%02x:%02x%02x" $((b0^2)) $t
}


cmd_x() {
	log "$@"
	test "$__dry_run" = "yes" && return 0
	$@
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
