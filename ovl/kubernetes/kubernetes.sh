#! /bin/sh
##
## kubernetes.sh --
##
##   Help script for the "kubernetes" xcluster ovl.
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$
hook=${HOOKD:-$HOME/lib}/$prg.hook

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

##   ca
##     Generate cerificates
##
cmd_ca() {
	mkdir -p $tmp
	cd $tmp
	openssl genrsa -out ca-key.pem 2048
	openssl req -x509 -new -nodes -key ca-key.pem -days 10000 \
	   -out ca.pem -subj "/CN=kube-ca"
	openssl genrsa -out apiserver-key.pem 2048
	openssl req -new -key apiserver-key.pem -out apiserver.csr \
	-subj "/CN=kube-apiserver" -config $dir/openssl.cfg
	openssl x509 -req -in apiserver.csr -CA ca.pem \
		-CAkey ca-key.pem -CAcreateserial \
		-out apiserver.pem -days 7200 -extensions v3_req \
		-extfile $dir/openssl.cfg
	ls $tmp

	local d=$dir/default/srv/kubernetes
	cp apiserver.pem $d/server.crt
	cp apiserver-key.pem $d/server.key
	cp ca.pem $d
}

##   runc_download
##
cmd_runc_download() {
	local runc=$ARCHIVE/runc.amd64
	test -x $runc && return 0
	local ver=v1.0.0-rc5
	local url=https://github.com/opencontainers/runc/releases/download
	curl -L $url/$ver/runc.amd64 > $runc
	chmod a+x $runc
	strip $runc
	ls -lh $runc >&2
}

# Check the hook
if test -r $hook; then
	. $hook
else
	hook=''
fi

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
