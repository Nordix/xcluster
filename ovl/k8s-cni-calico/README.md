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
xc mkcdrom k8s-cni-calico crio-test private-reg; xc starts
```

## Test

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
t=test-template
XOVLS="k8s-cni-calico private-reg" $($XCLUSTER ovld $t)/$t.sh test > $XCLUSTER_TMP/$t-test.log
```

## Doc

* https://docs.projectcalico.org/v3.8/networking/ipv6

* https://docs.projectcalico.org/v3.8/reference/felix/configuration

* https://docs.projectcalico.org/v3.8/getting-started/calicoctl/install
