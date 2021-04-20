# Xcluster/ovl - xdp

Experiments and tests with [XDP](https://en.wikipedia.org/wiki/Express_Data_Path)


## xdp-tutorial

The tutorial at;

* https://github.com/xdp-project/xdp-tutorial


### Prerequisites

Install
[dependencies](https://github.com/xdp-project/xdp-tutorial/blob/master/setup_dependencies.org).

We will use the `xcluster` kernel, not the kernel you have on your
computer, so it must be built locally;

```
xc env | grep __kver     # kernel version
xc env | grep KERNELDIR  # kernel source unpacked here
xc kernel_build
```

Now the `libbpf` can be build from the kernel source;

```
cdo xdp
./xdp.sh libbpf_build
```

The kernel `perf` tool is used for kernel tracing in the tutorial. It
is a part of the kernel and should be build from the `xcluster` kernel
source.

```
cdo xdp
./xdp.sh perf_build
```

Clone xdp-project;
```
mkdir -p $GOPATH/src/github.com/xdp-project
cd $GOPATH/src/github.com/xdp-project
git clone --depth 1 https://github.com/xdp-project/xdp-tutorial.git
```

`xdp-tutorial` expects `libbpf` as a git sub-module but we use the
kernel code so we create a link so the place `xdp-tutorial` expects;

```
cdo xdp
./xdp.sh libbpf_link
```

### HW offload for virtio

The `virtio` networking used in `xcluster` has support for HW offload
but "multiqueue" setup must be used. This is setup on the host side by
the `Envsettings` file;

```
cdo xdp
. ./Envsettings
./xdp.sh test start > $log
# On vm-001
ethtool -l eth1
Channel parameters for eth1:
Pre-set maximums:
RX:             0
TX:             0
Other:          0
Combined:       4
Current hardware settings:
RX:             0
TX:             0
Other:          0
Combined:       2
```

`eth1` has 4 Combined channels. If you forget to source `Envsettings`
there will be just 1, and examples may fail with something like;

```
# ./xdp_pass_user --dev eth1
libbpf: Kernel error message: virtio_net: Too few free TX rings available
ERR: ifindex(3) link set xdp fd failed (12): Cannot allocate memory
```

You can still load the examples by using the "--skb-mode" option to
skip hw offload.


### The examples

General build;
```
x=basic01-xdp-pass
cd $GOPATH/src/github.com/xdp-project/xdp-tutorial/$x
make USER_LIBS=-lz
# (do NOT do 'make clean'. Wipes libbpf!)
```

The `xdp-tutorial` examples are installed on `/root`. If the example
is not built the directory will be empty. The first example is shown
below;

```
cdo xdp
./xdp.sh test start > $log
# On vm-001
cd /root/basic01-xdp-pass
./xdp_pass_user --dev eth1
ping 192.168.1.2
```

