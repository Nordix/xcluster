# Xcluster ovl - k8s-base

A minimal image with [BusyBox](https://busybox.net/) intended as a
base for other images that need some fundamental functions, for
instance a shell for scripting and troubleshoting.

## Usage

Prequisite; A [local private docker registry](../private-reg/) is started.

```
images mkimage --force --upload ./image
xc mkcdrom private-reg k8s-base; xc starts
# Or;
SETUP=ipv6 xc mkcdrom etcd private-reg k8s-config k8s-base; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/xcbase.yaml
kubectl get pods
kubectl exec -it xcbase-... sh
kubectl get svc xcbase
wget -q -O - http://xcbase.default.svc.xcluster/cgi-bin/info
wget -q -O - http://xcbase.default.svc.xcluster/cgi-bin/env
```
