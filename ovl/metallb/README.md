Xcluster overlay - metallb
==========================

For experiments with the [metallb](https://github.com/google/metallb).

The `metallb` is not a load-balancer despite the `lb` suffix. It makes
the service `type: LoadBalancer` work in a similar way as in public
clouds.

Metallb has two major (independent) functions;

* Maintain and assign external addresses to services with `type:
  LoadBalancer` (controller)

* Announce the external addresses via BGP or L2 (speaker)

<img src="metallb-overview.svg" alt="metallb-overview" width="60%" />



Usage
-----

Assuming `xcluster` k8s image;

```
xc mkcdrom metallb gobgp; xc start
# On cluster;
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f /etc/kubernetes/metallb-config.yaml
kubectl apply -f /etc/kubernetes/mconnect.yaml
# On a router vm;
gobgp neighbor
ip ro
mconnect -address 10.0.0.2:5001 -nconn 1000
```

## Home-built pod

For internal experiments a local pod can be used;

Ipv4 setup;

```
images make coredns metallb docker.io/nordixorg/mconnect:0.2
xc mkcdrom metallb gobgp images; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/metallb-config-internal.yaml
kubectl apply -f /etc/kubernetes/metallb.yaml
kubectl apply -f /etc/kubernetes/metallb-speaker.yaml
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl logs pod/...
kubectl get svc
# On router;
gobgp neighbor
ip ro
# Outside cluster;
mconnect -address 10.0.0.2:5001 -nconn 1000
```


IPv6 setup;

```
images make coredns metallb docker.io/nordixorg/mconnect:0.2
SETUP=ipv6 xc mkcdrom etcd coredns k8s-config metallb gobgp images; xc start
```


Build
-----

Read the instructions on the
[contributing](https://metallb.universe.tf/community/#contributing) page.

```
go get -u go.universe.tf/metallb
cd $GOPATH/src/go.universe.tf/metallb
git checkout v0.7.3
go install go.universe.tf/metallb/speaker
go install go.universe.tf/metallb/controller
strip $GOPATH/bin/controller $GOPATH/bin/speaker
```

IP address sharing
------------------

Metallb supports that several services share the same `loadBalancerIP`
(VIP) (described
[here](https://metallb.universe.tf/usage/#ip-address-sharing)).

But the restriction for `ExternalTrafficPolicy: Local`; "the *exact
same selector" makes k8s distribure traffic to all sevices to all
pods.

