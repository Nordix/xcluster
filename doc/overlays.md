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

**NOTE**; You do not normally install SW on a running `xcluster`,
instead you create an overlay, include it in `xc mkcdrom` and
re-start. This is not what you are used to from other systems but has
number of advantages, for instance;

 * You always start from the same point. The system is never "tainted"
   by some previous action. This is a really big advantage for testing
   but also for development.

 * The system setup is simple to preserve, re-create and document in
   the ovl dir.

 * To switch between wastly different setups is done in seconds, for
   instance switch to ipv6-only for Kubernetes.


An overlay can be created from directory containing a `tar` script;

```
> ls -F $($XCLUSTER ovld timezone)
default/ README.md  tar*
```

The `timezone` overlay dir is a good template.

Xcluster will search for the ovl directories in the
`$XCLUSTER_OVLPATH`. Copy the `timezone` dir to some place of your
liking and add to the `$XCLUSTER_OVLPATH`;

```
mkdir -p $HOME/work/xcluster-ovls
cp -r $($XCLUSTER ovld timezone) $HOME/work/xcluster-ovls/work
export XCLUSTER_OVLPATH="$HOME/work/xcluster-ovls/work:$XCLUSTER_OVLPATH"
# (modify you "work" overlay dir)
xc mkcdrom work; xc start
```

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

