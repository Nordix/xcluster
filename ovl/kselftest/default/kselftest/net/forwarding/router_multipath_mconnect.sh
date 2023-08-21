#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# +--------------------+                     +----------------------+
# | H1                 |                     |                   H2 |
# |                    |                     |                      |
# |              $h1 + |                     | + $h2                |
# |     192.0.2.2/24 | |                     | | 198.51.100.2/24    |
# | 2001:db8:1::2/64 | |                     | | 2001:db8:2::2/64   |
# |                  | |                     | |                    |
# +------------------|-+                     +-|--------------------+
#                    |                         |
# +------------------|-------------------------|--------------------+
# | SW               |                         |                    |
# |                  |                         |                    |
# |             $rp1 +                         + $rp2               |
# |     192.0.2.1/24                             198.51.100.1/24    |
# | 2001:db8:1::1/64     + vip                   2001:db8:2::1/64   |
# |                        198.18.0.0/24                            |
# |                        2001:db8:18::/64    + $rp3               |
# |                                            | 203.0.113.1/24     |
# |                                            | 2001:db8:3::1/64   |
# |                                            |                    |
# |                                            |                    |
# +--------------------------------------------|--------------------+
#                                              |
#                                            +-|--------------------+
#                                            | |                 H3 |
#                                            | |                    |
#                                            | | 203.0.113.2/24     |
#                                            | | 2001:db8:3::2/64   |
#                                            | + $h3                |
#                                            |                      |
#                                            +----------------------+

ALL_TESTS="ping_ipv4 ping_ipv6 multipath_test"
NUM_NETIFS=6
source lib.sh

ns_create()
{
	ns=$1

	ip netns add $ns
	in_ns $ns ip link set dev lo up
	in_ns $ns sysctl -q -w net.ipv4.ip_forward=1
	in_ns $ns sysctl -q -w net.ipv6.conf.all.forwarding=1
}

ns_destroy()
{
	ip netns del $1
}

h1_create()
{
	local ns="ns-h1"

	ns_create $ns
	ip link set dev $h1 netns $ns

	in_ns $ns ip link set dev $h1 up

	in_ns $ns ip address add 192.0.2.2/24 dev $h1
	in_ns $ns ip address add 2001:db8:1::2/64 dev $h1

	in_ns $ns ip route add default via 192.0.2.1
	in_ns $ns ip route add default via 2001:db8:1::1
}

h1_destroy()
{
	local ns="ns-h1"

	in_ns $ns ip route del default via 2001:db8:1::1
	in_ns $ns ip route del default via 192.0.2.1

	in_ns $ns ip address del 2001:db8:1::2/64 dev $h1
	in_ns $ns ip address del 192.0.2.2/24 dev $h1

	in_ns $ns ip link set dev $h1 down
	in_ns $ns ip link set dev $h1 netns 1
	ns_destroy $ns
}

h2_create()
{
	local ns="ns-h2"

	ns_create $ns
	ip link set dev $h2 netns $ns

	in_ns $ns ip link set dev $h2 up

	in_ns $ns ip address add 198.51.100.2/24 dev $h2
	in_ns $ns ip address add 2001:db8:2::2/64 dev $h2

	in_ns $ns ip address add 198.18.0.0/24 dev lo
	in_ns $ns ip address add 2001:db8:18::/64 dev lo

	in_ns $ns ip route add 192.0.2.0/24 via 198.51.100.1
	in_ns $ns ip route add 2001:db8:1::/64 nexthop via 2001:db8:2::1
}

h2_destroy()
{
	local ns="ns-h2"

	in_ns $ns ip route del 2001:db8:1::/64 nexthop via 2001:db8:2::1
	in_ns $ns ip route del 192.0.2.0/24 via 198.51.100.1

	in_ns $ns ip address del 2001:db8:18::/64 dev lo
	in_ns $ns ip address del 198.18.0.0/24 dev lo

	in_ns $ns ip address del 2001:db8:2::2/64 dev $h2
	in_ns $ns ip address del 198.51.100.2/24 dev $h2

	in_ns $ns ip link set dev $h2 down
	in_ns $ns ip link set dev $h2 netns 1
	ns_destroy $ns
}

