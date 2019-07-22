Xcluster overlay - metallb
==========================

For experiments and tests with the
[metallb](https://github.com/danderson/metallb).

The `metallb` is not a load-balancer despite the `lb` suffix. It makes
the service `type: LoadBalancer` work in a similar way as in public
clouds.

Metallb has two major (independent) functions;

* controller - Maintain and assign external addresses to services with `type:
  LoadBalancer`

* speaker - Announce the external addresses via BGP or L2

<img src="metallb-overview.svg" alt="metallb-overview" width="80%" />



Usage
-----

```
configd=$($XCLUSTER ovld metallb)/default/etc/kubernetes
xc mkcdrom gobgp; xc start
# or
xc mkcdrom gobgp private-reg; xc start
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f $configd/metallb-config.yaml
kubectl apply -f $configd/mconnect.yaml
kubectl get pods -n metallb-system
kubectl get svc
# On a router vm;
gobgp neighbor
ip ro
mconnect -address 10.0.0.2:5001 -nconn 400
```

Static router an controller active only;
```
xc mkcdrom externalip private-reg; xc starts
configd=$($XCLUSTER ovld metallb)/default/etc/kubernetes
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f $configd/metallb-config.yaml
kubectl apply -f $configd/mconnect.yaml

# On vm-201;
mconnect -address 10.0.0.2:5001 -nconn 400
```


Helm installstion (install helm and start `tiller` as described in the
[kubernets ovelay](../kubernetes/README.md);

```
configd=$($XCLUSTER ovld metallb)/default/etc/kubernetes
xc mkcdrom metallb gobgp; xc start
helm install --name metallb stable/metallb
kubectl apply -f $configd/metallb-config-helm.yaml
```

You can start a private docker registry to avoid loading from the
internet every time or images can be pre-pulled for faster (and safer)
operation for instance in CI environment;

```
curl -L  https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml \
 > $($XCLUSTER ovld metallb)/default/etc/metallb.yaml
images make coredns nordixorg/mconnect:v1.2 \
 metallb/speaker:v0.7.3 metallb/controller:v0.7.3
xc mkcdrom metallb gobgp images; xc start
# On cluster;
images         # to check that the metallb images are pre-pulled
kubectl apply -f /etc/kubernetes/metallb-config.yaml
kubectl apply -f /etc/metallb.yaml
kubectl get pods -n metallb-system
kubectl apply -f /etc/kubernetes/mconnect.yaml
```


## Home-built pod

For internal experiments a local pod can be used Read the instructions
[contributing](https://metallb.universe.tf/community/#contributing).

Clone;
```
mkdir -p $GOPATH/src/github.com/danderson
cd $GOPATH/src/github.com/danderson
git clone git@github.com:Nordix/metallb.git
cd metallb
git remote add upstream git@github.com:danderson/metallb.git
git remote set-url --push upstream no_push
git remote -v
```

Sync;
```
git checkout master
# Or;
git checkout nordix-dev
git fetch upstream
git rebase upstream/master
git push
```

Build;
```
cd $GOPATH/src/github.com/danderson/metallb
go install github.com/danderson/metallb/speaker
go install github.com/danderson/metallb/controller
strip $GOPATH/bin/controller $GOPATH/bin/speaker
images mkimage --force --upload ./image
```

Update on new branch;
```
git checkout v0.7.4-nordix
git push --set-upstream origin v0.7.4-nordix
git tag v0.7.4-nordix-alpha2
git push origin v0.7.4-nordix-alpha2
```

Build on an old release;
```
mkdir -p $GOPATH/src/go.universe.tf
cd $GOPATH/src/go.universe.tf
git clone git@github.com:Nordix/metallb.git
cd metallb
git checkout v0.7.4-nordix-alpha2
go install ./controller/...
```


Ipv4;
```
xc mkcdrom metallb gobgp private-reg; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/metallb-config-internal.yaml
kubectl apply -f /etc/kubernetes/metallb.yaml
kubectl apply -f /etc/kubernetes/metallb-speaker.yaml
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl logs pod/...
kubectl get svc
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 400
# On router;
gobgp neighbor
ip ro
# Outside cluster;
mconnect -address 10.0.0.2:5001 -nconn 400
```

IPv6;
```
# Pre-pull
images make coredns metallb nordixorg/mconnect:v1.2
SETUP=ipv6 xc mkcdrom etcd coredns k8s-config metallb gobgp images; xc start
# Private reg
SETUP=ipv6 xc mkcdrom etcd coredns metallb gobgp private-reg k8s-config; xc start
# Outside cluster;
mconnect -address [1000::]:5001 -nconn 400
```


IP address sharing
------------------

Metallb supports that several services share the same `loadBalancerIP`
(VIP) (described
[here](https://metallb.universe.tf/usage/#ip-address-sharing)).

But the restriction for `ExternalTrafficPolicy: Local`; "the *exact
same selector" makes k8s distribure traffic to all sevices to all
pods.

