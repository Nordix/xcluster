# Xcluster ovl - nsm

Network Service Mesh [NSM](https://networkservicemesh.io/)
([github](https://github.com/networkservicemesh/networkservicemesh/))
in xcluster.


## NSM next-generation

Se also https://github.com/Nordix/nsm-test/

This is a Work in Progress. Images are built locally or taken from
`registry.nordix.org/cloud-native/nsm`. A local registry is required.

Refresh local image cache;
```
images lreg_missingimages default/
for x in cmd-nsmgr cmd-nsc cmd-registry-memory cmd-nse-icmp-responder \
  cmd-forwarder-vpp; do
  images lreg_cache registry.nordix.org/cloud-native/nsm/$x:latest
done
for x in wait-for-it:latest \
  spire-agent:0.10.0 spire-server:0.10.0; do
  images lreg_cache gcr.io/spiffe-io/$x
done
```

Usage;
```
log=/tmp/$USER/xcluster.log
xcadmin k8s_test --no-stop nsm basic_nextgen > $log
# Login and investigate things, e.g. kubectl logs ...
```




## NSM 1st generation

NSM 1st generation is not maintained.

### Usage

A [Private registry](../private-reg) is assumed.

Pre-load images;
```
ver=master
# NSM;
images lreg_cache docker.io/networkservicemesh/admission-webhook:$ver
images lreg_cache docker.io/networkservicemesh/vppagent-forwarder:$ver
images lreg_cache docker.io/networkservicemesh/prefix-service:$ver
images lreg_cache docker.io/networkservicemesh/nsmdp:$ver
images lreg_cache docker.io/networkservicemesh/nsmd:$ver
images lreg_cache docker.io/networkservicemesh/nsmd-k8s:$ver
images lreg_cache gcr.io/spiffe-io/wait-for-it:latest
images lreg_cache gcr.io/spiffe-io/spire-server:0.11.0
images lreg_cache gcr.io/spiffe-io/spire-agent:0.11.0

# Needed for icmp-responder test;
images lreg_cache docker.io/networkservicemesh/nsm-dns-init:$ver
images lreg_cache docker.io/networkservicemesh/nsm-init:$ver
images lreg_cache docker.io/networkservicemesh/coredns:$ver
images lreg_cache docker.io/networkservicemesh/nsm-monitor:$ver
images lreg_cache docker.io/networkservicemesh/test-common:$ver
images lreg_cache docker.io/networkservicemesh/vpp-test-common:$ver
images lreg_cache docker.io/alpine:latest
```


Start;
```
log=/tmp/$USER/xcluster/test.log
xcadmin  k8s_test nsm start > $log
# Now NSM is up and ready.
cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
helm install deployments/helm/vpp-icmp-responder --generate-name
helm install deployments/helm/client --generate-name
```

### The bridge-domain example

Build and upload to the private registry;
```
cd $GOPATH/src/github.com/networkservicemesh/examples
make k8s-bridge-domain-build
images lreg_upload networkservicemesh/bridge-domain-bridge:latest
```

Start `xcluster` with NSM;
```
cdo nsm
export __mem1=2048
export __mem=1536
XOVLS=private-reg ./nsm.sh test start > /dev/null
```

Then follow the instruction in the
[README](https://github.com/networkservicemesh/examples/blob/master/examples/bridge-domain/README.md)
file;

```
cd $GOPATH/src/github.com/networkservicemesh/examples/examples/bridge-domain/
kubectl apply -f ./k8s/bridge.yaml
kubectl get pods -l networkservicemesh.io/app=bridge-domain
kubectl apply -f ./k8s/simple-client.yaml
kubectl get pods -l networkservicemesh.io/app=simple-client
# (wait until all simple-clients are running and ready (3/3))

# Test;
p=<select-a-simple-client-pod>
kubectl exec -it -c alpine-img $p sh
# Inside the container;
ifconfig
ping 10.60.1.1
ping 10.60.1.2
ping 10.60.1.3
```


