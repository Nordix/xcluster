#! /bin/sh

nodeid=$1
n=$2

test -n "$3" && mtu=$3 || mtu=1500

dev=xcbr$n
ip link show dev $dev > /dev/null 2>&1 || \
	die "Bridge does not exists [$dev]"
tap=${dev}_t$nodeid
b0=$(printf '%02x' $nodeid)
b1=$n
mac="00:00:00:01:0$b1:$b0"

net_pci() {
	n=$1
	tap=$2
	dut="$3"

	echo " -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap \
	       -device $dut,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
}

net_pcie() {
	n="$1"
	tap="$2"
	dut="$3"

	echo " -device pcie-root-port,slot=$n,id=pcie_port.$n \
	       -netdev tap,id=net$n,script=no,downscript=/tmp/rmtap,ifname=$tap \
	       -device $dut,bus=pcie_port.$n,netdev=net$n,mac=00:00:00:01:0$b1:$b0"
}

if ip link show dev $tap > /dev/null 2>&1; then
	echo "Tap device already exist [$tap]" >&2
else
	ip tuntap add $tap mode tap user $USER
	ip link set mtu $mtu dev $tap
	ip link set dev $tap master $dev
	ip link set up $tap
fi

netdev=virtio
test $n -gt 1 && netdev=igb

echo "Using netdevice: $netdev" >&2
case $netdev in
	virtio)
		net_pci $n $tap virtio-net-pci;;
	e1000)
		net_pci $n $tap e1000;;
	igb)
		net_pcie $n $tap igb;;
esac
