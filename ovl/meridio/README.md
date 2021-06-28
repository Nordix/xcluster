# Xcluster ovl - Meridio

This overlay forces the routers to join the kubernetes cluster,
while also tainting them. That way only resources with proper
toleration can be scheduled on them.  
The aim is to deploy via Helm:
- two gateway PODs onto vm-201/202:
  These PODs will provide gateway router functionality for Meridio.
  They also get a secondary interface installed that will connect
  them to Meridio (through Multus). While a third interface connects
  them with a TG POD.
- traffic generator POD:
  Connects with the two gateway PODs through a secondary vlan interface
  installed via Multus. The benefit of a TG POD is to properly test Meridio
  when there are more than 1 external gateways available.
  Currently TG uses static routes to relay VIP traffic towards gateway-1. Thus
  when the set of VIPs is changed, routing in the TG POD must be manually updated. 
  (It might be worth introducing BGP between them as well...) 


## Basic Usage

Prerequisites:
- environment for starting `xcluster` is setup.
- docker image for the gateways is built/available; refer to gateway directory
  (Usage of local private docker registry is advised because of this.)

To setup the environment source the `Envsettings.k8s` file;

Note: Assign extra memory to VMs. Otherwise you risk running into out-of-memory
issues, where usually one of the VPP forwarder gets killed by the OS.

```
unset __mem1
export __mem201=1024
export __mem202=1024
xc mkcdrom private-reg meridio; xc starts --nets_vm=0,1,2 --nvm=2 --mem=4096 --smp=4
helm install Meridio/docs/demo/deployments/spire --generate-name
Meridio/docs/demo/scripts/spire-config.sh
helm install Meridio/docs/demo/deployments/nsm-vlan --generate-name
# use eth2 interface between meridio and the gateways, and eth1 between gateways and tg
helm install Meridio/deployments/helm --generate-name --set ipFamily=dualstack,vlan.interface=eth2
helm install xcluster/ovl/meridio/helm/gateway --generate-name --set masterItf=eth2,tgMasterItf=eth1
# test something...
xc stop
```

