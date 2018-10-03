Xcluster overlay - etcd
=======================

The [etcd](https://github.com/coreos/etcd) distributed key-value store.

[Etcd](https://github.com/coreos/etcd) is a central component in
Kubernetes. it is a distributed reliable key-value store and uses
[raft](https://raft.github.io/) for consensus.

Usage
-----

```
xc mkcdrom systemd etcd other-overlays...
# Or;
SETUP=etcd-start xc mkcdrom etcd [other-overlays...]
# On a vm;
etcdctl member list
etcdctl put Hello World
etcdctl get Hello
etcdctl get "" --from-key
etcdctl get "" --prefix=true
etcdctl get --prefix=true '' -w fields | grep '"Key"'
```

API versions
------------

The various etcd API versions are very confusing. Kubernetes seem to
require;

    ETCDCTL_API=3

which is set in the etcd overlay. The help text and options/parameters
are different for different api versions;

    ETCDCTL_API=2 etcdctl help




Info
----


 * [Howto ETCDCTL_API=2](https://www.digitalocean.com/community/tutorials/how-to-use-etcdctl-and-etcd-coreos-s-distributed-key-value-store)


Problems
--------

If the data-dir is lost or corrupt on a node it can never recover
automatically(!). The node must be removed and re-added. This is
cosidered to be perfecly ok and HA(!!).

It will happen on a `xc scalein` since the disk is re-initiated on
a subsequent scaleout.  What will happen is that `etcd` bails out with
a message like;

```
2018-01-30 10:13:43.566760 C | etcdmain: member e7db4eebbdb94a11 has already been bootstrapped
```

`Etcd` is only started on vm 1-3 which allows one of these to fail but
not two (consensus is lost).
