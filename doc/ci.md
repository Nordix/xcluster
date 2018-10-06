# Xcluster for Continuous Integration

All CI environments are different but here are some general notes.


## Headless operation

`Xcluste` can be started with consoles in
[GNU-screen](https://www.gnu.org/software/screen/) instead of `xterm`;

```
xc starts
eval $($XCLUSTER env | grep XCLUSTER_TMP)
> ls $XCLUSTER_TMP/screen/
screenlog.tmp     screenlog.vm-002  screenlog.vm-004  screenlog.vm-202  session
screenlog.vm-001  screenlog.vm-003  screenlog.vm-201  screen.rc
> screen -ls
There is a screen on:
        10756.xcluster-QiD0     (10/05/2018 01:07:52 PM)        (Detached)
1 Socket in /run/screen/S-uablrek.
> screen -r 10756.xcluster-QiD0 -p vm-003
```

After a failed test the console logs can be collected. There is no
support for fetching logs from the VMs but it should not be hard to do
with `ssh` and some scripting.


## Object Under Test (OUT)

The project build should produce an extended `xcluster` image with the
OUT installed and ready (as an "artifact"). Test programs and test
agents can be loaded as overlays, and everything managed by some test
system of your liking.

An advantage is that tests can be performed manually with the
pre-installed image which guarantees the same environment as the CI
test.


## Many xclusters on the same host

A test server will probably allow multiple tests and clusters must be
separated. The best is probably to use a netns or perhaps a
container. In main netns user-space networks can be separates by
specifying different "BASE" addresses. See the
`config/net-setup-userspace.sh` file.
