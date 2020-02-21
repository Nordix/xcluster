# Xcluster ovl - k8s-cni-xcluster


## Usage

```
images lreg_upload --strip-host registry.nordix.org/cloud-native/xcluster-cni:latest
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export XOVLS="k8s-cni-xcluster private-reg"
export __nvm=5
xc mkcdrom k8s-cni-xcluster; xc starts
```

## Release

```
ver=v0.1.0
docker tag registry.nordix.org/cloud-native/xcluster-cni:latest registry.nordix.org/cloud-native/xcluster-cni:$ver
docker push registry.nordix.org/cloud-native/xcluster-cni:latest
docker push registry.nordix.org/cloud-native/xcluster-cni:$ver
cd $GOPATH/src/github.com/Nordix/xcluster-cni
git tag $ver
git push origin $ver
```

## SIT tunnels

```
sed -i -e 's,"None","sit",' $GOPATH/src/github.com/Nordix/xcluster-cni/xcluster-cni.yaml
xc mkcdrom k8s-cni-xcluster; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods -o wide
```

Create a netns;
```
# On vm-004;
ip netns add ns1
ip link add name ns0 type veth peer name ns1
ip link set ns0 netns ns1
ip link set ns1 up
ip addr add 40.0.0.0/31 dev ns1
ip netns exec ns1 ip link set ns0 up
ip netns exec ns1 ip addr add 40.0.0.1/31 dev ns0
ip netns exec ns1 ip ro add default via 40.0.0.0
ping -c1 -W1 40.0.0.1
ip link set up dev sit0
# On vm-003;
ip link set up dev sit0
ip ro add 40.0.0.0/31 dev sit0 onlink via 192.168.1.4 src 192.168.1.3
ping -c1 -W1 40.0.0.1
```

Without k8s;
```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
unset XOVLS
xc mkcdrom xnet; xc starts
# On vm-003;
ip link set up dev tunl0
ip link set up dev sit0
ip addr add 20.0.0.3/32 dev sit0
ip route add 20.0.0.4/32 dev sit0 onlink via 192.168.1.4
tcpdump -ni eth1
# On vm-004;
ip link set up dev tunl0
ip link set up dev sit0
ip addr add 20.0.0.4/32 dev sit0
ip route add 20.0.0.3/32 dev sit0 onlink via 192.168.1.3
ping -c1 -W1 20.0.0.3
```
