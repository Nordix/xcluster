# Xcluster - ovl/k8s-cni-calico

Use [project calico](https://www.projectcalico.org/) in `xcluster`.

## Usage

Pre-load the local registry;
```
ver=v3.8.2
images lreg_cache docker.io/calico/cni:$ver
images lreg_cache docker.io/calico/node:$ver
images lreg_cache docker.io/calico/kube-controllers:$ver
images lreg_cache docker.io/calico/pod2daemon-flexvol:$ver
```

Start;
```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export __nvm=5
# Ipv4-only, ipv6-only, dual-stack;
SETUP=ipv4 xc mkcdrom k8s-xcluster k8s-cni-calico private-reg; xc starts
SETUP=ipv6 xc mkcdrom k8s-xcluster k8s-cni-calico private-reg; xc starts
xc mkcdrom k8s-cni-calico private-reg; xc starts
```

## Test

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
t=test-template
XOVLS="k8s-cni-calico private-reg" $($XCLUSTER ovld $t)/$t.sh test > $XCLUSTER_TMP/$t-test.log
```
## Build

Build an image with dual-stack and calico pre-pulled;
```
ver=v3.8.2
docker pull calico/cni:$ver
docker pull calico/node:$ver
docker pull calico/kube-controllers:$ver
docker pull calico/pod2daemon-flexvol:$ver
images make coredns nordixorg/mconnect:v1.2 library/alpine:3.8 \
  calico/cni:$ver calico/node:$ver calico/kube-controllers:$ver calico/pod2daemon-flexvol:$ver
#export KUBERNETESD=$ARCHIVE/kubernetes/server/bin
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster-cni-calico.img
cp $XCLUSTER_WORKSPACE/xcluster/hd.img $__image
xc ximage xnet etcd iptools k8s-xcluster mconnect images coredns k8s-cni-calico
# Test;
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
t=test-template
$($XCLUSTER ovld $t)/$t.sh test basic_dual > /dev/null
```

### Install calicoctl

```
ver=v3.8.2
curl -L \
 https://github.com/projectcalico/calicoctl/releases/download/$ver/calicoctl \
 > $GOPATH/bin/calicoctl
chmod a+x $GOPATH/bin/calicoctl
```

## Doc

* https://docs.projectcalico.org/v3.8/networking/ipv6

* https://docs.projectcalico.org/v3.8/reference/felix/configuration

* https://docs.projectcalico.org/v3.8/getting-started/calicoctl/install
