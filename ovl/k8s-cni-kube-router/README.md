# Xcluster/ovl - k8s-cni-kube-router

* Use the `kube-router` turn-key solution


## Prep

```
curl -L https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/generic-kuberouter-all-features.yaml > generic-kuberouter-all-features.yaml
sed -e 's,%CLUSTERCIDR%,11.0.0.0/16,' -e 's,%APISERVER%,http://192.168.1.1:8080,' < generic-kuberouter-all-features.yaml > ipv4/etc/kubernetes/load/kuberouter.yaml
vi ipv4/etc/kubernetes/load/kuberouter.yaml # Set version v1.0.0
k8s checkimages k8s-cni-kube-router
images lreg_cache docker.io/cloudnativelabs/kube-router:v1.0.0
```


## Test

```
log=/tmp/$USER/xcluster/test.log
xcluster_PROXY_MODE=disabled ./xcadmin.sh k8s_test --cni=kube-router \
  --k8sver=v1.18.5 test-template basic4 > $log
```