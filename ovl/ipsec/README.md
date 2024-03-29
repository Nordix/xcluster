# Xcluster/ovl - ipsec

Test and experiments with IKE/IPSEC behind NAT using strongswan.

The following network topology is used:
<img src="network-topology/ikev2-k8s.svg" alt="IKEv2 responder in a k8s pod" width="80%" />

## Build strongswan
```
./ipsec.sh build
```

## Basic example with IKEv2 responder in a pod
```
./ipsec.sh mkimage
./ipsec.sh test start
# Check the initiator and responder logs for debugging
# On vm-002
kubectl logs deploy/ipsec-responder
# On vm-221
cat /var/log/ipsec-initiate.log
```

## Notes on running Strongswan inside a pod (behind NAT)
### Set externalTrafficPolicy=local when running kube-proxy
> IPsec service running in a pod should be able to see the real peer IP of the remote initiating peer, other Strongswan will not be able find the peer configuration to setup IKE SA
### Recommended swanctl.conf settings
- local_addrs=%any (Loadbalancer IP, service IP, pod IP all can be used by initiator to setup IKEv2)
- id=@<fqdn/rdn> (Use of IP address as IKEv2 ID is not recommended, since it adds unnecessary complexity)
- auth=pubkey/psk
