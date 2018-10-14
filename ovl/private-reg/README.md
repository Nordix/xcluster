# Load images from a private docker registry

You can use a local, private, unsecure docker registry for downloading
images to `xcluster`. This is almost as fast as pre-pulled images and
*way* faster than downloading from internet (especially on mobile
network). Useful for;

 * Cache images for faster and safer download

 * Use own versions of images without altering manifests

 * Load your own private images

You can read more about deploying registries in the
[docker documentation](https://docs.docker.com/registry/deploying/).


## Start a local docker registry

```
# Start (the '-p' option is not necessary)
docker run -d --restart=always --name registry registry:2
# Get the address to the registry;
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry
# Stop (if you want);
docker container stop registry
docker container rm -v registry
```

## Usage

```
xc mkcdrom [other overlays...] private-reg; xc start
```

**Note**; A standard docker installation is assumed. Please
investigate the `tar` script in this ovl directory if you get problems.


## Manage your private registry

There are ways by using `docker` but IMO `skopeo` is simpler and more
intuitive.

The simplest way is to go through the local docker-daemon;

```
skopeo copy --dest-tls-verify=false docker-daemon:library/alpine:3.8 docker://172.17.0.2:5000/library/alpine:3.8
skopeo inspect --tls-verify=false docker://172.17.0.2:5000/library/alpine:3.8
```

You can also load directly from a public docker registry, please see
`man skopeo`.

You can refere to your local images with `example.com`.




kubectl get pods
kubectl apply -f /etc/kubernetes/alpine.yaml
tail -f /tmp/uablrek/coredns.log 


https://github.com/kubernetes-sigs/cri-o/issues/1768
