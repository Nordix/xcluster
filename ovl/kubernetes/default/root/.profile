. /etc/profile
alias images="crictl images"
alias pods="kubectl get pods -o 'custom-columns=NAME:metadata.name,NODE:spec.nodeName,IPs:status.podIPs[*].ip'"
