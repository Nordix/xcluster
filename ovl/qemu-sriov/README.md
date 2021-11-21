# Xcluster/ovl - qemu-sriov

Experiments with SR-IOV emulation in Qemu.

This is *not* about using SR-IOV in a host NIC to boost performance of
a VM guest (there are plenty of examples of that). This is about
having an emulated NIC with SR-IOV support to let you test and develop
sr-iov applications with qemu instead of buying (and maintaining)
expensive HW.


## Build

Qemu has not support for SR-IOV but is supported by
https://github.com/knuto/qemu. *NOTE* that actual packet handling is
[not supported](https://github.com/knuto/qemu/issues/4#issuecomment-928006345)
(yet).

Build a local qemu;
```
# Clone;
QEMUDIR=$GOPATH/src/github.com/knuto/qemu
mkdir -p $(dirname $QEMUDIR)
cd $(dirname $QEMUDIR)
#git clone -b sriov_patches_v14 https://github.com/knuto/qemu.git
git clone -b sriov_patches_v14 git@github.com:Nordix/qemu-knuto.git qemu
cd $QEMUDIR
git remote add upstream https://github.com/knuto/qemu.git
git remote set-url --push upstream no_push
git remote -v
# Rebase;
cd $QEMUDIR
git fetch upstream
git rebase upstream/sriov_patches_v14
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

The `xcluster` kernel must be re-built with support for the Intel
`igb` nic;

```
cdo qemu-sriov
QEMUDIR=$GOPATH/src/github.com/knuto/qemu
. ./Envsettings
xc kernel_build
```

## Usage

Basic test;
```
cdo qemu-sriov
QEMUDIR=$GOPATH/src/github.com/knuto/qemu
. ./Envsettings
#$__kvm -nic model=help
XOVLS='' xc mkcdrom xnet iptools qemu-sriov
xc starts --image=$XCLUSTER_WORKSPACE/xcluster/hd.img --nrouters=0 --nvm=1
# On vm-001
lspci | grep 82576
modprobe igb
modprobe igbvf
ls /sys/bus/pci/devices/0000:01:00.0/
echo 2 > /sys/bus/pci/devices/0000:01:00.0/sriov_numvfs
lspci | grep 82576
```

