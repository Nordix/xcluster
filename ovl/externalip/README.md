Xcluster overlay - externalip
=============================

A very small overlay on top of Kubernetes to use `externalIPs` in
the service for `mconnect`.

Usage
-----

```
xc mkcdrom externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
# Outside cluster;
mconnect -address 10.0.0.2:5001 -nconn 400
```
For ipv6;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
# Outside cluster;
mconnect -address [1000::2]:5001 -nconn 400
```


The ipv6/ecmp/ssh bug
---------------------

**OBSOLETE; KEPT FOR HISTORICAL REASONS**

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

