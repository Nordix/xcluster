
In a K8s dual-stack cluster traffic from an external machine to an ipv6 `loadBalancerIp` does not work. Ipv6 to the very same `loadBalancerIp` works from a K8s cluster node. Ipv4 to a `loadBalancerIp` in the same system works from an external machine.

### Test setup

K8s >=1.16.0 must be setup with dual-stack enabled; https://kubernetes.io/docs/concepts/services-networking/dual-stack/

Cilium is installed with `quick-install.yaml` with ènable-ipv6: "true"` as the **only** update.

The [mconnect](https://github.com/Nordix/mconnect) program is used for testing and is installed with ...



Service setup;
```
vm-003 ~ # kubectl get svc 
NAME            TYPE           CLUSTER-IP        EXTERNAL-IP   PORT(S)          AGE
coredns         ClusterIP      12.0.0.2          <none>        53/UDP,53/TCP    7m7s
kubernetes      ClusterIP      12.0.0.1          <none>        443/TCP          7m9s
mconnect        LoadBalancer   12.0.136.235      10.0.0.0      5001:31344/TCP   5m58s
mconnect-ipv6   LoadBalancer   fd00:4000::33e0   1000::        5001:30317/TCP   5m58s
vm-003 ~ # kubectl get svc mconnect-ipv6 -o yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"mconnect-ipv6","namespace":"default"},"spec":{"ipFamily":"IPv6","loadBalancerIP":"1000::","ports":[{"port":5001}],"selector":{"app":"mconnect"},"type":"LoadBalancer"}}
  creationTimestamp: "2019-09-19T10:07:21Z"
  name: mconnect-ipv6
  namespace: default
  resourceVersion: "399"
  selfLink: /api/v1/namespaces/default/services/mconnect-ipv6
  uid: 0f539225-6b1b-414f-aade-e76bb6c6fb25
spec:
  clusterIP: fd00:4000::33e0
  externalTrafficPolicy: Cluster
  ipFamily: IPv6
  loadBalancerIP: '1000::'
  ports:
  - nodePort: 30317
    port: 5001
    protocol: TCP
    targetPort: 5001
  selector:
    app: mconnect
  sessionAffinity: None
  type: LoadBalancer
status:
  loadBalancer:
    ingress:
    - ip: '1000::'
```

Tests;
```
# From a node within the cluster;
vm-003 ~ # mconnect -address mconnect.default.svc.xcluster:5001 -nconn 100
Failed connects; 0
Failed reads; 0
mconnect-deployment-54f999b8c9-rtxkt 25
mconnect-deployment-54f999b8c9-7lrf7 25
mconnect-deployment-54f999b8c9-ggj8w 25
mconnect-deployment-54f999b8c9-njrjg 25
vm-003 ~ # mconnect -address mconnect-ipv6.default.svc.xcluster:5001 -nconn 100
Failed connects; 0
Failed reads; 0
mconnect-deployment-54f999b8c9-njrjg 25
mconnect-deployment-54f999b8c9-7lrf7 25
mconnect-deployment-54f999b8c9-rtxkt 25
mconnect-deployment-54f999b8c9-ggj8w 25
vm-003 ~ # mconnect -address [1000::]:5001 -nconn 100
Failed connects; 0
Failed reads; 0
mconnect-deployment-54f999b8c9-ggj8w 25
mconnect-deployment-54f999b8c9-7lrf7 25
mconnect-deployment-54f999b8c9-njrjg 25
mconnect-deployment-54f999b8c9-rtxkt 25

