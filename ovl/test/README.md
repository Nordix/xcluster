# Xcluster test overlay

Contains test programs for `xcluster` itself and for Kubernetes on
xcluster.


## Usage

```
xc mkcdrom externalip test; xc start
# On cluster;
xctest k8s
# Or;
$(dirname $XCLUSTER)/xcadmin.sh test --xterm > /tmp/$USER/xctest.log
```

## Test code

Test programs are installed in `/usr/sbin` on the VMs.

There is no more requirement than that the test program shall return
with an error if the test fails and with success (0) otherwise.

As recommendation is that every test program shall output a
description if invoked with `--help`.
