# Xcluster testing

A wise advice I once got;

> It doesn't matter how you write the tests, just write them!

The danger is to spend too much time searching for the perfect tool so
at the end of the day no tests are written.

The `xcluster` test system is in an overlay (of course), please see
[ovl/test](../ovl/test). It is a framework in "shell" (not bash).

Examine the script lib, help printout with;
```
$($XCLUSTER ovld test)/default/usr/lib/xctest help
```

Tests programs should be placed in ovl's and are invoked with;

```
t=test-template
$($XCLUSTER ovld $t)/$t.sh test > $XCLUSTER_TMP/$t-test.log
```

That means that the ovl directory should have an executabe that is
named "ovl-name.sh" that takes "test" as a parameter. The
`test-template` is a template for this. It assumes Kubernetes but can
be altered.

The test program shall print test summary on `stderr` and verbose
logging to `stdout`.


## Private Docker Registry

Some tests downloads and installs images. The download speed varies a
lot so a reasonable timeout is impossible to set. To ensure fast and
stable download times a local private Docker registry is used. Howto
setup one is described in the [private-reg](../ovl/private-reg/README.md)
overlay.

The private registry can be manages by the `images.sh` script in
[ovl/images](../ovl/images). The `images` alias is setup;

```
$ images
   lreg_ls
     List the contents of the local registry.
   lreg_cache <external-image>
     Copy the image to the private registry. If this fails try "docker pull"
     and then "images lreg_upload ...". Example;
       images lreg_cache docker.io/library/alpine:3.8
   lreg_upload [--strip-host] <docker_image>
     Upload an image from you local docker daemon to the privare registry.
     Note that "docker.io" and "library/" is suppressed in "docker images";
       lreg_upload library/alpine:3.8
       lreg_upload --strip-host docker.io/library/alpine:3.8
   lreg_inspect <image:tag>
     Inspect an image in the private registry.
   lreg_rm <image:tag>
     Copy the image to the private registry.
   lreg_isloaded <image:tag>
     Returns ok if an image is loaded.
   lreg_missingimages <dir/ovl>
     List non-cached images.
   getimages <dir/ovl>
     List images.
   lreg_preload [--force] [--keep-going] <dir/ovl>
     Pre-load images for an ovl. --force loads already-loaded images.
...
```

