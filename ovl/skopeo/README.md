# Xcluster ovl - Skopeo

The [skopeo](https://github.com/containers/skopeo) image utility


`Skopeo` uses the same libraries as `cri-o` so it will experience the
same problems.


## Local build

Follow the
[instructions](https://github.com/containers/skopeo/blob/main/install.md#building-without-a-container) on github;

```

sudo apt install libgpgme-dev libassuan-dev btrfs-progs \
  libdevmapper-dev libostree-dev
git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo
cd $GOPATH/src/github.com/containers/skopeo
make bin/skopeo
mv ./bin/skopeo $GOPATH/bin
```

### Build and install

```
go get github.com/cpuguy83/go-md2man  # (if needed)
cd $GOPATH/src/github.com/containers/skopeo
skopeod=$GOPATH/src/github.com/containers/skopeo/sys
make DESTDIR=$skopeod install
# View man pages
man $skopeod/usr/share/man/man1/skopeo.1
man $skopeod/usr/share/man/man1/skopeo-list-tags.1
```
