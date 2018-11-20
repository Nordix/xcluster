# Xcluster ovl - K8s with Multus

Use [multus](https://github.com/intel/multus-cni) in a Kubernetes xcluster.


## Install

The binary release contains only one binary;
```
> tar tf ~/Downloads/multus-cni_v3.1_linux_amd64.tar.gz
multus-cni_v3.1_linux_amd64/multus-cni
multus-cni_v3.1_linux_amd64/README.md
multus-cni_v3.1_linux_amd64/LICENSE
tar -O -xf ~/Downloads/multus-cni_v3.1_linux_amd64.tar.gz \
 multus-cni_v3.1_linux_amd64/multus-cni > $ARCHIVE/multus-cni
chmod a+x $ARCHIVE/multus-cni
```

## Usage

```
# Once;
xc br_setup 3
xc br_setup 4
xc br_setup 5
# then;
xc mkcdrom multinet multus private-reg; xc start --nets-vm=0,1,3,4,5
# On cluster
kubectl apply -f /etc/kubernetes/multus-crd.yml
kubectl apply -f /etc/kubernetes/multus-crd-bridge.yaml
kubectl apply -f /etc/kubernetes/multus-crd-ipvlan.yaml
kubectl apply -f /etc/kubernetes/multus-crd-macvlan.yaml
kubectl apply -f /etc/kubernetes/multus-crd-host-device.yaml
kubectl apply -f /etc/kubernetes/multus-alpine.yaml
kubectl get pods -o wide
kubectl exec -it ... sh
```

In the `alpine` pod to a `ifconfig -a` and check the interfaces;

 * net1 - ipvlan (master eth2)
 * net2 - macvlan (master eth3)
 * net3 - host-device (eth4)


## The ipam host-local problem

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
to get a node unique index. The final `node-local` script in all it's
glory;

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

