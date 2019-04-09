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

### Help printouts

Server;
```
NAME:
   k3s server - Run management server

USAGE:
   k3s server [OPTIONS]

OPTIONS:
   --https-listen-port value           HTTPS listen port (default: 6443)
   --http-listen-port value            HTTP listen port (for /healthz, HTTPS redirect, and port for TLS terminating LB) (default: 0)
   --data-dir value, -d value          Folder to hold state default /var/lib/rancher/k3s or ${HOME}/.rancher/k3s if not root
   --disable-agent                     Do not run a local agent and register a local kubelet
   --log value, -l value               Log to file
   --cluster-cidr value                Network CIDR to use for pod IPs (default: "10.42.0.0/16")
   --cluster-secret value              Shared secret used to bootstrap a cluster [$K3S_CLUSTER_SECRET]
   --service-cidr value                Network CIDR to use for services IPs (default: "10.43.0.0/16")
   --cluster-dns value                 Cluster IP for coredns service. Should be in your service-cidr range
   --no-deploy value                   Do not deploy packaged components (valid items: coredns, servicelb, traefik)
   --write-kubeconfig value, -o value  Write kubeconfig for admin client to this file [$K3S_KUBECONFIG_OUTPUT]
   --write-kubeconfig-mode value       Write kubeconfig with this mode [$K3S_KUBECONFIG_MODE]
   --tls-san value                     Add additional hostname or IP as a Subject Alternative Name in the TLS cert
   --node-ip value, -i value           (agent) IP address to advertise for node
   --node-name value                   (agent) Node name [$K3S_NODE_NAME]
   --docker                            (agent) Use docker instead of containerd
   --no-flannel                        (agent) Disable embedded flannel
   --flannel-iface value               (agent) Override default flannel interface
   --container-runtime-endpoint value  (agent) Disable embedded containerd and use alternative CRI implementation
```

Agent;
```
NAME:
   k3s agent - Run node agent

USAGE:
   k3s agent [OPTIONS]

OPTIONS:
   --token value, -t value             Token to use for authentication [$K3S_TOKEN]
   --token-file value                  Token file to use for authentication [$K3S_TOKEN_FILE]
   --server value, -s value            Server to connect to [$K3S_URL]
   --data-dir value, -d value          Folder to hold state (default: "/var/lib/rancher/k3s")
   --containerd-config-template value  Use Custom Containerd config file
   --cluster-secret value              Shared secret used to bootstrap a cluster [$K3S_CLUSTER_SECRET]
   --docker                            (agent) Use docker instead of containerd
   --no-flannel                        (agent) Disable embedded flannel
   --flannel-iface value               (agent) Override default flannel interface
   --node-name value                   (agent) Node name [$K3S_NODE_NAME]
   --node-ip value, -i value           (agent) IP address to advertise for node
   --container-runtime-endpoint value  (agent) Disable embedded containerd and use alternative CRI implementation
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
xc mkcdrom xnet iptools k3s externalip; xc starts
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


## Local Docker registry

Containerd let you [specify
mirrors](https://github.com/containerd/cri/blob/master/docs/registry.md#configure-registry-endpoint)
which may be used for re-direct to a local (unsecure) registry.


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
# Only the server to start with;
SETUP=ipv6 xc mkcdrom xnet iptools k3s externalip; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods -o wide
kubectl apply -f /etc/kubernetes/mconnect.yaml
kubectl get svc
# On a router;
mconnect -address [1000::2]:5001 -nconn 100
```

### CNI plugin

Flannel does not support ipv6 so `bridge` CNI-plugin is used with
routes setup in a script. Ipam `node-local` is used which is just a
pipe to `host-local`. Test the ipam;

```
CNI_COMMAND=ADD CNI_CONTAINERID=example CNI_NETNS=/dev/null CNI_IFNAME=dummy0 \
  CNI_PATH=. /opt/cni/bin/node-local < /etc/cni/net.d/cni.conf
```
