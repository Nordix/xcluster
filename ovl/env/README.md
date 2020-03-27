# Xcluster/ovl - env

* Pass environment variables to the VMs

This ovl provides a way to pass variables from the host to the
xcluster VMs. Environment variables prefixed with "xcluster_" will be
added to `/etc/profile` in all VMs. Scripts must source this file and
can then check the variables. The prefix ("xcluster_") is removed.

```
xcluster_ENABLE=featureX xc mkcdrom env ...
# On node;
cat /etc/profile
ENABLE=featureX
...
```


