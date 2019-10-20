Xcluster overlay - images
=========================

Handles pre-pulled images in `xcluster`.

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


## Preparations

```
cd $($XCLUSTER ovld images)
sudo mkdir /etc/containers
sudo cp policy.json storage.conf /etc/containers
```

## Usage

An image overlay is created with the `images.sh` script. By default it
is created in the `$XCLUSTER_TMP` directory. The items may be;

 * A docker image reference. The version must be included.
 * An overlay dir. The `image/` dir in the overlay will be used.
 * An overlay dir and subdir, like `proxy/image2`

```
# ("images" alias defined in $h/Envsettings)
images make coredns nordixorg/mconnect:v1.2 ...  # Requires "sudo"
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

### The old way

The old way using a `manifest.json` file is still supported but is
obsolete.

The principle is;

 * Create a tar-file with the root fs.

 * Import it with `docker import`

When a overlay dir is given to `images.sh` it looks for an `image/'
subdir in that overlay dir. In the `image/` subdir there must be a
`tar` script, working exactly as for overlays.

In the `image/` dir there must also be a manifest named
`manifest.json`. The only things used are;

 1. Name
 2. Version
 3. Start command

With the `images/` subdir, the `images/tar` script and the
`images/manifest.json` the overlay dir can be specified as an item to
`images.sh`.



## Problems and future plans

The current procedure su*** !

What I want is a way to import images from a docker registry or a tar
directly to a containers-storage structure as non-root. `skopeo` would
be perfect if it allowed a destination dir to be specified.

There are
[many-ways](https://www.projectatomic.io/blog/2018/03/the-many-ways-to-build-oci-images/)
to build OCI images. Neither is good.


### Tools

The tools and `cri-o` itself uses the libraries in
[containers/storage](https://github.com/containers/storage) to handle
images. The library (and hence all tools) uses config in
`/etc/containers/storage.conf` (hard-coded!). The lib also reqires
"root".

Skopeo is used by `xcluster` so it must be installed. This other tools are
optional.

Skopeo is hard to build locally but fortunately the Ubuntu package
works;

```
sudo apt-add-repository ppa:projectatomic/ppa
sudo apt-get update
sudo apt-get install skopeo
mkdir /tmp/x
skopeo --insecure-policy copy docker://k8s.gcr.io/pause:3.1 dir:/tmp/x
skopeo --insecure-policy copy docker://k8s.gcr.io/pause:3.1 oci:/tmp/x:k8s.gcr.io/pause:3.1
```

There is a `containers-storage` utility bundled with the lib.  Build
with;

```
sudo apt install libdevmapper-dev -y
cd $GOPATH/src/github.com/containers/storage
go install ./cmd/...
strip $GOPATH/bin/containers-storage
```

#### image-tools

```
go get github.com/opencontainers/image-tools
cd go/src/github.com/opencontainers/image-tools
go install ./cmd/...
strip $GOPATH/bin/oci-image-tool
```

#### Test commands

```
skopeo --debug inspect docker://docker.io/fedora
kubectl run hello-world --replicas=2 --labels="run=load-balancer-example" --image=gcr.io/google-samples/node-hello:1.0  --port=8080
skopeo --debug inspect docker://gcr.io/google-samples/node-hello:1.0
skopeo --debug inspect docker://k8s.gcr.io/pause
skopeo --debug copy docker://gcr.io/google-samples/node-hello:1.0 \
  containers-storage:gcr.io/google-samples/node-hello:1.0
skopeo --debug copy docker://docker.io/library/alpine:3.8 \
  containers-storage:docker.io/library/alpine:3.8
kubectl create -f https://k8s.io/examples/pods/simple-pod.yaml
```
