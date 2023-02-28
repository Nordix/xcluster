# Xcluster/ovl - lldp

Experiments with lldpd.

The [bridge](../network-topology#bridge) network topology is often used,
but [xnet](../network-topology/#xnet) can also be used.

<img src="../network-topology/bridge.svg" width="60%" />

## Manual basic test

Requirement; `xcluster` must be started in an own [netns](
https://github.com/Nordix/xcluster/blob/master/doc/netns.md).

```
cdo lldp
./lldp.sh test start_empty > $log
# on vm-201 (VMs show up as neighbors)
lldpcli show ne
# on vm-221 (no neighbors)
lldpcli show ne
```