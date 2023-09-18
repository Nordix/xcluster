# Build xcluster

Describes howto build kernel, and images from scratch.  Most of the
work is done by the [xcadmin.sh](../xcadmin.sh) script.  Also how to
create a release is described here.

## Dependencies

Ubuntu:
```
apt install -y jq net-tools libelf-dev pkg-config libmnl-dev \
 libdb-dev docbook-utils libpopt-dev gperf libcap-dev libgcrypt20-dev \
 libgpgme-dev libglib2.0-dev gawk libreadline-dev libc-ares-dev xterm \
 qemu-kvm curl bison flex uuid libgmp-dev libncurses-dev \
 screen
# (there may be more)
```

For image handling you will need
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04).

The `go` language is needed to build some support programs. The
version in distros or snap is usually outdated, so a local
installation is recommended:

```
gover=1.21.1
curl -L https://go.dev/dl/go$gover.linux-amd64.tar.gz -o $HOME/Downloads/go$gover.linux-amd64.tar.gz
mkdir -p $HOME/bin
#rm -rf $HOME/bin/go      # remove old version if necessary
tar -C $HOME/bin -xf $HOME/Downloads/go$gover.linux-amd64.tar.gz
export PATH=$HOME/bin/go/bin:$PATH
go version
# The $GOPATH variable is used by xcluster, so it must be set
eval $(go env | grep GOPATH); export GOPATH
export PATH=$GOPATH/bin:$PATH
```


## Clone and setup environment

All non-temporary files, such as disk-images, kernels, etc., will be
stored in `$XCLUSTER_WORKSPACE`. Set it to some sensible dir. This is
assumed to be set in the rest of this description.

```
git clone --depth 1 https://github.com/Nordix/xcluster.git $GOPATH/src/github.com/Nordix/xcluster
cd $GOPATH/src/github.com/Nordix/xcluster
export XCLUSTER_WORKSPACE=$HOME/tmp/xcluster/workspace
mkdir -p $XCLUSTER_WORKSPACE
. ./Envsettings
# (Never mind any "WARNING: CoreDNS not found..." for now)
xc        # Help printout
xcadmin   # Help printout
```

## Build $XCLUSTER_WORKSPACE

Sone additional dependencies are required.

The `coredns` server is used to forward DNS queries, and it is a main
component in Kubernetes:
```
eval $(xcadmin env | grep __corednsver)
curl -L https://github.com/coredns/coredns/releases/download/v$__corednsver/coredns_${__corednsver}_linux_amd64.tgz > $HOME/Downloads/coredns_${__corednsver}_linux_amd64.tgz
```

The [diskim](https://github.com/lgekman/diskim) project is used to
create disk images without `sudo`.

```
eval $(xc env | grep __diskimver)
curl -L https://github.com/lgekman/diskim/releases/download/$__diskimver/diskim-$__diskimver.tar.xz > $HOME/Downloads/diskim-$__diskimver.tar.xz
```

Build the base, including the kernel and rootfs. The kernel source
will be unpacked in `$KERNELDIR`.

```
#export KERNELDIR=$HOME/tmp/linux   # Redefine if you like
export XCLUSTER_WORKSPACE=$HOME/tmp/xcluster/workspace
#rm -rf $XCLUSTER_WORKSPACE  # if re-building
xcadmin build_base
```


## Basic test

The `xcluster` base is now ready to use. Test in a fresh shell
(especially if you saw "WARNING: CoreDNS not found..." earlier)

```
cd /path/to/your/cloned/xcluster
. ./Envsettings
# (there shall not be any warning printouts)
# Start with xterm consoles
xc mkcdrom xnet; xc start
vm 1   # Opens a terminal on vm-001
# Start with "screens" consoles
xc mkcdrom xnet; xc starts
vm 1   # Opens a terminal on vm-001
# Stop xcluster. This is automatic on a re-start
xc stop

# Automatic test
cdo test
log=/tmp/$USER/xcluster-log
./test.sh test > $log
```

Consult the [Troubleshooting guide](troubleshooting.md) if necessary.

You might nothice that internet access doesn't work from VMs?  That's
because "iptables" is missing, which is addressed in the next section.


## Iptools

Since `xcluster` is intended for network testing, the iptools are
crucial. Some are dependent on the kernel, so they *may* have to be
re-built if the kernel is updated.

```
cdo iptools
./iptools.sh versions
./iptools.sh download
./iptools.sh build --clean  # (need to clean the iproute2 built for the base)
xc mkcdrom iptools xnet; xc starts
vm 1
# On vm-001
wget http://www.google.se
```

Man pages are built, and should be prefered before your distro's man
pages, which may be outdated.

```
./iptools.sh man            # list pages
./iptools.sh man_iproute2   # list pages
./iptools.sh man_iproute2 ip-link.8
```


## Create an xcluster release

Unfortunately a `xcluster` binary release contains the "kubectl"
program as a preparation for running Kubernetes. It is taken from an
already downloaded K8s server release archive or from a local K8s
build.

```
#export XCLUSTER_WORKSPACE=$HOME/tmp/xcluster/workspace
xcadmin k8s_workspace --k8sver=v1.28.1
# Require kubernetes-server-$__k8sver-linux-amd64.tar.gz
# Or from a local built K8s
xcadmin k8s_workspace --k8sver=master
```

Users of the release should be able to use `ovl/iptools` without
having to build the kernel, so this ovl must be cached.

```
xc cache --clear
xc cache iptools
```

When all of the above works, then build the release:

```
xcadmin release --version=8.0.0-rc1
```


## Kubernetes images

The Kubernetes images are not really a part of `xcluster` but most
testing is probably on K8s. Some more packages must be downloaded:

```
cdo crio
./crio.sh download
cdo cni-plugins
./cni-plugins.sh download
curl -L https://github.com/Nordix/assign-lb-ip/releases/download/v2.3.1/assign-lb-ip.xz > $HOME/Downloads/assign-lb-ip.xz
curl -L https://github.com/Nordix/mconnect/releases/download/v2.2.0/mconnect.xz > $HOME/Downloads/mconnect.xz
```

The Kubernetes images can be build from a local K8s clone, or from a
[K8s server archive](
https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.28.md)

```
ls ~/Downloads/kub*
/home/guest/Downloads/kubernetes-server-v1.28.1-linux-amd64.tar.gz
# The archive is renamed to include the K8s version, original name is
# kubernetes-server-linux-amd64.tar.gz
xcadmin k8s_build_images --k8sver=v1.28.1
#xcadmin k8s_build_images --k8sver=master   # Uses a local clone
```
