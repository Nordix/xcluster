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

##   docker_ls <image>
##     List files in a docker image
##   docker_ls_layers <image>
##     List files in a docker image per layer
##   docker_save_layers <image> <layers...> | tar t
##     Saves files from layers to tar on stdout
##   docker_export <image>
##     Same as "docker export" byt for an image
##
cmd_docker_ls() {
	cmd_docker_export $1 | tar t | sort
}

cmd_docker_export() {
	cmd_in_docker $1 || die "Can't find image [$1]"
	local c=$(docker create $1 sh) || die "FAILED; docker create"
	docker export $c
	docker rm $c > /dev/null 2>&1
}

cmd_docker_ls_layers() {
	test -n "$1" || die "No image"
	mkdir -p $tmp
	docker inspect "$1" > $tmp/out || die "Failed; docker inspect"
	docker save $1 > $tmp/img.tar || die "Failed; docker save"

	local l
	for l in $(tar tf $tmp/img.tar | grep layer.tar); do
		echo "=== Layer; $l"
		tar -xOf $tmp/img.tar $l | tar t
	done
}

cmd_docker_save_layers() {
	test -n "$1" || die "No image"
	test -n "$2" || die "No layer"
	mkdir -p $tmp/files
	docker inspect "$1" > $tmp/out || die "Failed; docker inspect"
	docker save $1 > $tmp/img.tar || die "Failed; docker save"
	shift
	cd $tmp/files
	local l
	for l in $@; do
		tar -xOf $tmp/img.tar $l | tar x
	done
	tar c .
	cd
	rm -rf $tmp
}

##   lreg_ls
##     List the contents of the local registry.
cmd_lreg_ls() {
	local regip=$(cmd_get_regip) || return 1
	local i
	for i in $(curl -s -X GET http://$regip:5000/v2/_catalog | jq -r .repositories[]); do
		echo "$i:"
		echo -n "  "
		curl -s -X GET http://$regip:5000/v2/$i/tags/list | jq -c .tags
	done

}
cmd_docker_lsreg() {
	cmd_lreg_ls
}
##   lreg_cache <external-image>
##     Copy the image to the private registry. If this fails try "docker pull"
##     and then "images lreg_upload ...". Example;
##       images lreg_cache docker.io/library/alpine:3.8
cmd_lreg_cache() {
	test -n "$1" || die "No image"
	local host=$(echo $1 | cut -d/ -f1)
	nslookup $host > /dev/null 2>&1 || die "Unknown host [$host]"
	local img=$(echo $1 | cut -d/ -f2-)
	local regip=$(cmd_get_regip) || return 1
	skopeo copy --dest-tls-verify=false docker://$1 docker://$regip:5000/$img
}
##   lreg_upload [--strip-host] <docker_image>
##     Upload an image from you local docker daemon to the privare registry.
##     Note that "docker.io" and "library/" is suppressed in "docker images";
##       lreg_upload library/alpine:3.8
##       lreg_upload --strip-host docker.io/library/alpine:3.8
cmd_lreg_upload() {
	test -n "$1" || die "No image"
	local regip=$(cmd_get_regip) || return 1
	local dst="$1"
	test "$__strip_host" = "yes" && dst=$(echo "$1" | cut -d/ -f2-)
	skopeo copy --dest-tls-verify=false docker-daemon:$1 docker://$regip:5000/$dst
	return 0
}
##   lreg_inspect <image:tag>
##     Inspect an image in the private registry.
cmd_lreg_inspect() {
	test -n "$1" || die "No image"
	local regip=$(cmd_get_regip) || return 1
	skopeo inspect --tls-verify=false docker://$regip:5000/$1
	return 0
}
##   lreg_rm <image:tag>
##     Copy the image to the private registry.
cmd_lreg_rm() {
	test -n "$1" || die "No image"
	local regip=$(cmd_get_regip) || return 1
	skopeo delete --tls-verify=false docker://$regip:5000/$1
	return 0
}
##
cmd_get_regip() {
	local regip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry)
	test -n "$regip" || die "Can't get address of the local registry"
	echo $regip
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

##   mkimage [--manifest=manifest] [--force] [--upload] [--strip-host] [--tag=] <dir>
##     Create an image in local docker from the <dir>. An executable
##     "tar" script must exist in the directory. '--upload' uploads
##     to a *local* private docker registry.
##
cmd_mkimage() {
	test -n "$1" || die "No <dir>"
	test -d "$1" || die "Not a directory [$1]"
	test -x "$1/tar" || die "Not executable [$1/tar]"
	test -n "$__manifest" || __manifest="$(readlink -f $1)/manifest.json"

	if test -r "$1/Dockerfile"; then
		mkimage_dockerfile $1
		return
	fi

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
		cmd_lreg_upload $n:$v || die "Upload failed"
	fi
	echo "$n:$v"
}
mkimage_dockerfile() {
	test -n "$__tag" || die "No --tag specified"
	mkdir -p $tmp/ovl
	$1/tar $tmp/ovl/ovl.tar || die "Failed to create ovl.tar"
	docker build -t $__tag -f "$(readlink -f $1)/Dockerfile" $tmp/ovl \
		|| die "Failed to build $__tag"
	if test "$__upload" = "yes"; then
		cmd_lreg_upload $__tag || die "Upload failed"
	fi
	echo "$__tag"
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
