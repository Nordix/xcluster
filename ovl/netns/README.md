# Xcluster/ovl - netns

Multiple Network Namespaces (netns) and interconnect. The Network
Namespaces are called "PODs" in this document even though K8s is
not used.

Keyword; netns, CNI-bridge, veth, unshare

<img src="netns.svg" width="70%" />

This is the most common setup for CNI-plugins. The "bridge" is not
necessarily a Linux bridge, it may be something else like `OVS`.

## Usage

This ovl is intended to be used by other ovl's. Check the output from;
```
./default/bin/netns_test
```
for the provided functions.

Example;
```
./netns.sh test start > $log
# On a VM;
# Create 10 netns'es;
netns_test create 1 10
# Check them;
ip netns
# Execute something in a netns;
netns_test exec 3 hostname
```

The `netns_test exec` will set the hostname name space (uts) so the
hostname will become something like "vm-001-ns03". The `ip netns exec`
will not set the `utsns` so you will see the node hostname.

Environment variables;
```
export xcluster_PODIF=eth0
export xcluster_PREFIX=1000::1
```

### Prerequisite

All address function requires the `ipu` utility from
[nfqlb](https://github.com/Nordix/nfqueue-loadbalancer/). A `nfqueue`
release dir can be specified in $NFQLBDIR.

```
export NFQLBDIR=$HOME/tmp/nfqlb-1.0.0
```

## Test

The tests uses environment variables to set the number of PODs per
node and the address template.

```
# The defaults;
export xcluster_NPODS=4
export xcluster_ADRTEMPLATE=172.16.0.0/16/24
```


#### CNI-bridge

To connect all netns to a bridge you *may* use the
[CNI-bridge](https://www.cni.dev/plugins/current/main/bridge/) plugin.

This requires a cni-plugins release archive in $ARCHIVE or
$HOME/Downloads.

Test;
```
test -r $HOME/Downloads/cni-plugins-linux-amd64-v1.0.1.tgz && echo "CNI OK"
./netns.sh test cni_bridge > $log
```

The output (json) from the `bridge` cni-plugin is stored in files on
`/tmp`. To get all assigned addresses do;

```
cat /tmp/$(hostname)-ns* | jq -r .ips[].address | cut -d/ -f1
```
