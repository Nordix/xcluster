# Xcluster/ovl - nfproxy

* Experiments with https://github.com/sbezverk/nfproxy

## Build

Build nfproxy and make sure the binary is in
"$GOPATH/src/github.com/sbezverk/nfproxy/bin/nfproxy"

## Test

Test without kube-proxy;
```
log=/tmp/$USER/nfproxy-test.log
export __cni=
export xcluster___cni=$__cni
XXOVLS=nfproxy ./xcadmin.sh k8s_test --no-stop test-template basic_dual > $log
XXOVLS=nfproxy ./xcadmin.sh k8s_test --no-stop test-template basic6 > $log
XXOVLS=nfproxy ./xcadmin.sh k8s_test --no-stop test-template basic4 > $log
```

Test with kube-proxy;
```
cdo nfproxy
log=/tmp/$USER/nfproxy-test.log
./nfproxy.sh test > $log
```

## Usage


Easiest is to use the `k8s_test` function in "xcadmin.sh". This ovl is
specifies in $XXOVLS. At the moment a `--cni` must *not* be used.


```
# Ipv4-only cluster;
XXOVLS=nfproxy ./xcadmin.sh k8s_test test-template basic4
# Dual-stack;
XXOVLS=nfproxy ./xcadmin.sh k8s_test test-template basic_dual
# Ipv4-only leave the cluster up for examination;
XXOVLS=nfproxy ./xcadmin.sh k8s_test --no-stop test-template basic4
vm 2   # Open a terminal and examine things, e.g;
vm-002 ~ # cat /bin/kube-proxy
```
