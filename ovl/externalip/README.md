Xcluster overlay - externalip
=============================

A very small overlay on top of Kubernetes to use `externalIPs` in
services for `mconnect` and `busybox` applications.

Usage
-----

```
images make coredns busybox docker.io/nordixorg/mconnect:0.2
xc mkcdrom externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
# Outside cluster;
mconnect -address 10.0.0.2:5001 -nconn 400
telnet 10.0.0.2 1023
ssh -p 1022 root@10.0.0.2 hostname
wget -q -O - http://10.0.0.2:1080/cgi-bin/info
```
For ipv6;

```
SETUP=ipv6 xc mkcdrom externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl apply -f /etc/kubernetes/busybox.yaml
# Outside cluster;
kubectl config use-context xcluster6
mconnect -address [1000::2]:5001 -nconn 400
telnet 1000::2 1023
ssh -p 1022 root@1000::2 hostname
wget -q -O - http://[1000::2]:1080/cgi-bin/info
```


The ipv6/ecmp/ssh bug
---------------------

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

