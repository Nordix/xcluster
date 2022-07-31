# Xcluster/ovl - static-kernel

Build and use a static Linux kernel.

## Usage

```
cdo static-kernel
./static-kernel.sh build
eval $(./static-kernel.sh env | grep -E '__kbin')
export __kbin
```

