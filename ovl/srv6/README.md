# Xcluster/ovl - srv6

Test and experiments with
[Segment Routing](https://en.wikipedia.org/wiki/Segment_routing)
with IPv6 as data plane, `SRv6`.

Inspired by the [presentation](https://www.youtube.com/watch?v=vJaOKGWiyvU&list=PLj6h78yzYM2P4FvE6vARKAUg9BUi7ydw8&index=4) by Daniel Bernier, Bell Canada at KubeCon in Valencia 2022.

Documentation about SRv6 in linux seem imature. For instance `man
ip-route` does not describe `End.DX4` but it is
[implemented](https://www.segment-routing.net/open-software/linux/). The
[kernel source](https://github.com/torvalds/linux/blob/874c8ca1e60b2c564a48f7e7acc40d328d5c8733/net/ipv6/seg6_local.c#L951-L1046)
may be the only true documentation.

#### uSID in Linux

I have not been able to find *any* information about uSID in Linux
after the [ROSE](https://netgroup.github.io/rose/#srv6-usid-micro-segment-implementation-in-linux) implementation for the 5.6 kernel in May 2020.
And the [ROSE](https://netgroup.github.io/rose/) project seem dead or dormant.


## Network

The [diamond](https://github.com/Nordix/xcluster/tree/master/ovl/network-topology#diamond) network topology is used;

<img src="https://raw.githubusercontent.com/Nordix/xcluster/master/ovl/network-topology/diamond.svg" width="70%" />

The routers are assigned local Segment IDs (SIDs) as;

```
vm-201 - fc00:201::/64
vm-202 - fc00:202::/64
...
```

According to the [docs](https://segment-routing.org/index.php/Implementation/AdvancedConf) the SID *must not* be a local address;

> Note that with this framework, segment identifiers cannot be assigned to a local interface. If an IPv6 address is both present as a non-local routing entry and as a locally assigned address, the latter will take precedence and the SRv6 programming will not work.

While the SIDs are not local addresses it is still necessary to
setup routes for them. Example from `vm-201`;

```
# ip -6 ro
fc00:203::/64 via 1000::1:c0a8:3cb dev eth2 metric 1024 pref medium
fc00:204::/64 via 1000::1:c0a8:4cc dev eth3 metric 1024 pref medium
...
```

To start a cluster with `srv6` enabled, sysctls and `localsid`
routing table, and the SID routes define between routers, do;

```
./srv6.sh test start > $log
```

This is a good starting-point for manual experiments.

Check the help printout from `./srv6.sh` for automatic tests and other
options.


## Manual SR setup

Start a cluster with srv6;
```
./srv6.sh test start > $log
```

On the edge routers, `vm-201` and `vm-202`;

* Encapsulate packets from vms and testes
* Decapsulate packets to vms and testes

```
# On vm-201;
ip -6 route add 1000::1:192.168.2.0/120 encap seg6 mode encap segs fc00:203::6,fc00:202::6 dev eth0
ip -6 ro add fc00:201::6 encap seg6local action End.DX6 nh6 :: dev eth0 table localsid
# On vm-202;
ip -6 route add 1000::1:192.168.1.0/120 encap seg6 mode encap segs fc00:204::6,fc00:201::6 dev eth0
ip -6 ro add fc00:202::6 encap seg6local action End.DX6 nh6 :: dev eth0 table localsid
```

The "dev" can be any non-loopback device according to the
documentation. Here we use `eth0` which is not involved in the traffic
at all.

The "intermediate" routers, `vm-203` and `vm-204`, should just do
regular SRH processing;

```
# On vm-203;
ip -6 ro add fc00:203::/64 encap seg6local action End count dev eth0 table localsid
# On vm-204;
ip -6 ro add fc00:204::/64 encap seg6local action End count dev eth0 table localsid
```

We are all set. Do some testing!

```
# on vm-001;
ping 1000::1:192.168.2.221
# Yay!
```

You may capture traffic and inspect packets with `wireshark`;

```
# On yout host;
xc tcpdump --start 203 eth2
# On vm-001;
ping -c2 1000::1:192.168.2.221
# On your host
xc tcpdump --get 203 eth1
wireshark /tmp/vm-203-eth1.pcap &
```



## PMTU discovery in SRv6 networks

TL;DR It doesn't work with Linux.

A packet from a VM is routed by "normal" routing to the first SR
router `vm-201`. This router will encapsulate the packet and add a SRH
so if the default mtu of 1500 is used on all networks, the packet will
not fit.

Bytes have to be
[reserved](https://support.huawei.com/enterprise/en/doc/EDOC1100177915)
for the segment header and encap. The solution used in this ovl is to
set `mtu 1400` on the default routes on vms and testers.


## References

* `man ip-sr`, `man ip-route` (ENCAP_SEG6)

* [Cisco maintained SR website](http://www.segment-routing.net/)

* [Linux SRv6 implementaton](https://segment-routing.org/) (not recently updated)

* [ROSE](https://netgroup.github.io/rose/) - Research on Open SRv6 Ecosystem

* [Lab 1](http://ce.sc.edu/cyberinfra/workshops/wast_june_2021_WS1/Day5%20-%20Lab%209%20Introduction%20to%20Segment%20Routing%20over%20IPv6%20(SRv6).pdf) - A lab from University of South Carolina. Very much like this ovl.

* [Lab 2](https://wiki.apnictraining.net/_media/apricot2020-sdn/2-module_3.2_lab_guide_-_srv6_v1.01.pdf) - More advanced net.

* [About mtu with SRv6](https://support.huawei.com/enterprise/en/doc/EDOC1100177915)
