# Overlays

In the earliest stage of start all VMs are mounting an iso image
(cdrom) that may contain any number of tar-files called
"overlays". The files are unpacked on root "/" in sort order and
provides a primitive packaging system. The iso image is created from
ovl directories. Example;

```
# Start an xcluster with overlays
xc mkcdrom systemd etcd; xc start
```

An overlay can either be a tar file or a directory containing a `tar`
script;

```
> ls -F $($XCLUSTER ovld skopeo)
README.md  tar*
```

Xcluster will search for the ovl's in the `$XCLUSTER_OVLPATH`.

The "tar" script must create a tar file for the overlay and take the
out-file as parameter. The out file may be "-" for 'stdout' which
allows a neat trick for checking the contents of an overlay;

```
> cd $($XCLUSTER ovld externalip)
> ./tar - | tar t
etc/
etc/init.d/
etc/init.d/30router.rc
etc/kubernetes/
etc/kubernetes/mconnect.yaml
```

## The SETUP variable

A primitive way to allow variations for overlays. It is up to the
"tar" script in the overlay to interpret the SETUP variable. Example;

```
SETUP=ipv6 xc mkcdrom etcd coredns k8s-config
```

## Overlay cache

Overlays may be cached. This server two purposes;

 1. Speed up overlays that take time to build

 2. Pre-build overlays that are particularly hard to build

Overlays are not cached automatically you must cache them;

```
xc cache systemd etc
xc cache --list
xc cache --clear   # Clears the cache
```

The `xcluster` binary release contains some cached overlays for
Kubernetes setup that you usually should keep.

