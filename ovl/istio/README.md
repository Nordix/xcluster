# Xcluster/ovl - istio

## Getting started

* https://istio.io/latest/docs/setup/getting-started/
* https://istio.io/latest/docs/ops/integrations/prometheus/

Prepare;
```
ISTIO_VERSION="$(curl -sL https://github.com/istio/istio/releases | \
  grep -o 'releases/[0-9]*.[0-9]*.[0-9]*/' | sort --version-sort | \
  tail -1 | awk -F'/' '{ print $2}')"
ar=istio-$ISTIO_VERSION-linux-amd64.tar.gz
curl -L https://github.com/istio/istio/releases/download/$ISTIO_VERSION/$ar \
  > $ARCHIVE/$ar
images lreg_cache docker.io/istio/proxyv2:$ISTIO_VERSION
images lreg_cache docker.io/istio/pilot:$ISTIO_VERSION
xver=1.16.2
for n in examples-bookinfo-details-v1 examples-bookinfo-ratings-v1 \
  examples-bookinfo-reviews-v1 examples-bookinfo-reviews-v2 \
  examples-bookinfo-reviews-v3 examples-bookinfo-productpage-v1; do
  images lreg_cache docker.io/istio/$n:$xver
done
```

Start and install;
```
cdo istio
./istio.sh test start > $log
# Or;
#export xcluster_IPV6_PREFIX=1000::1:
export __k8sver=v1.19.3
xcadmin k8s_test istio start > $log
xcadmin k8s_test --mode=ipv6 istio start > $log
# On vm-001
export ISTIO_VERSION=$(cat ISTIO_VERSION)
tar xzf istio-$ISTIO_VERSION-linux-amd64.tar.gz
alias istioctl=$PWD/istio-$ISTIO_VERSION/bin/istioctl
istioctl install --set profile=demo --set tag=$ISTIO_VERSION
kubectl label namespace default istio-injection=enabled --overwrite
assign-lb-ip -n istio-system -svc istio-ingressgateway -ip 10.0.0.1

# sample application
cd istio-1.7.4
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl get pods  # Wait for ready 2/2
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
# Back on the host;
kubectl -n istio-system get service istio-ingressgateway -o json | \
  jq '.spec.ports[]|select(.name == "http2")|.nodePort'
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
echo "http://192.168.0.1:$INGRESS_PORT/productpage"
#echo "http://[1000::1:192.168.0.1]:$INGRESS_PORT/productpage"
firefox -no-remote -P netns &
# Check the URL...
```

## Local testing

```
# Start as above, then;
# On vm-001
kubectl label namespace default istio-injection=enabled --overwrite
log=/tmp/test.log
k8s-test_test tcase_start_servers > $log
```


## Trouble-shooting

Links;

* https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/

* https://istio.io/latest/docs/ops/common-problems/injection/

* https://github.com/istio/istio/issues/22500

Commands;
```
kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o json
kubectl get namespace -L istio-injection
```