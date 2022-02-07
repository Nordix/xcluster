# Xcluster ovl - iperf

Test with [iperf2](https://sourceforge.net/projects/iperf2/) on `xcluster`.

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

a PR for a [KEP](https://github.com/kubernetes/enhancements/pull/2808),
but several CNI-plugins has already implemented the feature.

```
# Without bandwidth limitation;
./iperf.sh test k8s_bandwidth > $log
# With bandwidth limitation;
xcadmin k8s_test --cni=cilium iperf k8s_bandwidth > $log
```

## Trouble-shooting

Cilium crashed in `xcluster` with;
```
level=info msg="Setting sysctl" subsys=bandwidth-manager sysParamName=net.core.default_qdisc sysParamValue=fq
level=fatal msg="Failed to set sysctl needed by BPF bandwidth manager." error="could not write to the systctl file /proc/sys/net/core/default_qdisc: write /proc/sys/net/core/default_qdisc: no such file or directory" subsys=bandwidth-manager sysParamName=net.core.default_qdisc sysParamValue=fq
```
Kernel update;
```
CONFIG_NET_SCH_FQ=y
```
