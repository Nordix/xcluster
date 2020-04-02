# Xcluster - ovl/k8s-cni-flannel

Use the `flannel` CNI-plugin in `xcluster`.

There is no ipv6 support according to issue
[#248](https://github.com/coreos/flannel/issues/248), and no
dual-stack support either of course.

## Build

Pre-load the private registry;
```
docker pull quay.io/coreos/flannel:v0.12.0-amd64
images lreg_upload --strip-host quay.io/coreos/flannel:v0.12.0-amd64
```

Update the manifest;
```
curl -L https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > kube-flannel.yml
git difftool kube-flannel.yml
meld kube-flannel.yml ipv4/etc/kubernetes/load/kube-flannel.yaml
```

## Usage

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export __nvm=5
SETUP=ipv4 xc mkcdrom k8s-xcluster k8s-cni-flannel; xc starts
```

## Test

```
./xcadmin.sh k8s_test --cni=flannel test-template basic4 > /dev/null
```
