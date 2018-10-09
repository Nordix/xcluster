Xcluster ovl - Kubernetes
=========================

A [Kubernetes](https://kubernetes.io/) cluster.

This overlay provides a platform with ultra fast turn-around times and
very flexible network setup. The main purpose is development and
trouble shooting of Kubernetes network functions.

This is *not* a generic Kubernetes cluster that can be used for any
development for instance application.


Usage
-----

Prerequisite; Plugins and `cri-o` must be built as described
[below](#build) and `runc` must be downloaded. Kubernetes must be built
as described or [downloaded](#downloaded).

The normal way is to extend the base image with Kubernetes. This will
speed up the VM start and simplify subsequent adaptations since you
don't have to repeat the Kubernetes overlays for all `mkcdrom` calls;

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s.img
xc mkimage
images make coredns docker.io/nordixorg/mconnect:0.2
xc ximage systemd etcd iptools kubernetes coredns mconnect images
xc mkcdrom externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
# Outside the cluster;
mconnect -address 10.0.0.2:5001 -nconn 400
```

The `images` overlay requires sudo to create a container-storage
structure.

Ipv6;

```
# Prerequisite; xc ximage... as above
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
# Outside the cluster;
mconnect -address [1000::2]:5001 -nconn 400
```

### Access with kubectl from your host

For user-space networking port forwarding from `$XCLUSTER_K8S_PORT`
(default 18080) is setup to the k8s api-server.  Use that address in
`$HOME/.kube/config`;

```
> cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    server: http://127.0.0.1:18080
  name: xcluster
contexts:
- context:
    cluster: xcluster
    user: root
  name: xcluster
current-context: xcluster
kind: Config
preferences: {}
users:
- name: root
  user:
    as-user-extra: {}
```

### Helm

With `xcluster` the simplest is to run `tiller`
[locally](https://docs.helm.sh/using_helm/#running-tiller-locally). This
removes a port forwarding problems with user-space networking. Tiller
executes on your host and only needs access to the k8s api-server,
same as `kubectl`.

Prerequisite; Install a `$HOME/.kube/config` as above.

**Note**: Do not use ~~helm init~~.

#### Install

Download from the helm
[release-page](https://github.com/helm/helm/releases). Pick a Linux
binary. Unpack it at some place of your liking and add it to your
`$PATH`.

#### Start tiller

You can start it in background with redirects to a log file or in
foreground in a shell to see what's happening;

```
tiller
# or
tiller > /tmp/$USER/tiller.log 2>&1 &
```

#### Use helm

Set the variable for local `tiller` thenuse helm as usual;

```
export HELM_HOST=localhost:44134
helm install --name metallb stable/metallb
```


Build
-----
<a name="build"/>

Since the intention of this ovl is Kubernetes development we assume
that you build it but it is possible to use a
[downloaded](#downloaded) release.

Read the [developer
guide](https://github.com/kubernetes/community/blob/master/contributors/devel/development.md)
and the *excellent*
[work-flow](https://github.com/kubernetes/community/blob/master/contributors/guide/github-workflow.md)
document.


```
go get -u k8s.io/kubernetes
cd $GOPATH/src/k8s.io/kubernetes
for n in kube-controller-manager kube-scheduler kube-apiserver \
  kube-proxy kubectl kubelet; do
    make WHAT=cmd/$n
done
strip _output/bin/*
```

Build the plugins with;

```
go get github.com/containernetworking/plugins/
cd $GOPATH/src/github.com/containernetworking/plugins
./build.sh
cd bin
strip *
```

Needed for other builds;

```
go get k8s.io/apimachinery
go get k8s.io/client-go
go get k8s.io/api
go get github.com/golang/glog
go get github.com/google/gofuzz
```

### Cri-o

Cri-o is hosted on
[github](https://github.com/kubernetes-incubator/cri-o). The
"releases" have no binaries so you must build them yourself
([issue](https://github.com/kubernetes-incubator/cri-o/issues/1141)).

There is a good
[tutorial](https://github.com/kubernetes-incubator/cri-o/blob/master/tutorial.md). Here
is a short version;

```
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
make
go get -u github.com/kubernetes-incubator/cri-o
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
git checkout -b release-1.12
make install.tools
make
git status --ignored
strip bin/*
```

[Runc](https://github.com/opencontainers/runc) is the container
runtime in `cri-o`. It implements the
[OCI-specification](https://github.com/opencontainers/specs).

Download with;

```
./kubernetes.sh runc_download
```

<a name="downloaded"/>

### Use a downloaded version

Download the "Server Binaries" from a
[CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.12.md)
page. Unpack the file to some directory and install;

```
mkdir -p /tmp/$USER
cd /tmp/$USER
tar xvf ~/Downloads/kubernetes-server-linux-amd64.tar.gz
strip kubernetes/server/bin/*
export KUBERNETESD=/tmp/$USER/kubernetes/server/bin
```

Pods, Containers and Images
---------------------------

[cri-o](http://cri-o.io/) is used as container runtime.


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


Troubleshooting
---------------

The "Cluster state store" `etcd` is started as an own
service. Kubernetes binaries are started with `systemd`. The start
files are;

```
vm-001 ~ # find /etc/systemd -name 'kube-*'
/etc/systemd/bin/kube-prep
/etc/systemd/bin/kube-master
/etc/systemd/bin/kube-node
/etc/systemd/system/kube-node.service
/etc/systemd/system/kube-prep.service
/etc/systemd/system/kube-master.service
```

Check the scripts in `/etc/systemd/bin` to see the command line
options used for instance.

The output from the processes is re-directed to log files in /var/log;

```
vm-001 ~ # ls /var/log/
containers/                  kube-proxy.log
dumps/                       kube-scheduler.log
etcd.log                     kubelet.log
kube-apiserver.log           lastlog
kube-controller-manager.log  messages
```

First increase the log level. The easiest way is to use a temporary
ovl to alter the start options for the Kubernetes programs.

```
mkdir -p work/default/etc/systemd
cp -r kubernetes/default/etc/systemd/bin work/default/etc/systemd
cp -r cni-bridge/default/etc/systemd/bin work/default/etc/systemd
```

Problems
--------

```
error: failed to run Kubelet: mountpoint for cpu not found
```

Was missing mounts for `cgroups`.

```
error: failed to run Kubelet: open /proc/swaps: no such file or directory
```

Swap is required by systemd.

```
exec: "nsenter": executable file not found in $PATH
```

Nsenter is needed.

```
/proc/sys/kernel/keys/root_maxbytes: no such file or directory
# In linux config;
CONFIG_KEYS=y
```

Security config in the kernel.

```
Failed to ensure that %s chain %s jumps to MASQUERADE
```

"addrtype" iptables target missing in the kernel.

#### Kube-proxy

```
IPVS proxier will not be used because the following required kernel
modules are not loaded: [ip_vs nf_conntrack_ipv4]
```

These function are in the xcluster kernel, but apparently kube-proxy
**requires** them to be configured as modules.

```
proxier.go:1015] Failed to create dummy interface: kube-ipvs0, error: operation not supported
```

(sigh...)


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
