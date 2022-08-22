# Xcluster/ovl - spire

[Spire](https://spiffe.io/docs/latest/spire-about/spire-concepts/) in xcluster.

The new [registrar](https://github.com/spiffe/spire/tree/main/support/k8s/k8s-workload-registrar)
configuration is used.

The main intended usage is for
[nsm-test](https://github.com/Nordix/nsm-test/tree/master/ovl). We
attempt to be as close to the older NSM spire setup as possible so the
"spiffeid" is;

```
spiffe://example.org/ns/default/sa/default
```

The "default" service account is allowed and "identity_template" is set as;
```
    identity_template = "ns/{{.Pod.Namespace}}/sa/{{.Pod.ServiceAccount}}"
    #identity_template_label = "spiffe.io/spiffe-id"  (removed)
```

Then a default "spiffeid" is created with;
```
apiVersion: spiffeid.spiffe.io/v1beta1
kind: SpiffeID
metadata:
  name: default-spiffeid
  namespace: default
spec:
  parentId: "spiffe://example.org/spire/server"
  selector:
    namespace: default
    serviceAccount: default
  spiffeId: "spiffe://example.org/ns/default/sa/default"
```

## Usage


Manual test;
```
#images lreg_preload ./default   # (if needed)
./spire.sh test start_registrar > $log
# On a vm;
kubectl get spiffeid -A
kubectl get spiffeid -n spire vm-001 -o json
kubectl exec spire-server-0 -n spire -c spire-server -- ./bin/spire-server entry show
```

### Call from another ovl

Assuming the `ovl/test` is used, make sure `ovl/spire` is included and add in
your test start;
```
otcprog=spire_test
otc 1 start_spire_registrar
unset otcprog
```

## Update

```
mkdir -p $GOPATH/src/github.com/spiffe
git clone https://github.com/spiffe/spire.git $GOPATH/src/github.com/spiffe/spire
cd $GOPATH/src/github.com/spiffe/spire
git fetch --tags
git branch -a
git checkout v1.2.1
cdo spire
meld $GOPATH/src/github.com/spiffe/spire/support/k8s/k8s-workload-registrar/mode-crd/config default/etc/kubernetes/spire
images getimages default/
grep :1.1.0 default/etc/kubernetes/spire/*
sed -i -e 's,:1.1.0,:1.2.1,' default/etc/kubernetes/spire/*
images lreg_preload ./default
```
