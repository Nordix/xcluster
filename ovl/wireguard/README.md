# Xcluster ovl - WireGuard

Use [WireGuard](https://www.wireguard.com/) in `xcluster`.

https://www.digitalocean.com/community/tutorials/how-to-create-a-point-to-point-vpn-with-wireguard-on-ubuntu-16-04

## Usage

```
# Use base xcluster, no k8s;
eval $($XCLUSTER env | grep XCLUSTER_HOME=)
export __image=$XCLUSTER_HOME/hd.img
# Start
SETUP=test xc mkcdrom wireguard; xc start --nrouters=0
# On vm-001;
ping 169.0.1.2
# Somewhere else;
tcpdump -ni eth1 udp
# Remove and re-add node vm-003;
wg set wg0 peer $(cat /etc/wireguard/key.vm-003 | wg pubkey) remove
wg set wg0 peer $(cat /etc/wireguard/key.vm-003 | wg pubkey) \
 endpoint 192.168.1.3:51820 allowed-ips 169.0.1.3/32
```

View the man-page;
```
ver=0.0.20181119
man $XCLUSTER_WORKSPACE/WireGuard-$ver/src/tools/man/wg.8
```

## Build

```
ver=0.0.20181119
curl -L https://git.zx2c4.com/WireGuard/snapshot/WireGuard-$ver.tar.xz \
  > $ARCHIVE/WireGuard-$ver.tar.xz
tar -C $XCLUSTER_WORKSPACE -xf $ARCHIVE/WireGuard-$ver.tar.xz
wgd=$XCLUSTER_WORKSPACE/WireGuard-$ver
# Re-build the kernel;
eval $($XCLUSTER env | grep -E '__kver|ARCHIVE')
$wgd/contrib/kernel-tree/jury-rig.sh $ARCHIVE/$__kver
xc kernel_build --kcfg=config/linux-4.19.3.wireguard
# Build user-space tools;
cd $wgd/src
eval $($XCLUSTER env | grep __kobj)
make KERNELDIR=$__kobj -j$(nproc) tools
```

## Generate keys

```
ver=0.0.20181119
alias wg=$XCLUSTER_WORKSPACE/WireGuard-$ver/src/tools/wg
for x in $(seq 1 8); do
  wg genkey > test/etc/wireguard/key.$(printf "vm-%03d" $x)
done
```
