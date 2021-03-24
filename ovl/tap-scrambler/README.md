# Xcluster - ovl/tap-scrambler

A network test-tool built on a Linux `tap` device.

This is a functional test tool. It is not for performance testing.

<img src="tap-scrambler.svg" alt="tap-scrambler" width="50%" />

The idea is that incoming traffic is directed to a `tap` device and
furhter to the `tap-scrambler` process. The `tap-scrambler` does bad
things for test purposes and passes on the traffic.

In the image only traffic in one direction passes the
`tap-scrambler`. This is assumed to be the normal operation.


## Usage

Simple forwarding;
```
./tap-scrambler.sh test start > $log
# On vm-201
tap-scrambler fwd --tap=tap2
# On vm-221
ping -c1 -s 2000 192.168.1.1
ping -c1 -M do -s 2000 1000::1:192.168.1.1
```


## Links

* https://github.com/gregnietsky/simpletun
* https://backreference.org/2010/03/26/tuntap-interface-tutorial/

