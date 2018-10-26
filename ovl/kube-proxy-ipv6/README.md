# Xcluster ovl - kube-proxy-ipv6

Used for development and test of ipv6 (and dual stack) for the
`kube-proxy`. This ovl demonstrates how `xcluster` can be used to
archive very fast development turn-around times.



## Usage

Edit the `tar` script and files undes `ipv6/` in this ovl directory
to your needs, then do;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip kube-proxy-ipv6; xc start
# On cluster;
ipvsadm -L -n
less /var/log/kube-proxy.log
```

By default `proxy-mode=ipvs` is used.


### Development cycle

This is sort of a "real life" example of trouble-shooting of issue
[#68437](https://github.com/kubernetes/kubernetes/issues/68437). The
base commit used here is `022c05c141`.


```
cd $GOPATH/src/k8s.io/kubernetes
make WHAT=cmd/kube-proxy
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip kube-proxy-ipv6; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
ipvsadm -L -n
# See how the NodePort IP's are ipv4 (the bug we are examining)
```

In the issue it is claimed that the
[NodeIps](https://github.com/kubernetes/kubernetes/blob/07e81cb8ff590d096a61e951a3e6b4fc9076fb08/pkg/proxy/ipvs/proxier.go#L1098)
function returns ipv4 addresses. Add a log printout to verify that;

```
cd $GOPATH/src/k8s.io/kubernetes
vi pkg/proxy/ipvs/proxier.go
# Add a log printout on L1101, prefix "EKM:"
make WHAT=cmd/kube-proxy
```

Now restart `xcluster` with the updated `kube-proxy`. Note that there
is no need to do `xc stop`;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip kube-proxy-ipv6; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
grep EKM /var/log/kube-proxy.log
E1026 09:21:03.668696     252 proxier.go:1101] EKM: NodeIPs: [127.0.0.1 192.168.0.4 192.168.1.4]
E1026 09:21:03.668897     252 proxier.go:1101] EKM: NodeIPs: [127.0.0.1 192.168.0.4 192.168.1.4]
...
```

I clocked the time from (and including) the build command `make
WHAT=cmd/kube-proxy` until the added printout could be seen in the log
on a newly started `xcluster` to 58 seconds. Most time was waiting for
K8s to start.

