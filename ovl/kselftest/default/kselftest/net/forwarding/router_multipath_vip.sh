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

h1_create()
{
	vrf_create "vrf-h1"
	ip link set dev $h1 master vrf-h1

	ip link set dev vrf-h1 up
	ip link set dev $h1 up

	ip address add 192.0.2.2/24 dev $h1
	ip address add 2001:db8:1::2/64 dev $h1

	ip route add default vrf vrf-h1 via 192.0.2.1
	ip route add default vrf vrf-h1 via 2001:db8:1::1
}

h1_destroy()
{
	ip route del default vrf vrf-h1 via 2001:db8:1::1
	ip route del default vrf vrf-h1 via 192.0.2.1

	ip address del 2001:db8:1::2/64 dev $h1
	ip address del 192.0.2.2/24 dev $h1

	ip link set dev $h1 down
	vrf_destroy "vrf-h1"
}

h2_create()
{
	vrf_create "vrf-h2"
	ip link set dev $h2 master vrf-h2

	ip link set dev vrf-h2 up
	ip link set dev $h2 up

	ip address add 198.51.100.2/24 dev $h2
	ip address add 2001:db8:2::2/64 dev $h2

	ip address add 198.18.0.0/24 dev vrf-h2
	ip address add 2001:db8:18::/64 dev vrf-h2

	ip route add 192.0.2.0/24 vrf vrf-h2 via 198.51.100.1
	ip route add 2001:db8:1::/64 vrf vrf-h2 nexthop via 2001:db8:2::1
}

h2_destroy()
{
	ip route del 2001:db8:1::/64 vrf vrf-h2 nexthop via 2001:db8:2::1
	ip route del 192.0.2.0/24 vrf vrf-h2 via 198.51.100.1

	ip address del 2001:db8:18::/64 dev vrf-h2
	ip address del 198.18.0.0/24 dev vrf-h2

	ip address del 2001:db8:2::2/64 dev $h2
	ip address del 198.51.100.2/24 dev $h2

	ip link set dev $h2 down
	vrf_destroy "vrf-h2"
}

h3_create()
{
	vrf_create "vrf-h3"
	ip link set dev $h3 master vrf-h3

	ip link set dev vrf-h3 up
	ip link set dev $h3 up

	ip address add 203.0.113.2/24 dev $h3
	ip address add 2001:db8:3::2/64 dev $h3

	ip address add 198.18.0.0/24 dev vrf-h3
	ip address add 2001:db8:18::/64 dev vrf-h3

	ip route add 192.0.2.0/24 vrf vrf-h3 via 203.0.113.1
	ip route add 2001:db8:1::/64 vrf vrf-h3 nexthop via 2001:db8:3::1
}

h3_destroy()
{
	ip route del 2001:db8:1::/64 vrf vrf-h3 nexthop via 2001:db8:3::1
	ip route del 192.0.2.0/24 vrf vrf-h3 via 203.0.113.1

	ip address del 198.18.0.0/24 dev vrf-h3
	ip address del 2001:db8:18::/64 dev vrf-h3

	ip address del 2001:db8:3::2/64 dev $h3
	ip address del 203.0.113.2/24 dev $h3

	ip link set dev $h3 down
	vrf_destroy "vrf-h3"
}

router1_create()
{
	vrf_create "vrf-r1"
	ip link set dev $rp1 master vrf-r1
	ip link set dev $rp2 master vrf-r1
	ip link set dev $rp3 master vrf-r1

	ip link set dev vrf-r1 up
	ip link set dev $rp1 up
	ip link set dev $rp2 up
	ip link set dev $rp3 up

	ip address add 192.0.2.1/24 dev $rp1
	ip address add 2001:db8:1::1/64 dev $rp1

	ip address add 198.51.100.1/24 dev $rp2
	ip address add 2001:db8:2::1/64 dev $rp2

	ip address add 203.0.113.1/24 dev $rp3
	ip address add 2001:db8:3::1/64 dev $rp3

	ip route add 198.18.0.0/24 vrf vrf-r1 \
		nexthop via 198.51.100.2 \
		nexthop via 203.0.113.2
	ip route add 2001:db8:18::/64 vrf vrf-r1 \
		nexthop via 2001:db8:2::2 \
		nexthop via 2001:db8:3::2
}

