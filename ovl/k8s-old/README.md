# ovl/k8s-old - Older Kubernetes

Use older versions of Kubernetes in `xcluster`.

## Build images

```
export __k8sver=v1.10.13
export __criover=1.14   # Pre-requisite; this version of cri-o must be built
./xcadmin.sh k8s_build_images
#k8s build_images --version=$__k8sver
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd-k8s-$__k8sver.img
rm -f $XCLUSTER_HOME/hd-k8s-xcluster-$__k8sver.img
ls -lh $__image
# Test
xc mkcdrom test test-template k8s-old; xc starts
$($XCLUSTER ovld test-template)/test-template.sh test --no-start basic4 > $log
# Extend the image
chmod u+w $__image
xc ximage k8s-old
xc mkcdrom test test-template; xc starts
$($XCLUSTER ovld test-template)/test-template.sh test --no-start basic4 > $log
# Upload;
cp $__image /tmp/tmp
xz -T0  /tmp/tmp/hd-k8s-$__k8sver.img
ls -lh /tmp/tmp/hd-k8s-$__k8sver.img.xz
arm_upload_image /tmp/tmp/hd-k8s-$__k8sver.img.xz
rm -f /tmp/tmp/hd-k8s-$__k8sver.img.xz
```


### Cri-o

```
./k8s-old.sh --criover=1.14
```
