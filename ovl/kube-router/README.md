Xcluster overlay - kube-router
==============================

Use kube-router in Kubernetes clusters

The [kube-router](https://github.com/cloudnativelabs/kube-router)
replaces the `kube-proxy` and uses `ipvs` for load balancing to
pods. The `kube-proxy` also supports `ipvs` from v1.11 but the
`kube-router` seem to be quite a bit ahead of the `kube-proxy` in some
areal (for instance DSR) and it also implenets a number of other
functions. As it says in the "Primary Features" chapter;

    kube-router does it all.

Beside being a `kube-proxy` replacement `kube-router` is also a CNI, a
router for external traffic and implements the Kubernetes [Network
Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/).

Usage
-----

```
# (with a k8s hd image;)
xc mkcdrom gobgp kube-router; xc start
# On cluster;
gobgp neighbor
kubectl apply -f /etc/kubernetes/mconnect.yaml
/bin/gobgp neighbor    # /sbin/gobgp is not compatible with kube-router
# On router
gobgp neighbor
gobgp global rib
ip ro
# On a router
mconnect -address 10.0.0.2:5001 -nconn 400
```

Build
-----

```
go get -u github.com/cloudnativelabs/kube-router
go get github.com/matryer/moq
cd $GOPATH/src/github.com/cloudnativelabs/kube-router
make clean; make
# Also works;
go install ./cmd/...
```

Kube-router functions
---------------------

### Kube-proxy replacement

Enabled with `--run-service-proxy`. The standard `kube-proxy` shall
not be started and `kube-router` takes over it's functions using
`ipvs`. `kube-proxy` has more features and also seem more mature than
the `kube-proxy` in ipvs-mode (it is in "beta"), but it is not
"vanilla" Kubernetes.

### Kube-proxy as CNI

kube-router uses the `bridge CNI` but adds routes to other nodes using
BGP. The function can be disabled with `--enable-cni=false`


### Router for external traffic

Enabled with `--run-router`. Starts a BGP router on all nodes. Selected addresses can be advertised;

```
--advertise-cluster-ip
    Add Cluster IP of the service to the RIB so that it gets
    advertises to the BGP peers.

--advertise-external-ip
    Add External IP of service to the RIB so that it gets advertised
    to the BGP peers.
	
--advertise-loadbalancer-ip
    Add LoadbBalancer IP of service status as set by the LB provider
    to the RIB so that it gets advertised to the BGP peers.
```

### Enforce Network Policies

Enabled with `--run-firewall`. Not tested in this overlay.


