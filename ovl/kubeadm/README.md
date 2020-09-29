# Xcluster ovl - kubeadm

* Install Kubernetes with `kubeadm` in xcluster.

[kubeadm](https://github.com/kubernetes/kubeadm) is the "standard"
installation tool for Kubernetes.

## Prepare

Dependencies;

* Local private docker registry ([ovl/private-reg](../private-reg))
* K8s server binaries (can be found via the
  [changelog](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG))
* Some executables are taken from the host; `kmod`, `modprobe`, `find`, `jq`
* `/etc/ssl/certs/ca-certificates.crt` taken from the host
* A `cri-o` [static release bundle](https://github.com/cri-o/cri-o/releases)
* `skopeo` installed on the host (for loading images to the private registry)
* A CNI-plugin (see below)
* Optional; [assign-lb-ip.xz](https://github.com/Nordix/assign-lb-ip/releases)
  (needed for automatic tests)

Downloaded archives should be in the `$ARCHIVE` directory.

Set the K8s version and unpack the K8s server binary;
```
export __k8sver=v1.19.2
export KUBERNETESD=$HOME/tmp/kubernetes/kubernetes-$__k8sver/server/bin
# (make sure the K8s server binary are unpacked at $KUBERNETESD)
alias kubeadm="$KUBERNETESD/kubeadm"
kubeadm config images list --kubernetes-version $__k8sver  # (just testing)
log=/tmp/xcluster-$USER.log
```

These settings are assumed through this description.


### Pre-load the local private registry

If the local private registry is ok, just do;

```
./kubeadm.sh cache_images
```

[skopeo](https://github.com/containers/skopeo) is used for downloads.


### CNI-plugin

You must select a CNI-plugin. Tested and supported in xcluster are;

* [xcluster-cni](https://github.com/Nordix/xcluster-cni) (default)
* [Calico](http://www.projectcalico.org/)
* [Cilium](https://github.com/cilium/cilium)
* [Flannel](https://github.com/coreos/flannel) (ipv4-only)
* [Weave](https://www.weave.works/) (ipv4-only)

These can be selected with the `--cni=` parameter. Other CNI-plugin
might work but then you are on your own.

The images for the CNI-plugin must be in the local private
registry. Check and cache to the local private registry;

```
images lreg_missingimages k8s-cni-calico
docker.io/calico/cni:v3.14.0
...
images lreg_cache docker.io/calico/cni:v3.14.0
...
```


## Automatic Tests or installation

Prepare as described above.

Examples;
```
export __k8sver=v1.18.8
./kubeadm.sh test --list
./kubeadm.sh test > $log  # Default; --cni=xcluster test_template
./kubeadm.sh test --cni=cilium test_template > $log
./kubeadm.sh test --cni=weave test_template4 > $log
```

Install and leave the cluster running;
```
./kubeadm.sh test --cni=cilium --no-stop install > $log
# Or;
./kubeadm.sh test --cni=weave --no-stop install_ipv4 > $log
```



## Manual Installation

Read a description at;

* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

The description assumes that `kubectl`, `kubelet`, `kubeadm` and a
CRI-plugin (or docker) is installed on the system. An `xcluster` with
this installed is started with;

```
# Dual-stack with --cni=xcluster (default);
./kubeadm.sh test start > $log
# Dual-stack with Calico;
./kubeadm.sh test --cni=calico start > $log
# Ipv4-only with Flannel;
./kubeadm.sh test --cni=flannel start_ipv4 > $log
```

The rest of the commands are executed on the K8s nodes. Open a
terminal to the to-be master node with `vm 1`.

### Dual-stack manual installation

In this example `Calico` is used.

```
./kubeadm.sh test --cni=calico start > $log
vm 1
# On vm-001;
# Check versions:
echo $__k8sver
kubeadm version -o short
# Pull images (from the local registry);
kubeadm config images pull --kubernetes-version $__k8sver
less /etc/kubeadm-config.yaml  # Check it
kubeadm init --config /etc/kubeadm-config.yaml
# just checking...
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
can join.


### Ipv4 manual installation

In this example `Flannel` is used.

```
./kubeadm.sh test --cni=flannel start_ipv4 > $log
vm 1
# On vm-001;
# Check versions:
echo $__k8sver
kubeadm version -o short
# Pull images (from the local registry);
kubeadm config images pull --kubernetes-version $__k8sver
kubeadm init --token=11n1ns.vneshg4ikfoyiy09 --kubernetes-version $__k8sver --pod-network-cidr 11.0.0.0/16
# Install the CNI-plugin and test;
kubectl apply -f /etc/kubernetes/load/kube-flannel.yaml
# Check
kubectl get pods -A
kubectl get nodes   # Shall become "Ready" after some time
ls /etc/cni/net.d/
ls /opt/cni/bin/
```

Now you have a working one-node ipv4 K8s cluster and other nodes
can join.


### Join nodes

```
vm 2
# On vm-002
kubeadm join 192.168.1.1:6443 --token 11n1ns.vneshg4ikfoyiy09 --discovery-token-unsafe-skip-ca-verification
export KUBECONFIG=/etc/kubernetes/kubelet.conf
kubectl get nodes
killall coredns
coredns -conf /etc/Corefile.k8s 2>&1 > /var/log/coredns.log &
```

Repeat for other nodes.

You now have a working multi-node cluster.

### Manual tests

It may be a good idea to "untaint" the master node in this small cluster;

```
vm 1
# On vm-001;
kubectl taint node vm-001 node-role.kubernetes.io/master:NoSchedule- || tdie
```

Some images are "pre-pulled" and can be used immediately;

```
vm 1
# On vm-001;
images  # (alias that list pulled images)
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods -o wide
kubectl exec -it alpine-deployment-... -- sh
# In the POD;
nslookup kubernetes
... whatever you like
```


