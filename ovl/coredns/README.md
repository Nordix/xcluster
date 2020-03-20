# Xcluster ovl - CoreDNS

* CoreDNS POD in `xcluster` (obsolete)

`Xcluster` uses node-local `coredns` instances running in main netns
on each node. This ovl is kept for tests, e.g for
[k8s #87426](https://github.com/kubernetes/kubernetes/issues/87426).

## Usage

```
./coredns.sh test start
```

Test;

```
nslookup kubernetes.default.svc.xcluster 12.0.0.2
kubectl apply -f /etc/kubernetes/mconnect.yaml
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 400
nslookup -type=AAAA www.ericsson.se 2000::250
```


## Build

```
go get github.com/coredns/coredns
cd $GOPATH/src/github.com/coredns/coredns
make
strip coredns   # (not needed)
mv coredns $GOPATH/bin
sudo setcap 'cap_net_bind_service=+ep' $GOPATH/bin/coredns
```

### Make image

```
images mkimage --force --upload ./image
```

Test it;
```
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
xc mkcdrom xnet etcd iptools kubernetes coredns private-reg; xc start
# Ipv6;
SETUP=ipv6 xc mkcdrom xnet etcd iptools kubernetes coredns private-reg k8s-config
```

## The local-pod problem

When a query is sent to the ClusterIP of the coredns POD and it
happens to be on the local node the query will fail because the
response has the coredns pod-address as source;

```
14:00:49.090285 IP 11.0.1.3.43648 > 12.0.0.2.53: 16620+ A? kubernetes.default.svc.xcluster.default.svc.xcluster. (70)
14:00:49.090543 IP 11.0.1.3.43648 > 12.0.0.2.53: 17340+ AAAA? kubernetes.default.svc.xcluster.default.svc.xcluster. (70)
14:00:49.090712 IP 11.0.1.2.53 > 11.0.1.3.43648: 16620 NXDomain* 0/1/0 (148)
14:00:49.090884 IP 11.0.1.2.53 > 11.0.1.3.43648: 17340 NXDomain* 0/1/0 (148)
```

From a pod on another node the ClusterIP is source and the query works;
```
14:02:46.001573 IP 11.0.0.2.36545 > 12.0.0.2.53: 9367+ A? kubernetes.default.svc.xcluster.default.svc.xcluster. (70)
14:02:46.001766 IP 11.0.0.2.36545 > 12.0.0.2.53: 11076+ AAAA? kubernetes.default.svc.xcluster.default.svc.xcluster. (70)
14:02:46.003548 IP 12.0.0.2.53 > 11.0.0.2.36545: 11076 NXDomain 0/1/0 (148)
14:02:46.003781 IP 12.0.0.2.53 > 11.0.0.2.36545: 9367 NXDomain 0/1/0 (148)
```


## Connection tracking

Connection tracking should be turned off for UDP DNS queries, See this
[blog-post](https://jeanbruenn.info/2017/04/30/conntrack-and-udp-dns-with-iptables/).
