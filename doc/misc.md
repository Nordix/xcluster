# Xcluster miscellaneous info

Contains tips, tricks, Q&A, recipes and general information in no
particular order.


## cdo

The `cdo` function (defined in `Envsettings`) let you cd to a ovl directory;
```
cdo metallb
```

`cdo` had command competion in "bash".


## Use the master branch with a binary release

The binary releases will lag behind and you may want to use the
workspace from a binary release but use `xcluster` from the `master`
branch;

```
XCDIR=$HOME/tmp   # Change to your preference
mkdir -p $XCDIR
cd $XCDIR
git clone --depth 1 https://github.com/Nordix/xcluster.git
curl -L https://github.com/Nordix/xcluster/releases/download/v2.2/xcluster-workspace-v2.2.tar.xz | tar xJ
export XCLUSTER_WORKSPACE=$XCDIR/workspace
cd $XCDIR/xcluster
. ./Envsettings.k8s   # set XCLUSTER_WORKSPACE *before* sourcing!
# Go on as usual. Download hd-k8s.img if needed.
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


