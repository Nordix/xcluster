# Xcluster/ovl - dhcp

Tests and setups with
[DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol)
and [SLAAC](https://en.wikipedia.org/wiki/IPv6#Stateless_address_autoconfiguration_(SLAAC)).

DHCP is widely used for IPv4 (and quite simple) but [DHCPv6](
https://www.rfc-editor.org/rfc/rfc8415.html is more complicated), so
this ovl focuses most on that.

Keywords: SLAAC

## Implementations

These are downloaded or built locally. They are required to build the
ovl. Test with;

```
./tar - | tar t
```

### Udhcp

[Udhcp](https://udhcp.busybox.net/) is included (and maintained by)
`BusyBox`, so it's included in `xcluster` by default. `Udhcp` does not
have server support for IPv6 but a client (udhcpc6) exists.

The udhcp clients makes call-outs to a [script](
default/usr/share/udhcpc/default.script) where you as a used must set
(or remove/update) addresses.

```
./dhcp.sh test udhcp > $log
```

### ISC DHCP

The [ISC DHCP](https://www.isc.org/dhcp/) has a server with DHCPv6
support.

```
./dhcp.sh isc_build
./dhcp.sh isc_man
```

There is no option in DHCPv6 to pass prefix length (corresponding to
"mask" in IPv4). To use an environment variable is proposed as a
[work-around](https://kb.isc.org/docs/aa-01141).

```
./dhcp.sh test --mask=120 basic > $log
./dhcp.sh test --mask=64 basic > $log
```

#### ISC Kea

The newer DHCP implementation [Kea](https://gitlab.isc.org/isc-projects/kea)
is not currently used.


### Radvd

For IPv6 [radvd](https://github.com/radvd-project/radvd) is used to
send Router Advertisement (RA) messages.

```
./dhcp.sh radvd_build
./dhcp.sh radvd_man
```

RA messages are used to generate addresses with
[SLAAC](https://en.wikipedia.org/wiki/IPv6#Stateless_address_autoconfiguration_(SLAAC)).

```
./dhcp.sh test radvd > $log
```


## DHCPv6 and Router Advertisement messages

Even if DHCPv6 is used (instead of SLAAC) [RAs are still needed](
https://blogs.infoblox.com/ipv6-coe/why-you-must-use-icmpv6-router-advertisements-ras/).

Some fields that are included in DHCP for IPv4 are supposed to be
provided by RA for DHCPv6, for instance the [prefix length](
https://serverfault.com/questions/1044554/how-to-get-a-proper-prefix-length-from-dhcpv6-server)
("mask" for IPv4).

I haven't yet figured out how this is supposed to work, but the
`udhcpc6` might not be up to the task.

```
./dhcp.sh test dhcpv6 > $log
```
The address is still /128.



## DHCP and SLAAC with the bridge CNI-plugin

If the [bridge CNI-plugin](https://www.cni.dev/plugins/current/main/bridge/)
is used to add interfaces in PODs and the bridge enslaves an interface that
receives RAs then the POD interfases will get SLAAC addresses.

```
./dhcp.sh test --no-stop cni_bridge > $log
```

