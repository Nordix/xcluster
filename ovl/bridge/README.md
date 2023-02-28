# Xcluster/ovl - bridge

Experiments with nftables bridge family.

The [bridge](../network-topology#bridge) network topology is used.

<img src="../network-topology/bridge.svg" width="60%" />

## Pre-requisites
The following versions are a MUST to run the broute test successfully.
linux-6.3 (with CONFIG_NFT_BRIDGE_META=y/m)
libnfntl-1.2.5
nftables-v1.0.7

## Manual basic test

Requirement; `xcluster` must be started in an own [netns](
https://github.com/Nordix/xcluster/blob/master/doc/netns.md).

LLDP traffic is used to test if packet is bridged by "router" vm-201
from the VMs to the testers.

```
cdo bridge
./bridge.sh test start_empty > $log
# on vm-201 (VMs show up as neighbors)
lldpcli show ne
# on vm-221 (no neighbors)
lldpcli show ne

./bridge.sh test start_empty > $log
# on vm-201 (remove broute)
nft flush ruleset
# on vm-221 (VMs show up as neighbors)
lldpcli show ne
```