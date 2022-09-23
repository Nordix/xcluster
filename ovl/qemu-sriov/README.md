# Xcluster/ovl - qemu-sriov

Experiments with SR-IOV emulation in Qemu.

This is *not* about using SR-IOV in a host NIC to boost performance of
a VM guest (there are plenty of examples of that). This is about
having an emulated NIC with SR-IOV support to let you test and develop
sr-iov applications with qemu instead of buying (and maintaining)
expensive HW.

Support for SR-IOV was added to `qemu` in commit `7c0fa8dff`. It is
included in qemu `v7.0.0` (git tag --contains 7c0fa8dff).

There is no nic emulation that supports SR-IOV in `qemu` yet. An
emulation of `igb/igbvf` is provided by @knuto in https://github.com/knuto/qemu,
but packet handling is [not supported](https://github.com/knuto/qemu/issues/5).


## Build

We use a `qemu` [clone on Nordix](https://github.com/Nordix/qemu) with
the `igb/igbvf` patch from @knuto applied.


Build a local qemu;
```
# Clone;
QEMUDIR=$GOPATH/src/github.com/qemu/qemu  # (set by; . ./Envsettings)
mkdir -p $(dirname $QEMUDIR)
cd $(dirname $QEMUDIR)
git clone -b nic-igb git@github.com:Nordix/qemu.git
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

## Basic test

Requirement; `xcluster` must be started in an own [netns](
https://github.com/Nordix/xcluster/blob/master/doc/netns.md).

```
cdo qemu-sriov
. ./Envsettings
#$__kvm -nic model=help
XOVLS='' xc mkcdrom xnet lspci iptools qemu-sriov
xc starts --image=$XCLUSTER_WORKSPACE/xcluster/hd.img --nrouters=0 --nvm=1
# On vm-001
lspci | grep 82576
modprobe igb
modprobe igbvf
ls /sys/bus/pci/devices/0000:01:00.0/
echo 2 > /sys/bus/pci/devices/0000:01:00.0/sriov_numvfs
lspci | grep 82576
```

