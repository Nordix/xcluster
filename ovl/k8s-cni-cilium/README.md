# Xcluster/ovl - k8s-cni-cilium

The [cilium](https://github.com/cilium/cilium) CNI-plugin for
[k8s-xcluster](../k8s-xcluster/README.md).

SCTP is not supported issue [#5719](https://github.com/cilium/cilium/issues/5719)

## Usage

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export __nvm=5
SETUP=ipv4 xc mkcdrom k8s-cni-cilium private-reg; xc starts
```

## Build

Upgrade
```
ver=1.8.2
curl https://raw.githubusercontent.com/cilium/cilium/$ver/install/kubernetes/quick-install.yaml > quick-install-$ver.yaml
meld quick-install.yaml default/etc/kubernetes/load/quick-install.yaml &
cp quick-install-1.8.2.yaml default/etc/kubernetes/load/quick-install.yaml
# Modify quick-install.yaml
images lreg_missingimages default
# Update local-reg
```

```
mkdir -p $GOPATH/src/github.com/cilium
cd $GOPATH/src/github.com/cilium
git clone --depth 1 https://github.com/cilium/cilium.git
cd $GOPATH/src/github.com/cilium/cilium/install/kubernetes
helm template cilium \
  --namespace kube-system \
  --set global.containerRuntime.integration=crio \
  --set global.ipvlan.masterDevice=eth1 \
  --set global.tunnel=disabled \
  --set global.masquerade=true \
  --set global.installIptablesRules=false \
  --set global.autoDirectNodeRoutes=true \
  --set global.kubeProxyReplacement=strict \
  --set global.k8sServiceHost=192.168.1.1 \
  --set global.k8sServicePort=6443 \
  --set global.device=eth1 \
  --set config.ipam=kubernetes \
  > cilium.yaml
#  --set global.datapathMode=ipvlan \
```

Check http://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/



## Test

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
export __mem=1024
t=test-template
XOVLS="k8s-cni-cilium private-reg" $($XCLUSTER ovld $t)/$t.sh test basic4 > $XCLUSTER_TMP/$t-test.log
XOVLS="k8s-cni-cilium private-reg" $($XCLUSTER ovld $t)/$t.sh test basic_dual > $XCLUSTER_TMP/$t-test.log
t=metallb
XOVLS="k8s-cni-cilium private-reg" $($XCLUSTER ovld $t)/$t.sh test basic_dual > $XCLUSTER_TMP/$t-test.log
```

```
eso k8s_test --cni=cilium --mode=ipv4 "test-template start"
kubectl apply -f ./connectivity-check.yaml
kubectl get pods   # All shall become ready
```

## Debug

Use the "cilium" program inside a POD;
```
#kubectl exec -it cilium-jv7w2 -- bash
kubectl exec -it -n kube-system \
 $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) -- bash
pod=$(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1)
kubectl exec -it -n kube-system $pod -- bash
kubectl logs $pod
# In the POD;
cilium --help
cilium endpoint list
```

## Problems


#### TPROXY

Cilium needs `--tproxy-mark` in iptables.

Fix;
```
xc kernel_build --menuconfig
export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
xc mkimage
cdo iptools
rm -r /home/uablrek/tmp/xcluster/workspace/iptables-1.8.2
./iptools.sh build
# Test
xc mkcdrom iptools; xc starts --nvm=1 --nrouters=0
# On cluster;
ls /lib/modules/5.1.7/kernel/net/netfilter/
iptables -t mangle -A PREROUTING -p tcp -j TPROXY --tproxy-mark 0x1/0x1 --on-port 5000
xc cache iptools
```
