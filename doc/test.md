# Xcluster testing

No "tool" or procedure required, do as you please. There is a minimal
framework in "shell" (not bash) that may be useful. A wise advice I
once got;

> It doesn't matter how you write the tests, just write them!

The danger is to spend too much time searching for the perfect tool so
at the end of the day no tests are written.

Tests are placed in ovl's and are invoked with;

```
t=test-template
$($XCLUSTER ovld $t)/$t.sh test > $XCLUSTER_TMP/$t-test.log
```

That means that the ovl directory should have an executabe that is
named "ovl-name.sh" that takes "test" as a parameter. The
`test-template` is a template for this (of course).

The test program shall print test summary on `stderr` and verbose
logging to `stdout`.


## Test ovl and script library

Check the [test overlay](../ovl/test/README.md).

Examine the script lib, help printout with;
```
$($XCLUSTER ovld test)/default/usr/lib/xctest help
```



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
