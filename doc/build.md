# Build xcluster

Describes howto build kernel, images and some overlays (including
Kubernetes) from scratch. This may be necessary for instance if your
distribution is incompatible with the binary release.

Also how to create a binary release is described here.

## Environment setup

Clone the `xcluster` repository. Then setup your environment for
development;

```
cd $HOME                       # (or some other place)
git clone https://github.com/Nordix/xcluster.git
export ARCHIVE=$HOME/archive
mkdir -p $ARCHIVE              # Downloaded items stored here
export XCLUSTER_WORKSPACE=$HOME/tmp/xlcuster/workspace
mkdir -p $XCLUSTER_WORKSPACE   # Keep separated from the xcluster repo
cd xcluster
. ./Envsettings
# Install diskim according to the printout
```

## Kernel and base image

Please see the also the [image](image.md) documentation. Below is the
short version. Sources are downloaded to `$ARCHIVE` if needed.

```
xc kernel_build     # Unpacked on $ARCHIVE if needed
xc busybox_build
xc iproute2_build
# This will probably fail! But don't worry, "ip" is probably built fine so
# just go on...
xc dropbear_build
./image/tar - | tar t   # OPTIONAL! Check what goes into the image
xc mkimage
```

Your base system is ready. Test it;

```
xc nsadd 1
xc nsenter 1
cd $HOME/xcluster
. ./Envsettings
xc start --nrouters=0 --nvm=2
xc stop
exit        # from the netns
```

## Overlays

Clear the cache;

```
xc cache --clear
```

### Systemd

This is by far the worst overlay to build. Read more in the overlay
[readme](../ovl/systemd/README.md).

```
cd $($XCLUSTER ovld systemd)
./systemd.sh download
./systemd.sh unpack
cd $XCLUSTER_WORKSPACE/util-linux-2.31
./configure; make -j$(nproc)
cd -
./systemd.sh make clean
./systemd.sh make -j$(nproc)
# Cache it an never look back;
xc cache systemd
SETUP=ipv6 xc cache systemd
```

### Iptools

Tools such as `iptables` or `ipset` must be built to a specific kernel
so they can not be taken from your host machine.

```
cd $($XCLUSTER ovld iptools)
./iptools.sh download
./iptools.sh build
# Cache it;
xc cache iptools
SETUP=ipv6 xc cache iptools
```

## Kubernetes overlays

These overlays are needed to run [Kubernetes](https://kubernetes.io/)
on `xcluster`.


### Ovl etcd

```
cd $($XCLUSTER ovld etcd)
./etcd.sh download
# Cache it;
xc cache etcd
SETUP=ipv6 xc cache etcd
```

### Ovl gobgp

```
cd $($XCLUSTER ovld gobgp)
./gobgp.sh zdownload
./gobgp.sh zbuild
go get -u github.com/golang/dep/cmd/dep
go get -u github.com/osrg/gobgp
cd $GOPATH/src/github.com/osrg/gobgp
dep ensure
go install ./cmd/...
# Cache it;
xc cache gobgp
SETUP=ipv6 xc cache gobgp
```

### Kubernetes

Read the overlay [readme](../ovl/kubernetes/README.md). Here is the
short version;

Cri-o;

```
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
make
go get -u github.com/kubernetes-incubator/cri-o
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
git checkout -b release-1.12
make install.tools
make
strip bin/*
```

Build the plugins with;

```
go get github.com/containernetworking/plugins/
cd $GOPATH/src/github.com/containernetworking/plugins
./build.sh
strip bin/*
```

Kubernetes;

```
curl -L https://dl.k8s.io/v1.12.0/kubernetes-server-linux-amd64.tar.gz \
  > $ARCHIVE/kubernetes-server-linux-v1.12.0-amd64.tar.gz
tar -C $ARCHIVE -xf $ARCHIVE/kubernetes-server-linux-v1.12.0-amd64.tar.gz
export KUBERNETESD=$ARCHIVE/kubernetes/server/bin
strip $KUBERNETESD/*
cd $($XCLUSTER ovld kubernetes)
./kubernetes.sh runc_download
# Do not cache but test with
xc mkcdrom kubernetes
```

Optional: skopeo;

The `skopeo` program is not required on the cluster but is a good
troubleshooting tool.

```
xc cache skopeo
SETUP=ipv6 xc cache skopeo
```

### Kube-router

```
go get -u github.com/cloudnativelabs/kube-router
go get github.com/matryer/moq
cd $GOPATH/src/github.com/cloudnativelabs/kube-router
make clean; make
# Cache it;
xc cache kube-router
# (ipv6 not supported yet)
```

### Pre-pulled images

Some kubernetes images must be built and be "pre-pulled". Read more in
the image overlay [readme](../ovl/images/README.md). To build an image
overlay requires `docker` access (without root) and `sudo`. It also
requires that the `skopeo` program is available.

Prepare host (if needed);

```
cd $($XCLUSTER ovld images)
sudo mkdir -r /etc/containers
sudo cp policy.json storage.conf /etc/containers
```

Build CoreDNS;

```
go get -u github.com/coredns/coredns
cd $GOPATH/src/github.com/coredns/coredns
make
mkdir -p $GOPATH/bin
mv coredns $GOPATH/bin
```

Create the images overlay;

```
cd $($XCLUSTER ovld images)
docker rmi example.com/coredns:0.1
./images.sh make coredns docker.io/nordixorg/mconnect:0.2
eval $($XCLUSTER env | grep XCLUSTER_TMP)
ls $XCLUSTER_TMP   # An "images.tar" should be here
```

## Kubernetes disk image

```
curl -L https://github.com/Nordix/mconnect/releases/download/v0.2/mconnect \
  > $GOPATH/bin/mconnect
chmod a+x $GOPATH/bin/mconnect
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd-k8s.img
xc mkimage
xc ximage systemd etcd iptools kubernetes coredns mconnect images
```

Test it as described in the [Quick-start](../README.md#quick-start).

## Release

Build everything as described above.

Make sure the ovl cache looks like this;

```
> xc cache --list
Cache dir [.../workspace/xcluster/cache];
ipv6/gobgp.tar.xz
ipv6/iptools.tar.xz
ipv6/systemd.tar.xz
ipv6/etcd.tar.xz
ipv6/skopeo.tar.xz
default/kube-router.tar.xz
default/gobgp.tar.xz
default/iptools.tar.xz
default/systemd.tar.xz
default/etcd.tar.xz
default/skopeo.tar.xz
```

Create the release tar and compress it;

```
ver=v0.3
cd $(dirname $XCLUSTER)
./xcadmin.sh release --version=$ver
pxz /tmp/xcluster-$ver.tar
```

Test!

```
git tag $ver
git push origin $ver
```
