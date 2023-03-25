# Xcluster/ovl - lldp

Experiments with Link Layer Discovery Protocol (LLDP)

The [bridge](../network-topology#bridge) network topology is often used,
but [xnet](../network-topology/#xnet) can also be used.

<img src="../network-topology/bridge.svg" width="60%" />

The bridges on your host must [forward LLDP packets](
https://interestingtraffic.nl/2017/11/21/an-oddly-specific-post-about-group_fwd_mask/).
This is setup by default in `xcluster`.


## Test

Requirement; `xcluster` must be started in an own [netns](
https://github.com/Nordix/xcluster/blob/master/doc/netns.md).

```
./lldp.sh    # Help printout
./lldp.sh test neighbors > $log
```

Manual basic tests:
```
cdo lldp
./lldp.sh test start_empty > $log
# on vm-201 (VMs show up as neighbors)
lldpcli show ne
# on vm-221 (no neighbors)
lldpcli show ne
```
