# Xcluster ovl - k3s-private-reg

Use a private local (unsecure) docker registry for the `k3s` cluster
on `xcluster`. This allows working offline without having all images
pre-pulled. But the images you need must instead be "cached" in your
local registry.



### Necessary PR

Containerd let you [specify
mirrors](https://github.com/containerd/cri/blob/master/docs/registry.md#configure-registry-endpoint)
which may be used for re-direct to a local (unsecure) registry.

At the moment of writing the PR for configuring `containerd`
[#381](https://github.com/rancher/k3s/pull/381) is not merged, so you
must apply it and build locally.


## Setup the private registry

See ovl [private-reg](../private-reg/README.md). Ipv6 is not needed
(unless you want to test it).

## Cache images

The `images` alias can be used, example;
```
images lreg_cache k8s.gcr.io/pause:3.1
images lreg_cache docker.io/coredns/coredns:1.3.0
```

## Usage

```
xc mkcdrom k3s-private-reg ...(other ovls); xc starts

```

### Alter the sites that shall be cached

Add (or remove) sites in file;

```
./default/etc/containerd.conf
```

### Tip

If you (like me) intend to use the private registry always it is
convenient to add it permanently to your `k3s` image;

```
xc ximage k3s-private-reg
```


## Monitor external access

You might want to verify that no external image access is made and an
easy way it to monitor DNS queries. `Xcluster` starts a local CoreDNS
on port 10053. A message about this is printed the first time the
"Envsettins.*" is sourced. Monitor the coredns log with;

```
tail -f /tmp/$USER/coredns.log
```
