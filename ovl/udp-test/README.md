# Xcluster/ovl - udp-test

A simple program to send and receive UDP packets.

Build;
```
go build ./cmd/...
```

Manual test;
```
XOVLS='' xc mkcdrom network-topology iptools udp-test
xc start --image=$XCLUSTER_WORKSPACE/xcluster/hd.img --nrouters=1 --nvm=1
# On vm-001
udp-test -server
# On vm-201
udp-test -address 192.168.1.1:6001 -size 30000
udp-test -address [1000::1:192.168.1.1]:6001 -size 30000
```
