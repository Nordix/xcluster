# Xcluster overlay - images

Handles images in `xcluster`. Holds help script for docker
images, local registry and pre-pulled images.

The script for private registry is the most usable. Check the help printouts:

```
images    # Help printout
# Cache images used by an ovl in the private registry if needed
images lreg_preload k8s-cni-calico
```


## Build local images

An directory with a working `./tar` file and a `Dockerfile` can be
used to create a local image. A temporary docker "context" directory
is created. The `./tar` file is used to produce a `ovl.tar` in that
context which should be used. Here is an example from ovl/metallb;

```
FROM scratch
ADD --chown=0:0 ovl.tar /
CMD ["/bin/controller"]
```

The image can then be build with the "images mkimage" command;

```
images mkimage --force --tag=library/metallb:latest --upload ./image
```


## OBSOLETE: Pre-pulled images

Pre-pulled images as an ovl is very hard to maintain and requires
`sudo`. It is recommended to use a [private registry](../private-reg)
instead.

To install pre-pulled images on the `xcluster` disk image or as an
overlay saves time since nothing has to be dowloaded. In some
environments it is also hard to get external connectivity inside the
VMs.

What we want to do is to create an overlay with the
`containers-storage` structure containing all images we need. This is
not so simple and it requires "sudo", at least for now.

The way this is done at the moment is;

 * Pull or import the image to you local docker-daemon. You should see
   it with `docker images`.

 * Use `skopeo` to copy all pre-pulled images to a containers-storage
   on `/tmp/var`. This requires `sudo`.

 * Tar the `/tmp/var` structure. This also requires `sudo` since
   `skopeo` protects the dir.

 * Use the tar-file as an `xcluster` overlay.


### Preparations

```
cd $($XCLUSTER ovld images)
sudo mkdir /etc/containers
sudo cp policy.json storage.conf /etc/containers
```

### Usage

An image overlay is created with the `images.sh` script. By default it
is created in the `$XCLUSTER_TMP` directory. The items may be;

 * A docker image reference. The version must be included.
 * An overlay dir. The `image/` dir in the overlay will be used.
 * An overlay dir and subdir, like `proxy/image2`

```
# ("images" alias defined in $h/Envsettings)
# Requires "sudo"
images make k8s.gcr.io/pause:3.6 \
  registry.nordix.org/cloud-native/mconnect:latest docker.io/library/alpine:latest
eval $($XCLUSTER env | grep XCLUSTER_TMP)
ls $XCLUSTER_TMP/images.tar
xc mkcdrom [overlays...] images
```

You will be prompted for `password`.

You may notice that the `xc mkcdrom` can take just `images` as
parameter? The secret is in the `tar` script in the images ovl dir.

### Check images on a VM

On the VMs an alias will be set to list the pre-pulled images;

```
alias images="crictl --runtime-endpoint=unix:///var/run/crio/crio.sock images"
```



