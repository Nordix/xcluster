Xcluster overlay - ecmp
=======================

Demonstrates Equal Cost Multi Path (ECMP) with a simple load balancer.

<img src="ipv6-ecmp.svg" alt="Picture of ecmp setup" width="80%" />

Usage
-----

```
# Use the normal image (no k8s);
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
# Start;
xc mkcdrom ecmp; xc start --ntesters=1
# On the tester;
mconnect -address [1000::2]:5001 -nconn 100
mconnect -address 10.0.0.2:5001 -nconn 100
ssh 1000::2
mconnect -address 10.0.0.2:5001 -nconn 100 -src 222.222.222 -srcmax 254
mconnect -address [1000::2]:5001 -nconn 100 -src 5000: -srcmax 65534
# On vm-201;
mconnect -address 10.0.0.2:5001 -nconn 100 -src 222.222.233 -srcmax 254
mconnect -address [1000::2]:5001 -nconn 100 -src 6000: -srcmax 65534
mconnect -address [1000::2]:5001 -nconn 100  # WILL NOT BE LOAD-BALANCED!
```

The tester is setup with additional sub-nets on the `lo` interface
that can be used as sources by
[mconnect](https://github.com/Nordix/mconnect#many-source-addresses).


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

