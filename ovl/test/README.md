# Xcluster - ovl/test

Contains a test library and a basic test program for `xcluster` itself.

The test library is written in `shell` script (not bash). And no, it
will not use any "test framework" in the future, since those tend to
be heavy-weight, feature bloated and go in and out of fashion quickly.

There are no hard rules on howto write an ovl (except that the `tar`
script must exist), but there are some recommendation to make life
easier for users, and for CI:

* Have a script in ovl's with the same name but `.sh` extension
* The script shall implement sub-command "test [overlays...]".
* Write a summary to stderr and extensive log to stdout. Use the `tcase`,
  `tlog` and `tdie` functions where appropriate
* The script shall implement a "default" test, and invoke it if no test
  case is specified
* The test script shall return error on failure, and leave the cluster
  running for troubleshooting
* For Kubernetes tests, the script shall handle the `--cni=` option


Normally ovls are created with `xcadmin mkovl`, which setup a test
script.

```
#xcadmin mkovl --template=template --ovldir=/tmp ovl-no-k8s
xcadmin mkovl --ovldir=/tmp example-ovl   # (template-k8s is used by default)
cd /tmp/example-ovl   # (cdo can't be used unless /tmp is in $XCLUSTER_OVLPATH)
./example-ovl.sh      # Help printout
./example-ovl.sh env  # Print influential environment variables
export __log=/tmp/$USER/xcluster.log
./example-ovl.sh test # Execute default tests in default environment
# Use a different setup, and leave the cluster running
./example-ovl.sh test --no-stop --cni=flannel default containerd
```
