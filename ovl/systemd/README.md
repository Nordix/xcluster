Xcluster overlay - systemd
==========================

Make xcluster start with
[systemd](https://www.freedesktop.org/wiki/Software/systemd/).


Usage
-----

Prerequisite; `systemd` must be built as described below.

```
xc mkcdrom systemd
xc start
```


Build
-----

Systemd has abandoned autotools (which I totally undestand) but
replaced it with meson/ninja for some reason. A makefile with
menuconfig like the kernel or busybox would be more appropriate.

A simple makefile (Systemd.make) is provided which build a minimum
systemd, systemctl, systemd-run and libsystemd.so. Use the systemd.sh
script;

```
./systemd.sh download
./systemd.sh unpack
cd $XCLUSTER_WORKSPACE/util-linux-2.31
./configure; make -j$(nproc)
cd -
./systemd.sh make clean
./systemd.sh make -j$(nproc)
```

Default targets and services
----------------------------

The final target is `default.target`, however most services assumes a
`multi-user.target` so that target is also defined. The start in the
default setup is;

```
  syslog.service
sysinit.target
  network.service
network.target
  run-rc.service
multi-user.target
  login.service
default.target
```

All files are in `/etc/systemd/system/`.

Debug
-----

If systemd encounter some problem during startup it prints "Freezing
execution" and leave you with a dead system and no way to
troubleshoot. To make things worse systemd disables core dumps.

To troubleshoot systemd core dumps you must re-enable core dumps. In
`src/basic/util.c` disable the code;

```
 r = write_string_file("/proc/sys/kernel/core_pattern", "|/bin/false", 0);
```

Then build with debug option;

```
./systemd.sh make clean
CFLAGS=-g ./systemd.sh make -j4
```

Then make a cdrom image with the `debug` setup;

```
SETUP=debug xc mkcdrom systemd
```

This re-enables the old startup while still letting systemd run as
pid=1. After the crash, copy the core dump and run `gdb`;

```
rcp root@192.168.0.2:/var/log/dumps/core.systemd.75 /tmp
cd $XCLUSTER_WORKSPACE/systemd-238
gdb -c /tmp/core.systemd.75 ./obj/sbin/systemd
```


Problems
--------

### Reboot

Reboot doesn't work. The `reboot` BusyBox applet assumes a "normal"
init. The systemd way of reboot is to set the "reboot" target, which
is not yet implemented in xcluster.

### Machine-id

The `/etc/machine-id` must not exist on startup otherwise the targets
are reached immediately but no services are initiated - system is
dead. But we want the same machine-id on a reset, so in the
`init.hook`;

```
rm -f /etc/machine-id
exec /sbin/systemd --machine-id=$(printf "%032x" 0x$b0)
```

### Core dumps

If something bad happens `systemd` has the recovery..., well it has no
recovery;

```
systemd[1]: Caught <ABRT>, dumped core as pid 75.
systemd[1]: Freezing execution.
```
