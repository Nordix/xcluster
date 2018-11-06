# Xcluster - Experimental Cluster Environment

A very lightweight and configurable cluster environment primarily
intended for development and test of network functions.

To see how `xcluster` can be used with
[Kubernetes](https://kubernetes.io/) please see the demo video below
and the [Quick Start](#quick-start) section. See also the Kubernetes
[overlay](ovl/kubernetes/README.md) and fast `kube-proxy` ipv6
development in the [kube-proxy-ipv6](ovl/kube-proxy-ipv6/README.md)
overlay.

An `xcluster` consists of a number of identical (kvm) VMs. The disk
image is shared among the VMs and the `qemu-img` "backing_file"
function is used to allow individual writes (much like a layered
file-system). On start specified packages
([overlays](doc/overlays.md)) are installed.

<img src="xcluster-img.svg" alt="Figure of xcluster disks" width="80%" />


More info;

 * [Quick Start](#quick-start)
 * [Troubleshooting](doc/troubleshooting.md)
 * [Misc info](doc/misc.md). Prettiy xterms, use master-branch, and more...
 * [Networking](doc/networking.md). Default network and DNS setup.
 * [Network name space](doc/netns.md). Setup a netns for running `xcluster`.
 * [Overlays](doc/overlays.md). How they work and how they are created
 * [Overlay index](ovl-index.md)
 * [Disk-image and kernel](doc/image.md). How they are created and extended.
 * [Build from scratch](doc/build.md). If the binary release can't be used.
 * [Xcluster for CI](doc/ci.md). Headless operation.
 * [Pre-pulled images](ovl/images/README.md).
 * [Test](test/README.md)
 * [Fedora](doc/fedora.md). Not maintained.

The VMs are given "roles" depending on their hostname;

```
vm-001 - vm-200   Cluster nodes
vm-201 - vm-220   Router VMs
vm-221 - vm-240   Tester VMs
vm-250 -          Reserved
```

By default `xcluster` starts with consoles in `xterm` windows. This
short (<3min) demo shows Kubernetes ipv6-only on `xcluster`;


[![Xcluster demo video](http://img.youtube.com/vi/benldT1Ev-I/0.jpg)](http://www.youtube.com/watch?v=benldT1Ev-I)

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

**NOTE**; You do not normally install SW on a running `xcluster`,
instead you create an overlay, include it in `xc mkcdrom` and
re-start. Since re-start is so fast it is slower and clumsier to copy
sw to running VMs, e.g. with `ssh`.  [read more](doc/overlays.md).


### Execution environment and dependencies

`Xcluster` is developed on `Ubuntu 18.04.1 LTS`. It seems to work fine
also on Ubuntu 16.04 LTS but it will probably not work on other
distributions (mainly due to variations in libs). Xcluster can be
started on [Fedora](doc/fedora.md) but this environment is not
maintained. If you run on another distribution than Ubuntu 18.04 you
*may* run into problems with pre-built images and cached overlays from
the binary release when you add own programs (because of library
version probems). In that case there may be no other option than to
rebuild all images and overlays locally [from scratch](doc/build.md).

First you must be able to run a `kvm`;
```
> kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
# If it looks as above; fine! go on...
# If "kvm-ok" does not exist, install as below;
sudo apt install -y qemu-kvm
# To start kvm you must be in the "kvm" group;
sudo usermod -aG kvm $USER
id
# (you may have to logout/in to enable the new group)
```

Some additional packets may have to be installed. Below is the bare
minimum for development you will need [more](doc/build.md);

```
sudo apt install -y xterm pxz genisoimage jq screen
```

For image handling you will also need
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04).


#### Environment and default options

Options to the `xcluster` functions can be specified on the command
line as "long options" for instance `--nrouters=2` or as an
environment variable;

```
xc start --nrouter=2
# same as;
__nrouters=2 xc start
# same as;
export __nrouters=2
xc start
```

This makes it very easy to set default options. The current
environment settings and default options can be printed with;

```
xc env
# If you need to use the settings in a script do;
eval $($XCLUSTER env)
```

#### Timezone

The timezone in the VMs is set (by you) using the
[timezone overlay](ovl/timezone/README.md).


#### The $ARCHIVE variable

`Xcluster` uses the $ARCHIVE directory to store for instance
downloaded archives. It defaults to `$HOME/Downloads` but you might
want something better.



<a name="quick-start">

## Quick start

Verify that `kvm` is installed and can be used and install
dependencies if necessary;

```
> kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
> id
# (you must be member of the "kvm" group)
> sudo apt install -y xterm pxz genisoimage jq
```

If necessary install `kvm` as described
[above](#execution-environment-and-dependencies).


Download from the release page and install;

```
ver=v1.0
cd $HOME
tar xf Downloads/xcluster-$ver.tar.xz
cd xcluster
. ./Envsettings
```

Start an empty cluster. Xterms shall pop-up like in the screenshot
above. If they don't, please check the
[troubleshooting](doc/troubleshooting.md) doc.

```
xc start
# If the windows closes immediately, to troubleshoot do;
xtermopt=-hold xc start --nrouters=0 --nvm=2
```

This is the base `xcluster`. All VMs are connected to the "internal"
network and are reachable with `ssh` or `telnet`. You can login to a
vm using `vm` function. Experiment some and then stop the ckuster;

```
vm 1          # "vm" is a shell function that opens an xterm on the vm
ssh root@localhost -p 12301   # Qemu port forwarding is used
xc stop
```

### Xcluster with Kubernetes

```
cd $HOME/xcluster
. ./Envsettings.k8s
xc mkcdrom externalip; xc start
```


Open a terminal on a node with `vm`;

```
vm 4
# On the cluster node;
kubectl version
kubectl get nodes
images  # alias that lists the pre-pulled images
```

The [mconnect](https://github.com/Nordix/mconnect) image can be used
for basic connectivity tests;

```
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl get svc
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 400
# On a router;
mconnect -address 10.0.0.2:5001 -nconn 400
```

#### Kubernetes ipv6-only

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip; xc start
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
mconnect -address [1000::2]:5001 -nconn 400
```
