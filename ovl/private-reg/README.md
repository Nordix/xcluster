# Load images from a private docker registry

You can use a local, private, insecure docker registry for downloading
images to `xcluster`. This is almost as fast as pre-pulled images and
*way* faster than downloading from internet (especially on mobile
network).

Useful for;

 * Cache images for faster and safer download

 * Use own versions of images without altering manifests

 * Load your own private images

You can read more about deploying a private registry in the
[docker documentation](https://distribution.github.io/distribution/).


Include `ovl/private-reg` to use a private docker registry. Do:
```
export XOVLS=private-reg
```
to use it in all test-scripts.


## Host spoofing

You can "trick" the image pulling to use your local registry by
translating registry hostnames, such as "docker.io", to the address of
your private registry. In `xcluster` that is done by altering
`/etc/hosts`:

```
# (on a VM)
# cat /etc/hosts
...
172.17.0.2 docker.io
172.17.0.2 registry-1.docker.io
172.17.0.2 k8s.gcr.io
...
```

For this to work you must start the registry on the standard port,
which is `80` for an insecure registry.

The spoofed hosts are listed in a file pointed out by the
`$__dns_spoof` variable (default set in Envsettings.k8s):
```
# cat $__dns_spoof
docker.io
registry-1.docker.io
k8s.gcr.io
...
```

## Start a local docker registry

```
docker run -d --restart=always --name registry \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -e REGISTRY_HTTP_ADDR=:80 registry:2
# Get the address to the registry;
docker inspect registry | jq  -r .[0].NetworkSettings.IPAddress
# Stop (if you want);
docker container stop registry; docker container rm -v registry
```

## Manage images

The easiest way to manage images in the private registry is to use the
`image` alias (see [ovl/images](../images)):
```
# images | grep '^   lreg_'
   lreg_ls
   lreg_cache <external-image>
   lreg_upload [--include-host] <docker_image>
   lreg_inspect <image:tag>
   lreg_rm <image:tag>
   lreg_isloaded <image:tag>
   lreg_missingimages <dir/ovl>
   lreg_preload [--force] [--keep-going] <dir/ovl>
```

It uses the [skopeo](../skopeo) utility, which must be [installed](
https://github.com/containers/skopeo/blob/main/install.md) or built
locally.

To run the basic tests with a local registry:
```
images lreg_preload kubernetes mconnect
cdo test-template
export XOVLS=private-reg
./test-template.sh test basic > /dev/null
```


### Ipv6

Read the [Docker documentation](https://docs.docker.com/config/daemon/ipv6/).

Enable ipv6 for Docker;

```
# cat /etc/docker/daemon.json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:2008::/64"
}
# systemctl reload docker
```

Override the local registry IP with the IPv6 one:
```
export LOCAL_REGISTRY=$(docker inspect registry | jq -r .[0].NetworkSettings.GlobalIPv6Address)
```

Start a xcluster and verify that "example.com" is reachable, and is an
IPv6 address:
```
# ping -W1 -c1 -q example.com
PING example.com(example.com (fd00:8000::242:ac11:2)) 56 data bytes

--- example.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.601/0.601/0.601/0.000 ms
```


##  Secure registry

This is not used, or tested recently, but kept for documentation.
```
certd=$XCLUSTER_WORKSPACE/cert
openssl genrsa -out $certd/docker.key 2048
openssl req -new -x509 -sha256 -key $certd/docker.key -out $certd/dockercrt -days 3650

sudo docker run -d --restart=always --name registry \
  -v $certd:/certs \
  -e REGISTRY_HTTP_ADDR=:443 registry:2
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/docker.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/docker.key \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2
```