# From an external machine;
vm-201 ~ # mconnect -address 10.0.0.0:5001 -nconn 100
Failed connects; 0
Failed reads; 0
mconnect-deployment-54f999b8c9-ggj8w 25
mconnect-deployment-54f999b8c9-njrjg 25
mconnect-deployment-54f999b8c9-7lrf7 25
mconnect-deployment-54f999b8c9-rtxkt 25
vm-201 ~ # mconnect -address [1000::]:5001 -nconn 100
Failed connects; 100
Failed reads; 0
```

Trace on the incoming node;
```
vm-002 ~ # tcpdump -eni any port 5001
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
12:17:59.663346  In 00:00:00:01:01:c9 ethertype IPv6 (0x86dd), length 96: 1000::1:c0a8:1c9.52826 > 1000::.5001: Flags [S], seq 201229737, win 64800, options [mss 1440,sackOK,TS val 1421917500 ecr 0,nop,wscale 6], length 0
12:17:59.663554 Out e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: 1000::1:c0a8:102.43925 > f00d::b00:200:0:dd5b.5001: Flags [S], seq 201229737, win 64800, options [mss 1440,sackOK,TS val 1421917500 ecr 0,nop,wscale 6], length 0
12:17:59.663624  In 72:da:5c:a1:b8:51 ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553754036 ecr 1421917500,nop,wscale 7], length 0
12:17:59.663638 Out e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553754036 ecr 1421917500,nop,wscale 7], length 0
12:17:59.663641  In e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553754036 ecr 1421917500,nop,wscale 7], length 0
12:18:00.674117  In 00:00:00:01:01:c9 ethertype IPv6 (0x86dd), length 96: 1000::1:c0a8:1c9.52826 > 1000::.5001: Flags [S], seq 201229737, win 64800, options [mss 1440,sackOK,TS val 1421918511 ecr 0,nop,wscale 6], length 0
12:18:00.674219 Out e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: 1000::1:c0a8:102.43925 > f00d::b00:200:0:dd5b.5001: Flags [S], seq 201229737, win 64800, options [mss 1440,sackOK,TS val 1421918511 ecr 0,nop,wscale 6], length 0
12:18:00.674501  In 72:da:5c:a1:b8:51 ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553755047 ecr 1421917500,nop,wscale 7], length 0
12:18:00.674523 Out e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553755047 ecr 1421917500,nop,wscale 7], length 0
12:18:00.674526  In e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553755047 ecr 1421917500,nop,wscale 7], length 0
12:18:01.678552  In 72:da:5c:a1:b8:51 ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553756051 ecr 1421917500,nop,wscale 7], length 0
12:18:01.678577 Out e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553756051 ecr 1421917500,nop,wscale 7], length 0
12:18:01.678581  In e2:bb:b9:a8:26:ba ethertype IPv6 (0x86dd), length 96: f00d::b00:200:0:dd5b.5001 > 1000::1:c0a8:102.43925: Flags [S.], seq 3934384089, ack 201229738, win 64766, options [mss 1390,sackOK,TS val 1553756051 ecr 1421917500,nop,wscale 7], length 0
^C
13 packets captured
13 packets received by filter
0 packets dropped by kernel
```

Interfaces;
```
vm-002 ~ # ip -d link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00 promiscuity 0 minmtu 0 maxmtu 0 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:00:00:01:00:02 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:00:00:01:01:02 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
4: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0 promiscuity 0 minmtu 0 maxmtu 0 
    ipip any remote any local any ttl inherit nopmtudisc addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
5: gre0@NONE: <NOARP> mtu 1476 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/gre 0.0.0.0 brd 0.0.0.0 promiscuity 0 minmtu 0 maxmtu 0 
    gre remote any local any ttl inherit nopmtudisc addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
6: gretap0@NONE: <BROADCAST,MULTICAST> mtu 1462 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 0 
    gretap remote any local any ttl inherit nopmtudisc addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
7: erspan0@NONE: <BROADCAST,MULTICAST> mtu 1450 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 1500 
    erspan remote any local any ttl inherit nopmtudisc okey 0.0.0.0 erspan_index 0 erspan_ver 1 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
8: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0 promiscuity 0 minmtu 1280 maxmtu 65555 
    sit ip6ip remote any local any ttl 64 nopmtudisc addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
9: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/tunnel6 :: brd :: promiscuity 0 minmtu 68 maxmtu 65503 
    ip6tnl ip6ip6 remote any local any hoplimit inherit encaplimit 0 tclass 0x00 flowlabel 0x00000 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
10: ip6gre0@NONE: <NOARP> mtu 1448 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/gre6 :: brd :: promiscuity 0 minmtu 0 maxmtu 0 
    ip6gre remote any local any hoplimit inherit encaplimit 0 tclass 0x00 flowlabel 0x00000 addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
11: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 1e:24:fc:c7:28:85 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 0 maxmtu 0 
    dummy addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
12: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default 
    link/ether 6e:39:73:e5:13:84 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 0 maxmtu 0 
    dummy addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
13: cilium_net@cilium_host: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 5e:77:df:5e:70:bb brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535 
    veth addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
14: cilium_host@cilium_net: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 3a:3e:58:da:d9:2e brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535 
    veth addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
15: cilium_vxlan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 56:12:af:1c:dd:64 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535 
    vxlan externaladdrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
17: lxc_health@if16: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether fe:e5:e0:b1:6c:07 brd ff:ff:ff:ff:ff:ff link-netnsid 0 promiscuity 0 minmtu 68 maxmtu 65535 
    veth addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
19: lxcda1bbba57e7f@if18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether e2:bb:b9:a8:26:ba brd ff:ff:ff:ff:ff:ff link-netnsid 1 promiscuity 0 minmtu 68 maxmtu 65535 
    veth addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
```

1. Setup a K8s cluster with dual-stack; https://kubernetes.io/docs/concepts/services-networking/dual-stack/

2. Start servers exposed via a service with `type: LoadBalancer` and `ipFamily: IPv6`

3. Make sure an "EXTERNAL-IP" is assigned (not in pending)

4. Go to an external machine with route to the EXTERNAL-IP via some K8s node(s)

5. Try to connect to the EXTERNAL-IP

