# Xcluster ovl - K8s with Multus

Use [multus](https://github.com/k8snetworkplumbingwg/multus-cni) in a
Kubernetes xcluster. The
[whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts)
IPAM is used for the `ipvlan` example only since it doesn't support dual-stack.


## Install

Download multus and the cni-plugins to $HOME/Downloads or $ARCHIVE.

* multus-cni_3.8_linux_amd64.tar.gz
* cni-plugins-linux-amd64-v1.0.1.tgz

Whereabouts must be cloned and built locally;
```
export WHEREABOUTS_DIR=/path/to/your/whereabouts
cd $(dirname $WHEREABOUTS_DIR)
git clone --depth 1 https://github.com/k8snetworkplumbingwg/whereabouts.git
cd $WHEREABOUTS_DIR
./hack/build-go.sh
```

## Usage

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
SETUP=None WHEREABOUTS_DIR=/ $ovl_multus/tar - | tar -C $tmp -x
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
