# Xcluster - ovl/k8s-cni-calico

Use [project calico](https://www.projectcalico.org/) in
`xcluster`. Different date-planes can be tested.

Calico has currently 3 data-planes:

* linux - the traditional Calico data-plane
* epbf - A eBPF based data-plane ([no dual-stack support](
         https://github.com/projectcalico/calico/issues/4736))
* vpp - A VPP user-space data-plane (not working yet in xcluster)

The installation can be made with manifests or the `Tigera operator`.



## Usage

The easiest way to use Calico is to include this ovl, start with
`xcadmin` or add it to the start command. This will use the "linux"
data-plane.

```
images lreg_preload k8s-cni-calico
xcadmin k8s_test --cni=calico test-template > $log
# or
cdo test-template
./test-template.sh test basic k8s-cni-calico > $log
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
./k8s-cni-calico.sh test start_bpf test-template > $log
xcadmin k8s_test --no-start test-template > $log
# VPP
./k8s-cni-calico.sh test start_vpp test-template > $log
xcadmin k8s_test --no-start test-template > $log
```

Extra pre-loads needed by the operator and vpp:
```
ver=v3.26.4
images lreg_cache docker.io/calico/pod2daemon-flexvol:$ver
images lreg_cache docker.io/calico/typha:$ver
images lreg_cache docker.io/calico/node-driver-registrar:$ver
images lreg_cache docker.io/calico/csi:$ver
images lreg_cache docker.io/calicovpp/agent:v3.26.0
images lreg_cache docker.io/calicovpp/vpp:v3.26.0
```

While testing out configurations it may be best to start manually.

```
#export xcluster_PROXY_MODE=disabled
#__xterm=yes __mem=2G __mem1=3G __nvm=3 \
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
src=https://raw.githubusercontent.com/projectcalico/calico/release-v3.26/manifests
curl -L -o calico-orig.yaml $src/calico.yaml
cp calico-orig.yaml calico-new.yaml
# Check the xcluster specific config. (3-way diff)
meld calico-orig.yaml default/etc/kubernetes/calico/calico.yaml calico-new.yaml &
# apply the modifications and save.
cp calico-new.yaml default/etc/kubernetes/calico/calico.yaml
# Cache images
images lreg_preload default
# Test!! And if everything works; Commit updates

# Other manifests
dst=./default/etc/kubernetes/calico/
for m in calicoctl.yaml tigera-operator.yaml custom-resources.yaml; do
  curl -L -o $dst/$m $src/$m
done
curl -L -o $dst/calico-vpp-nohuge.yaml https://raw.githubusercontent.com/projectcalico/vpp-dataplane/release/v3.26.0/yaml/generated/calico-vpp-nohuge.yaml
```


## Doc/check

In no particular order.

* https://docs.projectcalico.org/v3.8/networking/ipv6
* https://docs.projectcalico.org/v3.8/reference/felix/configuration
* https://docs.tigera.io/calico/latest/operations/calicoctl/install
* https://projectcalico.docs.tigera.io/reference/installation/api
* https://www.server-world.info/en/note?os=Scientific_Linux_6&p=kvm&f=8

```
logs -n kube-system calico-node-cn5fv | grep -i "Successfully loaded configuration"
```
