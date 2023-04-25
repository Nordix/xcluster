# Xcluster/ovl - k8s-cni-cilium

The [cilium](https://github.com/cilium/cilium) CNI-plugin,

SCTP is not supported, issue [#5719](https://github.com/cilium/cilium/issues/5719).


## Install

A manifest (yaml) is generated with `helm` and will be used by default;

```
ver=v1.11.16
rm -rf $GOPATH/src/github.com/cilium/cilium
git clone --depth 1 -b $ver https://github.com/cilium/cilium.git \
  $GOPATH/src/github.com/cilium/cilium
cd $GOPATH/src/github.com/cilium/cilium/install/kubernetes
#less cilium/values.yaml
helm template cilium \
  --namespace kube-system \
  --set devices=eth1 \
  --set containerRuntime.integration=crio \
  --set kubeProxyReplacement=strict \
  --set k8sServiceHost=192.168.1.1 \
  --set k8sServicePort=6443 \
  --set ipv6.enabled=true \
  --set operator.replicas=1 \
  --set ipam.mode=kubernetes \
  --set bpf.masquerade=false \
  --set nativeRoutingCIDR=11.0.0.0/16 \
  > $($XCLUSTER ovld k8s-cni-cilium)/default/etc/kubernetes/load/quick-install.yaml
#  --set global.datapathMode=ipvlan \
#  --set global.ipvlan.masterDevice=eth1 \
```

You may also try the installation from the [quick-installation](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#quick-installation);
```
cd $HOME/Downloads
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
tar -C /dir/in/path -xf cilium-linux-amd64.tar.gz
export __mode=ipv4
xcadmin k8s_test test-template start_empty > $log
cilium install --restart-unmanaged-pods false --kube-proxy-replacement strict 
cilium status
__no_start=yes xcadmin k8s_test test-template basic > $log
```
Only IPv4 is supported at the moment (v1.10.4)





## Test

```
images lreg_preload k8s-cni-cilium
xcadmin k8s_test --cni=cilium test-template basic > $log
```


## Debug

* https://docs.cilium.io/en/stable/operations/troubleshooting/

Use the "cilium" program inside a POD;
```
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
