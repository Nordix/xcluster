# Xcluster - ovl/containerd

[Containerd](https://containerd.io/) in `xcluster`.

## Usage

Add this ovs when running K8s to replace `cri-o` which is the default
CRI-plugin.

```
XXOVLS=containerd xcadmin k8s_test test-template > $log
# Or;
cdo test-template
./test-template.sh test basic containerd > $log
```

`Ovl/containerd` has only been tested with "private-reg".


## Config

Generate default;
```
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
```

Do this rather than trying to read the `containerd` documentation
which has been outdated, incomplete and outright faulty
([issue](https://github.com/containerd/containerd/issues/9886)).

## Private registry

The private registry is used by default. The `32cri-plugin.rc`
generates configs. For version $lt$ 2.0 the `/etc/spoofed-hosts`
is used. For containerd `2.0+` it's simpler:

```
# tree /etc/containerd
/etc/containerd
├── certs.d
│   └── _default
│       └── hosts.toml
└── config.toml

# cat /etc/containerd/config.toml
version = 3
[plugins.'io.containerd.cri.v1.images'.PinnedImages]
  sandbox = "registry.k8s.io/pause:3.9"
[plugins.'io.containerd.cri.v1.images'.registry]
  config_path = "/etc/containerd/certs.d"
# cat /etc/containerd/certs.d/_default/hosts.toml 
server = "http://example.com:80"
[host."http://example.com:80"]
  capabilities = ["pull"]
  skip_verify = true
```

`example.com` is spoofed in `/etc/hosts` to the address of the private
docker registry.


## Pause image version

The version seems hard-coded to `pause:3.8`, but it is modified in the
`./tar` script to the same version as in `ovl/crio`. (this can
probably be done in a less obscure way)



