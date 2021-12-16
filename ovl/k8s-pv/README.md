# Xcluster/ovl - k8s-pv


K8s [persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) in xcluster.

Based on [rancher/local-path-provisioner](https://github.com/rancher/local-path-provisioner).

## Usage

Prepare;
```
for n in $(images lreg_missingimages .); do
  images lreg_cache $n
done
```

Manual test;
```
./k8s-pv.sh test start > $log
kubectl apply -k github.com/rancher/local-path-provisioner/examples/pod?ref=master
# On a node;
kubectl get storageclass
kubectl get pvc -A
kubectl get pv -A
```
