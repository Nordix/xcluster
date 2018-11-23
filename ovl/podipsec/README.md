# Xcluster ovl - podipsec

Encrypts all pod-to-pod traffic between pods on different nodes in a
K8s cluster using `IPSec`. Traffic between pods on the same node is
not encrypted.

There is **no** IKE, e.g StrongSwan, in this setup. Encrypted ESP
tunnels are setup using `ip xfrm`.


## Usage

The `alpine` pod can be used as an example.

```
xc mkcdrom podipsec private-reg; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods -o wide
kubectl exec -it <pod> sh
# In the alpine pod (replace 11.0.3.2 with a valid pod alpine address);
nc 11.0.3.2 5001 < /dev/null
# At some other place;
tcpdump -ni eth1 esp
```

