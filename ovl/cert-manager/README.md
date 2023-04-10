# Xcluster/ovl - cert-manager

The [cert-manager](https://github.com/jetstack/cert-manager) on xcluster.

## Usage

Test (only start is tested);
```
images lreg_preload default
./cert-manager.sh test > $log
```

Check from another ovl;
```
otcprog=cert-manager_test
otc 1 start_cert_manager
unset otcprog
```
