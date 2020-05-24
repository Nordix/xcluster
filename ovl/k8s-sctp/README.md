# Xcluster/ovl - k8s-sctp

Use SCTP in Kubernetes.

An image with `ncat` as a test server is created. `ncat` has SCTP
support and is used both as client and server.

[SCTP support in
K8s](https://kubernetes.io/docs/concepts/services-networking/service/#sctp)
is currently in "alpha" and `--feature-gates=SCTPSupport=true` must be
set.

## Build

Build local image;
```
images mkimage --force --upload ./image
```

Or;

Prepare [private-reg](../private-reg);
```
images lreg_cache registry.nordix.org/cloud-native/ncat:v0.1
images lreg_cache registry.nordix.org/cloud-native/mserver:latest
```

## Usage

```
xc mkcdrom k8s-dual-stack k8s-sctp private-reg; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/ncat-dual-stack-sctp.yaml
ncat -i 10ms --sctp ncat-ipv4-sctp.default.svc.xcluster 5001 2> /dev/null
ncat -i 10ms --sctp ncat-ipv6-sctp.default.svc.xcluster 5001 2> /dev/null
# TCP for reference;
kubectl apply -f /etc/kubernetes/ncat-dual-stack.yaml
ncat -i 10ms ncat-ipv4.default.svc.xcluster 5001 2> /dev/null
ncat -i 10ms ncat-ipv6.default.svc.xcluster 5001 2> /dev/null
```

## Test

```
cdo k8s-sctp
XOVLS=private-reg ./k8s-sctp.sh test > /dev/null
```

## Troubleshooting

The `ncat` image has no "os" (shell) but the POD also contains the
`mserver` container that has a shell and assorted network tools,
e.g. `netstat` and `tcpdump`.

```
kubectl get pods -l 'app=ncat-sctp'
pod=$(kubectl get pods -l 'app=ncat-sctp' -o json | jq -r .items[0].metadata.name)
kubectl exec -it -c mserver $pod sh
# In the pod;
netstat -putlnSw
tcpdump -eni eth0 sctp
# ...
```
