# Xcluster ovl - crio

[Cri-o](https://github.com/cri-o/cri-o) is used as CRI-plugin for
Kubernetes in `xcluster`.

Related links;

* https://kubernetes.io/docs/tutorials/security/seccomp/

* [Mock cri-o](https://github.com/HonakerM/mock-cri/tree/mocked-release-1.24)

## Cri-o static release bundle

Cri-o have a binary release since v1.18. It can't be downloaded with
"curl" so follow the link on the [release page](
https://github.com/cri-o/cri-o/releases) and store it in $ARCHIVE.

```
ver=v1.29.2
ar=cri-o.amd64.$ver.tar.gz
mv $HOME/Downloads/$ar $ARCHIVE/$ar
tar -C default --strip-components=1 -xf $ARCHIVE/$ar cri-o/etc/crio.conf
```

In crio v1.29, the binaries are pre-pended with "crio-". So, "crun"
becomes "crio-crun". To keep backward compatibility, the old names are
still used in `crio.conf` but are corrected in the `32cri-plugin.rc` script.


## Test

```
./crio.sh    # help printout
./crio.sh test start > $log
# On vm-001
crictl version
crictl pull docker.io/library/alpine:latest
images
```



## Build

cri-o;
```
mkdir -p $GOPATH/src/github.com/cri-o
cd $GOPATH/src/github.com/cri-o
rm -rf cri-o
git clone --depth 1 https://github.com/cri-o/cri-o.git
cd $GOPATH/src/github.com/cri-o/cri-o
git reset --hard HEAD
git pull
git clean -dxf
git status -u --ignored
#curl -L https://github.com/cri-o/cri-o/pull/2925.patch | patch -p1
make
```

conmon;
```
mkdir -p $GOPATH/src/github.com/containers
cd $GOPATH/src/github.com/containers
rm -rf conmon
git clone --depth 1 https://github.com/containers/conmon.git
cd conmon
make binaries
```

## Runtime

Both [runc](https://github.com/opencontainers/runc) and
[crun](https://github.com/containers/crun) runtimes are included
in the `cri-o` static release bundle. `crun` is used by default, but
you can alter that in `crio.conf`.



## Problems

Resource exhaust (from slack);
```
lsof 2>/dev/null | grep inotify | awk '{print $2}' | sort | uniq -c
```
