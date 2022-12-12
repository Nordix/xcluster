# Xcluster - ovl/k8s-cni-calico

Use [project calico](https://www.projectcalico.org/) in `xcluster`.

## Usage

Start, preload if needed;
```
#images lreg_preload k8s-cni-calico
xcadmin k8s_test --cni=calico test-template start_empty > $log
```

## Test

```
xcadmin k8s_test --cni=calico test-template > $log
```

## Upgrade

```
cdo k8s-cni-calico
curl https://docs.projectcalico.org/manifests/calico.yaml -O
# Check the xcluster specific config. (3-way diff)
cp calico.yaml calico-new.yaml
meld calico-orig.yaml default/etc/kubernetes/load/calico.yaml calico-new.yaml &
# Make the corresponding in the new "calico.yaml"
#cp calico.yaml calico-new.yaml
#ec calico-new.yaml
cp calico-new.yaml default/etc/kubernetes/load/calico.yaml
images lreg_preload default
# Cache images
# Test!
mv -f calico.yaml calico-orig.yaml
# Commit updates
```


## Build

Build an image with dual-stack and calico pre-pulled;
```
ver=v3.22.1
docker pull calico/cni:$ver
docker pull calico/node:$ver
docker pull calico/kube-controllers:$ver
docker pull calico/pod2daemon-flexvol:$ver
images make coredns nordixorg/mconnect:v1.2 library/alpine:3.8 \
  calico/cni:$ver calico/node:$ver calico/kube-controllers:$ver calico/pod2daemon-flexvol:$ver
#export KUBERNETESD=$ARCHIVE/kubernetes/server/bin
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster-cni-calico.img
cp $XCLUSTER_WORKSPACE/xcluster/hd.img $__image
xc ximage xnet etcd iptools k8s-xcluster mconnect images coredns k8s-cni-calico
# Test;
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
t=test-template
$($XCLUSTER ovld $t)/$t.sh test basic_dual > /dev/null
```

### Install calicoctl

```
ver=v3.23.1
curl -L \
 https://github.com/projectcalico/calico/releases/download/$ver/calicoctl-linux-amd64 \
 > $GOPATH/bin/calicoctl
chmod a+x $GOPATH/bin/calicoctl
```

## Doc/check

* https://docs.projectcalico.org/v3.8/networking/ipv6

* https://docs.projectcalico.org/v3.8/reference/felix/configuration

* https://docs.projectcalico.org/v3.8/getting-started/calicoctl/install

```
logs -n kube-system calico-node-cn5fv | grep -i "Successfully loaded configuration"
```
