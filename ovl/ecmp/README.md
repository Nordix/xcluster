Xcluster overlay - ecmp
=======================

Demonstrates Equal Cost Multi Path
[ECMP](https://en.wikipedia.org/wiki/Equal-cost_multi-path_routing)
with a simple load balancer.

<img src="ipv6-ecmp.svg" alt="Picture of ecmp setup" width="80%" />

Some articles on the topic;

* https://codecave.cc/multipath-routing-in-linux-part-1.html
* https://codecave.cc/multipath-routing-in-linux-part-2.html
* https://codecave.cc/multipath-routing-ecmp-in-linux-part-3.html
* https://cumulusnetworks.com/blog/celebrating-ecmp-part-one/
* https://cumulusnetworks.com/blog/celebrating-ecmp-part-two/


Usage
-----

```
# Use the normal image (no k8s);
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
# Start;
xc mkcdrom xnet ecmp; xc start --ntesters=1
# On the tester;
mconnect -address [1000::2]:5001 -nconn 100
mconnect -address 10.0.0.2:5001 -nconn 100
ssh 1000::2
mconnect -address 10.0.0.2:5001 -nconn 100 -srccidr 222.222.222.0/24
mconnect -address [1000::2]:5001 -nconn 100 -srccidr 5000::/112
# On vm-201;
mconnect -address 10.0.0.2:5001 -nconn 100 -srccidr 222.222.233.0/24
mconnect -address [1000::2]:5001 -nconn 100 -srccidr 6000::/112
mconnect -address [1000::2]:5001 -nconn 100  # WILL NOT BE LOAD-BALANCED!
```

The tester is setup with additional sub-nets on the `lo` interface
that can be used as sources by
[mconnect](https://github.com/Nordix/mconnect#many-source-addresses).


### Continuous traffic

This measures the disturbance on ongoing connections if an ECMP target
is added or removed.

```
unset XOVLS __mem1
export __mem=512
xc mkcdrom xnet ecmp; xc starts --nvm=10 --nrouters=1 --ntesters=1
# On vm-201
ip ro replace 10.0.0.0/24 \
  nexthop via 192.168.1.1 \
  nexthop via 192.168.1.2 \
  nexthop via 192.168.1.3 \
  nexthop via 192.168.1.4 \
  nexthop via 192.168.1.5 \
  nexthop via 192.168.1.6 \
  nexthop via 192.168.1.7 \
  nexthop via 192.168.1.8 \
  nexthop via 192.168.1.9 \
  nexthop via 192.168.1.10
# On vm-221 (tester)
ctraffic -address 10.0.0.2:5003 -nconn 100 -rate 500 -monitor \
  -timeout 20s -stats=all > /tmp/ctraffic4.json 
# On vm-201 while the test is running;
ip ro replace 10.0.0.0/24 \
  nexthop via 192.168.1.1 \
  nexthop via 192.168.1.2 \
  nexthop via 192.168.1.3 \
  nexthop via 192.168.1.4 \
  nexthop via 192.168.1.5 \
  nexthop via 192.168.1.6 \
  nexthop via 192.168.1.7 \
  nexthop via 192.168.1.8 \
  nexthop via 192.168.1.9
# (wait a few sec...)
ip ro replace 10.0.0.0/24 \
  nexthop via 192.168.1.1 \
  nexthop via 192.168.1.2 \
  nexthop via 192.168.1.3 \
  nexthop via 192.168.1.4 \
  nexthop via 192.168.1.5 \
  nexthop via 192.168.1.6 \
  nexthop via 192.168.1.7 \
  nexthop via 192.168.1.8 \
  nexthop via 192.168.1.9 \
  nexthop via 192.168.1.10
```

Post-processing;
```
scp root@192.168.0.221:/tmp/ctraffic4.json /tmp
cd $GOPATH/src/github.com/Nordix/ctraffic
./scripts/plot.sh connections < /tmp/ctraffic4.json > /tmp/ctraffic4.svg
```


The ipv6/ecmp/ssh bug
---------------------

This bug it fixed in kernel 4.18, but may be present in earlier
kernels.

```
> ssh -p 1022 root@1000::2 hostname
Warning: Permanently added '[1000::2]:1022' (ECDSA) to the list of known hosts.
packet_write_wait: Connection to 1000::2 port 1022: Broken pipe
```

Linux uses something they call `flowinfo` to compute the ecmp hash for
ipv6. This includes the `flowlabel` but also the DSCP bits. Ssh seem
to alter the DSCP in the middle of the session which disrupt the
`flow-based` ecmp.

To view this in action trace on a router, e.g. `vm-201`;

```
tcpdump -ni eth0 -w /tmp/ssh.pcap port 1022
```

Do a (failing) `ssh -p 1022 root@1000::2 hostname` and copy the pcap
file and use `wireshark`;

```
scp root@192.168.0.201:/tmp/ssh.pcap /tmp
wireshark /tmp/ssh.pcap &
```

