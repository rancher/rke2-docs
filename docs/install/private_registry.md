---
title: "Private Registry Configuration"
---

Containerd can be configured to connect to private registries and use them to pull private images on each node.

Upon startup, RKE2 will check to see if a `registries.yaml` file exists at `/etc/rancher/rke2/` and instruct containerd to use any registries defined in the file. If you wish to use a private registry, then you will need to create this file as root on each node that will be using the registry.

Note that server nodes are schedulable by default. If you have not tainted the server nodes and will be running workloads on them, please ensure you also create the `registries.yaml` file on each server as well.

Configuration in containerd can be used to connect to a private registry with a TLS connection and with registries that enable authentication as well. The following section will explain the `registries.yaml` file and give different examples of using private registry configuration in RKE2.

## Default Endpoint Fallback

Containerd has an implicit "default endpoint" for all registries.
The default endpoint is always tried as a last resort, even if there are other endpoints listed for that registry in `registries.yaml`.
Rewrites are not applied to pulls against the default endpoint.
For example, when pulling `registry.example.com:5000/rancher/mirrored-pause:3.6`, containerd will use a default endpoint of `https://registry.example.com:5000/v2`.
* The default endpoint for `docker.io` is `https://index.docker.io/v2`.  
* The default endpoint for all other registries is `https://<REGISTRY>/v2`, where `<REGISTRY>` is the registry hostname and optional port.  

In order to be recognized as a registry, the first component of the image name must contain at least one period or colon.
For historical reasons, images without a registry specified in their name are implicitly identified as being from `docker.io`.

:::info Version Gate
The `disable-default-registry-endpoint` option is available as an experimental feature as of February 2024 releases: v1.26.13+rke2r1, v1.27.10+rke2r1, v1.28.6+rke2r1, v1.29.1+rke2r1
:::

Nodes may be configured with the `disable-default-registry-endpoint: true` option.
When this is set, containerd will not fall back to the default registry endpoint, and will only pull from configured mirror endpoints,
along with the distributed registry if it is enabled.

This may be desired if your cluster is in a true air-gapped environment where the upstream registry is not available,
or if you wish to have only some nodes pull from the upstream registry.

Disabling the default registry endpoint applies only to registries configured via `registries.yaml`.
If the registry is not explicitly configured via mirror entry in `registries.yaml`, the default fallback behavior will still be used.


## Registries Configuration File

The file consists of two main sections:

- mirrors
- configs

### Mirrors

Mirrors is a directive that defines the names and endpoints of the private registries. Private registries can be used as a local mirror for the default docker.io registry, or for images where the registry is explicitly specified in the name.

For example, the following configuration would pull from the private registry at `https://registry.example.com:5000` for both `library/busybox:latest` and `registry.example.com/library/busybox:latest`:

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
  registry.example.com:
    endpoint:
      - "https://registry.example.com:5000"
```

Each mirror must have a name and set of endpoints. When pulling an image from a registry, containerd will try these endpoint URLs one by one, and use the first working one.

**Note:** If no endpoint is configured, containerd assumes that the registry can be accessed anonymously via HTTPS on port 443, and is using a certificate trusted by the host operating system. For more information, you may [consult the containerd documentation](https://github.com/containerd/containerd/blob/master/docs/cri/registry.md#configure-registry-endpoint).

#### Rewrites

Each mirror can have a set of rewrites, which use regular expressions to match and transform the name of an image when it is pulled from that mirror. This is useful if the organization/project structure in the mirror registry is different to the upstream one.

For example, the following configuration would transparently pull the image `rancher/rke2-runtime:v1.23.5-rke2r1` from `registry.example.com:5000/mirrorproject/rancher-images/rke2-runtime:v1.23.5-rke2r1`:

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
    rewrite:
      "^rancher/(.*)": "mirrorproject/rancher-images/$1"
```


Note that when using mirrors and rewrites, images will still be stored under the original name.
For example, `crictl image ls` will show `docker.io/rancher/rke2-runtime:v1.23.5-rke2r1` as available on the node, even if the image was pulled from a mirror with a different name.

:::info Version Gate
Rewrites are no longer applied to the Default Endpoint as of the February 2024 releases: v1.26.13+rke2r1, v1.27.10+rke2r1, v1.28.6+rke2r1, v1.29.1+rke2r1
Prior to these releases, rewrites were also applied to the default endpoint, which would prevent RKE2 from pulling from the upstream registry if the image could not be pulled from a mirror endpoint, and the image was not available under the modified name in the upstream.
:::

If you want to apply rewrites when pulling directly from a registry - when it is not being used as a mirror for a different upstream registry - you must provide a mirror endpoint that does not match the default endpoint.
Mirror endpoints in `registries.yaml` that match the default endpoint are ignored; the default endpoint is always tried last with no rewrites, if fallback has not been disabled.

For example, if you have a registry at `https://registry.example.com/`, and want to apply rewrites when explicitly pulling `registry.example.com/rancher/rke2-runtime:v1.23.5-rke2r1`, you can add a mirror endpoint with the port listed.
Because the mirror endpoint does not match the default endpoint - **`"https://registry.example.com:443/v2" != "https://registry.example.com/v2"`** - the endpoint is accepted as a mirror and rewrites are applied, despite it being effectively the same as the default.

```yaml
mirrors:
 registry.example.com
   endpoint:
     - "https://registry.example.com:443"
   rewrites:
     "^rancher/(.*)": "mirrorproject/rancher-images/$1"
```

### Configs

The configs section defines the TLS and credential configuration for each mirror. For each mirror you can define `auth` and/or `tls`. The TLS part consists of:

Directive | Description
----------|------------
`cert_file` | The client certificate path that will be used to authenticate with the registry
`key_file` | The client key path that will be used to authenticate with the registry
`ca_file` | Defines the CA certificate path to be used to verify the registry's server cert file
`insecure_skip_verify` | Boolean that defines if TLS verification should be skipped for the registry

The credentials consist of either username/password or authentication token:

- username: user name of the private registry basic auth
- password: user password of the private registry basic auth
- auth: authentication token of the private registry basic auth

Below are basic examples of using private registries in different modes:

### With TLS

Below are examples showing how you may configure `/etc/rancher/rke2/registries.yaml` on each node when using TLS.

*With Authentication:*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    auth:
      username: xxxxxx # this is the registry username
      password: xxxxxx # this is the registry password
    tls:
      cert_file:            # path to the cert file used to authenticate to the registry
      key_file:             # path to the key file for the certificate used to authenticate to the registry
      ca_file:              # path to the ca file used to verify the registry's certificate
      insecure_skip_verify: # may be set to true to skip verifying the registry's certificate
```

*Without Authentication:*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    tls:
      cert_file:            # path to the cert file used to authenticate to the registry
      key_file:             # path to the key file for the certificate used to authenticate to the registry
      ca_file:              # path to the ca file used to verify the registry's certificate
      insecure_skip_verify: # may be set to true to skip verifying the registry's certificate
```

### Without TLS

Below are examples showing how you may configure `/etc/rancher/rke2/registries.yaml` on each node when _not_ using TLS.

*Plaintext HTTP With Authentication:*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    auth:
      username: xxxxxx # this is the registry username
      password: xxxxxx # this is the registry password
```

*Plaintext HTTP Without Authentication:*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry.example.com:5000"
```

> If using a registry using plaintext HTTP without TLS, you need to specify `http://` as the endpoint URI scheme, otherwise it will default to `https://`.

In order for the registry changes to take effect, you need to either configure this file before starting RKE2 on the node, or restart RKE2 on each configured node.
