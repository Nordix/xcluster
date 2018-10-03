# Xcluster disk image and kernel

Describes howto alter the `xcluster` kernel and disk image.

The `xcluster` disk image is shared by all VMs. It is not bootable
instead `kvm` is started with the "-kernel bzImage" option. This is
simpler and it also allows parametes to the kernel to be specified
which can be accessed via `/proc/cmdline` from within the VMs.

## Diskim

The disk image and kernel is built using the
[diskim](https://github.com/lgekman/diskim) package. If it is not
installed you will get a warning and an instruction when you source
`Envsettings`;

```
~/xcluster$ . ./Envsettings.k8s 
"diskim" is missing. Install with;

wget -O - -q \
 https://github.com/lgekman/diskim/releases/download/v0.4.0/diskim-v0.4.0.tar.xz \
 | tar -I pxz -C /home/guest/xcluster/workspace -xf -
```

## Extend the image

Extend an existing disk image with new overlays.

Prerequisite; `diskim` is installed.


The disk image is stored in `$XCLUSTER_HOME` which defaults to
`$XCLUSTER_WORKSPACE/xcluster` if not set;

```
$ ls -F $XCLUSTER_WORKSPACE/xcluster
bzImage  cache/  hd.img  hd-k8s.img
```

You can specify the image with the `--image` option or the `$__image`
variable. By default `hd.img` is used. In this example we copy the
default image and extend the copy;

```
export __image=$XCLUSTER_WORKSPACE/xcluster/my-hd.img
cp $XCLUSTER_WORKSPACE/xcluster/hd.img $__image
xc ximage systemd
xc start
```

The image is extended with the `systemd` overlay and VMs should now
start with systemd.


## Kernel

Since the kernel modules has to be installed on the disk image there
is a dependency from the image to the kernel. The kernel must be build
before you can create a new image.

Prerequisite; `diskim` is installed.

```
xc kernel_build
```

This downloads the kernel and unpack it on $ARCHIVE (default
$HOME/Downloads).

### Alter the kernel config

```
xc kernel_build --menuconfig
```

### New kernel

```
export __kver=linux-4.18.11
export __kcfg=$MY_CONFIGS/$__kver
cp config/linux-4.18.5 $__kcfg
xc kernel_build --menuconfig
```

## New image

Some programs must be built;

 * [BusyBox](https://busybox.net/) - The Swiss Army Knife of Embedded Linux
 * [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - Small ssh server+client.
 * [iproute2](https://en.wikipedia.org/wiki/Iproute2) - For an `ip` built for the right kernel

The binary release of `xcluster` contains pre-built versions but if
you want to build them do;

```
xc busybox_build
xc dropbear_build
xc iproute2_build
```

Now you can build a new image;

Prerequisite; The kernel has been built and `diskim` is installed.

```
xc mkimage
```

Libraries, loader and some programs are included from your host.
