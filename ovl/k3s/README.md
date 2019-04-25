# Xcluster ovl - k3s

Use [k3s](https://github.com/rancher/k3s) in `xcluster`.


## Usage

First make sure `xcluster` works. Follow the Quick-start
[instructions](../../README.md#quick-start).

Download and unpack the k3s image;
```
curl -L http://artifactory.nordix.org/artifactory/cloud-native/xcluster/images/hd-k3s.img.xz \
 | xz -dc > /tmp/hd-k3s.img
```
This image contains everything necessary to start a `k3s` cluster
offline.

Start `xcluster` with the downloaded image;
```
export __image=/tmp/hd-k3s.img
xc mkcdrom; xc start
# Open a terminal on a vm;
vm 4
# On cluster;
kubectl get nodes
kubectl get pods --all-namespaces
# When coredns is Running, test it;
nslookup kubernetes.default.svc.cluster.local 10.43.0.10
nslookup www.google.se 10.43.0.10
```

When this is working you should be able to apply manifests from within
the cluster.


### Private docker registry

A local [private docker registry](../k3s-private-reg/README.md) allows
faster and more predictable image loads and offline work.


### Kubectl access from the host

This differs when you are executing in main netns with user-space
networking and when you are executing in an own
[netns](../../doc/netns.md) with bridged networking. User-space access
to the vm's uses port forwarding, so you access ports on `localhost`
which will be forwarded (by qemu) to the vm network on `eth0`.

User-space networking;
```
sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
scp $sshopt -P 12301 root@localhost:/etc/kubernetes/kubeconfig /tmp
# Do NOT alter the file! The localhost:6443 address is fine.
KUBECONFIG=/tmp/kubeconfig kubectl get nodes
```

Bridged networking in a [netns](../../doc/netns.md);
```
sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
scp $sshopt root@192.168.0.1:/etc/kubernetes/kubeconfig /tmp
# Alter the address;
sed -ie 's,localhost,192.168.0.1,' /tmp/kubeconfig
KUBECONFIG=/tmp/kubeconfig kubectl get nodes
```

### User-space networking v.s. netns with bridged networking

**NOTE:** The user-space networking in `xcluster` (or "quemu") is
**not** sufficient for large networks or heavy load! You shall use
`xcluster` in a [netns](../../doc/netns.md) with bridged networking if
you test a large cluster of if you have a network intensive
application or load big images.

That said, the user-space *is* sufficient for most function testing
and it is very convenient and you don't need "sudo".



### Large clusters

* Testing large clusters should be done in [netns](../../doc/netns.md)
  with bridged networking.

* `Xcluster` has a built-in limit of 200 VMs, vm-001 - vm-200.

* Use "xc starts" to avoid the terminal windows.

* Host-names in "/etc/hosts" including `vm-032` are generated. I you
  need more you must alter the "default/etc/init.d/20prep.rc" file.

* A local private registry is *strongly* recommended.


For clusters of moderate size just use the `--nvm` parameter;
```
xc mkcdrom; xc starts --nvm=16
```

For very large clusters the resource usage (e.g. network and cpu) on
startup may cause problems if all VMs are started at once. Then you
can start a smaller cluster and scale-out in chunks. This also
allows you to control the memory ammount for each VM;
```
xc mkcdrom; xc starts --mem=512 --nvm=1
xc scaleout --mem=256 $(seq 2 10)
xc scaleout --mem=256 $(seq 11 20)
xc scaleout --mem=256 $(seq 21 30)
...
```

For the record; Around 30 VMs is the reasonable limit on my 16GB
i7-8550U laptop. Cpu ~30-70% and ~80% memory used.


## Manual setup

This is what is described in the
[README](https://github.com/rancher/k3s/blob/master/README.md) for
k3s.

Prepare;
```
cd $HOME/xcluster
. ./Envsettings.k8s
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
# Verify that a local coredns is started on port 10053
nslookup -port=10053 www.google.se localhost
# Download k3s to the ARCHIVE directory (and do chmod a+x );
xc env | grep ARCHIVE
```

Start on a single node and expand;
```
SETUP=manual xc mkcdrom xnet iptools k3s; xc start --nrouters=1 --nvm=1
# Open a terminal on vm-001;
vm 1
# On vm-001;
k3s server --no-deploy traefik &
k3s crictl images
k3s kubectl get nodes -o wide
k3s kubectl get pods --all-namespaces
cat /var/lib/rancher/k3s/server/node-token
# Start another node;
xc scaleout 2
# On vm-002;
k3s agent --node-ip=192.168.1.2 --server https://192.168.1.1:6443 \
 --token=(from above) &
# (repeat for more nodes)
#xc scaleout 3 4 ...etc
```

Deploy [mconnect](https://github.com/Nordix/mconnect) as a test-pod;
```
# On vm-001;
k3s kubectl apply -f /etc/kubernetes/mconnect.yaml
k3s kubectl get pods -o wide
k3s kubectl get svc
mconnect -address mconnect.default.svc.cluster.local:5001 -nconn 100
mconnect -address 192.168.1.1:5001 -nconn 100
# On the router (vm-201);
mconnect -address 192.168.1.1:5001 -nconn 100
```


## Default setup

Use a local [private registry](../k3s-private-reg/README.md).

Prepare as for the manual setup (above) and make sure the needed
images are in the private registry.

```
. ./Envsettings.k8s
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
images lreg_cache k8s.gcr.io/pause:3.1
images lreg_cache docker.io/coredns/coredns:1.3.0
images lreg_cache docker.io/nordixorg/mconnect:v1.2
```

Start;
```
xc mkcdrom xnet iptools k3s k3s-private-reg externalip mserver; xc starts
# Scale out to 8 workers if you like;
xc scaleout $(seq 5 9)
# On cluster;
kubectl get nodes
kubectl get pods --all-namespaces
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl exec -it alpine-deployment-...
# In the pod;
wget -O /dev/null http://www.google.se
nslookup kubernetes.default.svc.cluster.local
```

## Ipv6

**THIS IS A WORK IN PROGRESS!**

See issue [#284](https://github.com/rancher/k3s/issues/284)

This is an attempt to start a ipv6-only cluster with `k3s`. To start
k8s in ipv6-only mode all address parameters must be ipv6
addresses. The CRI-plugin can (and should) still operate with ipv4
since images are downloaded with ipv4. This also removes the need for
a NAT64/DNS64 setup in the base-case.

To be able to set custom flags PR
[#309](https://github.com/rancher/k3s/pull/309) must be applied.

```
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
SETUP=ipv6 xc mkcdrom xnet iptools k3s k3s-private-reg externalip mserver; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods -o wide
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get svc
# On a router;
mconnect -address [1000::2]:5001 -nconn 100
# Or;
./k3s.sh test --no-stop ipv6 > /dev/null
# Will build, start and test the system and leave it for your use.
```

For ipv6 the internal certificate becomes a problem 
[note](https://github.com/rancher/k3s/issues/27#issuecomment-462525403).


### CNI plugin

Flannel does not support ipv6 so `bridge` CNI-plugin is used with
routes setup in a script. Ipam `node-local` is used which is just a
pipe to `host-local`. Test the ipam;

```
CNI_COMMAND=ADD CNI_CONTAINERID=example CNI_NETNS=/dev/null CNI_IFNAME=dummy0 \
  CNI_PATH=. /opt/cni/bin/node-local < /etc/cni/net.d/cni.conf
```
