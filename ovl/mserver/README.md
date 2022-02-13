# Xcluster ovl - mserver

`Mserver` is a generic test image. The image contains a rich set of
iptools and some servers;

* [mconnect](https://github.com/Nordix/mconnect)
* [ctraffic](https://github.com/Nordix/ctraffic)
* (WIP [kahttp](https://github.com/Nordix/kahttp))
* (WIP [sctpt](https://github.com/Nordix/xcluster/tree/master/ovl/sctp#the-sctpt-test-program)

## Usage

The `mserver` image is used to start PODs. Example;

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: mserver
spec:
  selector:
    matchLabels:
      app: mserver
  template:
    metadata:
      labels:
        app: mserver
    spec:
      containers:
      - name: mserver
        image: registry.nordix.org/cloud-native/mserver:latest
        securityContext:
          privileged: true
        ports:
        - name: mconnect
          containerPort: 5001
        - name: ctraffic
          containerPort: 5003
        - name: mconnect-udp
          protocol: UDP
          containerPort: 5001
        - name: ctraffic-udp
          protocol: UDP
          containerPort: 5003
        - name: "http"
          containerPort: 80
        - name: "kahttp"
          containerPort: 8080
        - name: "kahttps"
          containerPort: 8443
        - name: "sctpt"
          protocol: SCTP
          containerPort: 6000
```


## Tests

```
log=/tmp/$USER/xcluster.log
./mserver.sh test > $log
```


## Build image

```
./mserver.sh mkimage
```

