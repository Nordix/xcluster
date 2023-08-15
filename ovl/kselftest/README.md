# Xcluster/ovl - kselftest

Linux kernel self-test.

https://www.kernel.org/doc/html/v5.0/dev-tools/kselftest.html

Include the ovl kselftest when starting xcluster.
PLEASE NOTE: bash ovl is pre-requisite for running some selftests
```
./kselftest.sh test start ...
## vm-001
cd /kselftest/
./run_kselftest.sh -t net/forwarding:router_multipath_vip.sh
```

## Adding local tests
Add the shell script (*.sh) to default/kselftest directory, the test will be added to the /kselftest in the targets and the kselftest-list.txt will be updated to enable running the test via run_kselftest utility.