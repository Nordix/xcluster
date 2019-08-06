# Xcluster ovl - k8s-dual-stack

Ovl for the up-coming support for dual-stack in Kubernetes.

## Usage

For testing just use the up-loaded image;
```
curl -L https://artifactory.nordix.org/artifactory/cloud-native/xcluster/images/hd-k8s-pr73977.img.xz | xz -d > $__image
xc mkcdrom; xc starts
vm 1
# On cluster;
kubectl get node vm-002 -o json | jq .spec
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
p=alpine-deployment-568f6756d7-....
kubectl get pod $p -o json | jq .status.podIPs
kubectl exec $p ifconfig
```

Local Start;
```
xc mkcdrom k8s-dual-stack; xc starts
# On cluster;
kubectl get node vm-002 -o json | jq .spec
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
p=alpine-deployment-568f6756d7-....
kubectl get pod $p -o json | jq .status.podIPs
kubectl exec $p ifconfig
```

Start with proxy-mode=script;
```
rm $GOPATH/src/k8s.io/kubernetes
ln -s kubernetes-orig $GOPATH/src/k8s.io/kubernetes
xc mkcdrom k8s-dual-stack script-mode; xc starts
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

Rebuild image and regression-test;
```
cp $XCLUSTER_WORKSPACE/xcluster/hd.img $__image
xc ximage xnet etcd iptools kubernetes mconnect images coredns private-reg
xc mkcdrom; xc starts
kubectl version    # Check the git commit
./test/xctest.sh test --xovl=private-reg \
  k8s k8s_ipv6 k8s_metallb k8s_kube_router > $XCLUSTER_TMP/xtest.log
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
grep syncProxyRules /var/log/kube-proxy.log
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

