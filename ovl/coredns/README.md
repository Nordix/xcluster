Xcluster ovl - CoreDNS
======================

Adds CoreDNS in a Kubernetes cluster.

Also describes howto setup `CoreDNS` locally.

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

### Make image

```
images mkimage --force --upload ./image
```

Local setup
-----------

```
sudo setcap 'cap_net_bind_service=+ep' /home/uablrek/go/bin/coredns
cfg=$($XCLUSTER ovld coredns)/Corefile
coredns -conf $cfg > /tmp/$USER/coredns.log 2>&1 &
```

## DNS64

Add the plugin in `plugin.cfg`. **NOTE** that the order is important!
Insert the dns64 plugin after `log` for instance;

```
log:log
dns64:github.com/serverwentdown/dns64
...
```

Rebuild `coredns` and start.

```
nslookup -port=10053 -type=AAAA www.ericsson.se ::1
```

The `Corefile.k8s` file assumes that the "translateAll" PR is applied
[#4](https://github.com/serverwentdown/dns64/pull/4).

From a VM use;

```
nslookup www.google.se [2000::250]:10053
```

## Connection tracking

Connection tracking should be turned off for UDP DNS queries, See this
[blog-post](https://jeanbruenn.info/2017/04/30/conntrack-and-udp-dns-with-iptables/).
