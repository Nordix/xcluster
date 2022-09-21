# Apparmor/Seccomp Demo

The Meridio parts requires;

* https://github.com/Nordix/Meridio
* https://github.com/Nordix/nsm-test/tree/master/ovl/forwarder-test

## Apparmor without K8s

```
cdo apparmor
./apparmor.sh test --no-stop echo > $log

# On vm-001;
aa-enabled
mount | grep securityfs
cat /sys/kernel/security/apparmor/profiles
zcat /proc/config.gz | grep -i apparmor

# Handle profiles;
aa-status
cat /etc/apparmor.d/root/root.bin.echo
/root/bin/echo Hello
cat /etc/apparmor.d/root/root.bin.echo-empty
apparmor_parser -r /etc/apparmor.d/root/root.bin.echo-empty
/root/bin/echo Hello

# Complain mode
cp /bin/busybox /root/bin/sh
cat /etc/apparmor.d/root/root.bin.sh-empty
apparmor_parser -C /etc/apparmor.d/root/root.bin.sh-empty
/root/bin/sh    # (exit)
grep -oE 'apparmor="ALLOWED".*' /var/log/messages

cat /etc/apparmor.d/root/root.bin.sh-min
apparmor_parser -r /etc/apparmor.d/root/root.bin.sh-min
/root/bin/sh    # ls; exit
apparmor_parser -Cr /etc/apparmor.d/root/root.bin.sh-min
/root/bin/sh    # ls; exit
grep -oE 'apparmor="ALLOWED".*' /var/log/messages

cat /etc/apparmor.d/root/root.bin.sh-ls
apparmor_parser -r /etc/apparmor.d/root/root.bin.sh-ls
/root/bin/sh    # ls; exit

```



## Apparmor in K8s

```
export __nrouters=0
# Cluster without apparmor
__append=apparmor=0 ./apparmor.sh test k8s_start_empty > $log
# On a VM
aa-enabled
cat /proc/cmdline
cat /etc/kubernetes/alpine-apparmor.yaml
kubectl apply -f /etc/kubernetes/alpine-apparmor.yaml
kubectl get pods

# Cluster with apparmor
./apparmor.sh test k8s_start_empty > $log
# On a VM
aa-enabled
kubectl apply -f /etc/kubernetes/alpine-apparmor.yaml
kubectl get pods
aa-status
cat /etc/kubernetes/alpine.yaml
kubectl apply -f /etc/kubernetes/alpine.yaml
kubectl get pods
aa-status

# Meridio with apparmor
cdo forwarder-test
export XOVLS="private-reg apparmor containerd"
./forwarder-test.sh test --trenches=a start_e2e > $log
# On a VM
pods -n red | grep $(hostname)
aa-status

# seccomp
pod=proxy-trench-a-6sdfn
kubectl exec -n red $pod -- cat /proc/1/status | grep -i seccomp
crictl ps
crictl inspect 19c7b9faa6f17 | jq .info.runtimeSpec.linux.seccomp
```


## Seccomp

```
cdo forwarder-test
export XOVLS="private-reg apparmor containerd"
xcluster_CRI_OPTS=--seccomp-default ./forwarder-test.sh test --trenches=a start_e2e > $log

# On a VM
kubectl get pods -n red
pod=$(kubectl get pods -n red -o name | grep load-balancer | head -1)
echo $pod
kubectl exec -n red -c fe $pod -- cat /proc/1/status | grep -i seccomp
crictl ps
crictl inspect 19c7b9faa6f17 | jq .info.runtimeSpec.linux.seccomp
```


## KinD

```
cdo forwarder-test
# In a separate shell; ./forwarder-test.sh kind_start_e2e
kind version
head -18 kind/meridio.yaml

./forwarder-test.sh kind_sh
# On meridio-control-plane
kubectl get pods -n red
pod=$(kubectl get pods -n red -o name | grep load-balancer | head -1)
kubectl exec -n red -c fe $pod -- cat /proc/1/status | grep -i seccomp

# Check seccomp on a worker;
./forwarder-test.sh kind_sh worker
crictl ps
crictl inspect 19c7b9faa6f17 | jq .info.runtimeSpec.linux.seccomp
ps axwww | grep /usr/bin/kubelet  # check for --seccomp-default
```

### Apparmor in KinD

```
docker cp /usr/bin/aa-enabled meridio-worker:bin
docker cp /usr/sbin/aa-status meridio-worker:bin
# On the worker
aa-enabled
mount -t securityfs securityfs /sys/kernel/security
aa-enabled
aa-status
```


## Commands and info

```
aa-enabled
aa-status
apparmor_parser
kubectl exec -n red $pod -- cat /proc/1/status | grep -i seccomp
crictl ps
crictl inspect 19c7b9faa6f17 | jq .info.runtimeSpec.linux.seccomp
```
