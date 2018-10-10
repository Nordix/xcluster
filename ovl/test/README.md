# Xcluster tests

Contains test programs for `xcluster` itself and for Kubernetes on
xcluster.

No "tool" or procedure is imposed or recommended. To do that at early
stages usually leads to regrets. A wise advice I once got;

> It doesn't matter how you write the tests, just write them!

The danger is to spend too much time searching for the perfect tool so
at the end of the day no tests are written.


## Usage

```
xc mkcdrom externalip test; xc start
# On cluster;
xctest k8s
# Or;
xc mkcdrom externalip test
$(dirname $XCLUSTER)/xcadmin.sh test --xterm > /tmp/$USER/xctest.log
```

## Test code

Test programs are installed in `/usr/sbin` on the VMs.

There is no more requirement than that the test program shall return
with an error if the test fails and with success (0) otherwise.

As recommendation is that every test program shall output a
description if invoked with `--help`.
