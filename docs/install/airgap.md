---
title: Air-Gap Install
---

This guide walks you through installing RKE2 in an air-gapped environment using a three-step process.


## 1. Load Images

Each image loading method has different requirements and is suited for different air-gapped scenarios. Choose the method that best fits your infrastructure and security requirements.

<Tabs queryString="airgap-load-images">
<TabItem value="Private Registry Method">

These steps assume you have already created nodes in your air-gap environment, are using the bundled containerd as the container runtime, and have a OCI-compliant private registry available in your environment.

If you have not yet set up a private Docker registry, refer to the [official Registry documentation](https://distribution.github.io/distribution/about/deploying/#run-an-externally-accessible-registry).

#### Create the Registry YAML and Push Images

1. Obtain the images archive for your architecture from the [releases](https://github.com/rancher/rke2/releases) page for the version of RKE2 you will be running.
2. Assuming amd64, use `docker image load rke2-images.linux-amd64.tar.zst` to import images from the tar file into docker.
3. Use `docker tag` and `docker push` to retag and push the loaded images to your private registry.
4. Follow the [Private Registry Configuration](private_registry.md) guide to create and configure the `registries.yaml` file.
5. Proceed to the [Install RKE2](#2-install-rke2) section below.

:::info CNI plugins and vsphere extra images
`rke2-images.linux-amd64.tar.zst` includes images for Canal CNI plugin. As an alternative, you can load `rke2-images-core.linux-amd64.tar.zst` and the CNI plugin specific tarball, e.g. `rke2-images-cilium.linux-amd64.tar.zst` for Cilium. If enabling the vSphere CPI/CSI charts (--cloud-provider-name=rancher-vsphere), you must also load the `rke2-images-vsphere.linux-amd64.tar.zst` archive.
:::

</TabItem>
<TabItem value="Manually Deploy Images">

These steps assume you have already created nodes in your air-gap environment, are using the bundled containerd as the container runtime, and cannot or do not want to use a private registry.

This method requires you to manually deploy the necessary images to each node, and is appropriate for edge deployments where running a private registry is not practical.

#### Prepare the Images Directory and Airgap Image Tarball

1. On internet accessible machine, download the images archive for your architecture from the [releases](https://github.com/rancher/rke2/releases) page for the version of RKE2 you will be running.
```bash
  sudo curl -LO "https://github.com/rancher/rke2/releases/download/v1.33.1%2Brke2r1/rke2-images.linux-amd64.tar.zst"
```

2. Transfer the images tarball to the airgap nodes. Place them in the agent's image directory, for example and assuming amd64:
  ```bash
  sudo mkdir -p /var/lib/rancher/rke2/agent/images/
  sudo cp rke2-images.linux-amd64.tar.zst /var/lib/rancher/rke2/agent/images/rke2-images.linux-amd64.tar.zst"
  ```
3. Proceed to the [Install RKE2](#2-install-rke2) section below.

:::info CNI plugins and vsphere extra images
`rke2-images.linux-amd64.tar.zst` includes images for Canal CNI plugin. As an alternative, you can load `rke2-images-core.linux-amd64.tar.zst` and the CNI plugin specific tarball, e.g. `rke2-images-cilium.linux-amd64.tar.zst` for Cilium. If enabling the vSphere CPI/CSI charts (--cloud-provider-name=rancher-vsphere), you must also load the `rke2-images-vsphere.linux-amd64.tar.zst` archive.
:::


#### Enable Conditional Image Imports

:::info Version Gate
Conditional Image imports is available as of the May 2025 releases: v1.33.1+rke2r1, v1.32.5+rke2r1, v1.31.9+rke2r1, v1.30.13+rke2r1
:::

Image archives are imported every time RKE2 starts. This is done to ensure that all the images are consistently available, even if some images have been removed or pruned since last startup. However, this delays startup as the kubelet is not started until after all archives have been processed. To alleviate this delay there is an option to only import tarballs that have changed since they were last imported, even across restarts.

To enable this feature, create a `.cache.json` file in the images directory:
```bash
touch /var/lib/rancher/rke2/agent/images/.cache.json
```
The cache file will store archive metadata as files are processed. Subsequent restarts of RKE2 will not import the images, as long as the size and modification time of the archive remains the same.

:::warning
When this feature is enabled, it will not be possible to ensure that all images are available every time RKE2 starts. If an image was removed or pruned since last startup, take manual action to reimport the image. Either:
* Manually import the archive with `ctr image import`.
* Use `touch` to modify the timestamp of the archive containing the image.
* Clear the contents of the `.cache.json` file, and restart RKE2.
:::


</TabItem>
<TabItem value="Embedded Registry Mirror">

RKE2 includes an embedded distributed OCI-compliant registry mirror. When enabled and properly configured, images available in the containerd image store on any node
can be pulled by other cluster members without access to an external image registry.

The mirrored images may be sourced from an upstream registry, registry mirror, or airgap image tarball.
For more information on enabling the embedded distributed registry mirror, see the [Embedded Registry Mirror](registry_mirror.md) documentation.

</TabItem>
</Tabs>


## 2. Install RKE2

### Prerequisites

Before installing RKE2, choose one of the [Load Images](#1-load-images) options above to prepopulate the images that RKE2 needs to install.

<details>
<summary>**Default Network Route** - required for nodes without a default route</summary>

#### Default Network Route

If your nodes do not have an interface with a default route, a default route must be configured; even a black-hole route via a dummy interface will suffice. RKE2 requires a default route in order to auto-detect the node's primary IP, and for kube-proxy ClusterIP routing to function properly. To add a dummy route, do the following:
  ```
  ip link add dummy0 type dummy
  ip link set dummy0 up
  ip addr add 203.0.113.254/31 dev dummy0
  ip route add default via 203.0.113.255 dev dummy0 metric 1000
  ```

</details>

<details>
<summary>**SELinux RPM** - required for airgapped nodes with SELinux enabled</summary>

#### SELinux RPM

If running on an air-gapped node with SELinux enabled, you must manually install the rke2-selinux RPM before installing RKE2. This RPM includes the necessary SELinux policies for RKE2 to run properly. See our [RPM Documentation](https://docs.rke2.io/install/methods#rpm) to learn how to obtain the rpm. The rke2-selinux RPM installation requires the following dependencies to be available in the OS:  
    * container-selinux
    * iptables-nft
    * libnftnl
    * policycoreutils
    * selinux-policy

</details>


### Installation

RKE2 in airgap can be installed using the binary or the install script

<Tabs queryString="installation-methods">
<TabItem value="Binary install">

#### Binaries
- Download the RKE2 binary file `rke2.linux-amd64` from the [releases](https://github.com/rancher/rke2/releases) page, matching the same version and architecture used to get the airgap images. Place the binary in `/usr/local/bin` on each air-gapped node and ensure it is executable.
- Run the binary with the desired parameters. For example, if using the Private Registry Method, your config file would have the following:

```yaml
system-default-registry: "registry.example.com:5000"
```

**Note:** The `system-default-registry` parameter must specify only valid RFC 3986 URI authorities, i.e. a host and optional port.

</TabItem>
<TabItem value="Script install">

`install.sh` may be used in an offline mode by setting the `INSTALL_RKE2_ARTIFACT_PATH` variable to a path containing pre-downloaded artifacts. This will run though a normal install, including creating systemd units.

1. Download the install script, rke2, rke2-images, and sha256sum archives from the release into a directory, as in the example below:
```bash
mkdir /root/rke2-artifacts && cd /root/rke2-artifacts/
curl -OLs https://github.com/rancher/rke2/releases/download/v1.33.1%2Brke2r1/rke2-images.linux-amd64.tar.zst
curl -OLs https://github.com/rancher/rke2/releases/download/v1.33.1%2Brke2r1/rke2.linux-amd64.tar.gz
curl -OLs https://github.com/rancher/rke2/releases/download/v1.33.1%2Brke2r1/sha256sum-amd64.txt
curl -sfL https://get.rke2.io --output install.sh
```
2. Next, run install.sh using the directory, as in the example below:
```bash
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh install.sh
```
3. Enable and run the service as outlined [here.](quickstart.md#2-enable-the-rke2-server-service)

</TabItem>
</Tabs>


## 3. Upgrading

<Tabs queryString="airgap-upgrade">
<TabItem value="Manual Upgrade">

Upgrading an air-gap environment can be accomplished in the following manner:

1. Download the new air-gap images (tar files) from the [releases](https://github.com/rancher/rke2/releases) page for the version of RKE2 you will be upgrading to. Place the tar in the `/var/lib/rancher/rke2/agent/images/` directory on each node. Delete the old tar files.
2. Follow the steps of the [manual upgrade method](../upgrades/manual_upgrade.md#manually-upgrade-rke2-using-the-binary)

</TabItem>
<TabItem value="Automated Upgrade">

RKE2 supports [automated upgrades](../upgrades/automated_upgrade.md). To enable this in air-gapped environments, you must ensure the required images are available in your private registry.

You will need the version of rancher/rke2-upgrade that corresponds to the version of RKE2 you intend to upgrade to. Note, the image tag replaces the `+` in the RKE2 release with a `-` because Docker images do not support `+`.

You will also need the versions of system-upgrade-controller and kubectl that are specified in the system-upgrade-controller manifest YAML that you will deploy. Check for the latest release of the system-upgrade-controller [here](https://github.com/rancher/system-upgrade-controller/releases/latest) and download the system-upgrade-controller.yaml to determine the versions you need to push to your private registry. For example, in release v0.15.2 of the system-upgrade-controller, these images are specified in the manifest YAML:

```
rancher/system-upgrade-controller:v0.15.2
rancher/kubectl:v1.30.3
```

Once you have added the necessary rancher/rke2-upgrade, rancher/system-upgrade-controller, and rancher/kubectl images to your private registry, follow the [automated upgrades](../upgrades/automated_upgrade.md) guide.

</TabItem>
</Tabs>
