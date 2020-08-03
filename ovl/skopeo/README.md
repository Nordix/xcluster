# Xcluster ovl - Skopeo

Add the [skopeo](https://github.com/containers/skopeo) image utility.


`Skopeo` uses the same libraries as `cri-o` so it will experience the
same problems. When image pull fails it is easier to troubleshoot with
`skopeo` than analyzing `cri-o` logs.

```
# Test connectivity
skopeo -debug inspect docker://docker.io/library/alpine:3.8
# Pre-pull an image
skopeo -debug copy docker://docker.io/library/alpine:3.8 \
  containers-storage:docker.io/library/alpine:3.8
```

## Pre-pulled K8s images

An init-script will pre-load any images in archives (uncompressed tar
files) in `/var/lib/pre-loaded-images` on worker nodes.

Create an archive with the [images](../images/README.md) utility;

```
images docker_save --output=/tmp/pre-loaded-images.tar <images>
```

The images must exist in the local docker-daemon repo. Prefixes
`docker.io/` and `docker.io/library/` are implicit and must be omitted
from the image names.


## Local build

Follow the
[instructions](https://github.com/containers/skopeo#building-without-a-container) on github;

```

sudo apt install libgpgme-dev libassuan-dev btrfs-progs \
  libdevmapper-dev libostree-dev
git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo
cd $GOPATH/src/github.com/containers/skopeo
make bin/skopeo
mv ./bin/skopeo $GOPATH/bin
```

### Build and install

```
go get github.com/cpuguy83/go-md2man  # (if needed)
cd $GOPATH/src/github.com/containers/skopeo
skopeod=$GOPATH/src/github.com/containers/skopeo/sys
make DESTDIR=$skopeod install
# View man pages
man $skopeod/usr/share/man/man1/skopeo.1
man $skopeod/usr/share/man/man1/skopeo-list-tags.1
```

## Create a base archive

Create an archive with the `xcluster` base images with;
```
export BASE_IMAGES=/tmp/base-images.tar
images docker_save --output=$BASE_IMAGES \
  $(./xcadmin.sh prepulled_images | sed -e 's,docker.io/,,' -e 's,library/,,')
```
