# Xcluster testing

No "tool" or procedure is imposed or recommended. To do that at early
stages usually leads to regrets. A wise advice I once got;

> It doesn't matter how you write the tests, just write them!

The danger is to spend too much time searching for the perfect tool so
at the end of the day no tests are written.

## Run tests

Prerequisite; A private docker registry is started and contains
`alpine` and `metallb` images (see below).

```
$(dirname $XCLUSTER)/test/xctest.sh test --xovl=private-reg \
  > /tmp/$USER/xctest.log
# Or a single test;
$(dirname $XCLUSTER)/test/xctest.sh test --list
$(dirname $XCLUSTER)/test/xctest.sh test --xovl=private-reg k8s_metallb \
  > /tmp/$USER/xctest.log
```

## Test structure

For now all tests are in one shell script; `xctest.sh`. This script
configures the `xcluster`, start and stop and invoke on-cluster tests
defined in the [test overlay](../ovl/test/README.md).



## Private Docker Registry

Some tests downloads and installs images. The download speed varies a
lot so a reasonable timeout is impossible to set. To ensure fast and
stable download times a local private Docker registry is used. Howto
setup one is described in the
[private-reg](../ovl/private-reg/README.md) overlay.

Assuming you have downloaded the images to your local docker daemon, do;

```
regip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry)
for n in library/alpine:3.8 metallb/speaker:v0.7.3 metallb/controller:v0.7.3; do
  skopeo copy --dest-tls-verify=false docker-daemon:$n docker://$regip:5000/$n
done
```
