export KUBECONFIG=/etc/kubernetes/kubeconfig
alias images="crictl --runtime-endpoint=unix:///var/run/crio/crio.sock images"
