# Xcluster/ovl - systemtap

Use Linux systemtap on xcluster. Normally the entire kernel build
system is available on the target system. In xcluster it is not so.


## Preparations

The kernel *must* be built locally with `CONFIG_RELAY=y` and `KPROBES`
```
xc kernel_build --menuconfig
# [*] General setup > Kernel->user space relay support (formerly relayfs)
# [*] General architecture-dependent options > Kprobes
```

Clone, configure and build:
```
./systemtap.sh clone
./systemtap.sh configure
./systemtap.sh build
./systemtap.sh man --grep="-v ::"
```

## Basic test

```
eval $($XCLUSTER env | grep __kobj)
_output/bin/stap -r $__kobj -R $PWD/_output/share/systemtap/runtime -p4 \
  -m hello -e 'probe kernel.function("do_sys_open") {print("hello world")}'
./systemtap.sh test start_empty > $log
# On vm-001
staprun hello.ko
# Do something in another shell, then hit ^C
```


## References

* https://wiki.archlinux.org/title/SystemTap
* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/systemtap_beginners_guide/cross-compiling

