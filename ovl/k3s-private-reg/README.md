# Xcluster ovl - k3s-private-reg

Use a private local (unsecure) docker registry for the `k3s` cluster
on `xcluster`. This allows working offline without having all images
pre-pulled. But the images you need must instead be "cached" in your
local registry.



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
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd-k3s.img
xc mkcdrom k3s-private-reg ...(other ovls); xc starts

```

### DNS spoof

If the `$__dns_spoof` variable points to a file with FQDN's those will
be set to the local registry in `/etc/hosts`

```
cat $__dns_spoof
docker.io
registry-1.docker.io
k8s.gcr.io
gcr.io
registry.nordix.org
# On cluster;
head /etc/hosts
127.0.0.1 localhost
::1       ip6-localhost ip6-loopback
172.17.0.1 docker.io
172.17.0.1 registry-1.docker.io
172.17.0.1 k8s.gcr.io
172.17.0.1 gcr.io
172.17.0.1 registry.nordix.org
192.168.1.1 vm-001
192.168.1.2 vm-002
```


### Alter the sites that shall be cached

Add (or remove) sites in file;

```
./default/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
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

