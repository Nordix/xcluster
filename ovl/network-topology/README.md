# Xcluster/ovl - network-topology

* Network topologies in xcluster

Various network topology setups are defined in this ovl.

The maintenance network 0 (eth0) is alway setup but is not shown here.

An addressing pattern is used. All VMs gets addresses as;

```
PREFIX=1000::1
ip addr add ethX 192.168.$net.$i
ip -6 addr add ethX $PREFIX:192.168.$net.$i
```

Where `$i` is the vm-number, like 221 for "vm-221".

A local DNS server (CoreDNS) is also setup on all VMs by this ovl.


## Usage

Generic;
```
export TOPOLOGY=...
. $(XCLUSTER ovld network-topology)/$TOPOLOGY/Envsettings
xc mkcdrom network-topology ...
```

Default;
```
xc mkcdrom network-topology ...
# Eqivalent to;
xc mkcdrom xnet ...
```

Usually the number of VMs and testers can be scaled by setting `__nvm`
and `__ntesters` but most setups must have a defines number of
routers, so setting `__nrouters` should be avoided.


## Test

```
# Test all topologies;
./network-topology.sh test
# Test a specific topology
./network-topology.sh test $TOPOLOGY
```


## Xnet

<img src="xnet.svg" alt="Default network topology" width="70%" />

This is the "default" xcluster network topology described
[here](../../doc/networking.md). This obsoletes [ovl/xnet](../xnet/).


## Dual-path

<img src="dual-path.svg" alt="Dual-path network topology" width="80%" />

This setup is used for tests with multi-path/multi-homing e.g MPTCP or
SCTP with multi-homing.


