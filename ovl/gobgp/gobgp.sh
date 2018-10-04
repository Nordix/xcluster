#! /bin/sh
##
## gobgp.sh --
##
##   Scriptlets for the "gobgp" ekvm overlay.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$

die() {
    echo "ERROR: $*" >&2
    rm -rf $tmp
    exit 1
}
help() {
    grep '^##' $0 | cut -c3-
	test -r $hook && grep '^##' $hook | cut -c3-
    rm -rf $tmp
    exit 0
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

log() {
	echo "$prg: $*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

ver=1.29
ar=gobgp_${ver}_linux_amd64.tar.gz
baseurl=https://github.com/osrg/gobgp/releases/download

zver=1.2.4
zar=quagga-$zver.tar.gz
zbaseurl=http://download.savannah.gnu.org/releases/quagga

cmd_env() {
	test -n "$ARCHIVE" || die 'Not specified [$ARCHIVE]'
	test -d "$ARCHIVE" || die "Not a directory [$ARCHIVE]"
}

##   download
##     Download a binary release to $ARCHIVE.
##
cmd_download() {
	cmd_env
	if test -r "$ARCHIVE/$ar"; then
		dbg "Already downloaded [$ar]"
	else
		local url=$baseurl/v$ver/$ar
		curl -L $url > "$ARCHIVE/$ar" || die "Download failed [$url]"
		log "Downloaded [$ar]"
	fi
	echo "$ARCHIVE/$ar"
}

##   zdownload
##   zbuild
##     Download and build Quagga
##   zdir
##     Print the dir where Quagga is built
##   zinstall dest
##     Install zebra
##
cmd_zdownload() {
	cmd_env
	if test -r "$ARCHIVE/$zar"; then
		dbg "Already downloaded [$zar]"
	else
		local url=$zbaseurl/$zar
		curl -L $url > "$ARCHIVE/$zar" || die "Download failed [$url]"
		log "Downloaded [$zar]"
	fi
	echo "$ARCHIVE/$ar"
}
cmd_zbuild() {
	local d zebra
	d=$XCLUSTER_WORKSPACE/quagga-$zver
	test "$__clean" = "yes" && rm -rf $d
	test -d $d || tar -C $XCLUSTER_WORKSPACE -I pigz -xf $ARCHIVE/$zar
	zebra=$d/zebra/.libs/zebra
	if ! test -x $zebra; then
		cd $d
		./configure --enable-multipath=16 --disable-doc \
			|| die "Configure failed"

		# Systemd requires the link; /var/run -> /run but zebra can't
		# create it's files/sockets in a soft-link dir it seems :-(
		# So do a full change in the config.h
		sed -i -e 's,/var/run,/run,' config.h
		make -j4 || die "Build quagga failed"
		log "Built [$zebra]"
	else
		dbg "Already built [$zebra]"
	fi
}
cmd_zdir() {
	echo $XCLUSTER_WORKSPACE/quagga-$zver
}
cmd_zinstall() {
	test -n "$1" || die "No dest"
	test -d "$1" || die "Not a directory [$1]"
	local dst=$(readlink -f $1)
	local d=$XCLUSTER_WORKSPACE/quagga-$zver
	local f=$d/zebra/.libs/zebra
	test -x $f || die "Not executable [$f]"
	mkdir -p $dst/bin $dst/lib64
	cp $f $dst/bin
	f=$d/lib/.libs/libzebra.so.1
	test -r $f || die "Not readable [$f]"
	cp -L $f $dst/lib64
}

# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 $hook || die "Invalid command [$cmd]"

while echo "$1" | grep -q '^--'; do
    if echo $1 | grep -q =; then
	o=$(echo "$1" | cut -d= -f1 | sed -e 's,-,_,g')
	v=$(echo "$1" | cut -d= -f2-)
	eval "$o=\"$v\""
    else
	o=$(echo "$1" | sed -e 's,-,_,g')
	eval "$o=yes"
    fi
    shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
