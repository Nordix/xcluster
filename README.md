# Xcluster - Experimental Cluster Environment

A [very lightweight](doc/100nodes.md) and configurable cluster
environment primarily intended for development and test of network
functions.

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
 * [100 VMs](doc/100nodes.md)
 * [Troubleshooting](doc/troubleshooting.md)
 * [Misc info](doc/misc.md). Prettiy xterms, use master-branch, and more...
 * [Networking](doc/networking.md). Default network and DNS setup.
 * [Network name space](doc/netns.md). Setup a netns for running `xcluster`.
 * [Overlays](doc/overlays.md). How they work and how they are created
 * [Overlay index](ovl-index.md)
 * [Disk-image and kernel](doc/image.md). How they are created and extended.
 * [Build from scratch](doc/build.md). If the binary release can't be used.
 * [Xcluster for CI](doc/ci.md). Headless operation.
 * [Local docker registry](ovl/private-reg/README.md).
 * [Test](doc/test.md)
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
dependencies if necessary (see
[above](#execution-environment-and-dependencies);

```
kvm-ok
id     # (you must be member of the "kvm" group)
sudo apt install -y xterm pxz genisoimage jq   # (if necessary)
```

To get a k8s cluster with dual-stack running do;
```
XCDIR=$HOME/tmp   # Change to your preference
mkdir -p $XCDIR
cd $XCDIR
ver=<latest>
curl -L https://github.com/Nordix/xcluster/releases/download/$ver/xcluster-$ver.tar.xz | tar xJ
cd $XCDIR/xcluster
. ./Envsettings.k8s
armurl=http://artifactory.nordix.org/artifactory/cloud-native
curl -L $armurl/xcluster/images/hd-k8s.img.xz | xz -d > $__image
xc mkcdrom k8s-dual-stack
xc start   # (no xterms? See below) (use "xc starts" to start without xterms)
vm 2     # Opens a terminal on vm-002

# In the terminal (on cluster) test things, for example;
kubectl get nodes  # (may take ~10 sec to appear)
kubectl get node vm-002 -o json | jq .spec   # "podCIDRs" is dual-stack
kubectl -o json get pods -l 'app=coredns' | jq .items[0].status.podIPs
nslookup www.google.se   # (doesn't work? See below)
wget -4 -O /dev/null http://www.google.se # (doesn't work? See below)
# Traffic test with mconnect
kubectl apply -f /etc/kubernetes/mconnect-dual.yaml # (image is pre-pulled)
kubectl get svc
assign-lb-ip -svc mconnect; assign-lb-ip -svc mconnect-ipv6
kubectl get svc
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 100
mconnect -address mconnect-ipv6.default.svc.xcluster:5001 -nconn 100
```

No xterms? Start with "xtermopt=-hold xc start" to keep the window.
See also the [troubleshooting doc](https://github.com/Nordix/xcluster/blob/master/doc/troubleshooting.md)

Nslookup doesn't work? See [DNS-troubleshooting](https://github.com/Nordix/xcluster/blob/master/doc/networking.md#dns-trouble-shooting)

External access does not work (wget http://www.google.se)? Check you
host firewall settings. If this does not work then images can not be
loaded from external sites (docker.io).


Run some test-suites;
```
cdo test-template
./test-template.sh test > /tmp/xcluster-test.log
cdo metallb
./metallb.sh test basic4 basic6 > /tmp/xcluster-test.log
```

## K8s test and development with xcluster

**NOTE**: `xcluster` is intended for test and development of network
functions. It is *not* intended for general k8s application
development.

If you want to use `xcluster` for some more serious test/development
you *must* run `xcluster` inside an own netns as described
[here](https://github.com/Nordix/xcluster/blob/master/doc/netns.md).
In netns "bridged" networking is used, see the [networking
topology](https://github.com/Nordix/xcluster/blob/master/doc/networking.md).

While the user-space networking works (sort of) the performance is
*horrible*, slow and lossy. This will cause all sorts of weird problems
that you may not relate to poor network performance at first.

While not a requirement it is *strongly recommended* that you use a
[private docker
registry](https://github.com/Nordix/xcluster/tree/master/ovl/private-reg).
I recommend to modify the image so a private registry is always used;
```
xc ximage private-reg
```

To keep up with `xcluster` updates use a clone rather than a release
as described [here](doc/misc.md).



