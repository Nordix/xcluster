# Xcluster ovl - gobgp

Use [gobgp](https://github.com/osrg/gobgp) (BGP in golang) in xcluster
routers. Gobgp with the `zebra` backend is started on router and
tester VMs. The default configuration is to use "passive" BGP and
dynamic peers on teh routers. This allow speakers on the cluster VMs
to peer with the routers without re-configuration.

Usage
-----

```
xc mkcdrom gobgp ..(other ovls)
xc start --ntesters=2
```

Some useful commands;

```
gobgp neighbor
gobgp global rib
gobgp policy prefix
```

Validate a config;

```
gobgpd -d -t yaml -p -f /tmp/gobgp.cfg
```

Build
-----

```
./gobgp.sh zdownload
./gobgp.sh zbuild
go get -u github.com/golang/dep/cmd/dep
go get -u github.com/osrg/gobgp
cd $GOPATH/src/github.com/osrg/gobgp
dep ensure
go install ./cmd/...
```

Speaker
-------

Without the `zebra` backend `gobgp` is a stand-alone BGP speaker. We
must manually add routes to the rib. This can be used to announce
ExternalIPs and loadBalancerIp in a Kubernetes cluster.

```
gobgp global rib -a ipv4 add 10.0.0.1/32 nexthop 192.168.1.x
gobgp global rib -a ipv6 add 1000::1/128 nexthop 2000:1::x
```

This VIP address is supposed to be seen in the rib's on the routers
and testers. Useful commands;

```
gobgp neighbor
gobgp global rib
gobgp global rib -a ipv6
```

To make the speaker announce `externalIPs` and `loadBalancerIP`
addresses; compare output from;

```
kubectl get svc -o json | \
 jq -r '.items[]|.spec|.externalIPs[]?,.loadBalancerIP?|select(.!=null)'
gobgp -j global rib | \
  jq -r 'flatten[]|select(.attrs[]|.nexthop == "192.168.1.2")|.nlri.prefix' | \
  cut -d/ -f1
```


ECMP
----

To get ECMP working you must use
[zebra-multipath](https://github.com/osrg/gobgp/blob/master/docs/sources/zebra-multipath.md). Use
the configuration option;

```
--enable-multipath=16
```


BGP Links
---------


* [Wikipedia](https://en.wikipedia.org/wiki/Border_Gateway_Protocol)

* [tutorial](http://searchtelecom.techtarget.com/feature/BGP-essentials-The-protocol-that-makes-the-Internet-work) (good start)

* [Using BGP in Data Center
  Fabrics](http://blog.ipspace.net/2016/02/using-bgp-in-data-center-fabrics.html)

* [rfc7938](https://tools.ietf.org/html/rfc7938) DC BGP

* [Clos network](https://en.wikipedia.org/wiki/Clos_network) invented
  1952 by Charles Clos, used in DC today.


Unnumbered BGP
--------------

Gobgp supports [unnumbered
bgp](https://github.com/osrg/gobgp/blob/master/docs/sources/unnumbered-bgp.md).
It relies on the ipv6 neighbor cache (which seem weird IMHO) and as a
"trick" to fill it `ping6` is suggested, or more reliable, use router
advertisement with zebra (or radvd).


