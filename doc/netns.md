# Network name-space for xcluster

`Xcluster` is intended for development and testing of network
functions. As such it alter the network configuration for instance
create bridges and tap devices, defined new ip subnets, add rules to
iptables, etc. In most Linux distributions the main netns is governed
by some programs such as the `NetworkManager` and `firewalld`. There
is a risk that `xcluster` does things that conflicts with the
management program or that the management program interfere with the
`xcluster` setup.

For this reason `xcluster` should execute in it's own netns. To setup do;

```
xc nsadd 1    # Requires "sudo"
```

<img src="xcluster-netns.svg" alt="Figure of xcluster netns" width="80%" />

Routing and masquerade is setup so the host network (and internet) is
reachable from the netns. Also traffic from the ["External
net"](networking.md) in the xcluster is masqueraded to allow the nodes
in the xcluster to access the internet via the router VMs.



## DNS

The VMs are setup to use a DNS server on the host (within the netns of
course);

```
vm-201 ~ # cat /etc/resolv.conf 
#
nameserver 192.168.0.250
```

For this to work you must start some dns-server in the netns. The
[coredns](https://github.com/coredns/coredns) is bundled with
`xcluster` for this purpose. You must grant rights to open privileged
ports (53) to the `coredns` program (or use "sudo");

```
# (in the xcluster netns;)
cd $(dirname $XCLUSTER)
sudo setcap 'cap_net_bind_service=+ep' ./bin/coredns
./bin/coredns -conf "$($XCLUSTER ovld coredns)/Corefile" > /tmp/$USER/coredns.log 2>&1 &
nslookup www.google.se 2000::250
```

The lookup will probably fail on Ubuntu because a local dns-server is
installed by default. Check this with;

```
# (On your host, NOT in a VM;)
$ cat /etc/resolv.conf 
...
nameserver 127.0.1.1
```

If you see a local address as nameserver you must disable it. Follow
[these](https://askubuntu.com/questions/907246/how-to-disable-systemd-resolved-in-ubuntu)
instructions.

After this restart the coredns and lookup with your local `coredns`
should work.

Now check that dns lookup works from the VMs;

```
vm 201
# On the vm;
nslookup www.google.se
Server:    192.168.0.250
Address 1: 192.168.0.250

Name:      www.google.se
Address 1: 2a00:1450:400f:80b::2003 arn11s04-in-x03.1e100.net
Address 2: 216.58.207.195 arn11s04-in-f3.1e100.net
```
