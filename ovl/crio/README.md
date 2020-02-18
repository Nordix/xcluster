# Xcluster ovl - crio

[Cri-o](https://github.com/cri-o/cri-o) is used as CRI-plugin for
Kubernetes in `xcluster`. Cri-o has not yet any binary release so this
ovl builds `cri-o` from source.

## Build cri-o

```
cd $GOPATH/src/github.com/cri-o/cri-o
git reset --hard HEAD
git pull
git clean -dxf
git status -u --ignored
curl -L https://github.com/cri-o/cri-o/pull/2925.patch | patch -p1
make
```



## Problems

Resource exhaust (from slack);
```
lsof 2>/dev/null | grep inotify | awk '{print $2}' | sort | uniq -c
```
