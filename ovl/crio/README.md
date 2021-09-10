# Xcluster ovl - crio

[Cri-o](https://github.com/cri-o/cri-o) is used as CRI-plugin for
Kubernetes in `xcluster`.


## Cri-o static release bundle

Cri-o have a binary release since v1.18. It can't be downloaded with
"curl" so follow the link and store it in $ARCHIVE.

```
ver=v1.18.3
ar=crio-$ver.tar.gz
mv $HOME/Downloads/$ar $ARCHIVE/$ar
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

The [runc](https://github.com/opencontainers/runc) runtime is bundled
with the `cri-o` static release bundle.

It is possible to replace `runc` with
[crun](https://github.com/containers/crun)


## Problems

Resource exhaust (from slack);
```
lsof 2>/dev/null | grep inotify | awk '{print $2}' | sort | uniq -c
```
