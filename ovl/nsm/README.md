# Xcluster ovl - nsm

Network Service Mesh [NSM](https://networkservicemesh.io/)
([github](https://github.com/networkservicemesh/networkservicemesh/))
in xcluster.


## NSM next-generation

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

Usage with the test system;
```
#export xcluster_NSM_FORWARDER=generic
#export xcluster_NSM_NSE=generic
#export xcluster_NSM_FORWARDER_CALLOUT=/bin/forwarder.sh
log=/tmp/$USER/xcluster.log
export __get_logs=yes
xcadmin k8s_test --no-stop nsm basic_nextgen > $log
# Login and investigate things, e.g. kubectl logs ...
# Investigate logs;
./nsm.sh readlog /tmp/$USER/nsm-logs/nsmgr-local.log | less
```

Build local image;
```
x=cmd-nsc
cd $GOPATH/src/github.com/networkservicemesh/$x
docker build --target=runtime --tag=registry.nordix.org/cloud-native/nsm/$x:latest .
images lreg_upload --strip-host registry.nordix.org/cloud-native/nsm/$x:latest
```


## Usage

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


