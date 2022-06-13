# Xcluster/ovl - netns

Multiple Network Namespaces (netns) and interconnect.

Keyword; netns, CNI-bridge, veth, unshare


## Usage

This ovl is intended to be used by other ovl's. Check the output from;
```
./default/bin/netns_test
```
for the provided functions.

Example;
```
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

#### CNI-bridge

To connect all netns to a bridge you may the
[CNI-bridge](https://www.cni.dev/plugins/current/main/bridge/) plugin.

This requires a cni-plugins release archive in $ARCHIVE or
$HOME/Downloads and the `ipu` utility from
[nfqlb](https://github.com/Nordix/nfqueue-loadbalancer/). A `nfqueue`
release dir can be specified in $NFQLBDIR.

```
export NFQLBDIR=/tmp/nfqlb-0.11.0
test -r $HOME/Downloads/cni-plugins-linux-amd64-v1.0.1.tgz && echo "CNI OK"
./netns.sh test bridge > $log
```

The output (json) from the `bridge` cni-plugin is stored in files on
`/tmp`. To get all assigned addresses do;

```
for a in $(cat /tmp/$(hostname)-ns* | jq -r .ips[].address); do
  echo $a
done
```
