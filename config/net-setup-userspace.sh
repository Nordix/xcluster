#! /bin/sh

net_user() {
	local nodeid=$1
	local net=$2
	local b0=$(printf '%02x' $nodeid)
	test -n "$XCLUSTER_TELNET_BASE" || XCLUSTER_TELNET_BASE=12000
	local pt=$((XCLUSTER_TELNET_BASE+nodeid))
	test -n "$XCLUSTER_SSH_BASE" || XCLUSTER_SSH_BASE=12300
	local ps=$((XCLUSTER_SSH_BASE+nodeid))
	local k8s
	if test $nodeid -eq 1; then
		local pk=18080
		test -n "$XCLUSTER_K8S_PORT" && pk=$XCLUSTER_K8S_PORT
		k8s=",hostfwd=tcp:127.0.0.1:$pk-192.168.0.1:8080,hostfwd=tcp:127.0.0.1:6443-192.168.0.1:6443"
	fi
	echo "-device virtio-net-pci,netdev=net$net,mac=00:00:00:01:0$net:$b0"
	echo "-netdev user,id=net$net,net=192.168.0.$nodeid/24,host=192.168.0.250,ipv6-net=2000::/64,ipv6-host=2000::250,hostfwd=tcp:127.0.0.1:$pt-192.168.0.$nodeid:23,hostfwd=tcp:127.0.0.1:$ps-192.168.0.$nodeid:22$k8s"
}

net_user_old_qemu() {
	local nodeid=$1
	local net=$2
	local b0=$(printf '%x' $nodeid)
	test -n "$XCLUSTER_TELNET_BASE" || XCLUSTER_TELNET_BASE=12000
	local pt=$((XCLUSTER_TELNET_BASE+nodeid))
	test -n "$XCLUSTER_SSH_BASE" || XCLUSTER_SSH_BASE=12300
	local ps=$((XCLUSTER_SSH_BASE+nodeid))
	local k8s
	if test $nodeid -eq 1; then
		local pk=18080
		test -n "$XCLUSTER_K8S_PORT" && pk=$XCLUSTER_K8S_PORT
		k8s=",hostfwd=tcp:127.0.0.1:$pk-192.168.0.1:8080"
	fi
	echo "-net nic,vlan=$net,macaddr=0:0:0:1:$net:$b0,model=virtio"
	echo "-net user,vlan=$net,net=192.168.0.$nodeid/24,host=192.168.0.250,hostfwd=tcp:127.0.0.1:$pt-192.168.0.$nodeid:23,hostfwd=tcp:127.0.0.1:$ps-192.168.0.$nodeid:22$k8s"
}

net_uml() {
	local nodeid=$1
	local net=$2
	local b0=$(printf '%02x' $nodeid)
	test -n "$XCLUSTER_MCAST_BASE" || XCLUSTER_MCAST=XCLUSTER_MCAST_BASE=120
	local mcast="224.0.0.$((XCLUSTER_MCAST_BASE+net)):27030"
	echo "-device virtio-net-pci,netdev=net$net,mac=00:00:00:01:0$net:$b0"
	echo "-netdev socket,id=net$net,mcast=$mcast"
}

if test "$2" -eq 0; then
	if $__kvm -version | grep -qE 'QEMU emulator version 2\.[1-5]\.'; then
		net_user_old_qemu $1 $2
	else
		net_user $1 $2
	fi
else
	net_uml $1 $2
fi
