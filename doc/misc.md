# Xcluster miscellaneous info

Contains tips, tricks, Q&A, recipes and general information in no
particular order.


## cdo

The `cdo` function (defined in `Envsettings`) let you cd to a ovl directory;
```
cdo metallb
```

## Use the master branch with a binary release

The binary releases will lag behind and sometimes you may want to use
a binary release as base but use for instance overlays from the
`master` branch;

```
# Download and unpack the binary release;
ver=v0.4
cd $HOME
tar xf Downloads/xcluster-$ver.tar.xz
# Copy the pre-built binaries ($GOPATH assumed to be set);
cp $HOME/xcluster/bin/* $GOPATH/bin
# Clone xcluster to another place;
mkdir -p $HOME/work
cd $HOME/work
git clone https://github.com/Nordix/xcluster.git
# Use the workspace from the binary release;
cd $HOME/work/xcluster
export XCLUSTER_WORKSPACE=$HOME/xcluster/workspace
. ./Envsettings.k8s   # set XCLUSTER_WORKSPACE *before* sourcing!
xc ovld kube-router   # Should be our cloned dir
```


## Prettify the xterms

The `xterm` windows may look awful on your screen or be unreadable
depending on resolution, etc. This can be configured. First we try to
make the xterms look nice, then we position them on screen.

#### Xterm looks

`Xterm` is a very old program and still uses the `$HOME/.Xdefaults`
database. In here you can specify settings for *all* xterms on your
machine. Below are mine as an example. After editing
`$HOME/.Xdefaults` you must re-read the datbase with `xrdb`;

```
> grep -i xterm $HOME/.Xdefaults
XTerm*background: black
XTerm*foreground: wheat
XTerm*cursorColor: orchid
XTerm*faceName: VeraMono
XTerm*faceSize: 11
> xrdb $HOME/.Xdefaults
```

Change it until you are happy with the look. Probably you only need to
change the `faceSize`. I am using two screens and want to have a
larger font *only* for the `xcluster` xterms. Use the `xtermopt`
variable for this;

```
export xtermopt="-fs 12"
```

#### Xterm positioning

To position the `xterm` windows use the variables `$XCLUSTER_LAYOUT`
and `$XCLUSTER_OFFSET`. The defaults are;

```
export XCLUSTER_LAYOUT="dx=550;dy=220;sz=80x12"
export XCLUSTER_OFFSET="xo=20;yo=50"
```

Set `dx` and `dy` to avoid overlapping windows and `xo` and `yo` for
the base position (may be useful for multiple screens).


