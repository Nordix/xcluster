# Xcluster ovl - iperf

Test with [iperf2](https://sourceforge.net/projects/iperf2/) on `xcluster`.

Keywords: bandwidth limitation

To test performance in `xcluster` has limited use. Max bandwidth
itself is probably not interresting, but to compare bandwidth in
different configurations, e.g with and without encryption, may be useful.

Current focus is to test bandwidth limitation in Kubernetes. There is
a PR for a [KEP](https://github.com/kubernetes/enhancements/pull/2808), but several CNI-plugins has already implemented
the feature.




#### About iperf3

`Iperf3` is not used since it [doesn't work with load-balancing](
https://github.com/esnet/iperf/issues/823) (and likely never will).
`Iperf3` is not a development of `iperf2` (or iperf) but a different project.


## Usage

```
./iperf.sh    # Help printout
# If needed;
#export IPERF_WORKSPACE=/tmp/$USER/iperf
#./iperf.sh build
#./iperf.sh mkimage
./iperf.sh test connect > $log
# Or;
xcadmin k8s_test --cni=cilium iperf > $log
```


## K8s bandwidth limitation

There is a PR for a [KEP](https://github.com/kubernetes/enhancements/pull/2808),
but several CNI-plugins has already implemented the feature.

```
# Without bandwidth limitation;
./iperf.sh test k8s_bandwidth > $log
# With bandwidth limitation;
xcadmin k8s_test --cni=cilium iperf k8s_bandwidth > $log
```

## Trouble-shooting

Calico and Antrea uses the `bandwidth` CNI-plugin. If they don't work,
test `bandwidth` stand-alone;

```
CNIBIN=yes ./iperf.sh test bandwidth > $log
# On vm-001
ns=test-ns
export CNI_PATH=/opt/cni/bin
sed -e '/prevResult/r /tmp/bridge.json' < /etc/bandwidth.conf | \
 CNI_CONTAINERID=$ns CNI_NETNS=/var/run/netns/$ns CNI_IFNAME=net1 \
 CNI_COMMAND=ADD strace $CNI_PATH/bandwidth

tc qdisc show
```

Kernel updates in;
`Networking support > Networking options > QoS and/or fair queueing`
```
CONFIG_NET_SCH_FQ=y
```
