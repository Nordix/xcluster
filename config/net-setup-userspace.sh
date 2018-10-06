#! /bin/sh

net_user() {
	local nodeid=$1
	local net=$2
	local b0=$(printf '%x' $nodeid)
	test -n "$XCLUSTER_TELNET_BASE" || XCLUSTER_TELNET_BASE=12000
	local pt=$((XCLUSTER_TELNET_BASE+nodeid))
	test -n "$XCLUSTER_SSH_BASE" || XCLUSTER_SSH_BASE=12100
	local ps=$((XCLUSTER_SSH_BASE+nodeid))
	echo "-net nic,vlan=$net,macaddr=0:0:0:1:$net:$b0,model=virtio"
	echo "-net user,vlan=$net,net=192.168.0.$nodeid/24,host=192.168.0.250,ipv6-net=2000::/64,ipv6-host=2000::250,hostfwd=tcp:127.0.0.1:$pt-192.168.0.$nodeid:23,hostfwd=tcp:127.0.0.1:$ps-192.168.0.$nodeid:22"
}

net_uml() {
	local nodeid=$1
	local net=$2
	local b0=$(printf '%x' $nodeid)
	test -n "$XCLUSTER_MCAST_BASE" || XCLUSTER_MCAST=XCLUSTER_MCAST_BASE=120
	local mcast="224.0.0.$((XCLUSTER_MCAST_BASE+net)):27030"
	echo "-net nic,vlan=$net,macaddr=0:0:0:1:$net:$b0,model=virtio"
	echo "-net socket,vlan=$net,mcast=$mcast"
}

if test "$2" -eq 0; then
	net_user $1 $2
else
	net_uml $1 $2
fi
