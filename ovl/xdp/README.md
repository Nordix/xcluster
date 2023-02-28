# Xcluster/ovl - xdp

Experiments and tests with
[XDP](https://en.wikipedia.org/wiki/Express_Data_Path) and
[eBPF](https://ebpf.io/).

## Prerequisites

We will use the `xcluster` kernel, not the kernel you have on your
computer, so it must be built locally;

```
xc env | grep __kver     # kernel version
xc env | grep KERNELDIR  # kernel source unpacked here
xc kernel_build
```

Now the `libbpf` can be build from the kernel source;

```
#sudo apt install libbfd-dev
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

Optionally `libxdp` can be cloned and built;
```
#sudo ln -s x86_64-linux-gnu/asm /usr/include/asm
./xdp.sh libxdp_build
```

This is suddenly needed on Ubuntu 20;
```
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
sudo chmod u+s /usr/bin/qemu-system-x86_64
```

Test to build;
```
. ./Envsettings
mkdir -p /tmp/xdptest
make -C src O=/tmp/xdptest
```

## xdp-tutorial OBSOLETE?

**This seem to be un-maintained. It doesn't work on recent kernels**

The tutorial at;

* https://github.com/xdp-project/xdp-tutorial

These seem to be simplified versions of the sample programs found in
the Linux kernel tree in `samples/bpf/xdp*`.


### Prerequisites

Install
[dependencies](https://github.com/xdp-project/xdp-tutorial/blob/master/setup_dependencies.org).

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

## HW offload for virtio

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
# cd basic01-xdp-pass
# ./xdp_pass_user --dev eth1
libbpf: Kernel error message: virtio_net: Too few free TX rings available
ERR: ifindex(3) link set xdp fd failed (12): Cannot allocate memory
```

You can still load the examples by using the "--skb-mode" option to
skip hw offload.



## Local examples

These examples used `bpftool` and `ip` to load bpf programs and attach
them to devices, but after [linux-5.13](https://github.com/torvalds/linux/commit/10397994d30f2de51bfd9321ed9ddb789464f572)
that is not possible. You will get;

```
libbpf: Netlink-based XDP prog detected, please unload it in order to launch AF_XDP prog
Failed xsk_socket__create (ingress); Invalid argument
```


Test build;
```
make -C src O=/tmp/$USER/xdp
```

Usage;
```
cdo xdp
. ./Envsettings
export __nrouters=1
export __ntesters=1
export __nvm=1
./xdp.sh test start > $log
# On vm-201
cat /sys/kernel/debug/tracing/trace_pipe   # (optional)
cd /root/xdptest
bpftool prog loadall ./xdp_kern.o /sys/fs/bpf/xdptest pinmaps /sys/fs/bpf/xdptest
ls /sys/fs/bpf/xdptest
ethtool -L eth1 combined 1
ip link set dev eth1 xdpgeneric pinned /sys/fs/bpf/xdptest/xdp_prog_redirect
./xdptest/xdptest receive --dev=eth1 --fillq=4
ssh $sshopt root@192.168.0.1 ping -c1 -W1 192.168.1.201
ssh $sshopt root@192.168.0.1 ping -c1 -W1 1000::1:192.168.1.201 # (works)
#ip link set dev eth1 xdpgeneric none
```
