# Xcluster/ovl - nfproxy

Experiments with https://github.com/sbezverk/nfproxy


## Usage from scratch

* Install `xcluster` v3.x.x as described in the [Quick start](https://github.com/Nordix/xcluster#quick-start).

* Verify that the installation works.

```
./xcadmin.sh k8s_test test-template basic_dual
```

* Download and install the `bzImage` from xcluster v3.0.1 as described
  in the release note.

* Clone `xcluster` and set $XCLUSTER_OVLPATH to get the latest version
  of this ovl

```
xclusterdir=$HOME/xcluster-clone  # Change to your preference
mkdir -p $xclusterdir
cd $xclusterdir
git clone --depth 1 https://github.com/Nordix/xcluster.git
export XCLUSTER_OVLPATH=$xclusterdir/xcluster/ovl
```

* Build nfproxy and make sure the binary is in "$GOPATH/src/github.com/sbezverk/nfproxy/bin/nfproxy"

* Verify that the nfproxy builds ok

```
cdo nfproxy
./tar - | tat t
# (output;)
bin/
bin/nfproxy
etc/
etc/init.d/
etc/init.d/32nfproxy.rc
etc/init.d/25nfproxy-prep.rc
```

* Start `xcluster` with `nfproxy`







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
