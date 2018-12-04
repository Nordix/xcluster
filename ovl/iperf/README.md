# Xcluster ovl - iperf3

Use [iperf3](https://github.com/esnet/iperf) in xcluster-

## Usage

```
# Use the normal image (no k8s);
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
# Start
SETUP=test xc mkcdrom ecmp iperf; xc start
# On router;
/sbin/sysctl net.ipv4.tcp_available_congestion_control
iperf3 -i0 -d -k1 -c 10.0.0.2 -C reno  # Does NOT work!
iperf3 -i0 -t 5 -c 192.168.1.3
# iperf2 works fine;
iperf2 -p 5002 -c 10.0.0.2 -t 1 -P 12
iperf2 -p 5002 -t 5 -c 192.168.1.3
```

With Kubernetes;
```
xc mkcdrom private-reg iperf; xc start
# On cluster;
kubectl apply -f /etc/kubernetes/iperf.yaml
kubectl get pods -o wide
# Test
iperf2 -p 5002 -t5 -c 11.0.4.2
iperf2 -p 5002 -t5 -c iperf2.default.svc.xcluster
```

With Kubernetes and encryption;
```
# With IPSec;
xc mkcdrom private-reg podsec iperf; xc start
# With WireGuard;
SETUP=wireguard xc mkcdrom wireguard private-reg podsec iperf; xc start
```


## Build

### Iperf3

```
# Download;
mkdir -p $GOPATH/src/github.com/esnet
cd $GOPATH/src/github.com/esnet
git clone git@github.com:esnet/iperf.git
# Build;
cd $GOPATH/src/github.com/esnet/iperf
git clean -xdf
./configure --enable-static --disable-shared
make -j$(nproc)
strip src/.libs/iperf3
#(git status --ignored)
```

### Iperf2

```
ar=$ARCHIVE/iperf-2.0.12.tar.gz
cd $XCLUSTER_WORKSPACE
tar xf $ar
cd iperf-2.0.12
./configure
make -j$(nproc)
strip src/iperf
```

### K8s Image

```
images mkimage --force $($XCLUSTER ovld iperf)/image
img=library/iperf:0.1
skopeo copy --dest-tls-verify=false docker-daemon:$img docker://172.17.0.2:5000/$img
```
