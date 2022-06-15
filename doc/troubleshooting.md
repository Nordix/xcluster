# Xcluster troubleshooting

This is about troubleshooting of `xcluster` itself and the default
network. Problems caused by overlays are not handled.


## Basic start

To determine if the problem is in `xcluster` itself or in the default
network setup you should test the basic `xcluster` with an overlay
that is considered to be safe, or no overlay at all.

Use the basic image and remove all overlays. Start just one VM and
make sure the `xterm` window does not close in case of a failure;

```
# Assuming binary release
export __image=$XCLUSTER_WORKSPACE/xcluster/hd.img
eval $($XCLUSTER env | grep XCLUSTER_TMP)
rm -rf $XCLUSTER_TMP
mkdir -p $XCLUSTER_TMP
xtermopt=-hold xc start --nrouters=0 --nvm=1
# You must close the xterm window manually even if you to "xc stop"
```

## No xterm pops up

Verify that you have `xterm` installed and that is can start a window;

```
which xterm
xterm &
# If you have ssh'ed to another machine, make sure "ssh -X" is used and do;
xhost +
# on the machine you ssh from.
```

## Kvm/qemu problems

This is usually some "permission denied" problem. Verify that you can
run the "kvm" command and that you are a member in the "kvm" group;

```
xc env | grep __kvm=
eval $($XCLUSTER env | grep __kvm=)
which $__kvm
id   # check for "127(kvm)" on Ubuntu
```

You can see that you can alter the kvm start command by setting the
`$__kvm` variable to something that works for you.


## Conflicts

If something is "in use" or "busy" you have some kind of conflict.

**First**; make sure no other `xcluster` is running on the machine,
perhaps by another user.

The `xcluster` VMs opens some ports that must not be opened by other
progams;

* `XCLUSTER_MONITOR_BASE=4000` - open qemu monitor ports

* `XCLUSTER_TELNET_BASE=12000` - Telnet port forwarding

* `XCLUSTER_SSH_BASE=12300` - Ssh port forwarding


## User space networking

The user space networking uses local UDP multicast for the "socket"
networks. This may be prohibited by your local firewall. You will
notice that there is no connectivity on the "cluster" and "external"
networks.

The multicast address is `224.0.0.$XCLUSTER_MCAST_BASE` normally
`224.0.0.121` for the "cluster" network and `224.0.0.222` for the
"external" network. Ensure that no other programs are using these
addresses.

