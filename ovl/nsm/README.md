# Xcluster ovl - nsm

Network Service Mesh [NSM](https://networkservicemesh.io/)
([github](https://github.com/networkservicemesh/networkservicemesh/))
in xcluster.


## Usage

A [Private registry](../private-reg) is assumed (but not required).

Pre-load images;
```
ver=master
# NSM;
images lreg_cache docker.io/networkservicemesh/admission-webhook:$ver
images lreg_cache docker.io/networkservicemesh/vppagent-dataplane:$ver
images lreg_cache docker.io/networkservicemesh/nsmdp:$ver
images lreg_cache docker.io/networkservicemesh/nsmd:$ver
images lreg_cache docker.io/networkservicemesh/nsmd-k8s:$ver
images lreg_cache docker.io/networkservicemesh/spire-registration:$ver
images lreg_cache gcr.io/spiffe-io/wait-for-it:latest
images lreg_cache docker.io/lobkovilya/spire-agent:kind
images lreg_cache gcr.io/spiffe-io/spire-agent:0.8.0
# Needed for icmp-responder test;
images lreg_cache docker.io/networkservicemesh/nsm-init:$ver
images lreg_cache docker.io/networkservicemesh/nsm-coredns:$ver
images lreg_cache docker.io/networkservicemesh/nsm-monitor:$ver
images lreg_cache docker.io/networkservicemesh/test-common:$ver
images lreg_cache docker.io/networkservicemesh/vpp-test-common:$ver
images lreg_cache docker.io/alpine:latest
```

Manual start;
```
export __mem1=2048
export __mem=1536
xc mkcdrom nsm private-reg; xc starts
cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
helm install --generate-name --set spire.enable=false --set insecure=true deployments/helm/nsm
kubectl get pods   # Wait until the "nsmgr" pods are ready, 3/3
helm install --generate-name deployments/helm/icmp-responder
NSM_NAMESPACE=default ./scripts/nsc_ping_all.sh
kubectl get pods   # Wait until the "alpine-nsc" pods are ready, 3/3
NSM_NAMESPACE=default ./scripts/nsc_ping_all.sh
```

Start with the test-system;
```
export __mem1=2048
export __mem=1536
XOVLS=private-reg ./nsm.sh test --mode=dual-stack start
# Now NSM is up and ready.
cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
helm install deployments/helm/icmp-responder --generate-name
kubectl get pods   # Wait until the "alpine-nsc" pods are ready, 3/3
NSM_NAMESPACE=default ./scripts/nsc_ping_all.sh
```

## Automatic testing

When the manual test work, do them automatically;
```
export __mem1=2048
export __mem=1536
XOVLS=private-reg ./nsm.sh test > /tmp/nsmtest.log
```

## The bridge-domain example

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


## Local images

Build NSM locally;
```
cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
GO111MODULE=on go mod tidy
make k8s-build
docker images | grep networkservicemesh
```

This will create the NSM images in your local docker daemon with tag
`latest`. The "test-common" images are not built.


Upload the local-built images to the private registry;
```
ver=latest
# NSM;
images lreg_upload --strip-host docker.io/networkservicemesh/admission-webhook:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/vppagent-dataplane:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/nsmdp:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/nsmd:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/nsmd-k8s:$ver
#images lreg_upload --strip-host docker.io/networkservicemesh/kernel-forwarder:$ver
# Needed for icmp-responder test;
images lreg_upload --strip-host docker.io/networkservicemesh/nsm-init:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/nsm-coredns:$ver
images lreg_upload --strip-host docker.io/networkservicemesh/nsm-monitor:$ver
```

Manual start with local-built images;
```
export __mem1=2048
export __mem=1536
xc mkcdrom nsm private-reg; xc starts
cd $GOPATH/src/github.com/networkservicemesh/networkservicemesh
helm install --generate-name --set tag=latest deployments/helm/nsm
helm install --generate-name deployments/helm/icmp-responder
NSM_NAMESPACE=default ./scripts/nsc_ping_all.sh
```


