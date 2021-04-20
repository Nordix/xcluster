#! /bin/sh

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# "standard" xcluster setup;
netX() {
	local nodeid=$1
	local n=$2
	local tap b0 b1 dev

	dev=xcbr$n
	ip link show dev $dev > /dev/null 2>&1 || \
		die "Bridge does not exists [$dev]"
	tap=${dev}_t$nodeid
	b1=$n

	test "$__mtu" -ne 1500 && append="$append mtu$n=$__mtu"

	if ip link show dev $tap > /dev/null 2>&1; then
		echo "Tap device already exist [$tap]"
	else
		ip tuntap add $tap mode tap user $USER
		ip link set mtu $__mtu dev $tap
		ip link set dev $tap master $dev
		ip link set up $tap
	fi

	b0=$(printf '%02x' $nodeid)
	echo " -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap"
	echo " -device virtio-net-pci,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
}

# Mqueue setup. Needed for XDP with 0-copy
netY() {
	local nodeid=$1
	local n=$2
	local tap b0 b1 dev tmp

	dev=xcbr$n
	tap=${dev}_t$nodeid

	tmp=/tmp/tmp/xcnet
	mkdir -p $tmp
	cat > $tmp/$tap <<EOF
#! /bin/sh
echo $tap \$1 > $tmp/$tap.log
ip tuntap add \$1 mode tap user $USER
ip link set dev \$1 master $dev
ip link set up \$1
EOF
	chmod a+x $tmp/$tap
	
	b0=$(printf '%02x' $nodeid)
	b1=$n
	echo " -netdev tap,ifname=$tap,id=net$n,script=$tmp/$tap,queues=4,vhost=on"
	echo " -device virtio-net-pci,mq=on,vectors=6,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
}

if test "$2" != "0"; then
	netY $1 $2
else
	netX $1 $2
fi

