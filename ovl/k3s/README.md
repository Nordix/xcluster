# Xcluster ovl - k3s

Use [k3s](https://github.com/rancher/k3s) in `xcluster`.

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
# Download k3s to directory (and do chmod a+x );
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

The ClusterIP of the CoreDNS started by k3s should be configured as nameserver;
```
k3s kubectl get svc -n kube-system kube-dns
a=$(k3s kubectl get svc -n kube-system kube-dns -o json | jq -r .spec.clusterIP)
echo "nameserver $a" > /etc/resolv.conf
# Test it;
nslookup kubernetes.default.svc.cluster.local
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

This setup uses a [private registry](../private-reg) and the default
routes has two targets. This means that until this is fixed in a
official release you must apply PRs
[#248](https://github.com/rancher/k3s/pull/248) and
[#250](https://github.com/rancher/k3s/pull/250) and re-build `k3s`
locally.

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
xc mkcdrom xnet iptools k3s; xc starts
# Scale out to 8 workers if you like;
xc scaleout $(seq 5 9)
```

### Access from the host

This differs when you are executing in main netns with user-space
networking and when you are executing in an own netn with bridged
networking. User-space access to the vm's uses port forwarding, so you
access ports on `localhost` which will be forwarded (by qemu) to the
vm network on `eth0`.

User-space networking;
```
sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
scp $sshopt -P 12301 root@localhost:/etc/kubernetes/kubeconfig /tmp
# Do NOT alter the file! The localhost:6443 address is fine.
KUBECONFIG=/tmp/kubeconfig kubectl get nodes
```

Bridged networking;
```
sshopt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
scp $sshopt root@192.168.0.1:/etc/kubernetes/kubeconfig /tmp
# Alter the address;
sed -ie 's,localhost,192.168.0.1,' /tmp/kubeconfig
KUBECONFIG=/tmp/kubeconfig kubectl get nodes
```

## Helm and Tiller



## Local Docker registry

Containerd let you [specify
mirrors](https://github.com/containerd/cri/blob/master/docs/registry.md#configure-registry-endpoint)
which may be used for re-direct to a local (unsecure) registry.
