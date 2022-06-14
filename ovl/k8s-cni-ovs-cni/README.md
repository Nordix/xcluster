# Xcluster/ovl - k8s-cni-ovs-cni

Use CNI-plugin [ovs-cni](https://github.com/k8snetworkplumbingwg/ovs-cni)
in `xcluster`.

**NOTE**: There seems to be no way to configure the default route for
PODs. This makes the `ovs-cni` unusable as a primary K8s cni-plugin.
This seems to be a "multus-only" cni-plugin.

## Usage

Prerequisite; build `ovs` as described in [ovl/ovs](../ovs).

```
images lreg_preload default
xcadmin k8s_test --cni=ovs-cni test-template start_empty > $log
```

It works to start but no default route is set in PODs.


## Installation

The installation is intended for `multus` rather than as a
primary K8s cni-plugin (since it can't be used as a primary K8s cni-plugin).

You have to create the OVS bridge as described in the
[demo](https://github.com/k8snetworkplumbingwg/ovs-cni/blob/main/docs/demo.md).
We use "Shared L2" on `eth1`.

A `/etc/cni/net.d/10-ovs.conf` is created (cni v1.0.0 is *not* supported).
The `host-local` ipam is configured.

The
[ovs-cni.yml](https://github.com/k8snetworkplumbingwg/ovs-cni/blob/main/examples/ovs-cni.yml)
manifest is installed, renamed and modified so it starts always.
The `Antrea` work-around for the `cri-o` bug is used.


## Test

```
ip netns add ns1
CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth2 CNI_PATH=/opt/cni/bin /opt/cni/bin/ovs < /etc/cni/net.d/99-ovscni.conf
```
