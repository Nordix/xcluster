# Xcluster - ovl/k8s-cni-flannel

Use the `flannel` CNI-plugin in `xcluster`.

Dual-stack support was added in v0.15.0. Ipv6-only doesn't work.

## Build

Pre-load the private registry;
```
for n in $(images lreg_missingimages k8s-cni-flannel)
  images lreg_cache $n
done
```

Update the manifest;
```
curl -L https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml > kube-flannel.yml
git difftool kube-flannel.yml
meld kube-flannel.yml default/etc/kubernetes/load/kube-flannel.yaml
```

## Test

```
xcadmin k8s_test --cni=flannel test-template basic > /dev/null
```
