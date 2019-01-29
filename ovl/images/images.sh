#! /bin/sh
##
## images.sh --
##
##   Handles OCI images in "xcluster".
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=/tmp/${prg}_$$

pause="k8s.gcr.io/pause:3.1"

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
	echo "$*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

cmd_env() {
	eval $($XCLUSTER env)
}

##   docker_flush
##     Remove ALL containers and images form docker.
##
cmd_docker_flush() {
	docker rm -f $(docker ps -a -q)
	docker rmi -f $(docker images -q)
}

cmd_in_docker() {
	test -n "$1" || return 1
	echo "$1" | grep -q : || die "Image must have a version"
	skopeo inspect docker-daemon:$1 > /dev/null 2>&1
}

##   docker_lsreg
##     List the contents of the local registry.
##
cmd_docker_lsreg() {
	local regip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry)
	test -n "$regip" || die "Can't get address of the local registry"
	local i
	for i in $(curl -s -X GET http://$regip:5000/v2/_catalog | jq .repositories[] | tr -d '"'); do
		echo "$i:"
		echo -n "  "
		curl -s -X GET http://$regip:5000/v2/$i/tags/list | jq -c .tags
	done

}

##   docker_ls <image>
##
cmd_docker_ls() {
	cmd_in_docker $1 || die "Can't find image [$1]"
	local c=$(docker create $1) || die "FAILED; docker create"
	docker export $c | tar t | sort
	docker rm $c > /dev/null
}

#   get_manifest <rootfs>
#
cmd_get_manifest() {
	test -n "$1" || die "No rootfs"
	if test -r "$1/manifest.json"; then
		echo "$1/manifest.json"
		return 0
	fi
	# Fall-back;
	local d=$(dirname $1)
	find $d -mindepth 1 -maxdepth 1 -name '*.json'
}

#   get_rootfs <ovl>
#   get_rootfs <ovl/subdir>
#
cmd_get_rootfs() {
	test -n "$XCLUSTER" || die 'Not set [$XCLUSTER]'
	test -x "$XCLUSTER" || die "Not executable [$XCLUSTER]"
	test -n "$1" || die "No ovl"
	local d ovl rootfs=image
	if echo "$1" | grep -q / ; then
		ovl=$(echo $1 | cut -d/ -f1)
		rootfs=$(echo $1 | cut -d/ -f2)
	else
		ovl=$1
	fi
	d=$($XCLUSTER ovld $ovl) || die "Can't find ovl [$ovl]"
	test -d $d/$rootfs || die "Not a directory [$d/$rootfs]"
	echo $d/$rootfs
}

##   mkimage [--manifest=manifest] [--force] [--upload] <dir>
##     Create an image in local docker from the <dir>. An executable
##     "tar" script must exist in the directory. '--upload' uploads
##     to a *local* private docker registry.
##
cmd_mkimage() {
	test -n "$1" || die "No rootfs"
	test -d "$1" || die "Not a directory [$1]"
	test -x "$1/tar" || die "Not executable [$1/tar]"
	test -n "$__manifest" || __manifest="$(readlink -f $1)/manifest.json"
	test -r "$__manifest" || die "Not readable [$__manifest]"
	which jq > /dev/null || die "Not executable [jq]"

	local n v c tar
	tar="$(readlink -f $1)/tar"
	v=$(jq -r '.labels[] | select(.name=="version") | .value' $__manifest)
	n=$(jq -r .name $__manifest)
	c=$(jq -rc '.app.exec' $__manifest)

	test "$__force" = "yes" && docker rmi $n:$v > /dev/null 2>&1
	if $(cmd_in_docker "$n:$v"); then
		log "Cached [$n:$v]"
	else
		$tar - | docker import -c "CMD $c" - $n:$v > /dev/null
	fi
	if test "$__upload" = "yes"; then
		local regip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry)
		test -n "$regip" || die "No address to local docker registry"
		skopeo copy --dest-tls-verify=false docker-daemon:$n:$v docker://$regip:5000/$n:$v
	fi
	echo "$n:$v"
}

#   mktar --user=user [--tar=-] <images...>
#     Create a tar file with a container-storage structure.
#
cmd_mktar() {
	test -n "$__tar" || __tar=-
	test -n "$__user" || die "No --user"
	test $(id -u) -eq 0 || die 'Must run as "root"'
	rm -rf /tmp/var > /dev/null 2>&1
	local f n
	for f in $@; do
		log "Adding [$f]"
        skopeo --insecure-policy copy docker-daemon:$f \
            containers-storage:$f > /dev/null 2>&1 || die "skopeo failed [$f]"
	done

	tar -C /tmp -cf $__tar var
	test "$__tar" != "-" && chown $(id -u $__user):$(id -g $__user) $__tar
}

##   make [--tar=$XCLUSTER_TMP/images.tar <items...>
##     Create a tar file with the container-storage structure for the
##     passed image items.
##
cmd_make() {
	cmd_env
	test -n "$__tar" || __tar=$XCLUSTER_TMP/images.tar
	local n rootfs img=''
	mkdir -p $tmp
	for n in $pause $@; do
		if echo "$n" | grep -q : ; then
			cmd_in_docker "$n" || docker pull "$n" || die "Pull failed [$n]"
			img="$img $n"
		else
			rootfs=$(cmd_get_rootfs $n) || return 1
			manifest=$(cmd_get_manifest $rootfs)
			test -n "$manifest" || die "Can't find manifest [$n]"
			img="$img $($me mkimage --manifest=$manifest $rootfs)" || return 1
		fi
	done
	sudo $me mktar --user=$USER --tar=$__tar $img
	rm -rf $tmp
	return 0
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