h3_create()
{
	local ns="ns-h3"

	ns_create $ns
	ip link set dev $h3 netns $ns

	in_ns $ns ip link set dev $h3 up

	in_ns $ns ip address add 203.0.113.2/24 dev $h3
	in_ns $ns ip address add 2001:db8:3::2/64 dev $h3

	in_ns $ns ip address add 198.18.0.0/24 dev lo
	in_ns $ns ip address add 2001:db8:18::/64 dev lo

	in_ns $ns ip route add 192.0.2.0/24 via 203.0.113.1
	in_ns $ns ip route add 2001:db8:1::/64 nexthop via 2001:db8:3::1
}

h3_destroy()
{
	local ns="ns-h3"

	in_ns $ns ip route del 2001:db8:1::/64 nexthop via 2001:db8:3::1
	in_ns $ns ip route del 192.0.2.0/24 via 203.0.113.1

	in_ns $ns ip address del 198.18.0.0/24 dev lo
	in_ns $ns ip address del 2001:db8:18::/64 dev lo

	in_ns $ns ip address del 2001:db8:3::2/64 dev $h3
	in_ns $ns ip address del 203.0.113.2/24 dev $h3

	in_ns $ns ip link set dev $h3 down
	in_ns $ns ip link set dev $h3 netns 1
	ns_destroy $ns
}

router1_create()
{
	local ns="ns-r1"

	ns_create $ns
	ip link set dev $rp1 netns $ns
	ip link set dev $rp2 netns $ns
	ip link set dev $rp3 netns $ns

	in_ns $ns ip link set dev $rp1 up
	in_ns $ns ip link set dev $rp2 up
	in_ns $ns ip link set dev $rp3 up

	in_ns $ns ip address add 192.0.2.1/24 dev $rp1
	in_ns $ns ip address add 2001:db8:1::1/64 dev $rp1

	in_ns $ns ip address add 198.51.100.1/24 dev $rp2
	in_ns $ns ip address add 2001:db8:2::1/64 dev $rp2

	in_ns $ns ip address add 203.0.113.1/24 dev $rp3
	in_ns $ns ip address add 2001:db8:3::1/64 dev $rp3

	in_ns $ns ip route add 198.18.0.0/24 \
		nexthop via 198.51.100.2 \
		nexthop via 203.0.113.2
	in_ns $ns ip route add 2001:db8:18::/64 \
		nexthop via 2001:db8:2::2 \
		nexthop via 2001:db8:3::2
}

router1_destroy()
{
	local ns="ns-r1"

	in_ns $ns ip route del 2001:db8:18::/64
	in_ns $ns ip route del 198.18.0.0/24

	in_ns $ns ip address del 2001:db8:3::1/64 dev $rp3
	in_ns $ns ip address del 203.0.113.1/24 dev $rp3

	in_ns $ns ip address del 2001:db8:2::1/64 dev $rp2
	in_ns $ns ip address del 198.51.100.1/24 dev $rp2

	in_ns $ns ip address del 2001:db8:1::1/64 dev $rp1
	in_ns $ns ip address del 192.0.2.1/24 dev $rp1

	in_ns $ns ip link set dev $rp3 down
	in_ns $ns ip link set dev $rp2 down
	in_ns $ns ip link set dev $rp1 down

	in_ns $ns ip link set dev $rp3 netns 1
	in_ns $ns ip link set dev $rp2 netns 1
	in_ns $ns ip link set dev $rp1 netns 1
	ns_destroy $ns
}

mconnect4_test()
{
	local desc="$1"
	local weight_rp2=$2
	local weight_rp3=$3
	local h2_mconnect_pid h3_mconnect_pid

	# Transmit multiple flows from h1 to h2 and make sure they are
	# distributed between both multipath links (rp2 and rp3)
	# according to the configured weights.
	in_ns ns-r1 sysctl_set net.ipv4.fib_multipath_hash_policy 1
	in_ns ns-r1 ip route replace 198.18.0.0/24 \
		nexthop via 198.51.100.2 weight $weight_rp2 \
		nexthop via 203.0.113.2 weight $weight_rp3

	in_ns ns-h2 mconnect -server -address 198.18.0.0:5001 &
	h2_mconnect_pid=$!
	in_ns ns-h3 mconnect -server -address 198.18.0.0:5001 &
	h3_mconnect_pid=$!

	in_ns ns-h1 mconnect -address 198.18.0.0:5001 -nconn 1000
	check_err $? "mconnect tests failed"
	log_test "$desc"

	t1_rp2=$(in_ns ns-r1 link_stats_tx_packets_get $rp2)
	t1_rp3=$(in_ns ns-r1 link_stats_tx_packets_get $rp3)

	in_ns ns-r1 ip route replace 198.18.0.0/24 \
		nexthop via 198.51.100.2 \
		nexthop via 203.0.113.2

	in_ns ns-r1 sysctl_restore net.ipv4.fib_multipath_hash_policy
}

