# Xcluster ovl - virtualbox

Describes howto create a [VirtualBox](https://www.virtualbox.org/) image.

**NOTE**: The `xcluster` cluster functions can't really be used with
VirtualBox. However the ovl function can be used to create usable images.

## Kernel re-build

`Xcluster` uses [virtio](https://www.linux-kvm.org/page/Virtio)
disks. They show up as for instance `/dev/vda` in Linux. VirtualBox
does not support virtio disks so we must configure and re-build the
`xcluster` kernel to support ATA disks. Also `xcluster` uses the
serial link as console, VirtualBox uses a virtual screen.

```
./vbox.sh kernel_build [--menuconfig]
```


## Hd image

Set `$__image` so no existing image is overwritten.

```
export __image=/tmp/$USER/vbox.qcow2
./vbox.sh mkimage [ovls...]
```

Test with kvm;
```
kvm -hda $__image
```

### Alpine

```
export __image=/tmp/$USER/vbox.qcow2
./vbox.sh mkimage --alpine=alpine:latest [ovls...]
```

Extended Alpine example;
```
docker build -t alpine-xcluster:latest alpine
./vbox.sh mkimage --alpine=alpine-xcluster:latest
```


## Convert to vdi format

```
qemu-img convert -f qcow2 $__image -O vdi $VBOXDIR/xcluster.vdi
```

## VirtualBox network setup

All networks *must* be `virtio-net`.The first network should be a
`NAT` network. You may add port forwarding to port 23 (telnet);

<img src="vbox-net.png" alt="VBox network screenshot" width="80%" />
