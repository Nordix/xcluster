# Xcluster ovl - mtu

* Tests with different MTU sizes with and without Kubernetes.

Test jumbo frames in the K8s network with different CNI-plugins
(currently only [xcluster-cni](https://github.com/Nordix/xcluster-cni)).

Test of the [ecmp/pmdu-discovery
problem](https://blog.cloudflare.com/path-mtu-discovery-in-practice/)
without K8s.

* https://www.redhat.com/en/blog/deep-dive-virtio-networking-and-vhost-net


## MTU in xcluster

First; MTU tests must be performed in a netns since the user-space
networking does not handle jumbo frames.

```
__mtu=9000 xc starts
```

This will set the mtu on all tab devices and (implicitly) the bridges;
```
ifconfig xcbr1
xcbr1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 9000
...
```

It will also append strings like "mtu1=9000" to the kernel
command-line which can be read from within the VMs;

```
cat /proc/cmdline 
noapic root=/dev/vda rw init=/init  mtu0=9000 mtu1=9000
```

This is then used to set the mtu on the interfaces in all VMs;
```
ifconfig eth1
eth1      Link encap:Ethernet  HWaddr 00:00:00:01:01:03  
...
          UP BROADCAST RUNNING MULTICAST  MTU:9000  Metric:1
```



## Tests with K8s

Note that mtu tests shall be performed with a CNI-plugin so
`k8s-xcluster` shall be used.

Run test;
```
log=/tmp/$USER-xcluster.log
./xcadmin.sh k8s_test --cni=xcluster mtu > $log
```

Manual;
```
export __mtu=9000
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export __nvm=5
export __mem=1536
export XOVLS="k8s-cni-xcluster private-reg"
xc mkcdrom mtu; xc starts
# On vm-001;
ifconfig eth1    # Check MTU:9000
tracepath -n 192.168.1.2
tracepath -n 1000::1:192.168.1.2
/bin/ping -nc1 -W1 -s 8972 -M do 192.168.1.2
/bin/ping -nc1 -W1 -s 8952 -M do 1000::1:192.168.1.2
/bin/ping -nc1 -W1 -s 8974 -M do 192.168.1.2
/bin/ping -nc1 -W1 -s 8954 -M do 1000::1:192.168.1.2
# On vm-002;
tcpdump -eni eth1 icmp or icmp6
```

### Pmtu inside PODs

The POD network may have a larger MTU than the path to an external
peer, e.g when jumbo-frames are used internally. When a POD is
accessed from an external client via a service the POD will try to
respond with a too-big packet and it is essential that the ICMP
packets really is routed back to the POD. To test this the "backend"
network topology is used.

<img src="../network-topology/backend.svg" alt="Backend topology" width="80%" />

Jumbo-frames are not used but the "frontend" network is configured
with mtu=1400. A POD will send a packet with it's max mtu which is >1400
but the outgoing path have mtu=1400.

Test;
```
log=/tmp/$USER-xcluster.jog
xcluster_PROXY_MODE=iptables ./xcadmin.sh k8s_test --cni=calico mtu backend_http > $log
```

That work. So to test manually for some "tcpdump" do;
```
xcluster_PROXY_MODE=iptables ./xcadmin.sh k8s_test --cni=calico mtu backend_start_limit_mtu > /dev/null
# (the cluster is left running)
kubectl get pods
kubectl exec -it mserver-daemonset-... -- sh
# In the pod;
tcpdump -lni eth0
# On vm-221
wget -O /dev/null http://10.0.0.2  # (may have to be repeated some times)
```

Trace example;
```
15:22:09.790403 ARP, Request who-has 11.0.40.65 tell 192.168.0.5, length 28
15:22:09.790433 ARP, Reply 11.0.40.65 is-at 22:21:7a:8d:bd:d8, length 28
15:22:09.790437 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [S], seq 1568849216, win 64240, options [mss 1460,sackOK,TS val 3813805410 ecr 0,nop,wscale 7], length 0
15:22:09.790450 ARP, Request who-has 169.254.1.1 tell 11.0.40.65, length 28
15:22:09.790454 ARP, Reply 169.254.1.1 is-at ee:ee:ee:ee:ee:ee, length 28
15:22:09.790455 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [S.], seq 1597526885, ack 1568849217, win 65236, options [mss 1400,sackOK,TS val 2682440094 ecr 3813805410,nop,wscale 7], length 0
15:22:09.790905 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3813805411 ecr 2682440094], length 0
15:22:09.790934 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [P.], seq 1:72, ack 1, win 502, options [nop,nop,TS val 3813805411 ecr 2682440094], length 71: HTTP: GET / HTTP/1.1
15:22:09.790944 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [.], ack 72, win 510, options [nop,nop,TS val 2682440094 ecr 3813805411], length 0
15:22:09.792331 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [P.], seq 1:191, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 190: HTTP: HTTP/1.0 200 OK
15:22:09.792445 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [.], seq 191:1579, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 1388: HTTP
15:22:09.792449 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [P.], seq 1579:2967, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 1388: HTTP
15:22:09.792474 IP 192.168.0.5 > 11.0.40.65: ICMP 192.168.2.221 unreachable - need to frag (mtu 1400), length 556
15:22:09.792478 IP 192.168.0.5 > 11.0.40.65: ICMP 192.168.2.221 unreachable - need to frag (mtu 1400), length 556
15:22:09.792489 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [.], seq 191:1539, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 1348: HTTP
15:22:09.792490 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [.], seq 1539:2887, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 1348: HTTP
15:22:09.792491 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [P.], seq 2887:2967, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 80: HTTP
15:22:09.792709 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [FP.], seq 2967:3689, ack 72, win 510, options [nop,nop,TS val 2682440096 ecr 3813805411], length 722: HTTP
15:22:09.792935 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [.], ack 191, win 501, options [nop,nop,TS val 3813805413 ecr 2682440096], length 0
15:22:09.792961 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [.], ack 2967, win 480, options [nop,nop,TS val 3813805413 ecr 2682440096], length 0
15:22:09.793494 IP 192.168.2.221.57200 > 11.0.40.65.80: Flags [F.], seq 72, ack 3690, win 501, options [nop,nop,TS val 3813805413 ecr 2682440096], length 0
15:22:09.793529 IP 11.0.40.65.80 > 192.168.2.221.57200: Flags [.], ack 73, win 510, options [nop,nop,TS val 2682440097 ecr 3813805413], length 0
```

## Test without K8s

There is a problem with pmtu discovery with ECMP described in depth here;

* https://blog.cloudflare.com/path-mtu-discovery-in-practice/
* https://blog.cloudflare.com/increasing-ipv6-mtu/


Test setup;

<img src="../network-topology/multihop.svg" alt="Test setup" width="80%" />

**WARNING**: Linux > linux-5.4.x have a bug that makes ecmp packet
based for forwarded traffic. Download the pre-built
[bzImage-linux-5.4.35](https://artifactory.nordix.org/artifactory/cloud-native/xcluster/images/bzImage-linux-5.4.35)
and set the `__kbin` variable to point to it.

Also NIC "offload" must be disables or else you will see packets > mtu
in your traces. This is done by the test scripts;

```
ethtool -K eth1 gro off gso off tso off
```

A http request from an external source to the VIP address with a
rather large reply is assumed to be the most realistic test. Tests are
prepared for http without any precautions (fails) and work-arounds
with limited mtu and `pmtud`. It is *not* necessary to execute these
tests in a "netns", user-space networking is fine.

Prerequisite; build `pmtud`;
```
sudo apt install -y libpcap-dev libnetfilter-log-dev
# Clone to $GOPATH/src/github.com/cloudflare/pmtud
make -j$(nproc) -f Makefile.pmtud
```

Run tests;
```
cdo mtu
./mtu.sh test http_vanilla > /dev/null  # (fails)
./mtu.sh test http_limit_mtu > /dev/null
./mtu.sh test http_pmtud > /dev/null
```


Manual ECMP test;
```
./mtu.sh test vip_setup > /dev/null
# On vm-221
mconnect -address 10.0.0.0:5001 -nconn 100
mconnect -address [1000::1:10.0.0.0]:5001 -nconn 100
wget -O- http://10.0.0.0/index.html
# On vm-001
tracepath -n 20.0.0.0
ip ro replace 20.0.0.0/24 via 192.168.1.201 src 10.0.0.0
tracepath -n 20.0.0.0     # Does not work!

tracepath -n 1000::1:20.0.0.0
ip ro replace 1000::1:20.0.0.0/120 via 1000::1:192.168.1.201 src 1000::1:10.0.0.0
```




