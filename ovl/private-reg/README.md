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
docker run -d --restart=always --name registry \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true registry:2
# Get the address to the registry;
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry
# Stop (if you want);
docker container stop registry
docker container rm -v registry
```

### Ipv6

Read the Docker
[documentation](https://docs.docker.com/v17.09/engine/userguide/networking/default_network/ipv6/).

Enable ipv6 for Docker;

```
# cat /etc/docker/daemon.json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:2008::/64"
}
# systemctl reload docker
```

Inspect the assigned ipv6 address;
```
docker inspect -f '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' registry
```

## Usage

```
xc mkcdrom [other overlays...] private-reg; xc start
```

**Note**; A standard docker installation is assumed. Please
investigate the `tar` script in this ovl directory if you get problems.

## Support in the images script

There is support for building local images and for maintenance of your
private registry in the `images` script;

```
# In your ovl with an ./image;
images mkimage --force --upload ./image
# List files in an image;
images docker_ls nordixorg/ctraffic:v0.2
```

From the `images` help printout;
```
   lreg_ls
     List the contents of the local registry.
   lreg_cache <external-image>
     Copy the image to the private registry.
     Example;
       images lreg_cache docker.io/library/alpine:3.8
   lreg_inspect <image:tag>
     Inspect an image in the private registry.
   lreg_rm <image:tag>
     Copy the image to the private registry.
```


## Manage your private registry manually

There are ways by using `docker` but IMO `skopeo` is simpler and more
intuitive.

The simplest way is to go through the local docker-daemon;

```
skopeo copy --dest-tls-verify=false docker-daemon:library/alpine:3.8 docker://172.17.0.2:5000/library/alpine:3.8
skopeo inspect --tls-verify=false docker://172.17.0.2:5000/library/alpine:3.8
```

You can also load directly from a public docker registry, please see
`man skopeo`.


### List contents

```
regip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' registry)
curl -X GET http://$regip:5000/v2/_catalog
# Tags for an image;
curl -X GET http://$regip:5000/v2/library/alpine/tags/list
curl -s -X GET http://$regip:5000/v2/library/alpine/tags/list | jq .
```



## DNS spoofing

If you have manifests with fully qualified image references, that is
it includes the registry host, you can "trick" the image pulling to
use your local registry anyway.

Firsts you must start a docker registry on the standard port. Assuming
you don't have a local http server running, do;

```
# Stop the old registry (if necessary);
docker container stop registry
docker container rm -v registry
# Start with port forwarding on port 80;
docker run -d --restart=always -p 80:5000 --name registry registry:2
```

Then add the domain name (DN) for the host in the `/etc/hosts`
file. The simplest way is to edit the `tar` script in this ovl
dir. The `example.com` is already added.

Load your private registry with `skopeo` as described above and test
on cluster with;

```
crictl --runtime-endpoint=unix:///var/run/crio/crio.sock pull example.com/metallb:0.7.3
```


## Cri-o configuration

Here is a snipplet from `/etc/crio/crio.conf` to configure a local
private registry. Since the local registry comes before the default
`docker.io` it will function as a cache.

```
# insecure_registries is used to skip TLS verification when pulling images.
insecure_registries = [
 "172.17.0.2/16"
]

# registries is used to specify a comma separated list of registries to be used
# when pulling an unqualified image (e.g. fedora:rawhide).
registries = [
 "172.17.0.2:5000",
 "docker.io"
]
```
