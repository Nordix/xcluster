# Xcluster ovl - timezone

The timezone in `xcluster` is specified in `/etc/TZ` file on the
VMs. The entire timezone data-base is not installed (of course) so the
user friendly way, for instance `Pacific/Auckland` can **not** be
used. Instead the more basic format must be used. Please read;

```
man 3 tzset
```

The default timezone is Central Europe (CET);

```
CET-1CEST-2,M3.5.0,M10.5.0/3
```

## Usage

Copy the `timezone` overlay to some own directory earlier in the
`$XCLUSTER_OVLPATH`. Then edit the `/etc/TZ` file and include the
overlay;

```
echo "NZST-12:00:00NZDT-13:00:00,M10.1.0,M3.3.0" > \
  $($XCLUSTER ovld timezone)/default/etc/TZ
xc mkcdrom timezone; xc start
```

A good idea is probably to add this to the disk image. You may have to
install `diskim` first;

```
wget -O - -q \
 https://github.com/lgekman/diskim/releases/download/v0.4.0/diskim-v0.4.0.tar.xz \
 | tar -I pxz -C /home/guest/xcluster/workspace -xf -
xc ximage timezone
```

