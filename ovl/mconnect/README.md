# Xcluster ovl - mconnect

- Manifests for [mconnect](https://github.com/Nordix/mconnect)

All manifests are in `default/etc/kubernetes/mconnect`;

* `mconnect.yaml` - DaemonSet and Deployment and non family specific services
  of types `clusterIP`, `loadBalancer` and "headless".

* `single/` - A `PreferDualStack` service for deployment in a
  singe-stack cluster.

* `dual` - Dual-stack services using the "phase 3" API (>=v1.20.0)

* `dual-old` - Dual-stack services using the old API (<v1.20.0)

