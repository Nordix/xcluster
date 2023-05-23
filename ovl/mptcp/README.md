# Xcluster/ovl - mptcp

Test and examples with [MPTCP](https://www.rfc-editor.org/rfc/rfc8684.txt).
Support in `go` will be added in [v1.21](
https://github.com/golang/go/issues/56539#issuecomment-1332585915)

The `dual-path` [network-topology](
https://github.com/Nordix/xcluster/tree/master/ovl/network-topology)
is usually used:

<img src="https://github.com/Nordix/xcluster/raw/master/ovl/network-topology/dual-path.svg" alt="dual-path setup" width="60%" />



## Basic manual test

Routes are already setup, default on the upper path and direct routes
for the lower path.

```
./mptcp.sh test start_empty > $log
# On routers, vm-201, vm-202
tcpdump -ni eth1
# On vm-002
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.4.2 dev eth2 signal
mptcp server
# On vm-221
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.6.221 dev eth2 signal
mptcp client 192.168.1.2 7000
# Check status on vm-002 and vm-221
ss -ntM | grep 7000
netstat -pet
# On routers, vm-201, vm-202
iptables -A FORWARD -j DROP    # failover
iptables -D FORWARD -j DROP
```

The test shows the redundancy part of mptcp.


## Enforce mptcp

Use LD_PRELOAD to enforce mptcp with [mptcpize](
https://github.com/multipath-tcp/mptcpd)
```
#sudo apt install mptcpize
./mptcp.sh test start_empty > $log
# On vm-002
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.4.2 dev eth2 signal
mptcpize run ncat -lk 0.0.0.0 7000
#mptcpize run nc -s :: -p 7000 -lk
# On vm-221
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.6.221 dev eth2 signal
mptcpize run nc 192.168.1.2 7000
```

An other option is to use a [systemtap function]( 
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/getting-started-with-multipath-tcp_configuring-and-managing-networking). An important advantage is that this works
for statically linked (go) programs.

Prerequisite: Build ovl/systemtap

```
./mptcp.sh build_ko
./mptcp.sh test start_empty systemtap > $log
# On vm-002
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.4.2 dev eth2 signal
staprun mptcpapp.ko                     # (will hang)
ctraffic -server -address 0.0.0.0:5003  # (in another shell)
# On vm-221
ip mptcp limits set subflow 2 add_addr_accepted 2
ip mptcp endpoint add 192.168.6.221 dev eth2 signal
staprun mptcpapp.ko                     # (will hang)
ctraffic -address 192.168.1.2:5003 -monitor -rate 10 --nconn 1 --timeout 5m
```


## References

* https://www.multipath-tcp.org/
* https://lwn.net/Articles/800501/
* https://github.com/multipath-tcp/mptcp_net-next/wiki
* https://github.com/intel/mptcpd
* https://github.com/mkheirkhah/mptcp
* https://lwn.net/Articles/791376/
* https://www.phoronix.com/scan.php?page=news_item&px=Linux-5.6-Starts-Multipath-TCP
* https://medium.com/high-performance-network-programming/how-to-setup-and-configure-mptcp-on-ubuntu-c423dbbf76cc
* [Golang support in v1.21](
  https://github.com/golang/go/issues/56539#issuecomment-1332585915)
* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/getting-started-with-multipath-tcp_configuring-and-managing-networking
