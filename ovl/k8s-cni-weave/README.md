# Xcluster ovl - k8s-cni-weave

Use the [weave](https://www.weave.works/) CNI-plugin with `xcluster`.

Weave does not support ipv6, see; https://github.com/weaveworks/weave/issues/19

Config; https://www.weave.works/docs/net/latest/kubernetes/kube-addon/

The best configuration documentation is the
[launch-script](https://github.com/weaveworks/weave/blob/master/prog/weave-kube/launch.sh)



## Prepare

Update the manifest;
```
curl -L https://cloud.weave.works/k8s/net > weave-orig.yaml
meld weave-orig.yaml ipv4/etc/kubernetes/load/weave.yaml
```

```
ver=2.7.0
images lreg_cache docker.io/weaveworks/weave-kube:$ver
images lreg_cache docker.io/weaveworks/weave-npc:$ver
```

## Usage

```
export __image=$XCLUSTER_WORKSPACE/xcluster/hd-k8s-xcluster.img
export XCTEST_HOOK=$($XCLUSTER ovld k8s-xcluster)/xctest-hook
export __nvm=5
export __mem=1536
export XOVLS="private-reg"
xc mkcdrom k8s-cni-weave; xc starts
# Or
eso k8s_test --cni=weave --mode=ipv4 "test-template start"
# On cluster;
kubectl apply -f /etc/kubernetes/weave-daemonset-k8s-1.11.yaml
pod=$(kubectl -n kube-system get pods -l name=weave-net -o json | jq -r .items[0].metadata.name)
kubectl -n kube-system logs $pod -c weave
kubectl -n kube-system logs $pod -c weave-npc
```

## Troubleshooting

See; https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#-troubleshooting

```
kubectl get pods -n kube-system -l name=weave-net
# pick a pod from the list and do
kubectl exec -n kube-system  your-pod-id-here -c weave -- /home/weave/weave --local status
```
