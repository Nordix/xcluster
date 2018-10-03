# Xcluster - Experimental Cluster Environment

A very lightweight and configurable cluster environment primarily
intended for development and test of network functions.

To see how `xcluster` can be used with
[Kubernetes](https://kubernetes.io/) please see the [Quick
Start](#quick-start) section or the Kubernetes
[overlay](ovl/kubernetes/README.md).

More info;

 * [Quick Start](#quick-start)
 * [Networking](doc/networking.md). Default network setup.
 * [Network name space](doc/netns.md). Setup a netn for running `xcluster` and DNS
 * [Overlays](doc/overlays.md). How they work and how they are created
 * [Disk-image and kernel](doc/image.md). How they are created and extended.

An `xcluster` consists of a number of identical (kvm) VMs. The disk
image is shared among the VMs and the `qemu-img` "backing_file"
function is used to allow individual writes (much like a layered
file-system);

<img src="xcluster-img.svg" alt="Figure of xcluster disks" width="50%" />

The VMs are given "roles" depending on their hostname;

```
vm-001 - vm-200   Cluster nodes
vm-201 - vm-220   Router VMs
vm-221 - vm-240   Tester VMs
vm-250 -          Reserved
```

By default `xcluster` starts with consoles in `xterm` windows;

<img src="xcluster-screenshot.png" alt="xcluster screenshot" width="50%" />

#### Overlays

In the earliest stage of start all VMs are mounting an iso image
(cdrom) that may contain any number of tar-files called
"overlays". The files are unpacked on root "/" in sort order and
provides a primitive packaging system. The iso image is created from
ovl directories. Example;

```
# Start an xcluster with overlays (xc is an alias for the xcluster.sh script)
xc mkcdrom systemd etcd; xc start
```



### Execution environment and dependencies

`Xcluster` is developed on `Ubuntu 18.04.1 LTS`. It will probably not
work on other distributions (mainly due to variations in libs) but the
necessary adaptions should not be overwhelming.

You must grant execution without `root` for some binaries;

```
sudo setcap cap_net_admin,cap_sys_admin+ep /bin/ip
sudo setcap cap_net_admin,cap_sys_admin+ep /sbin/xtables-multi
```

Some additional packets may have to be installed. Below is a
suggestion, there may be others;

```
apt install -y jq net-tools libelf-dev pkg-config libmnl-dev \
 libdb-dev docbook-utils libpopt-dev gperf libcap-dev libgcrypt20-dev \
 libgpgme-dev libglib2.0-dev gawk libreadline-dev libc-ares-dev xterm \
 qemu-kvm curl pxz bison flex libc6:i386 uuid libgmp-dev libncurses-dev
apt-add-repository -y ppa:projectatomic/ppa
apt update
apt install -y skopeo
```

You must be a member of the `kvm` group to be able to run VMs;

```
sudo usermod -aG kvm <your-user>
```

#### The $ARCHIVE variable

`Xcluster` uses the $ARCHIVE directory to store for instance
downloaded archives. It defaults to `$HOME/Downloads` but you might
want something better.


<a name="quick-start">

## Quick start

Download from the release page and install;

```
ver=v0.1
cd $HOME
tar xf Downloads/xcluster-$ver.tar.xz
cd xcluster
. ./Envsettings
# (ignore the "diskim" warning)
```

Create and enter a network namespace ([netns](doc/netns.md)) on your
host for `xcluster` experiments. This requires `sudo`;

```
xc nsadd 1
xc nsenter 1
cd $HOME/xcluster
. ./Envsettings
# (again ignore the "diskim" warning)
```

Start an empty cluster. Xterms shall pop-up like in the screenshot
above. You can login to a vm using `vm`;

```
xc start
vm 1
```

This is the base `xcluster`. All VMs are connected to a network and
are reachable with ipv4 or ipv6 with `ssh` or `telnet`. Experiment some
and then stop the ckuster;

```
ssh root@2000::3
xc stop
```

### Xcluster with Kubernetes

In the netns;

```
cd $HOME/xcluster
. ./Envsettings.k8s
xc start
```

A Kubernetes cluster is started. The cluster is "offline", i.e. only
"pre-pulled" images can be used. Open a terminal on a node with `vm`;

```
vm 4
# On the cluster node;
kubectl version
kubectl get nodes
images  # alias that lists the loaded images
```

The [mconnect](https://github.com/Nordix/mconnect) image can be used
for basic connectivity tests;

```
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl get svc
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 1000
```

To be able to download images from the internet you must setup a local
dns server, please see instructions [here](doc/netns.md). The node and
router VM must also be configured with approriate routes. The easiest
way is to use the `externalip` overlay;

```
xc mkcdrom externalip; xc start
```

Note that you don't have to stop `xcluster` before re-starting, the
old cluster will be stopped automatically (and all associated windows
closed).

Now from a VM test connectivity and start a `alpine` pod which will
trig a downliad of the image;

```
vm 4
# On the node;
nslookup www.google.com
ping -c 1 www.google.com
images
kubectl apply -f /etc/kubernetes/alpine.yaml
# (wait some time...)
images   # docker.io/library/alpine should appear
kubectl get pods
```


#### Kubernetes ipv6-only

```
SETUP=ipv6 xc mkcdrom etcd coredns k8s-config externalip; xc start
vm 1
# On the cluster node;
kubectl get nodes -o wide
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get svc
```

As you can see the `mconnect` service has an external ip
`1000::2`. Test to access it from a router VM;

```
vm 201
# On the router vm;
mconnect -address [1000::2]:5001 -nconn 1000
```
