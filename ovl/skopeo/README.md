# Xcluster ovl - Skopeo

Add the [skopeo](https://github.com/containers/skopeo) image utility.

Prerequisite; `skopeo` is installed on the host.


## Usage

`Skopeo` uses the same libraries as `cri-o` so it will experience the
same problems. When image pull fails it is easier to troubleshoot with
`skopeo` than analyzing `cri-o` logs.

```
# Test connectivity
skopeo -debug inspect docker://docker.io/library/alpine:3.8
# Pre-pull an image
skopeo -debug copy docker://docker.io/library/alpine:3.8 \
  containers-storage:docker.io/library/alpine:3.8
images
```

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
