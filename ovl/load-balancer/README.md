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



## NFQUEUE


Test;
```
./load-balancer.sh test nfqueue > $log
# Or start with one lb for manual tests;
__nrouters=1 ./load-balancer.sh test start_nfqueue > $log
```

The `-j NFQUEUE` iptables target directs packets to a user-space
program. The program can analyze the packet, set `fwmark` and place a
"verdict".

<img src="nfqueue.svg" alt="NFQUEUQE packet path" width="60%" />


Refs;

* https://home.regit.org/netfilter-en/using-nfqueue-and-libnetfilter_queue/
* http://www.netfilter.org/projects/libnetfilter_queue/doxygen/html/index.html


### Maglev hashing and the lb program

Maglev is the Google load-balancer;

* https://static.googleusercontent.com/media/research.google.com/en/pubs/archive/44824.pdf

The NFQUEUE example uses "maglev hashing". The hash state is stored in
"shared memory" so it is accessible from the program listening to the
nfqueue as well as from programs performing various configurations;

```c
#define MAX_M 10000
#define MAX_N 100
struct MagData {
        unsigned M, N;
        int lookup[MAX_M];
        unsigned permutation[MAX_N][MAX_M];
        unsigned active[MAX_N];
};
```

The `lb` program when listening on nfqueue ("lb run") creates a hash
on src/dest addresses and gets a "fwmark" from MagData.lookup.

The `lb` program is also used to create and configure the MagData in
shared memory. It can be built and executed on your laptop;

```
gcc -o /tmp/lb src/lb.c src/maglev.c -lmnl -lnetfilter_queue -lrt
/tmp/lb create
/tmp/lb show
/tmp/lb deactivate 1
/tmp/lb show
/tmp/lb activate 6 7 8
/tmp/lb show
/tmp/lb clean
```

The `maglev.c` has a stand-alone test which is rather crude but can be
extended (by you);

```
gcc -DSATEST -o /tmp/maglev src/maglev.c
/tmp/maglev  # The example from p6 in the maglev doc
# /tmp/maglev M N seed -- Shows permutation, lookup and a scale in/out;
/tmp/maglev 20 5 1
# /tmp/maglev M N seed loops -- Test scale in/out and print % loss
/tmp/maglev 20 5 1 10
/tmp/maglev 10000 10 1 10  # Larger M comes nearer to the ideal (10%)
```

