# Xcluster/ovl - nfproxy

Experiments with https://github.com/sbezverk/nfproxy


## Usage

Easiest is to use the `k8s_test` function in "xcadmin.sh". This ovl is
specifies in $XXOVLS. At the moment a cni *must* be specified.


```
# Ipv4-only cluster;
XXOVLS=nfproxy ./xcadmin.sh k8s_test --cni=xcluster test-template basic4
# Dual-stack;
XXOVLS=nfproxy ./xcadmin.sh k8s_test --cni=xcluster test-template basic_dual
```
