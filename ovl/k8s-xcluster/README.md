# Xcluster ovl - k8s-xcluster

- Kubernetes in `xcluster` with downloaded CNI-plugin.

This is and updated version of "ovl/kubernetes". It isolates the
"master" in a similar way as k3s;

<img src="k8s-xcluster-vms.svg" alt="Figure of VMs" width="80%" />

The normal "hd-k8s-xcluster.img" does not include a CNI-plugin. A
CNI-plugin ovl should be used, e.g. `k8s-cni-xcluster`.


## Usage

Start using the test system (prefered);
```
log=/tmp/$USER-xcluster.log
# Dual-stack with xcluster-cni;
./xcadmin.sh k8s_test --cni=xcluster test-template start > $log
# Ipv4;
./xcadmin.sh k8s_test --cni=flannel --mode=ipv4 test-template start > $log
# Ipv6;
./xcadmin.sh k8s_test --cni=calico --mode=ipv6 test-template start > $log
```

Manual start;
```
# Dual-stack (default);
xc mkcdrom k8s-cni-xcluster
xc starts --image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
# Ipv4;
SETUP=ipv4 xc mkcdrom k8s-xcluster k8s-cni-flannel
xc starts --image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
# Ipv6;
SETUP=ipv6 xc mkcdrom k8s-xcluster k8s-cni-calico
xc starts --image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
```


## Test

```
log=/tmp/$USER-xcluster.log
./xcadmin.sh k8s_test --cni=xcluster test-template > $log
./xcadmin.sh k8s_test --cni=weave test-template basic4 > $log
```

## CNI-plugin and private registry

If a private local registry ([ovl/private-reg](../private-reg)) is
used (and it *really* should) you must make sure that the images
needed by the CNI-plugin is cached in the private local registry.

```
images lreg_missingimages k8s-cni-calico
# If there are missing images, cache them with;
images lreg_cache ...
```

