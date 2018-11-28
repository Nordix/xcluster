# Xcluster ovl - Older Kubernetes

Use older versions (<v1.12) of Kubernetes in `xcluster`.


## Usage

```
eval $($XCLUSTER env | grep XCLUSTER_HOME=)
export __image=$XCLUSTER_HOME/hd-k8s-v1.9.img
xc mkimage
images make coredns nordixorg/mconnect:v1.2
# MAKE SURE cri-o HAS CORRECT VERSION!!
SETUP=v1.9 xc ximage systemd etcd iptools k8s-old coredns mconnect images
xc mkcdrom externalip; xc starts
# On cluster;
kubectl apply -f /etc/kubernetes/mconnect.yaml
mconnect -address mconnect.default.svc.xcluster:5001 -nconn=400
# On router;
mconnect -address 10.0.0.2:5001 -nconn 400
```

### Cri-o


```
sudo apt install libseccomp-dev
cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
git checkout release-1.9
go install ./cmd/crictl
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
git checkout release-1.9
make install.tools
make
git status --ignored
strip bin/*
```

