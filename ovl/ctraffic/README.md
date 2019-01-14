# Xcluster ovl - ctraffic

Adds the [ctraffic](https://github.com/Nordix/ctraffic) continuous
traffic test program.

## Usage

Basic usage;
```
xc mkcdrom private-reg externalip ctraffic; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/ctraffic-extip.yaml
# On a router;
ctraffic -address 10.0.0.2:5003 -nconn 400 -rate 100 -monitor_interval 1s
```

With loadBalancerIP;
```
xc mkcdrom private-reg metallb gobgp ctraffic; xc starts
# On cluster;
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
kubectl apply -f /etc/kubernetes/metallb-config.yaml
kubectl get pods -n metallb-system
kubectl apply -f https://github.com/Nordix/ctraffic/raw/master/ctraffic.yaml
# On a router;
ctraffic -address 10.0.0.0:5003 -nconn 400 -rate 100 -monitor_interval 1s
```

Copy the image to the private registry;
```
ver=0.1      # (or whatever...)
skopeo copy --dest-tls-verify=false \
  docker-daemon:nordixorg/ctraffic:$ver \
  docker://172.17.0.2:5000/nordixorg/ctraffic:$ver
skopeo delete --tls-verify=false docker://172.17.0.2:5000/nordixorg/ctraffic:$oldver
```

## ECMP test

```
# On a router;
ctraffic -timeout 1m -address 10.0.0.2:5003 -nconn 400 -rate 400 -monitor_interval 1s
# On the same router;
ip route change 10.0.0.0/24 \
  nexthop via 192.168.1.2 \
  nexthop via 192.168.1.3 \
  nexthop via 192.168.1.4
# Watch the monitoring printouts;
ip route change 10.0.0.0/24 \
  nexthop via 192.168.1.1 \
  nexthop via 192.168.1.2 \
  nexthop via 192.168.1.3 \
  nexthop via 192.168.1.4
```

Some manual experimenting gives that ~200 connections are lost when
one (of 4) ECMP target is removed. When the ECMP target is re-added
another ~100 connections are lost. This is less than expected so it
implies that Linux uses [consitent
hashing](https://en.wikipedia.org/wiki/Consistent_hashing).
