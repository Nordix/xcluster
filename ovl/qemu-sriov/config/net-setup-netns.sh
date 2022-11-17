#! /bin/sh

nodeid=$1
n=$2

dev=xcbr$n
ip link show dev $dev > /dev/null 2>&1 || \
	die "Bridge does not exists [$dev]"
tap=${dev}_t$nodeid
b1=$n

dut=igb

b0=$(printf '%02x' $nodeid)
if test $n -gt 0 ; then
	if ! ip link show dev $tap > /dev/null 2>&1; then
		ip tuntap add $tap mode tap user $USER multi_queue
		ip link set mtu $__mtu dev $tap
		ip link set dev $tap master $dev
		ip link set up $tap
	fi
	echo "$opt -device pcie-root-port,slot=$n,id=pcie_port.$n"
	echo "$opt -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap,queues=2"
	echo "$opt -device $dut,bus=pcie_port.$n,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
else
	if ! ip link show dev $tap > /dev/null 2>&1; then
		ip tuntap add $tap mode tap user $USER
		ip link set mtu $__mtu dev $tap
		ip link set dev $tap master $dev
		ip link set up $tap
	fi
	echo "$opt -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap"
	echo "$opt -device virtio-net-pci,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
	#echo "$opt -device e1000,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
fi
