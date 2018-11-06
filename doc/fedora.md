# Xcluster on Fedora

Xcluster is not tested on Fedora so there are likely some problems but
here is a start anyway.

To run `xcluster` on Fedora 29 you must use a version >v1.0 or use
xcluster from the
[master-branch](misc.md#use-the-master-branch-with-a-binary-release).

## Install qemu-kvm

```
sudo dnf install -y qemu-kvm qemu-img
sudo usermod -aG qemu $USER
# (logout/in to enable the new group)
```

## Install dependencies

```
sudo dnf install -y xterm jq genisoimage pxz screen
# (probably not needed;)
#sudo dnf install -y xorg-x11-xauth bitstream-vera-sans-mono-fonts
```

## Start xcluster

The `kvm` command differs from Ubuntu so you must specify it;

```
export __kvm=qemu-kvm
cd $HOME/xcluster
. ./Envsettings.k8s
...
```

