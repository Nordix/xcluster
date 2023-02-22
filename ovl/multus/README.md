# Xcluster ovl - K8s with Multus

Use [multus](https://github.com/k8snetworkplumbingwg/multus-cni) in a
Kubernetes xcluster. The
[whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts)
IPAM is used for the `ipvlan` example only since it doesn't support dual-stack.


## Multus Installer

The Multus [Quickstart Installation
Guide](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart-installation-guide)
can't be applied without tweaks. For instance, it assumes flannel. To
overcome the shortcomings a `multus-installer` image is provided. It
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

Tested (just simple deployment) with the following K8s base CNI-plugins;

* kindnet
* flannel
* calico
* cilium
* antrea



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


### Build

Download multus and the cni-plugins to $HOME/Downloads or $ARCHIVE.

Get versions;
```
./multus.sh version
$($XCLUSTER ovld cni-plugins)/cni-plugins.sh version
```

Whereabouts and sriov-cni must be cloned and built locally;
```
export WHEREABOUTS_DIR=/path/to/your/whereabouts
git clone --depth 1 https://github.com/k8snetworkplumbingwg/whereabouts.git $WHEREABOUTS_DIR
cd $WHEREABOUTS_DIR
./hack/build-go.sh
export SRIOV_DIR=/path/to/your/sriov-cni
git clone https://github.com/k8snetworkplumbingwg/sriov-cni.git $SRIOV_DIR
cd $SRIOV_DIR
make
./tar - | tar t     # Check that whereabouts and sriov are included
```

Build the image;
```
./multus.sh mkimage
```


## Test in xcluster

The [multinet](../network-topology/README.md#multinet)
network-topology is used which provides additional networks for the
cluster VMs as eth2,3,4.

```
log=/tmp/$USER/xcluster.log
xcadmin k8s_test multus basic > $log
# Manual testing;
xcadmin k8s_test multus start > $log
```

In the `alpine` pod to a `ifconfig -a` and check the interfaces;

 * net1 - ipvlan (master eth2, only IPv6 because of IPAM whereabouts)
 * net2 - macvlan (master eth3)
 * net3 - host-device (eth4)


## Usage from another ovl

```
ovl_multus=$($XCLUSTER ovld multus)
$ovl_multus/tar - | tar -C $tmp -x
```

## IPAM whereabouts

IPAM [whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts)
does not support dual-stack so it is of limited use.


## IPAM node-local

If the ip ranges are defined in the CRD object all pods will get the
same addresses on different nodes. To fix this a "glue" ipam is
invented; `node-local`. The `node-local` is implemented as a shell
script with `host-local` as a beckend.

First an example from the `host-local` documentation;

```
hostlocal=$GOPATH/src/github.com/containernetworking/plugins/bin/host-local
cat <<EOF | CNI_COMMAND=ADD CNI_CONTAINERID=example CNI_NETNS=/dev/null CNI_IFNAME=dummy0 CNI_PATH=. $hostlocal
{ "cniVersion": "0.3.1",
  "name": "examplenet",
  "ipam": {
    "type": "host-local",
	"ranges": [
	  [{"subnet": "203.0.113.0/24"}], [{"subnet": "2001:db8:1::/64"}]
	],
    "dataDir": "/tmp/cni-example"
  }
}
EOF
```

In `xcluster` the nodes has names like `vm-004` so we use the hostname
to get a node unique index. The final `node-local` script;


```
#! /bin/sh
i=$(hostname | cut -d- -f2 | sed -re 's,^0+,,')
cfg=$(jq -r .ipam.cfg)
d=/etc/cni/node-local
sed -e "s,\.x,\.$i," < $d/$cfg | /opt/cni/bin/host-local
```

Place different configs for the new `node-local` ipam in
"/etc/cni/node-local". This is the "default";

```
{
  "cniVersion": "0.3.1",
  "name": "default",
  "ipam": {
     "type": "host-local",
     "ranges": [
       [
          {
            "subnet": "11.0.x.0/24",
            "gateway": "11.0.x.1"
          }
       ]
     ]
  }
}
```

The `.x` string is replaced by `node-local` to the node unique id.


## Multus-service

[Multus-service](https://github.com/k8snetworkplumbingwg/multus-service)
implements ClusterIP services for multus networks. External traffic is
not supported.

Clone and build;
```
MSERVICE_DIR=/path/to/your/multus-service
cd $(dirname $MSERVICE_DIR)
git clone https://github.com/k8snetworkplumbingwg/multus-service.git
cd $MSERVICE_DIR
go install ./cmd/...
ls -l $GOPATH/bin/multus-*
```

```
log=/tmp/$USER/xcluster.log
xcadmin k8s_test multus start_server > $log
# On a node
kubectl apply -f /etc/kubernetes/multus-service/svc.yaml
# In a POD
nc -w 1 -v multus-service 5001
apk add iptables ip6tables
iptables -t nat -L -nv
```


## References

In no particular order or importance.

* https://vincent.bernat.ch/en/blog/2017-linux-bridge-isolation
