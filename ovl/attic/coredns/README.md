# Xcluster ovl - CoreDNS

CoreDNS POD in `xcluster` (obsolete)

`Xcluster` uses node-local `coredns` instances running in main netns
on each node. This ovl is kept for tests, e.g for
[k8s #87426](https://github.com/kubernetes/kubernetes/issues/87426).

## Usage

```
./coredns.sh test start
```

Test;

```
nslookup kubernetes.default.svc.xcluster 12.0.0.2
kubectl apply -f /etc/kubernetes/mconnect.yaml
mconnect -address mconnect.default.svc.xcluster:5001 -nconn 400
nslookup -type=AAAA www.ericsson.se 2000::250
```


## Build

```
go get github.com/coredns/coredns
cd $GOPATH/src/github.com/coredns/coredns
make
strip coredns   # (not needed)
mv coredns $GOPATH/bin
sudo setcap 'cap_net_bind_service=+ep' $GOPATH/bin/coredns
./coredns.sh mkimage
```

## Start a coredns container

```
docker run -d --name=xcluster-coredns registry.nordix.org/cloud-native/xcluster-coredns:latest
docker inspect xcluster-coredns | jq -r .[].NetworkSettings.IPAddress
adr=$(docker inspect xcluster-coredns | jq -r .[].NetworkSettings.IPAddress)
dig -p 10053 @$adr www.google.se
```


## Connection tracking

Connection tracking should be turned off for UDP DNS queries, See this
[blog-post](https://jeanbruenn.info/2017/04/30/conntrack-and-udp-dns-with-iptables/).
