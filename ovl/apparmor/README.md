# Xcluster/ovl - apparmor and seccomp

Experiments and examples with [Apparmor](https://apparmor.net/) and
[seccomp](https://en.wikipedia.org/wiki/Seccomp).

Also check the [demo](./demo) and the [demo commands](./demo/apparmor-seccomp.md).

Links;

* https://www.kernel.org/doc/html/v5.19/admin-guide/LSM/apparmor.html
* https://kubernetes.io/docs/tutorials/security/apparmor/
* https://kubernetes.io/docs/tutorials/security/seccomp/
* https://www.maketecheasier.com/selinux-vs-apparmor/
* https://github.com/moby/moby/issues/7512


## Start and test

```
./apparmor.sh test start > $log
# Check;
aa-enabled
aa-status
cat /sys/kernel/security/apparmor/profiles
# Disable apparmor
__append=apparmor=0 ./apparmor.sh test start > $log
# Seccomp
xcluster_CRI_OPTS=--seccomp-default ./apparmor.sh test start > $log
# Basic test
./apparmor.sh test echo > $log
```

## Apparmor in KinD

Apparmor is not enabled in KinD. A problem is that the apparmor
configuration on your host applies also in the KinD docker image.  It
should be possible to enable apparmor in KinD but it will not be
certain that it will work in all configuration on all Linux distros.

Things that must be done;

* Mount the securityfs in the KinD container

* Make sure that default profile is loaded on the host before KinD is
  started, or allow the KinD container to load it, which requires...

* Make sure that the "apparmor_parse" binary is executable in the KinD
  container *before* the CRI-plugin (containerd) is started.
