# Xcluster - ovl/containerd

[Containerd](https://containerd.io/) in `xcluster`.

## Usage

Add this ovs when running K8s to replace `cri-o` which is the default
CRI-plugin. Example;

```
XXOVLS=containerd xcadmin k8s_test test-template > $log
# Or;
cdo test-template
XOVLS="private-reg containerd" ./test-template.sh test > $log
```

`Ovl/containerd` has only been tested with "private-reg". Some images
that are "pre-pulled" for `cri-o` must be cached;

```
for i in $(xcadmin prepulled_images); do
  images lreg_cache $i
done
```


## Config

Generate default;
```
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
```

## Private registry

The start script generates a config from `/etc/spoofed-hosts`;

```
version = 2
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://docker.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry-1.docker.io"]
      endpoint = ["http://registry-1.docker.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["http://k8s.gcr.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["http://gcr.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.nordix.org"]
      endpoint = ["http://registry.nordix.org"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://quay.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
      endpoint = ["http://ghcr.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."projects.registry.vmware.com"]
      endpoint = ["http://projects.registry.vmware.com"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
      endpoint = ["http://registry.k8s.io"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."docker.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry-1.docker.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."k8s.gcr.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."gcr.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.nordix.org".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."quay.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."ghcr.io".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."projects.registry.vmware.com".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.k8s.io".tls]
      insecure_skip_verify = true

```
