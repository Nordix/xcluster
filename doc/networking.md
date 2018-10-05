# Xcluster networking

The `xcluster` network is using linux bridges and tap devices (the
normal way). The default network has 3 nets (i.e. 3 bridges);

<img src="xcluster-network.svg" alt="Figure, xcluster network" width="80%" />

 * Internal net - Intended mainly for control functions. All VMs shall
   be reachable via this network.  The `vm` function for open a
   terminal to a VM does a `telnet` on this net.

 * Cluster net - This is the main cluster network. It is connected to
   cluster nodes for cluster signalling and to the routers for
   external connectivity. The addresses varies depending on the
   cluster setup.

 * External net - This represents the outside world, like the
   "internet".

The base image only setup the Internal net on the VMs. The other
networks are configured by overlays.

The `xcbr0` and `xcbr2` bridge interfaces are configured with
addresses to be usable from the host. The `xcbr1` should normally not
be used by the host.

The addresses are assigned from the hostname of the VM. The last digit
in the address is the number from the hostname, e.g. 1 for
"vm-001". For now the hostname number is taken from the lsb of the MAC
address on the interface towards the Internal net (eth0). This may
however change for instance if the MAC addresses can't be controlled.


## Customizing

To alter the network setup, for instance adding another network, you
must create you own start-function in the `xcluster.sh` script. You
should not edit the script but use a "hook";

```
export XCLUSTER_HOOK=$MY_EXPERIMENT_DIR/xcluster.hook
xc mystart
```

Copy `cmd_start()` to your hook and modify it to your needs.

### Alternative network

If the network topology is ok but you want to use something else than
the default bridge/tap networking, for instance
[ovs](https://www.openvswitch.org/) then you can secify a script with
the `__net_setup` variable. The script will be called for each vm
like;

```
$__net_setup <node> <net>
# Example; $__net_setup 3 1
```

Your script must do necessary configuration and print out options to
`kvm`. The easiest is to copy from the `cmd_boot_vm()` function in
`xcluster.sh` and modify.

