# Xcluster ovl - Multi network

Configure `xcluster` with more than the "standard" (3) networks.


# Usage

**NOTE**: This ovl should be used with `xlcuster` in a network
  namespace (netns). It may work in main netns but there may be port
  collisions.

```
# Inside a netns;
xc br_setup 3
xc br_setup 4
xc br_setup 5
```

Basic test;
```
eval $($XCLUSTER env | grep XCLUSTER_HOME=)
export __image=$XCLUSTER_HOME/hd.img
SETUP=test xc mkcdrom multinet; xc start --nets-vm=0,1,3,4,5
```

With systemd (e.g. in k8s);
```
eval $($XCLUSTER env | grep XCLUSTER_HOME=)
export __image=$XCLUSTER_HOME/hd-k8s.img
xc mkcdrom multinet; xc start --nets-vm=0,1,3,4,5
```
