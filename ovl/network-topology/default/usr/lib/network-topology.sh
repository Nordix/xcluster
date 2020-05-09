#! /bin/sh
die() {
	echo "$@"
	exit 1
}

hostname | grep -Eq 'vm-[0-9]+$' || die "Invalid hostname [$(hostname)]"
i=$(hostname | cut -d- -f2 | sed -re 's,^0+,,')
PREFIX=1000::1

echo 0 > /proc/sys/net/ipv6/conf/eth1/accept_dad

# ifsetup device network
ifsetup() {
	dev=$1
	net=$2
	echo 0 > /proc/sys/net/ipv6/conf/$dev/accept_dad
	ip addr add 192.168.$net.$i/24 dev $dev
	ip -6 addr add $PREFIX:192.168.$net.$i/120 dev $dev
	eval $(grep -oE "mtu$net=[0-9]+" /proc/cmdline)
	eval "mtu=\$mtu$net"
	test -n "$mtu" && ip link set $dev mtu $mtu
	ip link set up dev $dev
}

fwsetup() {
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo 1 > /proc/sys/net/ipv4/fib_multipath_hash_policy
	echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
	echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
}
