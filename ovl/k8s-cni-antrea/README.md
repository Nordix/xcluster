# Xcluster/ovl - k8s-cni-antrea

K8s cni-plugin [Antrea](https://github.com/antrea-io/antrea)

Upgrade;
```
tag=v1.11.1
curl -L https://github.com/antrea-io/antrea/releases/download/$tag/antrea.yml\
 > antrea.yaml
```

Test;
```
images lreg_preload k8s-cni-antrea
xcadmin k8s_test --cni=antrea test-template > $log
```


## Build

```
# Clone
rm -rf $GOPATH/src/github.com/antrea-io/antrea
cd $GOPATH/src/github.com/antrea-io
git clone --depth 1 https://github.com/antrea-io/antrea.git \
  $GOPATH/src/github.com/antrea-io/antrea
# Build
cd  $GOPATH/src/github.com/antrea-io/antrea
...
```