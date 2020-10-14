# Xcluster/ovl - load-balancer

* Test setup for load-balancers

This ovl provides a setup for testing different load-balancers. The
default xcluster network-topology is used when possible (always);

<img src="../network-topology/xnet.svg" alt="Default network topology" width="60%" />

The routers (vm-201--vm-220) are used as load-balancing machines.
Only one tester is used (vm-221). The number of server VMs and
load-balancer VMs can be varied.

Simplest is to start using the `load-balancer.sh` script;
```
LB=ecmp
./load-balancer.sh test $LB > $log
# Or to leave the cluster running;
./load-balancer.sh test --no-stop $LB > $log
# Or to just start;
./load-balancer.sh test start_$LB > $log
```

You can start manually;
```
LB=ecmp
SETUP=$LB xc mkcdrom env network-topology iptoolsload-balancer; xc starts
```
However some additional settings may be needed for some load-balancers.

Manual tests on the tester (vm-221);
```
mconnect -address 10.0.0.0:5001 -nconn 100 -srccidr 50.0.0.0/16
mconnect -address [1000::]:5001 -nconn 100 -srccidr 2000::/112
ctraffic -address 10.0.0.0:5003 -nconn 40 -rate 100 -monitor -timeout 10s \
  -stats all -srccidr 50.0.0.0/16 | jq .
ctraffic -address [1000::]:5003 -nconn 40 -rate 100 -monitor -timeout 10s \
  -stats all -srccidr 2000::/112 | jq .
```


## ECMP load-balancer

This is the simplest form of load-balancer. Due to some kernel bug
linux-5.5.x and above sprays packets regardless of hash so
`linux-5.4.35` is used in tests.

```
./load-balancer.sh test ecmp > $log
```



https://home.regit.org/netfilter-en/using-nfqueue-and-libnetfilter_queue/
http://www.netfilter.org/projects/libnetfilter_queue/doxygen/html/index.html
https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/44824.pdf
https://github.com/kkdai/maglev/blob/master/maglev.go



## NFQUEUE

https://home.regit.org/netfilter-en/using-nfqueue-and-libnetfilter_queue/

```
./load-balancer.sh test nfqueue > $log
```



Manual test with `nf-queue`
```
__nrouters=1 ./load-balancer.sh test start > $log
# On vm-201
iptables -t mangle -A PREROUTING -s 50.0.0.0/16 -j NFQUEUE --queue-num 2
ip6tables -t mangle -A PREROUTING -s 2000::/112 -j NFQUEUE --queue-num 2
ip rule add fwmark 5 table 101
ip route add default via 192.168.1.1 table 101
ip -6 route add default via 1000::1:192.168.1.1 table 101
lb 2
# On vm-221
ping -c1 -W1 -I 50.0.0.1 192.168.1.1
ping -I 2000::1 -c1 1000::1:192.168.1.1
```