router1_destroy()
{
	ip route del 2001:db8:18::/64 vrf vrf-r1
	ip route del 198.18.0.0/24 vrf vrf-r1

	ip address del 2001:db8:3::1/64 dev $rp3
	ip address del 203.0.113.1/24 dev $rp3

	ip address del 2001:db8:2::1/64 dev $rp2
	ip address del 198.51.100.1/24 dev $rp2

	ip address del 2001:db8:1::1/64 dev $rp1
	ip address del 192.0.2.1/24 dev $rp1

	ip link set dev $rp3 down
	ip link set dev $rp2 down
	ip link set dev $rp1 down

	vrf_destroy "vrf-r1"
}

multipath4_test()
{
	local desc="$1"
	local weight_rp2=$2
	local weight_rp3=$3
	local t0_rp2 t0_rp3 t1_rp2 t1_rp3
	local packets_rp2 packets_rp3

	# Transmit multiple flows from h1 to h2 and make sure they are
	# distributed between both multipath links (rp2 and rp3)
	# according to the configured weights.
	sysctl_set net.ipv4.fib_multipath_hash_policy 1
	ip route replace 198.18.0.0/24 vrf vrf-r1 \
		nexthop via 198.51.100.2 weight $weight_rp2 \
		nexthop via 203.0.113.2 weight $weight_rp3

	t0_rp2=$(link_stats_tx_packets_get $rp2)
	t0_rp3=$(link_stats_tx_packets_get $rp3)

	ip vrf exec vrf-h1 $MZ $h1 -q -p 64 -A 192.0.2.2 -B 198.18.0.0 \
		-d 1msec -t tcp "sp=1024,dp=0-127,flags=syn"

	t1_rp2=$(link_stats_tx_packets_get $rp2)
	t1_rp3=$(link_stats_tx_packets_get $rp3)

	let "packets_rp2 = $t1_rp2 - $t0_rp2"
	let "packets_rp3 = $t1_rp3 - $t0_rp3"
	multipath_eval "$desc" $weight_rp2 $weight_rp3 $packets_rp2 $packets_rp3

	ip route replace 198.18.0.0/24 vrf vrf-r1 \
		nexthop via 198.51.100.2 \
		nexthop via 203.0.113.2

	sysctl_restore net.ipv4.fib_multipath_hash_policy
}

