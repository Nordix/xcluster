#! /bin/sh
##
## vbox.sh --
##   Script for creating VirtualBox images with xcluster.
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

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__kcfg" || . $dir/Envsettings
	eval $($XCLUSTER env)
	test -n "$VBOXDIR" || VBOXDIR=$HOME/VirtualBox
	test "$cmd" = "env" && set | grep -E '^(__.*|ARCHIVE)='
}

##  kernel_build [--menuconfig]
##
cmd_kernel_build() {
	cmd_env
	test -r "$__kcfg" || die "Kernel config not readable [$__kcfg]"
	$XCLUSTER kernel_build --menuconfig=$__menuconfig
}

##  mkimage [--alpine=docker-img] [ovls...]
##
cmd_mkimage() {
	test -n "$__image" || die 'Not set [$__image]'
	test "$__force" = "yes" && rm -f "$__image"
	test -e "$__image" && die "Already exists [$__image]"
	cmd_env

	if test -z "$__alpine"; then
		mkdir -p $(dirname $__image) || die mkdir
		$XCLUSTER mkimage --bootable --size=$__size || die mkimage
		$XCLUSTER ximage virtualbox $@ || die ximage
		return 0
	fi

	# Alpine image
	local images=$($XCLUSTER ovld images)/images.sh
	mkdir -p $tmp
	$images docker_export $__alpine > $tmp/alpine.tar || die docker_export
	$DISKIM mkimage --bootable $tmp/alpine.tar $dir/alpine
	$XCLUSTER ximage virtualbox $@ || die ximage
}

##  replace_disk --image= [--vdi_image=] <vm...>
##    Delete the old vdi_image, create a new from image and replace on vms.
##
cmd_replace_disk() {
	cmd_env
	test -n "$__image" || die "No image"
	test -r "$__image" || die "Not readable [$__image]"
	test -n "$__vdi_image" || __vdi_image=/tmp/$USER/xcluster.vdi
	local vm
	for vm in $@; do
		VBoxManage storageattach $vm --type hdd --storagectl IDE \
			--port 0 --device 0 --medium none
	done
	deletemedium $__vdi_image
	qemu-img convert -f qcow2 $__image -O vdi $__vdi_image || die convert
	VBoxManage modifymedium disk $__vdi_image --type immutable || die immutable
	for vm in $@; do
		VBoxManage storageattach $vm --type hdd --storagectl IDE \
			--port 0 --device 0 --mtype immutable --medium $__vdi_image \
			|| die "Reattach hda"
	done
}
deletemedium() {
	local child
	for child in $(VBoxManage showmediuminfo disk $1 | \
		grep -A100 'Child UUIDs:' | sed -e 's,Child UUIDs:,,'); do
		VBoxManage closemedium disk $child --delete || die "Delete child medium"
	done
	# May fail if there is no medium
	VBoxManage closemedium disk $1 --delete > /dev/null 2>&1
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
