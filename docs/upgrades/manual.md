---
title: Manual Upgrades
---


You can upgrade RKE2 by using the installation script, by manually installing the binary of the desired version, or by using rpm upgrades in case of rpm installation.

:::tip
Upgrade the server nodes first, one at a time. Once all servers have been upgraded, you may then upgrade agent nodes.
:::

## Release Channels

Upgrades performed via the installation script or using our [automated upgrades](automated.md) feature can be tied to different release channels. The following channels are available:

| Channel         |   Description  |
|-----------------|---------|
| stable          | (Default) Stable is recommended for production environments. These releases have been through a period of community hardening, and are compatible with the most recent release of Rancher. |
| latest          | Latest is recommended for trying out the latest features.  These releases have not yet been through a period of community hardening, and may not be compatible with Rancher. |
| v1.26 (example) | There is a release channel tied to each Kubernetes minor version, including versions that are end-of-life. These channels will select the latest patch available, not necessarily a stable release. |

For an exhaustive and up-to-date list of channels, you can visit the [rke2 channel service API](https://update.rke2.io/v1-release/channels). For more technical details on how channels work, you can see the [channelserver project](https://github.com/rancher/channelserver).

:::warning
When attempting to upgrade to a new version of RKE2, the [Kubernetes version skew policy](https://kubernetes.io/docs/setup/release/version-skew-policy/) applies. Ensure that your plan does not skip intermediate minor versions when upgrading. Nothing in the upgrade process will protect against unsupported changes to the Kubernetes version.
:::


## Upgrade RKE2 Using the Installation Script

To upgrade RKE2 from an older version you can re-run the installation script using the same flags, for example:

```sh
curl -sfL https://get.rke2.io | sh -
```
This will upgrade to the most recent version in the stable channel by default.

If upgrading agent nodes, you should specify the `INSTALL_RKE2_TYPE` environment variable:
```sh
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -
```

If you want to upgrade to the most recent version in a specific channel (such as latest) you can specify the channel:
```sh
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=latest sh -
```

If you want to upgrade to a specific version you can run the following command:

```sh
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vX.Y.Z+rke2rN sh -
```

Remember to restart the rke2 process after installing:

```sh
# Server nodes:
systemctl restart rke2-server

# Agent nodes:
systemctl restart rke2-agent
```

## Manually Upgrade RKE2 Using the Binary

Or to manually upgrade RKE2:

1. Download the desired version of the rke2 binary from [releases](https://github.com/rancher/rke2/releases)
2. Copy the downloaded binary to `/usr/local/bin/rke2` for tarball installed rke2, and `/usr/bin` for rpm installed rke2
3. Restart the rke2-server or rke2-agent service

## Upgrade RKE2 Using the RPM upgrades

In case of RPM installation, its expected to upgrade RKE2 from an older version using rpm upgrades, for example:

```sh
# zypper upgrade
zypper update rke2-server
```

```sh
yum update rke2-server
```
This will upgrade `rke2-server` rpm package to the latest package in your channel which is configured initially in the yum or zypper repos by the install script at the initial installation.

If upgrading agent nodes, you should specify name of the `rke2-agent` package

```sh
# zypper upgrade
zypper update rke2-agent
```

```sh
# yum upgrade
yum update rke2-agent
```

Remember to restart the rke2 process after installing:

```sh
# Server nodes:
systemctl restart rke2-server

# Agent nodes:
systemctl restart rke2-agent
```

:::note
In case you enabled `rke2-selinux` you should also be able to upgrade rke2-selinux to the latest version using:
```sh
yum update rke2-selinux
```
:::

## Restarting RKE2

Restarting RKE2 is supported by the installation script for systemd.

**systemd**

To restart servers manually:
```sh
sudo systemctl restart rke2-server
```

To restart agents manually:
```sh
sudo systemctl restart rke2-agent
```
