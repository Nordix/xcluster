# Overlay index

 * [apparmor](./apparmor/README.md) -  Experiments and examples with [Apparmor](https://apparmor.net/) and [seccomp](https://en.wikipedia.org/wiki/Seccomp). 
 * [attic](./attic/README.md) -  These OVLs are obsolete and unmaintained 
 * [cert-manager](./cert-manager/README.md) -  The [cert-manager](https://github.com/jetstack/cert-manager) on xcluster. 
 * [cni-plugins](./cni-plugins/README.md) -  Installs [cni-plugins](https://github.com/containernetworking/plugins) in `/opt/cni/bin`. The intention is to have a uniform way of installing cni-plugins rather than letting every ovl using it's own way. 
 * [containerd](./containerd/README.md) -  [Containerd](https://containerd.io/) in `xcluster`. 
 * [crio](./crio/README.md) -  [Cri-o](https://github.com/cri-o/cri-o) is used as CRI-plugin for Kubernetes in `xcluster`. 
 * [ctraffic](./ctraffic/README.md) -  Adds the [ctraffic](https://github.com/Nordix/ctraffic) continuous traffic test program. 
 * [dhcp](./dhcp/README.md) -  Tests and setups with [DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) and [SLAAC](https://en.wikipedia.org/wiki/IPv6#Stateless_address_autoconfiguration_(SLAAC)). 
 * [dpdk](./dpdk/README.md) -  Run DPDK in xcluster. 
 * [env](./env/README.md) -  This ovl provides a way to pass variables from the host to the xcluster VMs. Environment variables prefixed with "xcluster_" will be added to `/etc/profile` in all VMs. Scripts must source this file and can then check the variables. The prefix ("xcluster_") is removed. 
 * [etcd](./etcd/README.md) -  The [etcd](https://github.com/coreos/etcd) distributed key-value store. 
 * [frr](./frr/README.md) -  Install an [FRR](https://frrouting.org/) router. Frr is a quagga fork, read the [docs](http://docs.frrouting.org/en/latest/). 
 * [gobgp](./gobgp/README.md) -  Use [gobgp](https://github.com/osrg/gobgp) (BGP in golang) in xcluster routers. Gobgp with the `zebra` backend is started on router and tester VMs. The default configuration is to use "passive" BGP and dynamic peers on teh routers. This allow speakers on the cluster VMs to peer with the routers without re-configuration. 
 * [images](./images/README.md) -  Handles images in `xcluster`. Holds help script for docker images, local registry and pre-pulled images. 
 * [iperf](./iperf/README.md) -  Test with [iperf2](https://sourceforge.net/projects/iperf2/) on `xcluster`. 
 * [ipsec](./ipsec/README.md) -  Test and experiments with IKE/IPSEC behind NAT using strongswan. 
 * [iptools](./iptools/README.md) -  Overlay that installs some ip tools. Intended for experiments with the latest iptools. The `ntf` program for configuring the [nftables](https://netfilter.org/projects/nftables/index.html) is included. 
 * [istio](./istio/README.md) -  The [Istio](https://istio.io/) service mesh in `xcluster`. 
 * [k8s-base](./k8s-base/README.md) -  Creates the `xcluster` base image. It is basically the same as the `hd.image` with `ovl/iptools` installed. The image is intended as base for other images, used in a "Dockerfile" like; 
 * [k8s-cni-antrea](./k8s-cni-antrea/README.md) -  K8s cni-plugin [Antrea](https://github.com/antrea-io/antrea) 
 * [k8s-cni-bridge](./k8s-cni-bridge/README.md) -  The `k8s-cni-bridge` is a xcluster-only cni plugin. It *always* assign dual-stack addresses to PODs. 
 * [k8s-cni-calico](./k8s-cni-calico/README.md) -  Use [project calico](https://www.projectcalico.org/) in `xcluster`. Different date-planes can be tested. 
 * [k8s-cni-cilium](./k8s-cni-cilium/README.md) -  The [cilium](https://github.com/cilium/cilium) CNI-plugin, 
 * [k8s-cni-flannel](./k8s-cni-flannel/README.md) -  Use the [flannel](https://github.com/flannel-io/flannel) CNI-plugin in `xcluster`. 
 * [k8s-cni-ovs-cni](./k8s-cni-ovs-cni/README.md) -  Use CNI-plugin [ovs-cni](https://github.com/k8snetworkplumbingwg/ovs-cni) in `xcluster`. 
 * [k8s-cni-xcluster](./k8s-cni-xcluster/README.md) -  Use the [xcluster-cni](https://github.com/Nordix/xcluster-cni) CNI-plugin. 
 * [k8s-pv](./k8s-pv/README.md) -  K8s [persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) in xcluster. Based on [rancher/local-path-provisioner](https://github.com/rancher/local-path-provisioner). 
 * [k8s-sctp](./k8s-sctp/README.md) -  Use SCTP in Kubernetes. 
 * [k8s-xcluster](./k8s-xcluster/README.md) -  - Kubernetes in `xcluster` with downloaded CNI-plugin. 
 * [kselftest](./kselftest/README.md) -  Linux kernel self-test. 
 * [lldp](./lldp/README.md) - Run LLDP in xcluster.
 * [kubeadm](./kubeadm/README.md) -  Install Kubernetes with `kubeadm` in xcluster. [kubeadm](https://github.com/kubernetes/kubeadm) is the standard installation tool for Kubernetes. 
 * [kubernetes](./kubernetes/README.md) -  A [Kubernetes](https://kubernetes.io/) cluster with bridge CNI-plugin. 
 * [load-balancer](./load-balancer/README.md) -  This ovl tests different load-balancers (without K8s). The default xcluster network-topology is used; 
 * [lspci](./lspci/README.md) -  Adds `lspci` and the hw database. 
 * [mconnect](./mconnect/README.md) -  - Manifests for [mconnect](https://github.com/Nordix/mconnect) 
 * [metallb](./metallb/README.md) -  For experiments and tests with the [metallb](https://github.com/danderson/metallb). 
 * [mpls](./mpls/README.md) -  Tests and experiments with [MPLS](https://en.wikipedia.org/wiki/Multiprotocol_Label_Switching). This is a complement to [ovl/srv6](https://github.com/Nordix/xcluster/tree/master/ovl/srv6). 
 * [mserver](./mserver/README.md) -  `Mserver` is a generic test image. The image contains a rich set of iptools and some servers; 
 * [mtu](./mtu/README.md) -  Tests with different MTU sizes with and without Kubernetes. 
 * [multus](./multus/README.md) -  Use [multus](https://github.com/k8snetworkplumbingwg/multus-cni) in a Kubernetes xcluster. The [whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts) IPAM is used for the `ipvlan` example only since it doesn't support dual-stack. 
 * [netns](./netns/README.md) -  Multiple Network Namespaces (netns) and interconnect. The Network Namespaces are called "PODs" in this document even though K8s is not used. 
 * [network-topology](./network-topology/README.md) -  Various network topology setups are defined in this ovl. 
 * [ovs](./ovs/README.md) -  Tests and experiments with [Open vSwitch](https://www.openvswitch.org/) (OVS). OVS is used in the xcluster VMs, *not on the host* as a VM-VM network (as the image on [www.openvswitch.org](https://www.openvswitch.org/) shows). 
 * [podsec](./podsec/README.md) -  Encrypts all pod-to-pod traffic between pods on different nodes in a K8s cluster. Traffic between pods on the same node is not encrypted. 
 * [private-reg](./private-reg/README.md) -  You can use a local, private, unsecure docker registry for downloading images to `xcluster`. This is almost as fast as pre-pulled images and *way* faster than downloading from internet (especially on mobile network). 
 * [qemu-sriov](./qemu-sriov/README.md) -  Experiments with SR-IOV emulation in Qemu. 
 * [sctp](./sctp/README.md) -  Test and experiments with the [SCTP](https://en.wikipedia.org/wiki/Stream_Control_Transmission_Protocol) protocol ([rfc4960](https://datatracker.ietf.org/doc/html/rfc4960)). 
 * [skopeo](./skopeo/README.md) -  Add the [skopeo](https://github.com/containers/skopeo) image utility. 
 * [spire](./spire/README.md) -  [Spire](https://spiffe.io/docs/latest/spire-about/spire-concepts/) in xcluster. 
 * [srv6](./srv6/README.md) -  Test and experiments with [Segment Routing](https://en.wikipedia.org/wiki/Segment_routing) with IPv6 as data plane, `SRv6`. 
 * [static-kernel](./static-kernel/README.md) -  Build and use a static Linux kernel. 
 * [tap-scrambler](./tap-scrambler/README.md) -  A network test-tool built on a Linux `tap` device. 
 * [test](./test/README.md) -  Contains a test library and a basic test program for `xcluster` itself. 
 * [test-template](./test-template/README.md) -  Template for test program using `ovl/test` script-based testing. 
 * [timezone](./timezone/README.md) -  The timezone in `xcluster` is specified in `/etc/TZ` file on the VMs. The entire timezone data-base is not installed so the user friendly way, for instance `Pacific/Auckland` can **not** be used. Instead the more basic format must be used. Please read; 
 * [udp-test](./udp-test/README.md) -  A simple program to send and receive UDP packets. 
 * [usrsctp](./usrsctp/README.md) -  Test and experiments with userspace SCTP stack and linux SCTP conntrack module 
 * [virtualbox](./virtualbox/README.md) -  Describes howto create a [VirtualBox](https://www.virtualbox.org/) image. 
 * [wireguard](./wireguard/README.md) -  Use [WireGuard](https://www.wireguard.com/) in `xcluster`. 
 * [xdp](./xdp/README.md) -  Experiments and tests with [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) and [eBPF](https://ebpf.io/). 
 * [xnet](./xnet/README.md) -  Setup default networking according to the xcluster [networking description](../../doc/networking.md). 
