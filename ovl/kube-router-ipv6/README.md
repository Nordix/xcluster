Xcluster - Kube-router in ipv6 configuration
============================================

Intended for development of ipv6-only or dual stack with ipv6 prefix
as described in;
[#534](https://github.com/cloudnativelabs/kube-router/issues/534)

This is under development and for now only the CNI function of
`kube-router` is enabled.


## Usage


Ipv4;
```
xc mkcdrom externalip kube-router-ipv6; xc start
# Do some basic test to see if everything is messed up;
# On cluster
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl get svc
gobgp neighbor
ip ro
ipset list
# Outside cluster (e.g on a router);
mconnect -address 10.0.0.2:5001 -nconn 400
```

Ipv6;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip kube-router-ipv6; xc start
# On cluster;
gobgp neighbor
kubectl apply -f /etc/kubernetes/mconnect.yaml
ip -6 ro
```

## Build

PR [#545](https://github.com/cloudnativelabs/kube-router/pull/545)
should be applied.

```
cd $GOPATH/src/github.com/cloudnativelabs/kube-router
rm -f kube-router; make
```
