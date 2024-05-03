# Xcluster ovl - K8s with Multus

Use [multus](https://github.com/k8snetworkplumbingwg/multus-cni) in a
Kubernetes xcluster.

**WARNING**: the `registry.nordix.org/cloud-native/multus-installer:3.9.2`
which is default will not be updated since no maintainer have access to
the `registry.nordix.org` registry. You should build an own image and
modify `multus-install.yaml` accordingly. (instruction below)

## Basic usage from another ovl

If the internal cni is used (or "k8s-cni-bridge"), then just include
the `multus` ovl (this ovl).

If another cni-plugin is used (one that is loaded with an image), then
use the `Multus Installer` described below.


## Multus Installer

The Multus [Quickstart Installation
Guide](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart-installation-guide)
assumes a "thick" installation. To allow the "thin" installation
a `multus-installer` image is provided. It
can be applied without modifications in most cases, e.g. in a
[KinD](https://kind.sigs.k8s.io/) cluster;

```
kubectl apply -f https://raw.githubusercontent.com/Nordix/xcluster/master/ovl/multus/multus-install.yaml
```

The structure in `/etc/cni/` is altered. Example from KinD:

```
# Before:
/etc/cni/net.d/10-kindnet.conflist
# After;
/etc/cni/net.d/multus.d/multus.kubeconfig
/etc/cni/net.d/10-multus.conf
/etc/cni/multus/net.d/kindnet.conflist
```

The original CNI-plugin config is moved to `/etc/cni/multus/net.d/`,
but *it is not altered*. CNI-plugins are installed in `/opt/cni/bin/`
and a Network Attachment Definition (NAD) is created for the original
K8s CNI-plugin.

Tested with the following K8s main CNI-plugins;

* kindnet
* flannel
* calico
* cilium (with `cni-exclusive: "false"`)
* antrea
* xcluster-cni

The test use a `Deployment` with an extra (ipvlan) interface and
performs a ping-test using the extra interface. Example:

```
./multus.sh test --cni=kindnet
```

By default `Cilium` restores itself, and disables `multus`:
```
# ls /etc/cni/net.d/
05-cilium.conflist 10-multus.conf.cilium_bak  multus.d/  whereabouts.d/
```
To prevent this, you _must_ set `cni-exclusive: "false"`.


### Build

Download multus and the cni-plugins to $HOME/Downloads or $ARCHIVE.

Get versions;
```
./multus.sh version
$($XCLUSTER ovld cni-plugins)/cni-plugins.sh version
```

Build the image;
```
./multus.sh mkimage --tag=docker.io/(you)/multus-installer
```
The version will be the multus version and "latest".

Some extra cni-plugins can be included:

Whereabouts is taken from `whereabouts-amd64` (a release asset) in
$HOME/Downloads or $ARCHIVE (if it exist).

Sriov-cni can be cloned and built locally;
```
export SRIOV_DIR=/path/to/your/sriov-cni
git clone https://github.com/k8snetworkplumbingwg/sriov-cni.git $SRIOV_DIR
cd $SRIOV_DIR
make
cdo multus
./image/tar - | tar t     # Check if whereabouts and sriov are included
```



### Life cycle

The installation is done in an initContainer and then the POD is
paused (the main container image is "pause"). Installation is done
once, so you *may* remove the `multus-installer` after installation.
The version of the `multus-installer` image is the same as the version
of Multus it has installed.

The logs shows the install process;
```
> kubectl logs -n kube-system multus-install-q9cjh -c multus-install
Installing cni-bin:v1.1.1 and multus:3.9.2 in /opt/cni/bin
multus-installer.sh: Installing Multus...
multus-installer.sh: Generate; /etc/cni/net.d/multus.d/multus.kubeconfig
multus-installer.sh: Current net config; /etc/cni/net.d/10-kindnet.conflist, net=kindnet
networkattachmentdefinition.k8s.cni.cncf.io/kindnet created
multus-installer.sh: Multus enabled
multus-installer.sh: Multus installed
```



## Test in xcluster

The [multinet](../network-topology/README.md#multinet)
network-topology is used which provides additional networks for the
cluster VMs as eth2,3,4.


```
./multus.sh                    # help printout
./multus.sh test               # Default test with ipvlan and whereabouts ipam
./multus.sh test --cni=flannel # Same, but with flannel cni-plugin
```



## References

In no particular order or importance.

* https://vincent.bernat.ch/en/blog/2017-linux-bridge-isolation
