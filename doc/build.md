# Build xcluster

Describes howto build kernel, and images from scratch. This may be
necessary for instance if your distribution is incompatible with the
binary release. Most of the work is done by the
[xcadmin.sh](../xcadmin.sh) script.

Also how to create a binary release is described here.

## Additional dependencies

```
apt install -y jq net-tools libelf-dev pkg-config libmnl-dev \
 libdb-dev docbook-utils libpopt-dev gperf libcap-dev libgcrypt20-dev \
 libgpgme-dev libglib2.0-dev gawk libreadline-dev libc-ares-dev xterm \
 qemu-kvm curl pxz bison flex libc6:i386 uuid libgmp-dev libncurses-dev \
 screen
apt-add-repository -y ppa:projectatomic/ppa
apt update
apt install -y skopeo
```

For image handling you will also need
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04).

## The $ARCHIVE

To build `xcluster` a number of archives are needed. These are assumed
to be in a directory defined in the `$ARCHIVE` variable which defaults
to `$HOME/Downloads`. It might be a good idea to set it to something else;

```
export ARCHIVE=$HOME/archive
mkdir -p $ARCHIVE
```


## Kernel and base image

Clone the xcluster repo and source `Envsettings`.  You will build the
$XCLUSTER_WORKSPACE so set that variable before sourcing;
```
builddir=/tmp/$USER/xcluster-build
mkdir -p $builddir; cd $builddir
git clone --depth 1 https://github.com/Nordix/xcluster.git
export XCLUSTER_WORKSPACE=$builddir/workspace
export XCLUSTER_TMP=$builddir/tmp
export KERNELDIR=$HOME/tmp/linux
cd xcluster
. ./Envsettings
```

`XCLUSTER_TMP` will be used to store temporary xcluster files such
as cdrom image and hd overlay images.

`KERNELDIR` is the place where the Linux kernel source is
unpacked. Since this is used read-only it can be stored in a
(semi-)permanent place.


Make sure all base archives are downloaded to $ARCHIVE;
```
$ xcadmin base_archives
/home/guest/archive/diskim-1.0.0.tar.xz
/home/guest/archive/linux-5.18.1.tar.xz
/home/guest/archive/busybox-1.30.1.tar.bz2
/home/guest/archive/dropbear-2020.81.tar.bz2
/home/guest/archive/iproute2-5.18.0.tar.xz
/home/guest/archive/coredns_1.8.1_linux_amd64.tgz
```

Build the base system;
```
$ xcadmin build_base $XCLUSTER_WORKSPACE
... (lots of printouts)
0   :2022-06-15-08:17:34: Build xcluster
0   :2022-06-15-08:17:34: Coredns  installed
0   :2022-06-15-08:17:34: Diskim installed
335 :2022-06-15-08:23:09: Kernel built
354 :2022-06-15-08:23:28: Busybox built
368 :2022-06-15-08:23:42: Dropbear built
382 :2022-06-15-08:23:56: Iproute2 built
386 :2022-06-15-08:24:00: Image built
```

Test the build;
```
# Manual start in xterms
xc mkcdrom; xc start
xc stop
# Automatic test;
cdo test
./test.sh test
```

The automatic test only tests cluster start and DNS for now.



## Binary release

Unfortunately a `xcluster` binary release must be prepared for
Kubernetes. This is for legacy reasons and because I can't really find
a better way.


### Pre-build cache archive

Some ovls are hard to build, for instance the "images" ovl requires
"sudo" access. This makes automation and CI hard. Fortunately these
ovls are rerely altered so we can pre-buid them and store them in the
xcluster "cache".

Pull the pre-pulled images to your local `docker`;
```
for i in $(./xcadmin.sh prepulled_images); do
  docker pull $i
done
```

Then build the pre-built cache archive;
```
./xcadmin.sh mkcache_ar    # You will be prompted for passwd
```

This builds `$ARCHIVE/xcluster-cache.tar`.

The "images.tar.xz" is rarely updated so keep this so you don't have
to execute "sudo" again (likely required for CI).


### K8s'ify the workspace

Download more archives;
```
$ ./xcadmin.sh k8s_archives
/home/guest/archive/cni-plugins-linux-amd64-v1.0.1.tgz
/home/guest/archive/etcd-v3.3.10-linux-amd64.tar.gz
/home/guest/archive/kubernetes-server-v1.18.3-linux-amd64.tar.gz
/home/guest/archive/mconnect.xz
/home/guest/archive/xcluster-cache.tar
/home/guest/archive/assign-lb-ip.xz
/home/guest/archive/crio-v1.22.0.tar.gz
```

The `kubernetes` archive does not contain a version and must be
renamed after download.


```
./xcadmin.sh k8s_workspace
```

The first time a lot of source archives are downloaded.

## Create a binary release

```
./xcadmin.sh release --version=test
```

