# Xcluster ovl - frr - Free Range Router

Install an [FRR](https://frrouting.org/) router. Frr is a quagga fork,
read the [docs](http://docs.frrouting.org/en/latest/).


## Usage

Manual test (without k8s);
```
eval $($XCLUSTER env | grep XCLUSTER_HOME)
export __image=$XCLUSTER_HOME/hd.img
SETUP=test xc mkcdrom test frr; xc starts
# On a VM AND on a router (e.g. vm-001 and vm-201);
frr_test tcase_gen_config > /tmp/frr.log
/usr/local/sbin/bgpd -u root -g root -A ::1 -d -f /etc/frr/bgpd.conf
telnet ::1 2605   # (passwd; "zebra")
terminal length 0
show bgp neighbor
```


## Build

Prep;
```
apt install dh-autoreconf libjson-c-dev libpython-dev
```

Libyang
```
mkdir -p $GOPATH/src/github.com/CESNET
cd $GOPATH/src/github.com/CESNET
git clone git@github.com:CESNET/libyang.git
cd $GOPATH/src/github.com/CESNET/libyang
rm -rf build; mkdir build; cd build
cmake -DENABLE_LYD_PRIV=ON ..
make -j$(nproc)
libyangd=$GOPATH/src/github.com/CESNET/libyang/build/sys
make DESTDIR=$libyangd install
sed -ie "s,/usr/local,$libyangd/usr/local," $libyangd/usr/local/lib/pkgconfig/libyang.pc
PKG_CONFIG_PATH=$libyangd/usr/local/lib/pkgconfig pkg-config --libs libyang
```

Frr;
```
mkdir -p $GOPATH/src/github.com/FRRouting
cd $GOPATH/src/github.com/FRRouting
git clone git@github.com:FRRouting/frr.git
cd $GOPATH/src/github.com/FRRouting/frr
git clean -f -d -x
git status -u --ignored
./bootstrap.sh
libyangd=$GOPATH/src/github.com/CESNET/libyang/build/sys
PKG_CONFIG_PATH=$libyangd/usr/local/lib/pkgconfig \
 ./configure --disable-doc
LD_RUN_PATH=$libyangd/usr/local/lib make -j$(nproc)
frrd=$GOPATH/src/github.com/FRRouting/frr/sys
make DESTDIR=$frrd install
rm -rf $frrd/usr/local/include
# Local test;
find $frrd -type f
man ld-linux
LD_LIBRARY_PATH=$frrd/usr/local/lib $frrd/usr/local/bin/vtysh -h
LD_LIBRARY_PATH=$frrd/usr/local/lib $frrd/usr/local/sbin/bgpd -h
```

Pod (not used);
```
images mkimage --force --upload ./image
```
