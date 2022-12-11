# Overlay index

 * [apparmor](./ovl/apparmor/README.md)  Experiments and examples with [Apparmor](https://apparmor.net/) and [seccomp](https://en.wikipedia.org/wiki/Seccomp). 
 * [cert-manager](./ovl/cert-manager/README.md)  The [cert-manager](https://github.com/jetstack/cert-manager) on xcluster. 
 * [cni-plugins](./ovl/cni-plugins/README.md)  Installs [cni-plugins](https://github.com/containernetworking/plugins) in `/opt/cni/bin`. The intention is to have a uniform way of installing cni-plugins rather than letting every ovl using it's own way. 
 * [containerd](./ovl/containerd/README.md)  [Containerd](https://containerd.io/) in `xcluster`. 
 * [coredns](./ovl/coredns/README.md)  CoreDNS POD in `xcluster` (obsolete) 
 * [crio](./ovl/crio/README.md)  [Cri-o](https://github.com/cri-o/cri-o) is used as CRI-plugin for Kubernetes in `xcluster`. 
 * [ctraffic](./ovl/ctraffic/README.md)  Adds the [ctraffic](https://github.com/Nordix/ctraffic) continuous traffic test program. 
 * [dhcp](./ovl/dhcp/README.md)  Tests and setups with [DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) and [SLAAC](https://en.wikipedia.org/wiki/IPv6#Stateless_address_autoconfiguration_(SLAAC)). 
 * [dpdk](./ovl/dpdk/README.md)  Run DPDK in xcluster. 
 * [env](./ovl/env/README.md)  This ovl provides a way to pass variables from the host to the xcluster VMs. Environment variables prefixed with "xcluster_" will be added to `/etc/profile` in all VMs. Scripts must source this file and can then check the variables. The prefix ("xcluster_") is removed. 
 * [etcd](./ovl/etcd/README.md)  The [etcd](https://github.com/coreos/etcd) distributed key-value store. 
 * [frr](./ovl/frr/README.md)  Install an [FRR](https://frrouting.org/) router. Frr is a quagga fork, read the [docs](http://docs.frrouting.org/en/latest/). 
 * [gobgp](./ovl/gobgp/README.md)  Use [gobgp](https://github.com/osrg/gobgp) (BGP in golang) in xcluster routers. Gobgp with the `zebra` backend is started on router and tester VMs. The default configuration is to use "passive" BGP and dynamic peers on teh routers. This allow speakers on the cluster VMs to peer with the routers without re-configuration. 
 * [images](./ovl/images/README.md)  Handles pre-pulled images in `xcluster`. 
 * [iperf](./ovl/iperf/README.md)  Test with [iperf2](https://sourceforge.net/projects/iperf2/) on `xcluster`. 
 * [ipsec](./ovl/ipsec/README.md)  Test and experiments with IKE/IPSEC behind NAT using strongswan. 
 * [iptools](./ovl/iptools/README.md)  Overlay that installs some ip tools. Intended for experiments with the latest iptools. The `ntf` program for configuring the [nftables](https://netfilter.org/projects/nftables/index.html) is included. 
 * [istio](./ovl/istio/README.md)  The [Istio](https://istio.io/) service mesh in `xcluster`. 
 * [k8s-base](./ovl/k8s-base/README.md)  Creates the `xcluster` base image. It is basically the same as the `hd.image` with `ovl/iptools` installed. The image is intended as base for other images, used in a "Dockerfile" like; 
 * [k8s-cni-antrea](./ovl/k8s-cni-antrea/README.md)  K8s cni-plugin [Antrea](https://github.com/antrea-io/antrea) 
 * [k8s-cni-bridge](./ovl/k8s-cni-bridge/README.md)  The `k8s-cni-bridge` is a xcluster-only cni plugin. It *always* assign dual-stack addresses to PODs. The order of the address families can be controlled with; 
 * [k8s-cni-calico](./ovl/k8s-cni-calico/README.md)  Use [project calico](https://www.projectcalico.org/) in `xcluster`. 
 * [k8s-cni-cilium](./ovl/k8s-cni-cilium/README.md)  The [cilium](https://github.com/cilium/cilium) CNI-plugin, 
 * [k8s-cni-flannel](./ovl/k8s-cni-flannel/README.md)  Use the [flannel](https://github.com/flannel-io/flannel) CNI-plugin in `xcluster`. 
 * [k8s-cni-kube-router](./ovl/k8s-cni-kube-router/README.md)  Use the `kube-router` turn-key solution 
 * [k8s-cni-ovs-cni](./ovl/k8s-cni-ovs-cni/README.md)  Use CNI-plugin [ovs-cni](https://github.com/k8snetworkplumbingwg/ovs-cni) in `xcluster`. 
 * [k8s-cni-xcluster](./ovl/k8s-cni-xcluster/README.md)  Use the [xcluster-cni](https://github.com/Nordix/xcluster-cni) CNI-plugin. 
 * [k8s-pv](./ovl/k8s-pv/README.md)  K8s [persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) in xcluster. Based on [rancher/local-path-provisioner](https://github.com/rancher/local-path-provisioner). 
 * [k8s-sctp](./ovl/k8s-sctp/README.md)  Use SCTP in Kubernetes. 
 * [k8s-xcluster](./ovl/k8s-xcluster/README.md)  - Kubernetes in `xcluster` with downloaded CNI-plugin. 
 * [kselftest](./ovl/kselftest/README.md)  Linux kernel self-test. 
 * [kubeadm](./ovl/kubeadm/README.md)  Install Kubernetes with `kubeadm` in xcluster. [kubeadm](https://github.com/kubernetes/kubeadm) is the standard installation tool for Kubernetes. 
 * [kubernetes](./ovl/kubernetes/README.md)  - A [Kubernetes](https://kubernetes.io/) cluster with built-in CNI-plugin. 
 * [load-balancer](./ovl/load-balancer/README.md)  This ovl tests different load-balancers (without K8s). The default xcluster network-topology is used; 
 * [lspci](./ovl/lspci/README.md)  Adds `lspci` and the hw database. 
 * [mconnect](./ovl/mconnect/README.md)  - Manifests for [mconnect](https://github.com/Nordix/mconnect) 
 * [metallb](./ovl/metallb/README.md)  For experiments and tests with the [metallb](https://github.com/danderson/metallb). 
 * [mpls](./ovl/mpls/README.md)  Tests and experiments with [MPLS](https://en.wikipedia.org/wiki/Multiprotocol_Label_Switching). This is a complement to [ovl/srv6](https://github.com/Nordix/xcluster/tree/master/ovl/srv6). 
 * [mserver](./ovl/mserver/README.md)  `Mserver` is a generic test image. The image contains a rich set of iptools and some servers; 
 * [mtu](./ovl/mtu/README.md)  Tests with different MTU sizes with and without Kubernetes. 
 * [multus](./ovl/multus/README.md)  Use [multus](https://github.com/k8snetworkplumbingwg/multus-cni) in a Kubernetes xcluster. The [whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts) IPAM is used for the `ipvlan` example only since it doesn't support dual-stack. 
 * [netns](./ovl/netns/README.md)  Multiple Network Namespaces (netns) and interconnect. The Network Namespaces are called "PODs" in this document even though K8s is not used. 
 * [network-topology](./ovl/network-topology/README.md)  Various network topology setups are defined in this ovl. 
 * [nfproxy](./ovl/nfproxy/README.md)  Experiments with https://github.com/sbezverk/nfproxy 
 * [ovs](./ovl/ovs/README.md)  Tests and experiments with [Open vSwitch](https://www.openvswitch.org/) (OVS). OVS is used in the xcluster VMs, *not on the host* as a VM-VM network (as the image on [www.openvswitch.org](https://www.openvswitch.org/) shows). 
 * [podsec](./ovl/podsec/README.md)  Encrypts all pod-to-pod traffic between pods on different nodes in a K8s cluster. Traffic between pods on the same node is not encrypted. 
 * [private-reg](./ovl/private-reg/README.md)  You can use a local, private, unsecure docker registry for downloading images to `xcluster`. This is almost as fast as pre-pulled images and *way* faster than downloading from internet (especially on mobile network). 
 * [qemu-sriov](./ovl/qemu-sriov/README.md)  Experiments with SR-IOV emulation in Qemu. 
 * [sctp](./ovl/sctp/README.md)  Test and experiments with the [SCTP](https://en.wikipedia.org/wiki/Stream_Control_Transmission_Protocol) protocol ([rfc4960](https://datatracker.ietf.org/doc/html/rfc4960)). 
 * [skopeo](./ovl/skopeo/README.md)  Add the [skopeo](https://github.com/containers/skopeo) image utility. 
 * [spire](./ovl/spire/README.md)  [Spire](https://spiffe.io/docs/latest/spire-about/spire-concepts/) in xcluster. 
 * [srv6](./ovl/srv6/README.md)  Test and experiments with [Segment Routing](https://en.wikipedia.org/wiki/Segment_routing) with IPv6 as data plane, `SRv6`. 
 * [static-kernel](./ovl/static-kernel/README.md)  Build and use a static Linux kernel. 
 * [systemd](./ovl/systemd/README.md)  Make xcluster start with [systemd](https://www.freedesktop.org/wiki/Software/systemd/). 
 * [tap-scrambler](./ovl/tap-scrambler/README.md)  A network test-tool built on a Linux `tap` device. 
 * [test](./ovl/test/README.md)  Contains a test library and a basic test program for `xcluster` itself. 
 * [test-template](./ovl/test-template/README.md)  Template for test program using `ovl/test` script-based testing. 
 * [timezone](./ovl/timezone/README.md)  The timezone in `xcluster` is specified in `/etc/TZ` file on the VMs. The entire timezone data-base is not installed so the user friendly way, for instance `Pacific/Auckland` can **not** be used. Instead the more basic format must be used. Please read; 
 * [udp-test](./ovl/udp-test/README.md)  A simple program to send and receive UDP packets. 
 * [usrsctp](./ovl/usrsctp/README.md)  Test and experiments with userspace SCTP stack and linux SCTP conntrack module 
 * [virtualbox](./ovl/virtualbox/README.md)  Describes howto create a [VirtualBox](https://www.virtualbox.org/) image. 
 * [wireguard](./ovl/wireguard/README.md)  Use [WireGuard](https://www.wireguard.com/) in `xcluster`. 
 * [xdp](./ovl/xdp/README.md)  Experiments and tests with [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) and [eBPF](https://ebpf.io/). 
 * [xnet](./ovl/xnet/README.md)  Setup default networking according to the xcluster [networking description](../../doc/networking.md). 
