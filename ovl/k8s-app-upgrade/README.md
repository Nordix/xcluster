# Xcluster/ovl - k8s-app-upgrade

Test of application upgrade in Kubernetes. [Ctraffic](
https://github.com/Nordix/ctraffic) is used to show traffic impact

A Deplyment is upgraded using [rolling upgrade](
https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment)





## Test

Build a ":local" mserver image (assuming the :latest exist already):
```
cdo mserver
./mserver.sh mkimage --tag=registry.nordix.org/cloud-native/mserver:local
```

```
./k8s-app-upgrade.sh   # Help printout
./k8s-app-upgrade.sh test --scheduler=lc upgrade_image
```
