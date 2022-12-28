#! /bin/sh
##
## multus-installer.sh --
##
##
## Commands;
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
tmp=/tmp/${prg}_$$

##   env
##     Print environment.
cmd_env() {
	test -n "$__multus_ver" || __multus_ver=unknown
	test -n "$__cnibin_ver" || __cnibin_ver=unknown

    if test "$cmd" = "env"; then
        set | grep -E '^(__.*)='
        return 0
    fi
}

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

##   install_binaries [--dest=/opt/cni/bin]
##     Install multus and cni-bin
cmd_install_binaries() {
	cmd_env
	test -n "$__dest" || __dest=/opt/cni/bin
	echo "Installing cni-bin:$__cnibin_ver and multus:$__multus_ver in $__dest"
	test -d $__dest || die "Not a directory [$__dest]"
	local ar=multus-cni_${__multus_ver}_linux_amd64.tar.gz
	test -r "$dir/$ar" || die "Not readable [$ar]"
	tar -C $__dest --strip-components=1 -xf $dir/$ar multus-cni_${__multus_ver}_linux_amd64/multus-cni
	ar=cni-plugins-linux-amd64-${__cnibin_ver}.tgz
	test -r "$dir/$ar" || die "Not readable [$ar]"
	tar -C $__dest -xf $dir/$ar

	local f
	for f in whereabouts node-annotation sriov; do
		test -x $dir/$f && cp $dir/$f $__dest
	done
}

##   enable
##     Enable Multus on the local node. Modifies /etc/cni
cmd_enable() {
	cmd_env
	test -d /etc/cni || die "Not a directory [/etc/cni]"
	mkdir -p /etc/cni/multus/net.d/
	local f=$(find /etc/cni/net.d -maxdepth 1 -type f | sort | head -1)
	test -n "$f" || die "Not network config found"
	if echo $f | grep -q multus; then
		log "Multus already enabled"
		return 0
	fi
	local ext=conf
	echo $f | grep -q conflist && ext=conflist
	local net=$(cat $f | jq -r .name)
	log "Current net config; $f, net=$net"
	mv $f /etc/cni/multus/net.d/$net.$ext
    cat > /etc/cni/net.d/10-multus.conf <<EOF
{
    "cniVersion": "0.4.0",
    "name": "multus",
    "type": "multus-cni",
    "logFile": "/var/log/multus.log",
    "logLevel": "debug",
    "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig",
    "confDir": "/etc/cni/multus/net.d",
    "cniDir": "/var/lib/cni/multus",
    "binDir": "/opt/cni/bin",
    "clusterNetwork": "$net",
        "defaultNetworks": []
}
EOF
	export KUBECONFIG=/etc/cni/net.d/multus.d/multus.kubeconfig
	cat > /tmp/nad.yaml <<EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  namespace: kube-system
  name: $net
EOF
	local now start=$(date +%s)
	while ! kubectl apply -f /tmp/nad.yaml; do
		now=$(date +%s)
		test $((now - start)) -gt 10 && die "Load NAD"
		sleep 1
	done
	log "Multus enabled"
}

##   generate_kubeconfig [--path=/etc/cni/net.d/multus.d/multus.kubeconfig]
##     Generate a kubeconfig file
cmd_generate_kubeconfig() {
	# Seems to originate from;
	# https://github.com/projectcalico/cni-plugin/blob/be4df4db2e47aa7378b1bdf6933724bac1f348d0/k8s-install/scripts/install-cni.sh#L104-L153
	test -n "$__path" || __path=/etc/cni/net.d/multus.d/multus.kubeconfig
	log "Generate; $__path"
	mkdir -p $(dirname $__path) || die "mkdir $(dirname $__path)"
	local sa=/var/run/secrets/kubernetes.io/serviceaccount
	KUBE_CA_FILE=$sa/ca.crt
	SKIP_TLS_VERIFY=false
	# Pull out service account token.
	SERVICEACCOUNT_TOKEN=$(cat $sa/token)

  test -f "$KUBE_CA_FILE" && \
      TLS_CFG="certificate-authority-data: $(cat $KUBE_CA_FILE | base64 | tr -d '\n')"

  # Write a kubeconfig file for the CNI plugin.  Do this
  # to skip TLS verification for now.  We should eventually support
  # writing more complete kubeconfig files. This is only used
  # if the provided CNI network config references it.
  cat > $__path <<EOF
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
    $TLS_CFG
users:
- name: multus
  user:
    token: "${SERVICEACCOUNT_TOKEN}"
contexts:
- name: multus-context
  context:
    cluster: local
    user: multus
current-context: multus-context
EOF
}

##   install
##     Install and enable multus and cni-plugins
cmd_install() {
	if test -r /opt/cni/bin/sentinel; then
		if cmp -s $dir/sentinel /opt/cni/bin/sentinel; then
			log "Multus already installed"
			cat $dir/sentinel >&2
			return 0
		fi
	fi
	log "Installing Multus..."
	cmd_install_binaries
	cmd_generate_kubeconfig
	cmd_enable
	cp $dir/sentinel /opt/cni/bin/sentinel
	log "Multus installed"
}


##
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
