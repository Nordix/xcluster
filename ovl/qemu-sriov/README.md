# Xcluster/ovl - qemu-sriov

Experiments with SR-IOV emulation in Qemu.

This is *not* about using SR-IOV in a host NIC to boost performance of
a VM guest (there are plenty of examples of that). This is about
having an emulated NIC with SR-IOV support to let you test and develop
sr-iov applications with qemu instead of buying (and maintaining)
expensive HW.

Support for SR-IOV was added to `qemu` in commit `7c0fa8dff`. It is
included in qemu `v7.0.0` (git tag --contains 7c0fa8dff).

A NIC that supports SR-IOV in `qemu` is now available. It is built on the
Intel `igb` emulation by @knuto.

The [multilan-router](../network-topology#multilan-router) network
topology is most often used.

<img src="../network-topology/multilan-router.svg" width="60%" />



## Build


Build a local qemu;
```
# Clone;
QEMUDIR=$GOPATH/src/github.com/qemu/qemu  # (set by; . ./Envsettings)
git clone --depth 1 https://github.com/qemu/qemu.git $QEMUDIR

# Build;
cd $QEMUDIR
mkdir build
cd build
../configure --target-list=x86_64-softmmu
make -j$(nproc)
make DESTDIR=$PWD/sys install
./qemu-system-x86_64 -net nic,model=? | grep igb
./qemu-system-x86_64 -M ?  # -m q35 must be used!
```

## Manual basic test

Requirement; `xcluster` must be started in an own [netns](
https://github.com/Nordix/xcluster/blob/master/doc/netns.md).

```
cdo qemu-sriov
. ./Envsettings
./qemu-sriov.sh test start_empty > $log
# On vm-001
lspci | grep 82576
modprobe igb
modprobe igbvf
ls /sys/bus/pci/devices/0000:01:00.0/
echo 2 > /sys/bus/pci/devices/0000:01:00.0/sriov_numvfs
lspci | grep 82576
```

For non-xcluster users, here is the `ps` printout as a hint:
```
$HOME/go/src/github.com/qemu/qemu/build/qemu-system-x86_64 -enable-kvm \
  -kernel $HOME/tmp/xcluster/workspace/xcluster/bzImage-linux-6.1 \
  -drive file=/tmp/${USER}/xcluster/${USER}_xcluster1/hd-1.img,if=virtio \
  -nographic -smp 2 -k sv -m 1024 -monitor telnet::4001,server,nowait \
  -drive file=/tmp/${USER}/xcluster/${USER}_xcluster1/cdrom.iso,if=virtio,media=cdrom \
  -netdev tap,id=net0,script=no,downscript=/tmp/rmtap,ifname=xcbr0_t1 \
  -device virtio-net-pci,netdev=net0,mac=00:00:00:01:00:01 \
  -device pcie-root-port,slot=1,id=pcie_port.1 \
  -netdev tap,id=net1,script=no,downscript=/tmp/rmtap,ifname=xcbr1_t1,queues=4 \
  -device igb,bus=pcie_port.1,netdev=net1,mac=00:00:00:01:01:01 \
  -M q35 -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=80000 \
  -cpu qemu64,+sse4.2,+sse4.1,+ssse3 -append noapic root=/dev/vda rw init=/init
```
The important stuff is the `igb` device and `-M q35`.

## KVM permissions

If your user doesn't have permissions for KVM, an error like this is displayed
```
bash-5.1$ $__kvm
Could not access KVM kernel module: Permission denied
qemu-system-x86_64: failed to initialize kvm: Permission denied
```

Make sure your user is part of kvm group and check the permissions for /dev/kvm
```
chown root:kvm /dev/kvm
chmod 660 /dev/kvm
```

## Test

```
./qemu-sriov.sh                       # Help printout
./qemu-sriov.sh test > $log           # Default tests
images lreg_preload default           # Pre-load the local registry
./qemu-sriov.sh test start_k8s > $log # Test with K8s.
```

## CNI-plugin trace

The calls to the `sriov` cni-plugin can be traced using the trace
function in [ovl/cni-plugins](../cni-plugins).
```
xcluster_CNI_PLUGIN_TRACE=sriov ./qemu-sriov.sh test --no-stop net3 > $log
# cat /var/log/cni-trace
=============================================================
--------- Environment
CNI_PATH=/opt/cni/bin:/opt/cni/bin/
CNI_ARGS=IgnoreUnknown=true;K8S_POD_NAMESPACE=default;K8S_POD_NAME=net3-74585d67cf-w2qtg;K8S_POD_INFRA_CONTAINER_ID=54b646284cd392a4288ea37b8850577a3b2ad0cdcec547fc5043d23c0d9717d9;K8S_POD_UID=0909da63-de72-41f9-a8c0-5174729c0ba8;IgnoreUnknown=1;K8S_POD_NAMESPACE=default;K8S_POD_NAME=net3-74585d67cf-w2qtg;K8S_POD_INFRA_CONTAINER_ID=54b646284cd392a4288ea37b8850577a3b2ad0cdcec547fc5043d23c0d9717d9;K8S_POD_UID=0909da63-de72-41f9-a8c0-5174729c0ba8
CNI_CONTAINERID=54b646284cd392a4288ea37b8850577a3b2ad0cdcec547fc5043d23c0d9717d9
CNI_NETNS=/var/run/netns/2d937f84-94ef-4020-9395-03f216122a77
CNI_IFNAME=net3
CNI_COMMAND=ADD
--------- Stdin
{
  "cniVersion": "0.4.0",
  "deviceID": "0000:01:10.2",
  "ipam": {
    "ipRanges": [
      {
        "exclude": [
          "192.168.3.0/28"
        ],
        "range": "192.168.3.0/24"
      },
      {
        "exclude": [
          "fd00::c0a8:300/124"
        ],
        "range": "fd00::c0a8:300/120"
      }
    ],
    "type": "whereabouts"
  },
  "name": "net3",
  "pciBusID": "0000:01:10.2",
  "type": "sriov"
}
--------- Stdout
{
  "cniVersion": "0.4.0",
  "interfaces": [
    {
      "name": "net3",
      "mac": "ca:54:50:98:28:ac",
      "sandbox": "/var/run/netns/2d937f84-94ef-4020-9395-03f216122a77"
    }
  ],
  "ips": [
    {
      "version": "4",
      "interface": 0,
      "address": "192.168.3.16/24"
    },
    {
      "version": "6",
      "interface": 0,
      "address": "fd00::c0a8:310/120"
    }
  ],
  "dns": {}
}
```


## Locally built sriov images

This shouldn't be needed normally. The `image:` lines in manifests in the
`default/` directory must be updated manually.

```
./qemu-sriov.sh clone_sriov
./qemu-sriov.sh build_sriov_images
# If that doesn't work, try
./qemu-sriov.sh build_sriov_images --local
```
