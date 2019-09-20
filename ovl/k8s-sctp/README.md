# Xcluster/ovl - k8s-sctp

Use SCTP in Kubernetes.

An image with `ncat` as a test server is created. `ncat` has SCTP
support and is used both as client and server.

[SCTP support in
K8s](https://kubernetes.io/docs/concepts/services-networking/service/#sctp)
is currently in "alpha" and `--feature-gates=SCTPSupport=true` must be
set.

## Build

```
images mkimage --force --upload ./image
```

## Usage

```
xc mkcdrom k8s-sctp private-reg; xc starts
# On cluster;
ncat -nvkle /bin/hostname --sctp
kubectl apply -f /etc/kubernetes/ncat-ipv4-sctp.yaml
ncat -i 10ms --sctp ncat-ipv4-sctp.default.svc.xcluster 5001 2> /dev/null
# TCP for reference;
kubectl apply -f /etc/kubernetes/ncat-ipv4.yaml
ncat -i 10ms ncat-ipv4.default.svc.xcluster 5001 2> /dev/null
```

## Test

```
cdo k8s-sctp
XOVLS=private-reg ./k8s-sctp.sh test > /dev/null
```

## Troubleshooting

The `ncat` POD also contains the `mserver` container that has a shell
and assorted network tools, e.g. `netstat` and `tcpdump`.



Check sctp sockets;
```
netstat -putlnSw
```

