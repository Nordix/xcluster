# Xcluster ovl - k8s-base

Creates the `xcluster` base image. It is basically the same as the
`hd.image` with `ovl/iptools` installed. The image is intended as base
for other images, used in a "Dockerfile" like;

```
FROM registry.nordix.org/cloud-native/xcluster-base:latest
```

## Test

Prequisite; A [local private docker registry](../private-reg/) is started.

```
./base-image.sh test > $log
```
