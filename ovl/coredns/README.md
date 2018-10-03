Xcluster ovl - CoreDNS
======================

Adds CoreDNS in a Kubernetes cluster.

Also described howto setup `CoreDNS` locally.

Usage
-----

Coredns should be included in the base Kubernetes image.

```
# Include "coredns" in images
xc mkcdrom coredns
```

Test;

```
nslookup kubernetes.default.svc.xcluster 12.0.0.2
kubectl apply -f /etc/kubernetes/mconnect.yaml
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 400
nslookup -type=AAAA www.ericsson.se 2000::250
```


Build
-----

```
go get github.com/coredns/coredns
cd $GOPATH/src/github.com/coredns/coredns
make
strip coredns   # (not needed)
mv coredns $GOPATH/bin
sudo setcap 'cap_net_bind_service=+ep' $GOPATH/bin/coredns
```


Local setup
-----------

```
sudo setcap 'cap_net_bind_service=+ep' /home/uablrek/go/bin/coredns
cfg=$($XCLUSTER ovld coredns)/Corefile
coredns -conf $cfg > /tmp/$USER/coredns.log 2>&1 &
```
