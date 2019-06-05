# Xcluster overlay - k8s-config

Ipv6 configuration for Kubernetes.

## Usage

Assuming a k8s `xcluster` image;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip; xc start
```

## Dual-stack

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


Apply PR and build;
```
cd $GOPATH/src/k8s.io/kubernetes
# Re-base
git checkout nordix-dev
git fetch upstream
git rebase upstream/master
git push
# Apply the patch on a new branch
b=$USER-pr-73977
git checkout -b $b
curl -L https://github.com/kubernetes/kubernetes/pull/73977.patch | patch -p1
find . -name '*.rej'  # If any, see below
rm $(find . -name '*.orig')
git commit -m "Applied pr-73977" -a
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

Start;
```
SETUP=dual-stack xc mkcdrom k8s-config; xc starts
# On cluster;
kubectl get node vm-002 -o json | jq .spec
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
p=alpine-deployment-568f6756d7-....
kubectl get pod $p -o json | jq .status.podIPs
kubectl exec $p ifconfig
```

Test ipam;
```
# On cluster;
CNI_COMMAND=ADD CNI_CONTAINERID=example CNI_NETNS=/dev/null \
 CNI_IFNAME=dummy0 CNI_PATH=. /opt/cni/bin/node-local < /etc/cni/net.d/cni.conf
```
