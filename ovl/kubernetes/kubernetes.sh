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
	cp ca.pem $d/ca.crt
	cp ca-key.pem $d/ca.key
}

##   kubeconfig_sec
##     Generate secure kubeconfig's
##
cmd_kubeconfig_sec() {
	local cfg=$dir/default/etc/kubernetes/kubeconfig

	export KUBECONFIG=$cfg.token
	cp $cfg $KUBECONFIG
	kubectl config set-cluster xcluster --server=https://192.168.1.1:6443
	kubectl config set-cluster xcluster --insecure-skip-tls-verify=true
	kubectl config set-credentials root --token=kallekula

	# This doesn't work but is kept as reference
	# Unable to connect to the server: x509: certificate signed by unknown authority
	local certd=$dir/default/srv/kubernetes
	export KUBECONFIG=$cfg.sec
	cp $cfg $KUBECONFIG
	kubectl config set-cluster xcluster --server=https://192.168.1.1:6443
	kubectl config set-cluster xcluster --embed-certs=true \
		--certificate-authority=$certd/server.crt
	kubectl config set-credentials root --embed-certs=true \
		--client-certificate=$certd/server.crt --client-key=$certd/server.key
}
##   build
##     Build the k8s binaries
##
cmd_build() {
	local n d=$GOPATH/src/k8s.io/kubernetes
	cd $d
	for n in kube-controller-manager kube-scheduler kube-apiserver \
		kube-proxy kubectl kubelet; do
		make WHAT=cmd/$n || die "Failed to build [$n]"
	done
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
