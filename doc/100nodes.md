# Xcluster - 100 nodes

This demonstrates how lightweight `xcluster` is. 100 VMs are started
on a Dell XPS13 9370 with 16G ram. This example is mostly a show-off
since I can't put much load on the VMs on my laptop, but it can be
useful for some network testing and on more powerful computers.

The default hd-image is used and the VMs are started with a minimum of
ram per VM. All VMs can (normally) not be started simultaneously
without problems so we start 20 VMs at the time. Use "starts" rather
than "start" to avoid 100 xterm's.

```
unset __mem1
export __mem=64
export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
xc mkcdrom xnet; xc starts --nrouters=0 --nvm=20
```

Do some initial experimenting, for instance login to a node and ping
another;

```
vm 17
# On the vm;
ping 192.168.1.11
free
```

Now start the rest of the VMs by repeated "scaleout". Watch you CPU
and let thing cool off between the scaleouts;

```
xc scaleout $(seq 21 40)
# wait...
xc scaleout $(seq 41 60)
# wait...
xc scaleout $(seq 61 80)
# wait...
xc scaleout $(seq 81 100)
# wait...
```

On my laptop the CPU load is ~30-40% with 100 VMs. Note that
`xcluster` is designed for max 200 nodes. The cap is imposted by the
network addressing and *may* be ovecome by ovls (but it's not trivial).

