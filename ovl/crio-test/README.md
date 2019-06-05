# Xcluster ovl - crio-test

A small ovl for `cri-o` testing.

## Usage

```
# Download image (once);
curl -L https://artifactory.nordix.org/artifactory/cloud-native/xcluster/images/hd-k8s-pr73977.img.xz | xz -d > $__image
# Start
xc mkcdrom crio-test; xc starts
vm 2   # Open a xterm on vm-002
# Re-build - re-start
cd $GOPATH/src/github.com/cri-o/cri-o
make
xc mkcdrom crio-test; xc starts
```

On cluster tests;
```
# Print the pre-pulled images
images
# Check k8s dual-stack
kubectl get node vm-002 -o json | jq .spec
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
p=alpine-deployment-568f6756d7-....
kubectl get pod $p -o json | jq .status.podIPs
kubectl exec $p ifconfig
```

Note the used images are pre-pulled, no internet access is needed.


## Test and check the contents of the ovl

```
./tar - | tar t
```

The `crio` binary is assumed to be in
`$GOPATH/src/github.com/cri-o/cri-o/bin`, if it is some place else,
please edit the `./tar` script.
