# Xcluster/ovl - k8s-cni-kube-router

* Use the `kube-router` turn-key solution


## Prep

```
curl -L https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/generic-kuberouter-all-features.yaml > generic-kuberouter-all-features.yaml
sed -e 's,%CLUSTERCIDR%,11.0.0.0/16,' < generic-kuberouter-all-features.yaml > ipv4/etc/kubernetes/load/kuberouter.yaml
vi ipv4/etc/kubernetes/load/kuberouter.yaml
# Set version v1.1.0
# Alter kubeconfig to mimic ../kubernetes/default/etc/kubernetes/kubeconfig.token
k8s checkimages k8s-cni-kube-router
images lreg_cache docker.io/cloudnativelabs/kube-router:v1.3.1
```


## Test

```
log=/tmp/$USER/xcluster/test.log
xcluster_PROXY_MODE=disabled xcadmin k8s_test --cni=kube-router \
  test-template basic4 > $log
```