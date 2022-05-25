# Xcluster - ovl/test

Contains a test library and a basic test program for `xcluster` itself.

The test library is written in `shell` script (not bash). There are
some recommendations to keep tests uniform;

#### Always have a test script in all ovl's

```
ovl/ovl-name/ovl-name.sh
ovl/ovl-name/default/bin/ovl-name_test
```
The `ovl-name_test` is loaded on all VMs.

#### Write a summary to stderr and extensive log to stdout

Normal invocation;
```
log=/tmp/$USER/xcluster.log
cdo ovl-name
./ovl-name.sh test > $log
```
The script shall take options "test [test-suites...]".

#### The test script shall return error on failure

And leave the cluster running for troubleshooting.



## Test program example

Create an ovl called "testex" in your `$XCLUSTER_OVLPATH`. Create a
`testex.sh` script;

```sh
#! /bin/sh
. $($XCLUSTER ovld test)/default/usr/lib/xctest
xcluster_start
xcluster_stop
```

Invoke with;
```
log=/tmp/$USER/xcluster.log
./testex.sh test > $log
# To use xterm's and leave the cluster running;
__xterm=yes __no_stop=yes ./testex.sh test > $log
xc stop
```

This just start an `xcluster`, checks that the VMs are started, and
stops. The options ("test ...") are ignored in this basic example

Now create a `default/bin/testex_test` script;
```sh
#! /bin/sh
. /etc/profile
. /usr/lib/xctest
tcase "Called with [$@]"
kver=$(uname -r)
tlog "Kernel version: $kver"
test "$2" != "FAIL" || tdie "FAILED [$@]"
```

And alter the `testex.sh` script;
```sh
#! /bin/sh
. $($XCLUSTER ovld test)/default/usr/lib/xctest
xcluster_start
otc 1 "my_test_test_case PASS"
xcluster_stop
```

`otc 1 ...` invokes the `testex_test` on VM 1. Check the paramaters
and try to change "PASS" to "FAIL".

```
# ./testex.sh test > $log
  09:42:05 (uablrek-XPS-13-9370): TEST CASE: Build cluster [env  testex private-reg test]
  09:42:05 (uablrek-XPS-13-9370): TEST CASE: Cluster start (hd-k8s.img)
  09:42:07 (uablrek-XPS-13-9370): TEST CASE: VM connectivity; 1 2 3 4 201 202 
  09:42:07 (vm-001): TEST CASE: Called with [tcase_kernel_version PASS]
  09:42:07 Kernel version: 5.17.8
  09:42:08 (uablrek-XPS-13-9370): TEST CASE: Stop xcluster
```


## More info

Please see [ovl/test-template](../ovl/test-template) for a more
comprehensive example.


## Xcluster self test

```
log=/tmp/$USER/xcluster.log
./test.sh test > $log
```
