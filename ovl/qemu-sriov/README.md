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
./qemu-sriov.sh test > $log       # Default tests
```

Current status;
* ./qemu-sriov.sh test vfs -- Works
* ./qemu-sriov.sh test packet_handling -- Does NOT work

## SRIOV cni and device plugins
## Build

Build sriov-cni;
```
# Clone;
SRIOV_CNI_DIR=$GOPATH/src/github.com/k8snetworkplumbingwg/sriov-cni  # (set by; . ./Envsettings)
mkdir -p $(dirname $SRIOV_CNI_DIR)
cd $(dirname $SRIOV_CNI_DIR)
git clone git@github.com/k8snetworkplumbingwg/sriov-cni.git
cd $SRIOV_CNI_DIR

# Build;
cd $SRIOV_CNI_DIR
make
docker build . -t registry.nordix.org/cloud-native/sriov-cni:latest
images lreg_upload --force --strip-host registry.nordix.org/cloud-native/sriov-cni:latest
```

Build sriov-network-device-plugin;
```
# Clone;
SRIOV_DP_DIR=$GOPATH/src/github.com/k8snetworkplumbingwg/sriov-network-device-plugin  # (set by; . ./Envsettings)
mkdir -p $(dirname $SRIOV_DP_DIR)
cd $(dirname $SRIOV_DP_DIR)
git clone -b igb-device git@github.com/k8snetworkplumbingwg/sriov-cni.git
cd $SRIOV_DP_DIR

# Build;
cd $SRIOV_DP_DIR
TAG=registry.nordix.org/cloud-native/sriov-network-device-plugin:latest make image
images lreg_upload --force --strip-host registry.nordix.org/cloud-native/sriov-network-device-plugin:latest
```
