# Xcluster ovl - kubeadm

Install Kubernetes with `kubeadm` in xcluster.
[kubeadm](https://github.com/kubernetes/kubeadm) is the most common
installation tool for Kubernetes.

## Prepare

Dependencies;

* Local private docker registry ([ovl/private-reg](../private-reg))
* Some executables are taken from the host; `kmod`, `modprobe`, `find`, `jq`
* `/etc/ssl/certs/ca-certificates.crt` taken from the host
* A `cri-o` [static release bundle](https://github.com/cri-o/cri-o/releases)
* `skopeo` installed on the host (for loading images to the private registry)
* A CNI-plugin (optional)

Downloaded archives should be in the `$ARCHIVE` directory.

Set the K8s version and unpack the K8s server binary;
```
export __k8sver=v1.30.0
export KUBERNETESD=$HOME/tmp/kubernetes/kubernetes-$__k8sver/server/bin
# (make sure the K8s server binary are unpacked at $KUBERNETESD)
alias kubeadm="$KUBERNETESD/kubeadm"
kubeadm config images list --kubernetes-version $__k8sver  # (just testing)
export __log=/tmp/xcluster-$USER.log
```

These settings are assumed through this description.


### Pre-load the local private registry

If the local private registry is ok, just do;

```
./kubeadm.sh cache_images
```

[skopeo](../skopeo/) is used for downloads.


## Installation and test

Prepare as described above.

Examples;
```
#export __k8sver=v1.30.0
./kubeadm.sh test start
# On vm-001 (control plane)
kubectl get nodes
kubectl get pods -A
```

The [ovl/k8s-test](https://github.com/uablrek/xcluster-ovls/tree/main/k8s-test)
is used.

```
./kubeadm.sh test start_app
cdo k8s-test
export xcluster_DOMAIN=cluster.local
./k8s-test.sh test --no-start --no-stop mconnect
./k8s-test.sh test --no-start --no-stop basic
./k8s-test.sh test --no-start --no-stop connectivity
```

### Containerd

To use `containerd` instead of `cri-o`, just add ovl/containerd:
```
./kubeadm.sh test start containerd
# Or
./kubeadm.sh test start_app containerd
```


### CNI-plugin

Supported in xcluster are;

* [bridge (xcluster internal)](../k8s-cni-bridge/) This is the default
* [xcluster-cni](https://github.com/Nordix/xcluster-cni)
* [Calico](http://www.projectcalico.org/)
* [Cilium](https://github.com/cilium/cilium)
* [Flannel](https://github.com/coreos/flannel)

These can be selected with the `--cni=` parameter.


The images for the CNI-plugin must be in the local private
registry. Check and cache to the local private registry;

```
cdo k8s-cni-calico
images lreg_missingimages default
images lreg_preload default
```


## Manual Installation

Read a description at;

* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

The description assumes that `kubectl`, `kubelet`, `kubeadm` and a
CRI-plugin is installed on the system. An `xcluster` with this
installed is started with;

```
./kubeadm.sh test start_empty > $log
```

The rest of the commands are executed on the K8s nodes. Open a
terminal to the to-be master node with `vm 1`.

```
vm 1
# On vm-001;
# Check versions:
kubeadm version
# Pull images (from the local registry);
kubeadm config images pull
less /etc/kubeadm-config.yaml  # Check it
kubeadm init --config /etc/kubeadm-config.yaml
# The install of the control-plane (if succesful) prints a
# "kubeadm join ..." command to be executed on joining nodes
# Execute this on vm-002, ...
# Checks
kubectl get nodes
kubectl get pods -A
```

The CNI-plugin manifest is found in `/etc/kubernetes/load/`. It will
be different for different CNI-plugins but it is applied the same;

```
kubectl apply -f /etc/kubernetes/load/calico.yaml
# Check
kubectl get pods -A
kubectl get nodes   # Shall become "Ready" after some time
ls /etc/cni/net.d/
ls /opt/cni/bin/
```

#### Use a node-local CoreDNS

The internal `xcluster` CoreDNS is used but knows nothing about
K8s. Delete the K8s coredns deployment and re-configure and
re-start the local CoreDNS;

```
kubectl delete -n kube-system deployment coredns
killall coredns
coredns -conf /etc/Corefile.k8s 2>&1 > /var/log/coredns.log &
nslookup kubernetes.default.svc.cluster.local
```

Now you have a working one-node dual-stack K8s cluster and other nodes
can join with the "kubernetes join ..." command printed on install of
the control plane.
