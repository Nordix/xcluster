# Xcluster/ovl - cni-plugins

Installs [cni-plugins](https://github.com/containernetworking/plugins)
in `/opt/cni/bin`. The intention is to have a uniform way of installing
cni-plugins rather than letting every ovl using it's own way.

## Usage

Include `ovl/cni-plugins` when building the cdrom or include this ovl
in another ovl's tar-file;

```
mkdir -p $tmp/opt/cni/bin
x=$($XCLUSTER ovld cni-plugins)/cni-plugins.sh
$x install --dest=$tmp/opt/cni/bin || die
# Or
$x install --dest=$tmp/opt/cni/bin host-local bridge loopback || die
```
