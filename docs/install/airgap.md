---
title: Air-Gap Install
---

RKE2 can be installed in an air-gapped environment with two different methods. You can either deploy images via the [rke2-airgap-images tarball release artifact](#manually-deploy-images-method-tarball) or by using a [private registry](#private-registry-method). It is also possible to use the [embedded registry mirror](#embedded-registry-mirror) as long as there is at least one cluster member that has access to the required images.

## Load images

### Manually deploy images Method (Tarball)

This method requires you to manually deploy the necessary images to each node, and is appropriate for edge deployments where running a private registry is not practical.

#### Prepare the Images Directory and Airgap Image Tarball

1. Obtain the images archive for your architecture from the [releases page](https://github.com/rancher/rke2/releases) for the version of RKE2 you will be running:
    * Use `rke2-images.linux-amd64.tar.zst` or `rke2-images.linux-amd64.tar.gz`. Zstandard offers better compression ratios and faster decompression speeds compared to gzip.
    * If using the default Canal CNI (`--cni=canal`), you can use either the `rke2-image` legacy archive as described above, or `rke2-images-core` and `rke2-images-canal` archives.
    * If using the alternative Cilium CNI (`--cni=cilium`), you must download the `rke2-images-core` and `rke2-images-cilium` archives instead.
    * If using your own CNI (`--cni=none`), you can download only the `rke2-images-core` archive.
    * If enabling the vSphere CPI/CSI charts (`--cloud-provider-name=rancher-vsphere`), you must also download the `rke2-images-vsphere` archive.
2. Ensure that the `/var/lib/rancher/rke2/agent/images/` directory exists on the node.
3. Copy the compressed archive to `/var/lib/rancher/rke2/agent/images/` on the node, ensuring that the file extension is retained.
4. [Install RKE2](#install-rke2)

#### Enable Conditional Image Imports

:::info Version Gate
Conditional Image imports is available as of the May 2025 releases:
v1.33.1+rke2r1, v1.32.5+rke2r1, v1.31.9+rke2r1, v1.30.13+rke2r1
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


### Private Registry Method
Private registry support honors all settings from the [containerd registry configuration](private_registry.md). This includes endpoint override and transport protocol (HTTP/HTTPS), authentication, certificate verification, etc.

1. Add all the required system images to your private registry. A list of images can be obtained from the `.txt` file corresponding to each tarball referenced above, or you may `docker load` the airgap image tarballs, then tag and push the loaded images.
2. [Install RKE2](#install-rke2) using the `system-default-registry` parameter, or use the [containerd registry configuration](private_registry.md) to use your registry as a mirror for docker.io.

### Embedded Registry Mirror

RKE2 includes an embedded distributed OCI-compliant registry mirror.
When enabled and properly configured, images available in the containerd image store on any node
can be pulled by other cluster members without access to an external image registry.

The mirrored images may be sourced from an upstream registry, registry mirror, or airgap image tarball.
For more information on enabling the embedded distributed registry mirror, see the [Embedded Registry Mirror](./registry_mirror.md) documentation.

## Install RKE2

### Prerequisites

:::warning
If your node has NetworkManager installed and enabled, [ensure that it is configured to ignore CNI-managed interfaces.](../known_issues.md#networkmanager)
:::

The following options to install RKE2 should only be performed after completing one of either the [Tarball Method](#manually-deploy-images-method-tarball) or [Private Registry Method](#private-registry-method).

#### Default Network Route

If your nodes do not have an interface with a default route, a default route must be configured; even a black-hole route via a dummy interface will suffice. RKE2 requires a default route in order to auto-detect the node's primary IP, and for kube-proxy ClusterIP routing to function properly. To add a dummy route, do the following:
  ```
  ip link add dummy0 type dummy
  ip link set dummy0 up
  ip addr add 203.0.113.254/31 dev dummy0
  ip route add default via 203.0.113.255 dev dummy0 metric 1000
  ```


#### SELinux RPM

If running on an air-gapped node with SELinux enabled, you must manually install the rke2-selinux RPM before installing RKE2. This RPM includes the necessary SELinux policies for RKE2 to run properly. See our [RPM Documentation](https://docs.rke2.io/install/methods#rpm) to learn how to obtain the rpm. The rke2-selinux RPM installation requires the following dependencies to be available in the OS:  
    * container-selinux
    * iptables-nft
    * libnftnl
    * policycoreutils
    * selinux-policy


### Installing RKE2 in an Air-Gapped environment

#### RKE2 Binary Install

1. Obtain the rke2 binary file `rke2.linux-amd64`.
2. Ensure the binary is named `rke2` and place it in `/usr/local/bin`. Ensure it is executable.
3. Run the binary with the desired parameters. For example, if using the Private Registry Method, your config file would have the following:

```yaml
system-default-registry: "registry.example.com:5000"
```

**Note:** The `system-default-registry` parameter must specify only valid RFC 3986 URI authorities, i.e. a host and optional port.

#### RKE2 Install.sh Script Install

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


## Upgrading

### Manual Upgrade Method

Upgrading an air-gap environment can be accomplished in the following manner:

1. Download the new air-gap images (tar files) from the [releases](https://github.com/rancher/rke2/releases) page for the version of RKE2 you will be upgrading to. Place the tar in the `/var/lib/rancher/rke2/agent/images/` directory on each node. Delete the old tar files.
2. Follow the steps of the [manual upgrade method](../upgrades/manual_upgrade.md#manually-upgrade-rke2-using-the-binary)


### Automated Upgrades Method

RKE2 supports [automated upgrades](../upgrades/automated_upgrade.md). To enable this in air-gapped environments, you must ensure the required images are available in your private registry.

You will need the version of rancher/rke2-upgrade that corresponds to the version of RKE2 you intend to upgrade to. Note, the image tag replaces the `+` in the RKE2 release with a `-` because Docker images do not support `+`.

You will also need the versions of system-upgrade-controller and kubectl that are specified in the system-upgrade-controller manifest YAML that you will deploy. Check for the latest release of the system-upgrade-controller [here](https://github.com/rancher/system-upgrade-controller/releases/latest) and download the system-upgrade-controller.yaml to determine the versions you need to push to your private registry. For example, in release v0.4.0 of the system-upgrade-controller, these images are specified in the manifest YAML:

```
rancher/system-upgrade-controller:v0.4.0
rancher/kubectl:v0.17.0
```

Once you have added the necessary rancher/rke2-upgrade, rancher/system-upgrade-controller, and rancher/kubectl images to your private registry, follow the [automated upgrades](../upgrades/automated_upgrade.md) guide.