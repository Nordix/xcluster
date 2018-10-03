Xcluster overlay - images
=========================

Handles pre-pulled images in cri-o

`Cri-o` stores images with
[containers/storage](https://github.com/containers/storage). This is
very complicated and the lib requires "root" and uses hard-coded
paths. The unpacking, e.g using
[skopeo](https://github.com/containers/skopeo) is also horrible slow
and causes the start-up to fail (overloads the `mqueue` I think) in
xcluster.

All-in-all it's a mess.

What we want to do is to create an overlay with the
`containers-storage` structure containing all images from
start. Unfortunately we must do this is one file, it can not be done
from the overlay's containing the images, and it requires "sudo".


Usage
-----

```
# ("images" alias defined in $h/Envsettings)
images make coredns docker.io/nordixorg/mconnect:0.2
xc mkcdrom [overlays...] images
```

You will be prompted for `password` for `sudo skopeo`.


Build images
------------

There are
[many-ways](https://www.projectatomic.io/blog/2018/03/the-many-ways-to-build-oci-images/)
to build OCI images. Neither is good.

Uses the (configurable) root directory `/var/lib/containers/storage`.


### Pre-pull

To pre-pull images, which is necessary in `xcluster` is very hard. The
images must be visible on;

```
> crictl --runtime-endpoint=unix:///var/run/crio/crio.sock images
IMAGE                          TAG                 IMAGE ID            SIZE
docker.io/nordixorg/mconnect   0.2                 d52a1329f66d7       1.89MB
example.com/coredns            0.1                 9914622955cf0       38.7MB
k8s.gcr.io/pause               3.1                 da86e6ba6ca19       746kB
```

The current approach is;

* Use the old ACI manifest but import the images to `docker` locally.

* Use `skopeo` (with sudo) to create a tar-file with the images in
  containers-storage format.

* Use the tar-file as an `xcluster` overlay.

An advantage is that the `xcluster` image starts up with the images loaded
nad ready. With `rkt` the images were installed on each node on
startup.


Tools
-----

The tools and `cri-o` itself uses the libraries in
[containers/storage](https://github.com/containers/storage) to handle
images. The library (and hence all tools) uses config in
`/etc/containers/storage.conf` (hard-coded!). The lib also reqires
"root".

You should install `storage.conf` and `policy.json` from this overlay.

### skopeo

Skopeo is used by `xcluster` so it must be installed. This other tools are
optional.

Skopeo is hard to build locally but fortunately the Ubuntu package
works fine;

```
sudo apt-add-repository ppa:projectatomic/ppa
sudo apt-get update
sudo apt-get install skopeo
mkdir /tmp/x
skopeo --insecure-policy copy docker://k8s.gcr.io/pause:3.1 dir:/tmp/x
skopeo --insecure-policy copy docker://k8s.gcr.io/pause:3.1 oci:/tmp/x:k8s.gcr.io/pause:3.1
```

### containers-storage

There is a `containers-storage` utility bundled with the lib.  Build
with;

```
sudo apt install libdevmapper-dev -y
cd $GOPATH/src/github.com/containers/storage
go install ./cmd/...
strip $GOPATH/bin/containers-storage
```

### image-tools

```
go get github.com/opencontainers/image-tools
cd go/src/github.com/opencontainers/image-tools
go install ./cmd/...
strip $GOPATH/bin/oci-image-tool
```


### Test commands

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
