# Xcluster overlay - k8s-config

Ipv6 configuration for Kubernetes.

## Usage

Assuming a k8s `xcluster` image;

```
SETUP=ipv6 xc mkcdrom etcd k8s-config externalip; xc start
```

