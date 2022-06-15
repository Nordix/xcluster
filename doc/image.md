# Xcluster disk image and kernel

Describes howto alter the `xcluster` kernel and disk image.

The `xcluster` disk image is shared by all VMs. It is not bootable
instead `kvm` is started with the "-kernel bzImage" option. This makes
it possible to select different kernels and it also allows parametes
to the kernel to be specified which can be accessed via
`/proc/cmdline` from within the VMs.

## Diskim

The disk image and kernel is built using the
[diskim](https://github.com/lgekman/diskim) package. If it is not
installed you will get a warning and an instruction when you source
`Envsettings`;

```
~/xcluster$ . ./Envsettings.k8s 
"diskim" is missing. Install with;

wget -O - -q \
 https://github.com/lgekman/diskim/releases/download/1.0.0/diskim-1.0.0.tar.xz \
 | tar -I xz -C /home/guest/xcluster/workspace -xf -
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
xc ximage iptools
xc start
```

## Kernel

Prerequisite; `diskim` is installed.

Download the kernel from https://www.kernel.org/ to $ARCHIVE (default
$HOME/Downloads), then;

```
xc kernel_build
```

The kernel modules are included in the bzImage in an "init ramfs".

### Alter the kernel config

```
xc kernel_build --menuconfig
```

### New kernel

```
export __kver=linux-5.18.2
export __kcfg=$MY_CONFIGS/$__kver
cp config/linux-5.18.2 $__kcfg
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
