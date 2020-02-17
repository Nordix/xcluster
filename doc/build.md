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
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04).

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


Make sure that the base archives are downloaded;
```
$ ./xcadmin.sh base_archives
/home/guest/archive/diskim-v0.4.0.tar.xz
/home/guest/archive/linux-5.4.2.tar.xz
/home/guest/archive/busybox-1.30.1.tar.bz2
/home/guest/archive/dropbear-2016.74.tar.bz2
/home/guest/archive/iproute2-4.19.0.tar.xz
/home/guest/archive/coredns_1.6.7_linux_amd64.tgz
```

Build the base system;
```
$ ./xcadmin.sh build_base $XCLUSTER_WORKSPACE
... (lots of printouts)
0   :2020-02-17-12:40:12: Build xcluster
0   :2020-02-17-12:40:12: Coredns  installed
0   :2020-02-17-12:40:12: Diskim installed
130 :2020-02-17-12:42:22: Kernel built
142 :2020-02-17-12:42:34: Busybox built
151 :2020-02-17-12:42:43: Dropbear built
158 :2020-02-17-12:42:50: Iproute2 built
165 :2020-02-17-12:42:57: Image built
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


### Pre-pulled images

`Xcluster` required some K8s images to be "pre-pulled". That is they
must exist when K8s starts. This makes it possible to execute basic
K8s tests "offline".

The problem is that building an archive with the pre-pulled images
requires `sudo`.

First pull the images to your local `docker`;
```
for i in $(./xcadmin.sh prepulled_images); do
  docker pull $i
done
```

The build the archive;
```
./xcadmin.sh mkimages_ar    # You will be prompted for passwd
```

The "images.tar.xz" is rarely updated so keep this so you don't have
to execute "sudo" again (likely required for CI).

### K8s'ify the workspace

Download more archives;
```
$ ./xcadmin.sh k8s_archives
/home/guest/archive/coredns_1.6.7_linux_amd64.tgz
/home/guest/archive/kubernetes-server-v1.17.2-linux-amd64.tar.gz
/home/guest/archive/mconnect-v2.0.gz
```

The `kubernetes` and `mconnect` archive anes does not contain a
version and must be renamed after download.


```
./xcadmin.sh k8s_workspace
```

The first time a lot of source archives are downloaded.

## Create a binary release

```
./xcadmin.sh release --version=test
```

