# Xcluster - ovl/k8s-cni-flannel

Use the [flannel](https://github.com/flannel-io/flannel)
CNI-plugin in `xcluster`.

Dual-stack support was added in v0.15.0. Ipv6-only doesn't work.

## Build

Pre-load the private registry;
```
images lreg_preload k8s-cni-flannel
```

Update the manifest;
```
ver=v0.24.2
curl -L https://github.com/flannel-io/flannel/releases/download/$ver/kube-flannel.yml > kube-flannel-new.yml
cp kube-flannel-new.yml kube-flannel-orig.yml
# check the old updates and apply them 
meld kube-flannel.yml default/etc/kubernetes/load/kube-flannel.yaml kube-flannel-new.yml
# the diff may be too large, so update "net-conf.json:" "FLANNELD_IFACE" manually
mv -f kube-flannel-new.yml default/etc/kubernetes/load/kube-flannel.yaml
mv -f kube-flannel-orig.yml kube-flannel.yml
```

## Test

```
xcadmin k8s_test --cni=flannel test-template basic > /dev/null
```
