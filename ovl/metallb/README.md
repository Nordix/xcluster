# Xcluster overlay - metallb

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


The main focus in this ovl is metallb development so a local built
version is most often used.


## Official release usage

A local built metallb is normally used for development, but an
official release can also be used. A [private
registry](../private-reg) is strongly recommended but not really
necessary.

Pre-load the private registry;
```
ver=v0.8.2
images lreg_cache docker.io/metallb/speaker:$ver
images lreg_cache docker.io/metallb/controller:$ver
```

Ipv4 with BGP;
```
xc mkcdrom metallb gobgp private-reg; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/metallb-orig.yaml
kubectl apply -f /etc/kubernetes/metallb-config.yaml
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods -A
kubectl get svc
# On vm-201 (router);
gobgp neighbor
ip ro
mconnect -address 10.0.0.0:5001 -nconn 400
```

Ipv6 with L2 (BGP is not supported for IPv6);
```
SETUP=ipv6 xc mkcdrom metallb private-reg k8s-config; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/metallb-orig.yaml
kubectl apply -f /etc/kubernetes/metallb-config-ipv6-L2.yaml
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods -A
kubectl get svc
# On vm-201 (router);
ip -6 route add 1000::/124 dev eth1
mconnect -address [1000::]:5001 -nconn 100
```

## Build a local image

For internal experiments a local pod is used, read the instructions
[contributing](https://metallb.universe.tf/community/#contributing).

For local development a [private registry](../private-reg) is *required*.

Clone;
```
git_project=git@github.com:Your-project-here
mkdir -p $GOPATH/src/github.com/danderson
cd $GOPATH/src/github.com/danderson
git clone $git_project/metallb.git
cd metallb
git remote add upstream git@github.com:danderson/metallb.git
git remote set-url --push upstream no_push
git remote -v
```

Sync;
```
cd $GOPATH/src/github.com/danderson/metallb
git checkout master
git fetch upstream
git rebase upstream/main
git push
```

Apply a PR on the local clone (optional)
```
pr=466
cd $GOPATH/src/github.com/danderson/metallb
#(sync)
git checkout -b pr-$pr
curl -sL https://github.com/danderson/metallb/pull/$pr.patch | patch -p1
```

Build;
```
cd $GOPATH/src/github.com/danderson/metallb
git clean -dxf
export GO111MODULE=on
go install ./controller
go install ./speaker
cdo metallb
images mkimage --force --tag=metallb/controller:latest --upload ./image
images mkimage --force --tag=metallb/speaker:latest --upload ./speaker
```


## Usage local image

Local image with L2 and dual-stack (assumes PR #466);
```
xc mkcdrom metallb k8s-dual-stack private-reg; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/metallb-config-dual-stack.yaml
kubectl apply -f /etc/kubernetes/metallb.yaml
kubectl apply -f /etc/kubernetes/mconnect-dual-stack.yaml
kubectl get svc
kubectl apply -f /etc/kubernetes/metallb-speaker.yaml
# On a router;
ip ro add 10.0.0.0/28 dev eth1
ip -6 ro add 1000::/124 dev eth1
mconnect -address 10.0.0.0:5001 -nconn 100
mconnect -address [1000::]:5001 -nconn 100
```

## Test

```
cdo metallb
./metallb.sh test > $XCLUSTER_TMP/metallb-test.log
```



## IP address sharing

Metallb supports that several services share the same `loadBalancerIP`
(VIP) (described
[here](https://metallb.universe.tf/usage/#ip-address-sharing)).

But the restriction for `ExternalTrafficPolicy: Local`; "the *exact
same selector" makes k8s distribure traffic to all sevices to all
pods.

