# Xcluster/ovl - cert-manager

The [cert-manager](https://github.com/jetstack/cert-manager) on xcluster.

## Usage

Prepare;
```
for n in $(images lreg_missingimages .); do
  images lreg_cache $n
done
```

Test (only start is tested);
```
./cert-manager.sh test > $log
```

Usage from another ovl;
```
otcprog=cert-manager_test
otc 1 start_cert_manager
unset otcprog
```
