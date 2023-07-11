# Xcluster overlay - iptools

Overlay that installs some ip tools. Intended for experiments with
the latest iptools. The `ntf` program for configuring the
[nftables](https://netfilter.org/projects/nftables/index.html) is
included.


## Usage

Prerequisite: The kernel must be built with nftables support.

Build;

```
./iptools.sh versions
./iptools.sh download
./iptools.sh build
```

Use;

```
xc mkcdrom iptools ...
```

This overlay is almost always used with other overlays.

