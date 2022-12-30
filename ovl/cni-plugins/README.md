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

## Trace

A wrapper can be installed over a cni-plugin to trace invocatios.

```
export xcluster_CNI_PLUGIN_TRACE=bridge
# (include the cni-plugins ovl)
```
If included in another ovl, add:
```
cp -r $($XCLUSTER ovld cni-plugins)/trace/* $tmp
```

A wrapper will take the place of the cni-plugin and log to
`/var/log/cni-trace`. The original cni-plugin will be renamed with a
`-orig` suffix.

```
# cat /var/log/cni-trace 
=============================================================
--------- Environment
CNI_PATH=dummy
CNI_ARGS=
CNI_CONTAINERID=
CNI_NETNS=dummy
CNI_IFNAME=dummy
CNI_COMMAND=VERSION
--------- Stdin
{
  "cniVersion": "1.0.0"
}
--------- Stdout
{
  "cniVersion": "1.0.0",
  "supportedVersions": [
    "0.1.0",
    "0.2.0",
    "0.3.0",
    "0.3.1",
    "0.4.0",
    "1.0.0"
  ]
}
```