multipath6_l4_test()
{
	local desc="$1"
	local weight_rp2=$2
	local weight_rp3=$3
	local t0_rp2 t0_rp3 t1_rp2 t1_rp3
	local packets_rp2 packets_rp3

	# Transmit multiple flows from h1 to h2 and make sure they are
	# distributed between both multipath links (rp2 and rp3)
	# according to the configured weights.
	sysctl_set net.ipv6.fib_multipath_hash_policy 1
	ip route replace 2001:db8:18::/64 vrf vrf-r1 \
		nexthop via 2001:db8:2::2 weight $weight_rp2 \
		nexthop via 2001:db8:3::2 weight $weight_rp3

	t0_rp2=$(link_stats_tx_packets_get $rp2)
	t0_rp3=$(link_stats_tx_packets_get $rp3)

	ip vrf exec vrf-h1 $MZ $h1 -6 -q -p 64 -A 2001:db8:1::2 -B 2001:db8:18::0 \
		-d 1msec -t tcp "sp=1024,dp=0-127,flags=syn"

	t1_rp2=$(link_stats_tx_packets_get $rp2)
	t1_rp3=$(link_stats_tx_packets_get $rp3)

	let "packets_rp2 = $t1_rp2 - $t0_rp2"
	let "packets_rp3 = $t1_rp3 - $t0_rp3"
	multipath_eval "$desc" $weight_rp2 $weight_rp3 $packets_rp2 $packets_rp3

	ip route replace 2001:db8:18::/64 vrf vrf-r1 \
		nexthop via 2001:db8:2::2 \
		nexthop via 2001:db8:3::2

	sysctl_restore net.ipv6.fib_multipath_hash_policy
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
	sysctl_set net.ipv4.fib_multipath_hash_policy 1
	ip route replace 198.18.0.0/24 vrf vrf-r1 \
		nexthop via 198.51.100.2 weight $weight_rp2 \
		nexthop via 203.0.113.2 weight $weight_rp3

	ip vrf exec vrf-h2 mconnect -server -address 198.18.0.0:5001 &
	h2_mconnect_pid=$!
	ip vrf exec vrf-h3 mconnect -server -address 198.18.0.0:5001 &
	h3_mconnect_pid=$!

	ip vrf exec vrf-h1 mconnect -address 198.18.0.0:5001 -nconn 1000
	check_err $? "mconnect tests failed"
	log_test "$desc"

	kill $h2_mconnect_pid && wait $h2_mconnect_pid
	kill $h3_mconnect_pid && wait $h3_mconnect_pid

	ip route replace 198.18.0.0/24 vrf vrf-r1 \
		nexthop via 198.51.100.2 \
		nexthop via 203.0.113.2

	sysctl_restore net.ipv4.fib_multipath_hash_policy
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
	sysctl_set net.ipv6.fib_multipath_hash_policy 1
	ip route replace 2001:db8:18::/64 vrf vrf-r1 \
		nexthop via 2001:db8:2::2 weight $weight_rp2 \
		nexthop via 2001:db8:3::2 weight $weight_rp3

	ip vrf exec vrf-h2 mconnect -server -address [2001:db8:18::]:5001 &
	h2_mconnect_pid=$!
	ip vrf exec vrf-h3 mconnect -server -address [2001:db8:18::]:5001 &
	h3_mconnect_pid=$!

	ip vrf exec vrf-h1 mconnect -address [2001:db8:18::]:5001 -nconn 1000
	check_err $? "mconnect tests failed"
	log_test "$desc"

	kill $h2_mconnect_pid && wait $h2_mconnect_pid
	kill $h3_mconnect_pid && wait $h3_mconnect_pid

	ip route replace 2001:db8:18::/64 vrf vrf-r1 \
		nexthop via 2001:db8:2::2 \
		nexthop via 2001:db8:3::2

	sysctl_restore net.ipv6.fib_multipath_hash_policy
}

multipath_test()
{
	log_info "Running IPv4 multipath tests"
	multipath4_test "ECMP" 1 1
	multipath4_test "Weighted MP 2:1" 2 1
	multipath4_test "Weighted MP 11:45" 11 45

	log_info "Running IPv4 multipath connect tests"
	mconnect4_test "ECMP" 1 1
	mconnect4_test "Weighted MP 2:1" 2 1
	mconnect4_test "Weighted MP 11:45" 11 45

	log_info "Running IPv6 L4 hash multipath tests"
	multipath6_l4_test "ECMP" 1 1
	multipath6_l4_test "Weighted MP 2:1" 2 1
	multipath6_l4_test "Weighted MP 11:45" 11 45

	log_info "Running IPv6 L4 hash multipath connect tests"
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

	vrf_prepare

	h1_create
	h2_create
	h3_create

	router1_create

	forwarding_enable
}

cleanup()
{
	pre_cleanup

	forwarding_restore

	router1_destroy

	h3_destroy
	h2_destroy
	h1_destroy

	vrf_cleanup
}

ping_ipv4()
{
	ping_test $h1 198.51.100.2
	ping_test $h1 203.0.113.2
}

ping_ipv6()
{
	ping6_test $h1 2001:db8:2::2
	ping6_test $h1 2001:db8:3::2
}

# trap cleanup EXIT

setup_prepare
setup_wait

tests_run

exit $EXIT_STATUS
