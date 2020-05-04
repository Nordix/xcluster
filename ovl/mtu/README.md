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



## K8s usage

Note that mtu tests shall be performed with a CNI-plugin so
`k8s-xcluster` shall be used.

Run test;
```
./xcadmin.sh k8s_test --cni=xcluster mtu > /dev/null
# Or manually;
cdo mtu
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export __nvm=5
export __mem=1536
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export XOVLS="k8s-cni-xcluster private-reg"
./mtu.sh test
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


## Test without K8s

There is a problem with pmtu discovery with ECMP described in depth here;

* https://blog.cloudflare.com/path-mtu-discovery-in-practice/
* https://blog.cloudflare.com/increasing-ipv6-mtu/


Test setup;

<img src="mtu-ladder.svg" alt="Test setup" width="80%" />

**WARNING**: Linux > linux-5.4.x have a bug that makes ecmp packet
based for forwarded traffic. Download the pre-built
[bzImage-linux-5.4.35](https://artifactory.nordix.org/artifactory/cloud-native/xcluster/images/bzImage-linux-5.4.35)
and set the `__kbin` variable to point to it.

Also NIC "offload" must be disables or else you will see packets > mtu
in your traces; `ethtool -K eth1 gro off`. This is done by the test scripts.

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




