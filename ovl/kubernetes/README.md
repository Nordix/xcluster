Xcluster ovl - Kubernetes
=========================

A [Kubernetes](https://kubernetes.io/) cluster.

This overlay provides a platform with fast turn-around times and very
flexible network setup. The main purpose is development and trouble
shooting of Kubernetes network functions. This is *not* a generic
Kubernetes cluster that is suitable for any purpose, for instance
application development. There are better alternatives for application
development like;

* [microk8s](https://microk8s.io/)
* [k3s](https://k3s.io/)
* [minikube](https://github.com/kubernetes/minikube/)
* [kind](https://kind.sigs.k8s.io/)


## Basic Usage

Prerequisiste; environment for starting `xcluster` without K8s is setup.

To setup the environment source the `Envsettings.k8s` file;

```
$ cd xcluster
$ . ./Envsettings.k8s

The image is not readable [/home/guest/xcluster/workspace/xcluster/hd-k8s.img] 

Please follow the instructions at;
https://github.com/Nordix/xcluster#xcluster-with-kubernetes

Example;
armurl=http://artifactory.nordix.org/artifactory/cloud-native
curl -L $armurl/xcluster/images/hd-k8s.img.xz | xz -d > $__image
```

Pre-built images for K8s on `xcluster` are provided, please see the
[wiki](https://github.com/Nordix/xcluster/wiki/Kubernetes-Images). When
a `hd-k8s.img` has been downloaded start (and stop) a cluster with;

```
xc mkcdrom; xc start
# test something...
xc stop
```

The "standard" cluster is started with 4 nodes and 2 "routers". Xterm
windows are started as consoles for all VMs. In a node console xterm
(green) test K8s things, for instance;

```
kubectl get nodes   # (take some time to see the nodes)
kubectl get pods -A
kubectl wait -A --timeout=150s --for condition=Ready --all pods
```

The xterm consoles are not necessary and may soon feel annoying. Then start `xcluster`
"[in background](https://github.com/Nordix/xcluster/blob/master/doc/ci.md)".
The consoles are still available via
[Gnu screen](https://www.gnu.org/software/screen/manual/);

```
xc mkcdrom; xc starts
```

Note the tailing "s" in "starts" and that you don't have to stop
`xcluster` before starting it again, a running `xcluster` will
automatically be stopped before the new one is started.

To get a terminal window to a VM use the `vm` command (a bash function
actually);

```
vm 1
```

An xterm window will pop-up with a teminal to the VM logged in as
"root".

Some base images for startup an tests are "pre-pulled". These can be
used off-line. A basic [alpine](https://alpinelinux.org/) image for
general tests and a [mconnect](https://github.com/Nordix/mconnect)
image for load-balancing test are provided;

```
vm 1
# On vm-001;
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
kubectl exec -it (an-alpine-pod) sh
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get pods
kubectl get svc
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 100
kubectl top pods
```

### Dual-stack




### Images

[Images](https://kubernetes.io/docs/concepts/containers/images/) are
"Pre-pulled" in xcluster since we often run "off-line" and since it is
much faster. The image "pull" operation is quite complicated with
`cri-o`, please read more in the [images](../images/README.md)
overlay.



Service Account
---------------

To access the API from within a pod a [Service
Account](https://kubernetes.io/docs/admin/service-accounts-admin/)
must be used. This is not easy but reading about others
[problems](https://github.com/kubernetes/kubernetes/issues/27973) helps.

Some keys and certificates must be generated. A good instruction can
be found
[here](https://icicimov.github.io/blog/kubernetes/Kubernetes-cluster-step-by-step-Part2/). Certificates are stored in git but can be re-generated with;

```
./kubernetes.sh ca
```


#### Security or lack threreof

It is actually hard to configure Kubernetes without security.

https://github.com/kubernetes/client-go/issues/314

Access to the API from
[within](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/#accessing-the-api-from-a-pod)
a pod uses the secure port. An API token is needed and some x509
stuff; [1287](https://github.com/kubernetes/dashboard/issues/1287)


### The random problem

This showed up as a real problem in `linux-4.17`.

The `kube-apiserver` uses `/dev/random` this blocks until enough
"enthropy" has been collected which is ~3-4 minutes on an xcluster VM.

There is a [virtual device](https://wiki.qemu.org/Features/VirtIORNG)
that make the host /dev/random be used in the VMs.

Enable the kernel config;

```
Character devices >
  Hardware Random Number Generator Core support >
    VirtIO Random Number Generator support 
```

Then configure it in the kvm startup. We can't use the host
`/dev/random` since it drains too fast and blocks, but we *can* use
`/dev/urandom`;

```
__kvm_opt+=" -object rng-random,filename=/dev/urandom,id=rng0"
__kvm_opt+=" -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=80000"
export __kvm_opt
```
