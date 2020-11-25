. /etc/profile
alias images="crictl --runtime-endpoint=unix:///var/run/crio/crio.sock images"
alias pods="kubectl get pods -o 'custom-columns=NAME:metadata.name,NODE:spec.nodeName,IPs:status.podIPs[*].ip'"
