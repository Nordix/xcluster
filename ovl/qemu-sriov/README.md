# Xcluster/ovl - qemu-sriov

Experiments with SR-IOV emulation in Qemu.

This is *not* about using SR-IOV in a host NIC to boost performance of
a VM guest (there are plenty of examples of that). This is about
having an emulated NIC with SR-IOV support to let you test and develop
sr-iov applications with qemu instead of buying (and maintaining)
expensive HW.

Support for SR-IOV was added to `qemu` in commit `7c0fa8dff`. It is
included in qemu `v7.0.0` (git tag --contains 7c0fa8dff).

A NIC that supports SR-IOV in `qemu` is on it's way. It is built on the
Intel `igb` emulation by @knuto. Packet handling was [not implemented](
https://github.com/knuto/qemu/issues/5) but is now added in a
[clone on Nordix](https://github.com/Nordix/qemu/tree/igb-device).

## Build


Build a local qemu;
```
# Clone;
QEMUDIR=$GOPATH/src/github.com/qemu/qemu  # (set by; . ./Envsettings)
mkdir -p $(dirname $QEMUDIR)
cd $(dirname $QEMUDIR)
git clone -b igb-device git@github.com:Nordix/qemu.git
cd $QEMUDIR
git remote add upstream https://github.com/qemu/qemu.git
git remote set-url --push upstream no_push
git remote -v
# Rebase;
cd $QEMUDIR
git fetch upstream
git rebase upstream/master

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
./qemu-sriov.sh                   # Help printout
./qemu-sriov.sh test > $log       # Default tests without K8s
./qemu-sriov.sh start_k8s         # Test with K8s. Requires images (see below)
```


## SRIOV cni and device plugins

We need SRIOV CNI and device plugins to orchestrate discovery of
the SRIOV VFs and assigning them to the pods.

```
./qemu-sriov.sh clone_sriov
./qemu-sriov.sh build_sriov_images
# If that doesn't work, try
./qemu-sriov.sh build_sriov_images --local
```
