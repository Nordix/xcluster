# Xcluster/ovl - mpls

Tests and experiments with
[MPLS](https://en.wikipedia.org/wiki/Multiprotocol_Label_Switching).
This is a complement to
[ovl/srv6](https://github.com/Nordix/xcluster/tree/master/ovl/srv6).

MPLS itself is *really* simple. The marketed benefits of MPLS, such as
"50ms failover time", "Improve User Experience", etc. are not
properties of MPLS but how MPLS is setup, i.e. the control
plane. However MPLS makes these things *possible*.


## Network

The [diamond](https://github.com/Nordix/xcluster/tree/master/ovl/network-topology#diamond) network topology is used;

<img src="https://raw.githubusercontent.com/Nordix/xcluster/master/ovl/network-topology/diamond.svg" width="70%" />


## Manual test

Check the help printout for `./mpls.sh` for automatic tests.

Start cluster
```
./mpls.sh test start > $log
```

Now we have no connectivity vms<->testers. Our job is to setup this
using MPLS.

```
# On vm-001
ping 192.168.2.221    # Doesn't work
# On vm-201
ip route add 192.168.2.0/24 encap mpls 201 via inet6 1000::1:192.168.3.203
ip route add 1000::1:192.168.2.0/120 encap mpls 201 via inet6 1000::1:192.168.3.203
ip -f mpls route add 203 dev lo
# On vm-202
ip route add 192.168.1.0/24 encap mpls 202 via inet6 1000::1:192.168.5.203
ip route add 1000::1:192.168.1.0/120 encap mpls 202 via inet6 1000::1:192.168.5.203
ip -f mpls route add 203 dev lo
# On vm-203
ip -f mpls route add 201 as 203 via inet6 1000::1:192.168.5.202
ip -f mpls route add 202 as 203 via inet6 1000::1:192.168.3.201
# On vm-001
ping 192.168.2.221    # Works!
ping 1000::1:192.168.2.221
```

I direct packets to `lo` for decapsulation. Is there a better way?

You may capture traffic to see what's happening;
```
# On host
./mpls.sh test --no-stop > $log
xc tcpdump --start 203 eth1
xc tcpdump --start 203 eth2
# On vm-001
ping -c2 192.168.2.221
# On host
xc tcpdump --get 203 eth1 eth2
```


## References

* [mpls with tc](https://www.redhat.com/sysadmin/mpls-tc-linux-kernel)

* [Simple tutorial](https://liuhangbin.netlify.app/post/mpls-on-linux/)

* [What is MPLS, and why isn't it dead yet?](https://www.networkworld.com/article/2297171/network-security-mpls-explained.html)

