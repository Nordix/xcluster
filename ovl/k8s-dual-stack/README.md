# Xcluster ovl - k8s-dual-stack

Ovl for the up-coming support for dual-stack in Kubernetes.

## Usage

Use xcluster v2.1 and the default image.

```
xc mkcdrom k8s-dual-stack; xc starts
# On cluster;
kubectl get node vm-002 -o json | jq .spec
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
# Check dual addresses on pods
p=$(kubectl -o json get pods -l 'app=alpine' | jq -r .items[0].metadata.name)
kubectl get pod $p -o json | jq .status.podIPs
kubectl exec $p ifconfig
# Create services
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl apply -f /etc/kubernetes/mconnect-svc-ipv6.yaml
kubectl get svc
# Test traffic to ipv4 and ipv6 ClisterIP's
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 100
mconnect -address mconnect-ipv6.default.svc.xcluster:5001 -nconn 100
nslookup mconnect-ipv6.default.svc.xcluster
```


## Build

Apply PR and build;
```
cd $GOPATH/src/k8s.io/kubernetes
# Re-base
git checkout nordix-dev
git fetch upstream
git rebase upstream/master
git push
# Apply the patch on a new branch
b=dual-stack
git checkout -b $b
curl -L https://github.com/kubernetes/kubernetes/pull/79386.patch | patch -p1
curl -L https://github.com/kubernetes/kubernetes/pull/79576.patch | patch -p1
find . -name '*.rej'  # If any, see below
rm $(find . -name '*.orig')
git commit -m "Applied $b" -a
# Build
for n in kube-controller-manager kube-scheduler kube-apiserver \
  kube-proxy kubectl kubelet; do
    make WHAT=cmd/$n
done
strip _output/bin/*
```

In case of rejects;
```
f=./pkg/controller/route/route_controller.go
diff -u $f.orig $f > /tmp/working.diff
git log -4 $f
# Back-off to a commit you think works
git checkout 5c9f4d9dc67b28fb31fd95f88448c09150a4cbfb $f
patch -p1 < /tmp/working.diff
patch -p0 < $f.rej
rm $(find . -name '*.rej')
```

### Build from a development branch

```
# Save the original and clone the development branch
cd $GOPATH/src/k8s.io
mv kubernetes kubernetes-orig
git clone --depth 1 -b dualstack-phase2-kubeproxy git@github.com:vllry/kubernetes.git kubernetes-vllry
git clone --depth 1 -b phase2-dualstack git@github.com:khenidak/kubernetes.git kubernetes-khenidak
for n in kube-controller-manager kube-scheduler kube-apiserver \
  kube-proxy kubectl kubelet; do
    make WHAT=cmd/$n
done
strip _output/bin/*
```

### Update and re-run

```
cd $GOPATH/src/k8s.io/kubernetes
make WHAT=cmd/kube-proxy
#
xc mkcdrom k8s-dual-stack kube-proxy; xc starts
```

Test;
```
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl apply -f /etc/kubernetes/mconnect-svc-ipv6.yaml
kubectl get svc
ip -4 addr show dev kube-ipvs0
ip -6 addr show dev kube-ipvs0
node-util update_routes --dry-run --log-file=/dev/tty
kubectl -o json get nodes | jq '.items[].spec.podCIDRs'
mconnect -address <<address-here>>:5001 -nconn 100
```

#### The BoundedFrequencyRunner

```
gdoc k8s.io/kubernetes/pkg/util/async
grep minSyncPeriod /var/log/kube-proxy.log
grep "Loop running" /var/log/kube-proxy.log
grep SyncLoop /var/log/kube-proxy.log
```


## Ipam

For dual-stack the
[ipam-node-local](https://github.com/Nordix/ipam-node-local) is used.

