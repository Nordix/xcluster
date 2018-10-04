Xcluster overlay - iptools
==========================

Overlay that installs some ip tools

Intended for experiments with the latest iptools. The `ntf` program
for configuring the
[nftables](https://netfilter.org/projects/nftables/index.html) is
included.


Usage
-----

Prerequisite: The kernel must be built with nftables support.

Build;

```
./iptools.sh download
./iptools.sh build
```

Use;

```
xc mkcdrom iptools ...
```

This overlay is almost always used with other overlays.

Versions
--------

```
> ./iptools.sh versions
libmnl=1.0.4
libnftnl=1.0.9
iptables=1.6.2
nftables=0.8.3
libnfnetlink=1.0.1
libnetfilter_cttimeout=1.0.0
libnetfilter_conntrack=1.0.6
libnetfilter_cthelper=1.0.0
libnetfilter_queue=1.0.3
conntrack_tools=1.4.4
libnl=1.1.4
ipvsadm=1.26
ipset=6.38
```
