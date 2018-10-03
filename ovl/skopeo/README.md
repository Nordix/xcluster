# Xcluster ovl - Skopeo

Add the [skopeo](https://github.com/containers/skopeo) inage utility.

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

