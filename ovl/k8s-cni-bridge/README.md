# Xcluster/ovl - k8s-cni-bridge

* Use the `bridge` CNI-plugin and `host-local` ipam.

The `k8s-cni-bridge` *alway* assign dual-stack addresses to PODs. The
order of the address families can be controlled with;

```
export xcluster_IP_FAMILY_ORDER=46   # (default)
# or;
export xcluster_IP_FAMILY_ORDER=64
```

## Usage

```
log=/tmp/$USER/xcluster-test.log
./xcadmin.sh k8s_test --cni=bridge test-template basic > $log
```

