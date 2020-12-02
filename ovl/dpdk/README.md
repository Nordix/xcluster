# Xcluster/ovl - dpdk

Run DPDK in xcluster.

## Links

May or may not be useful, in no particular order;

* https://doc.dpdk.org/guides/nics/virtio.html
* https://wiki.qemu.org/Features/VirtioVhostUser
* https://doc.dpdk.org/guides-2.0/sample_app_ug/vhost.html
* https://www.redhat.com/en/blog/hands-vhost-user-warm-welcome-dpdk
* https://doc.dpdk.org/guides/prog_guide/kernel_nic_interface.html#kni
* https://doc.dpdk.org/guides/tools/devbind.html
* https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html
* https://dpdk-guide.gitlab.io/dpdk-guide/setup/binding.html CONFIG_VFIO_NOIOMMU=y
* https://doc.dpdk.org/guides/sample_app_ug/l2_forward_real_virtual.html


## Usage

A dpdk built for an xcluster kernel must be used. This is described in
the "Build" chapter below. But for the normal user a pre-packed
ovl/dpdk and kernel can be downloaded.

Prepare;
```
cdo dpdk
. ./Envsettings    # (use kernel linux-5.8.1)
./dpdk.sh download_cache
./dpdk.sh download_kernel
```

Then;

```
#sudo apt install -y hugeadm # (if needed)
cdo dpdk
. ./Envsettings
./dpdk.sh test start > $log
# On vm 201
modprobe igb_uio
modprobe rte_kni
dpdk-testpmd -l 0-1 -n 2 --vdev=eth_af_packet0,iface=eth2 -- \
  -i --total-num-mbufs=16384
# Or
dpdk-testpmd -l 0-1 -n 2 --vdev=net_pcap0,iface=eth2 \
  --huge-dir=/dev/hugepages -- -i --total-num-mbufs=16384
# Or
dpdk-l2fwd -l 0-1 -n 2 --vdev=eth_af_packet0,iface=eth2 \
  --vdev=eth_af_packet1,iface=eth1 --huge-dir=/dev/hugepages -- -p 3
```


## Build

The LTS (Long Term Stable) version is used;

```
cdo dpdk
. ./Envsettings
./dpdk.sh env | grep -E 'dpdk_ver|kver'
__dpdk_ver='19.11.5'
__kver='linux-5.8.1'
```

The current version (19.11.5) does not build with linux-5.9.1 which is
the current default for xcluster so the kernel version is set to linux-5.8.1.

To build dpdk a locally built kernel must be used;

```
cdo dpdk
. ./Envsettings    # (use kernel linux-5.8.1)
curl -L https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.8.1.tar.xz > $ARCHIVE/linux-5.8.1.tar.xz
mkdir -p $HOME/bin $HOME/tmp/linux
xc kernel_build
```

Kernel configs to check (already set in xcluster);
```
> Device Drivers > Userspace I/O drivers > Generic driver...
> Device Drivers > PCI support > Message Signaled Interrupts (MSI and MSI-X)
```

Dpdk build uses meson/ninja so these tools may have to be
installed. Then build;

```
#sudo apt install -y meson
./dpdk.sh install_meson
./dpdk.sh download
./dpdk.sh unpack
./dpdk.sh build
```

### Build older dpdk versions

DPDK is kernel dependent so an older kernel must be used. Older dpdk
uses an older SDK so `dpdk.sh make` must be used.

```
cdo dpdk
export __dpdk_ver=17.11.10
export __kver=linux-5.4.35
. ./Envsettings
# Download and build the kernel if necessary
./dpdk.sh download
./dpdk.sh unpack
./dpdk.sh make
```


Remember to remove the cached ovl/dpdk if you want to use your local build.


## Build own applications

As part of the build dpdk is installed and the SDK can be used to
build your own dpdk programs. An example `Makefile` is provided that
builds some dpdk examples;

```
cdo dpdk
. ./Envsettings
eval $(./dpdk.sh env | grep __dpdk_src)
export __dpdk_src
make -f src/Makefile
ls /tmp/tmp/$USER/dpdk
```

Copy the Makefile and modify it for your needs and, if needed, copy
the dpdk SDK from `$__dpdk_src/build/sys`.

You must copy the used dpdk lib's to the xcluster ovl;

```
./dpdk.sh libs /tmp/tmp/$USER/dpdk/*
```

See an example in the "tar" script.


## Other info and commands

```
lshw -class network -businfo
# json output is broken for "-class network"
lshw -json | jq '.children[0].children[]|select(.class == "bridge")|.children[]|select(.class == "network")'
echo igb_uio > /sys/bus/pci/devices/0000:00:05.0/driver_override
hugeadm --explain
cat /proc/meminfo | grep Huge
sysctl vm.nr_hugepages
ls /dev/hugepages
```

