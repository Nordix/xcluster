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
./xcadmin.sh k8s_test --cni=xcluster test-template start > $log
```

Manual start;
```
export __
eval $($XCLUSTER env | grep XCLUSTER_HOME)
# Dual-stack (default);
xc mkcdrom k8s-cni-xcluster
xc starts --image=$XCLUSTER_HOME/hd-k8s-xcluster.img
```

### Use kube-proxy in iptables mode

The `ipvs` mode is used by default. To use `iptables` mode do;
```
export xcluster_PROXY_MODE=iptables
```
before test or start.


## Test

```
log=/tmp/$USER-xcluster.log
./xcadmin.sh k8s_test --cni=xcluster test-template > $log
```

## CNI-plugin and private registry

If a private local registry ([ovl/private-reg](../private-reg)) is
used (and it *really* should) you must make sure that the images
needed by the CNI-plugin is cached in the private local registry.

```
images lreg_preload k8s-cni-calico
```

