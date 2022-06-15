# Alpine image for xcluster

This is most for fun.


## Create a disk image from docker

Since the image does not have to be bootable this is a simple way.  We
use the `images` script form "ovl/images" which in turn requires
[diskim](https://github.com/lgekman/diskim).

The "initfs" in `xcluster` kernels calls `/init` so we must ensure
that it exists with a simple ovl. We must mount /sys and /proc since
they are not mounted by docker;

```
mkdir /tmp/init
cat > /tmp/init/init <<EOF
#! /bin/sh
mkdir -p /sys /proc
mount -t sysfs sysfs /sys
mount -t proc procfs /proc
mdev -s
exec /bin/sh
EOF
chmod a+x /tmp/init/init
```

Create the image and start;
```
images docker_export alpine:latest > /tmp/alpine.tar
export __image=/tmp/alpine.img
diskim mkimage /tmp/alpine.tar /tmp/init
xc start --nvm=1 --nrouters=0
```

While this works and is good for educational purposes it has no
practical use.


### Better start and networking

An "xcluster like" image ovl is prepared;

```
images docker_export alpine:latest > /tmp/alpine.tar
export __image=/tmp/alpine.img
diskim mkimage /tmp/alpine.tar ./image/alpine
xc start --nvm=1 --nrouters=0
```

Now you should have basic networking but the Alpine image has no
servers so login with `ssh` or `telnet` does not work. The dns is by
default set to 8.8.8.8 which works but should be avoided!

To specify a DNS use `ovl/env`;
```
xcluster_DNS=192.168.10.1 xc mkcdrom env
xc start --nvm=1 --nrouters=0
# On the VM;
cat /etc/resolv.conf
```

The specified DNS address shall appear in `/etc/resolv.conf`.




