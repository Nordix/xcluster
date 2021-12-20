# Xcluster/ovl - ovs

Open vSwitch is used in the xcluster VMs, not on the host as a VM-VM
network (as the image on https://www.openvswitch.org/ shows).


## Usage

Test;
```
./ovs.sh test > $log
```

Manual tests;
```
./ovs.sh test start_base > $log
# On a VM;
ovs-vsctl -V
grep -v JSON /etc/openvswitch/conf.db | jq
ovs-vsctl add-br br0
ovs-appctl dpctl/show
#ovs-vsctl add-br br1 -- set Bridge br1 datapath_type=netdev
ovs-appctl dpif/show-dp-features br0
ovs-vsctl add-port br0 eth1
ovs-vsctl add-port br0 vlan10 tag=10 -- set Interface vlan10 type=internal
i=$(hostname | cut -d- -f2 | sed -re 's,^0+,,')
ip link set up dev vlan10
ip addr add 3000::$i/120 dev vlan10
ping -c1 3000::$i
```


## Build

```
# Clone;
mkdir -p $GOPATH/src/github.com/openvswitch
cd $GOPATH/src/github.com/openvswitch
git clone --depth=1 https://github.com/openvswitch/ovs.git
# Build;
cdo ovs
eval $(./ovs.sh env | grep SYSD)
cd $GOPATH/src/github.com/openvswitch/ovs
./boot.sh
./configure
make -j$(nproc)
make DESTDIR=$SYSD install
```

### Build with XDP support

[afxdp doc](https://docs.openvswitch.org/en/latest/intro/install/afxdp/)

```
cdo xdp
./xdp.sh libbpf_build
cdo ovs
eval $(./ovs.sh env | grep SYSD)
eval $(xc env | grep -e '__kobj')
bpflibd=$(readlink -f $__kobj/source)/tools/lib/bpf/build/usr
cd $GOPATH/src/github.com/openvswitch/ovs
LDFLAGS=-L$bpflibd/lib64 CPPFLAGS=-I$bpflibd/include ./configure --enable-afxdp
make -j$(nproc)
make DESTDIR=$SYSD install
```

## Links

In no particular order or usefulness.

* https://www.openvswitch.org/
* https://github.com/openvswitch/ovs/
* https://kumul.us/switches-ovs-vs-linux-bridge-simplicity-rules/
* https://www.plixer.com/blog/openflow-vs-netflow/
* https://www.linuxtechi.com/install-use-openvswitch-kvm-centos-7-rhel-7/
* https://arthurchiao.art/blog/ovs-deep-dive-6-internal-port/
* https://arthurchiao.art/blog/ovs-deep-dive-1-vswitchd/

