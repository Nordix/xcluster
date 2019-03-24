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

