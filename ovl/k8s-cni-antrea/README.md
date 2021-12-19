# Xcluster/ovl - k8s-cni-antrea

K8s cni-plugin [Antrea](https://github.com/antrea-io/antrea)

Prepare;
```
for n in $(images lreg_missingimages .); do
  images lreg_cache $n
done
```

Test;
```
xcadmin k8s_test --cni=antrea test-template > $log
```


## Build

```
# Clone
mkdir -p $GOPATH/src/github.com/antrea-io
cd $GOPATH/src/github.com/antrea-io
git clone --depth 1 https://github.com/antrea-io/antrea.git
# Build
cd  $GOPATH/src/github.com/antrea-io/antrea
...
```