mconnect6_test()
{
	local desc="$1"
	local weight_rp2=$2
	local weight_rp3=$3
	local h2_mconnect_pid h3_mconnect_pid

	# Transmit multiple flows from h1 to h2 and make sure they are
	# distributed between both multipath links (rp2 and rp3)
	# according to the configured weights.
	in_ns ns-r1 sysctl_set net.ipv6.fib_multipath_hash_policy 1
	in_ns ns-r1 ip route replace 2001:db8:18::/64 \
		nexthop via 2001:db8:2::2 weight $weight_rp2 \
		nexthop via 2001:db8:3::2 weight $weight_rp3

	in_ns ns-h2 mconnect -server -address [2001:db8:18::]:5001 &
	h2_mconnect_pid=$!
	in_ns ns-h3 mconnect -server -address [2001:db8:18::]:5001 &
	h3_mconnect_pid=$!

	in_ns ns-h1 mconnect -address [2001:db8:18::]:5001 -nconn 1000
	check_err $? "mconnect tests failed"
	log_test "$desc"

	in_ns ns-r1 ip route replace 2001:db8:18::/64 \
		nexthop via 2001:db8:2::2 \
		nexthop via 2001:db8:3::2

	in_ns ns-r1 sysctl_restore net.ipv6.fib_multipath_hash_policy
}

multipath_test()
{
	log_info "Running IPv4 multipath tests"
	mconnect4_test "ECMP" 1 1
	mconnect4_test "Weighted MP 2:1" 2 1
	mconnect4_test "Weighted MP 11:45" 11 45

	log_info "Running IPv6 L4 hash multipath tests"
	mconnect6_test "ECMP" 1 1
	mconnect6_test "Weighted MP 2:1" 2 1
	mconnect6_test "Weighted MP 11:45" 11 45
}

setup_prepare()
{
	h1=${NETIFS[p1]}
	rp1=${NETIFS[p2]}

	rp2=${NETIFS[p3]}
	h2=${NETIFS[p4]}

	rp3=${NETIFS[p5]}
	h3=${NETIFS[p6]}

	h1_create
	h2_create
	h3_create

	router1_create
}

setup_wait()
{
	h1=${NETIFS[p1]}
	rp1=${NETIFS[p2]}

	rp2=${NETIFS[p3]}
	h2=${NETIFS[p4]}

	rp3=${NETIFS[p5]}
	h3=${NETIFS[p6]}

	in_ns ns-h1 setup_wait_dev $h1
	in_ns ns-h2 setup_wait_dev $h2
	in_ns ns-h3 setup_wait_dev $h3
	in_ns ns-r1 setup_wait_dev $rp1
	in_ns ns-r1 setup_wait_dev $rp2
	in_ns ns-r1 setup_wait_dev $rp3

	# Make sure links are ready.
	sleep $WAIT_TIME
}

cleanup()
{
	pre_cleanup

	forwarding_restore

	router1_destroy

	h3_destroy
	h2_destroy
	h1_destroy
}

ping_test()
{
	RET=0

	local ns=$1
	local dip=$2
	local args=$3

	in_ns $ns $PING $args $dip -c $PING_COUNT -i 0.1 \
		-w $PING_TIMEOUT &> /dev/null
	check_err $?
	log_test "ping$args"
}

ping6_test()
{
	RET=0

	local ns=$1
	local dip=$2
	local args=$3

	in_ns $ns $PING6 $args $dip -c $PING_COUNT -i 0.1 \
		-w $PING_TIMEOUT &> /dev/null
	check_err $?
	log_test "ping6$args"
}

ping_ipv4()
{
	ping_test ns-h1 198.51.100.2
	ping_test ns-h1 203.0.113.2
}

ping_ipv6()
{
	ping6_test ns-h1 2001:db8:2::2
	ping6_test ns-h1 2001:db8:3::2
}

trap cleanup EXIT

setup_prepare
setup_wait

tests_run

exit $EXIT_STATUS
