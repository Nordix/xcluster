# Xcluster - ovl/k8s-cni-calico

Use [project calico](https://www.projectcalico.org/) in
`xcluster`. Different date-planes can be tested.

Calico has currently 3 data-planes:

* linux - the traditional Calico data-plane
* epbf - A eBPF based data-plane ([only ipv4 for now](
         https://github.com/projectcalico/calico/issues/4736))
* vpp - A VPP user-space data-plane (not working yet in xcluster)

The installation can also be made with manifests or the `Tigera operator`.



## Usage

Pre-load the private registry if needed;
```
cdo k8s-cni-calico
images lreg_preload default
# If the Tigera operator is used;
ver=v3.24.5
images lreg_cache docker.io/calico/pod2daemon-flexvol:$ver
images lreg_cache docker.io/calico/typha:$ver
images lreg_cache docker.io/calico/apiserver:$ver
```

The easiest way to use Calico is to start with `xcadmin`. This will
use the "linux" data-plane.

```
xcadmin k8s_test --cni=calico test-template > $log
```


## Data-planes

The data-plane and installation is selected with the
$xcluster_CALICO_BACKEND environment variable for now. But data-planes
also have other requirements, for instance to disable `kube-proxy` or
need more memory or huge-pages.

Values for $xcluster_CALICO_BACKEND:

* `legacy` or empty - Install the linux data-plane with manifests
* `operator+install-linux` - Install the linux data-plane with the Tigera operator
* `operator+install-vpp` - Install the VPP data-plane with the Tigera operator
* `bpf` - Install the eBPF data-plane with manifests

The VPP and eBPF data-planes replaces the `kube-proxy` so it has to be
disabled. The VPP data-plane require much more memory and optionally
huge-pages.

The `k8s-cni-calico.sh` script has functions for start with different
data-planes. Then other ovl's can be started with the `--no-start`
flag.

```
./k8s-cni-calico.sh        # Help printout
./k8s-cni-calico.sh test start_bpf k8s-test > $log
xcadmin k8s_test --no-start k8s-test > $log
# VPP doesn't work yet
./k8s-cni-calico.sh test start_vpp k8s-test > $log
```

While testing out configurations it may be best to start manually.

```
#export xcluster_PROXY_MODE=disabled
#__xterm=yes __mem=2G __mem1=1G __nvm=3 \
./k8s-cni-calico.sh test start_empty > $log
# On vm-001:
/etc/kubernetes/init.d/50calico.sh   # help printout
/etc/kubernetes/init.d/50calico.sh operator
/etc/kubernetes/init.d/50calico.sh vpp
```


## Upgrade

The manifests are altered but a 3-way diff can make it easier to
upgrade to newer versions.

```
cdo k8s-cni-calico
curl -L -o calico-new.yaml https://raw.githubusercontent.com/projectcalico/calico/release-v3.25/manifests/calico.yaml
# Check the xcluster specific config. (3-way diff)
meld calico-orig.yaml default/etc/kubernetes/calico/calico.yaml calico-new.yaml &
# apply the modifications and save.
cp calico-new.yaml default/etc/kubernetes/calico/calico.yaml
# Cache images
images lreg_preload default
# Test!! And if everything works;
mv -f calico-new.yaml calico-orig.yaml
# Commit updates
```


## Doc/check

In no particular order.

* https://docs.projectcalico.org/v3.8/networking/ipv6

* https://docs.projectcalico.org/v3.8/reference/felix/configuration

* https://docs.projectcalico.org/v3.8/getting-started/calicoctl/install

* https://projectcalico.docs.tigera.io/reference/installation/api

* https://www.server-world.info/en/note?os=Scientific_Linux_6&p=kvm&f=8

```
logs -n kube-system calico-node-cn5fv | grep -i "Successfully loaded configuration"
```
