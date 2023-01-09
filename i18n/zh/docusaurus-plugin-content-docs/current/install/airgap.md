---
title: 离线安装
---

**重要**：如果你的节点安装并启用了 NetworkManager，请[确保将其配置为忽略 CNI 管理的接口](../known_issues.md#networkmanager)。

你可以使用两种不同的方法在离线环境中安装 RKE2。你可以通过 `rke2-airgap-images` 压缩包发布工件进行部署，也可以使用私有镜像仓库进行部署。

步骤中提到的所有文件都可以从[此处](https://github.com/rancher/rke2/releases)所需 RKE2 版本的 asset 中获取。

如果在启用了 SELinux 的离线节点上运行，则必须在执行这些步骤之前手动安装必要的 SELinux 策略 RPM。请参阅 [RPM 文档](../install/methods.md#rpm) 确定你需要的内容。

如果在运行 SELinux、CentOS 或 RHEL 8 的离线节点上运行并启用 SELinux，则在执行 [RPM 安装](../install/methods.md#rpm)时需要以下依赖项：

    Installing dependencies:
    container-selinux
    iptables
    libnetfilter_conntrack
    libnfnetlink
    libnftnl
    policycoreutils-python-utils
    rke2-common
    rke2-selinux

本文档中列出的所有步骤都必须以 root 用户或通过 `sudo` 运行。

## Tarball 方法

1. 从 RKE release artifacts 列表下载 RKE2 离线镜像 tarball。
   * 对于 v1.20 之前的版本，使用 `rke2-images.linux-amd64.tar.zst` 或 `rke2-images.linux-amd64.tar.gz`。与 gzip 相比，Zstandard 支持更好的压缩比和更快的解压缩速度。
   * 如果使用默认的 Canal CNI (`--cni=canal`)，你可以使用如上所述的 `rke2-image` 旧版存档文件，或者使用 `rke2-images- core` 和 `rke2-images-canal`。
   * 如果使用 Cilium CNI (`--cni=cilium`)，你必须下载 `rke2-images-core` 和 `rke2-images-cilium`。
   * 如果使用你自己的 CNI (`--cni=none`)，则只能下载 `rke2-images-core`。
   * 如果启用 vSphere CPI/CSI Chart (`--cloud-provider-name=rancher-vsphere`)，你还必须下载 `rke2-images-vsphere`。
2. 确保节点上存在 `/var/lib/rancher/rke2/agent/images/` 目录。
3. 将压缩包复制到节点上的`/var/lib/rancher/rke2/agent/images/`，需要保留文件扩展名。
4. [安装 RKE2](#安装-rke2)

## 私有镜像仓库方法
从 RKE2 v1.20 开始，私有镜像仓库支持遵循 [containerd 镜像仓库配置](containerd_registry_configuration.md)中的所有设置。其中包括端点覆盖和传输协议（HTTP/HTTPS）、身份验证、证书验证等。

在 RKE2 v1.20 之前，私有镜像仓库必须使用 TLS，并使用主机 CA 捆绑包信任的证书。如果镜像仓库使用的是自签名证书，你可以使用 `update-ca-certificates` 将证书添加到主机 CA 捆绑包。镜像仓库还必须允许匿名（未经身份验证）访问。

1. 将所有必需的系统镜像添加到你的私有镜像仓库。你可以从与上述每个压缩包对应的 `.txt` 文件中获取镜像列表，也可以对离线镜像压缩包使用 `docker load`，然后标记并推送加载的镜像。
2. 如果在镜像仓库上使用私有或自签名证书，请将镜像仓库的 CA 证书添加到 containerd 镜像仓库配置中，如果使用 v1.20 之前的版本，则添加到操作系统的受信任证书中。
3. 使用 `system-default-registry` 参数[安装 RKE2](#安装-rke2)，或使用 [containerd 镜像仓库配置](containerd_registry_configuration.md)将你的镜像仓库用作 docker.io 的 mirror。

## 安装 RKE2
以下安装 RKE2 的选项只能在完成 [Tarball 方法](#tarball-方法)或[私有镜像仓库方法](#私有镜像仓库方法)之一后执行。

你可以直接运行[二进制文件](#rke2-二进制安装)或使用 [install.sh 脚本](#rke2-installsh-脚本安装)来安装 RKE2。

### RKE2 二进制安装

1. 获取 RKE2 二进制文件 `rke2.linux-amd64`。
2. 确保二进制文件名为 `rke2` 并将其放在 `/usr/local/bin` 中。请确保文件可执行。
3. 使用所需参数运行二进制文件。例如，如果使用私有镜像仓库方法，你的配置文件将具有以下内容：

```yaml
system-default-registry: "registry.example.com:5000"
```

**注意**：`system-default-registry` 参数必须仅指定有效的 RFC 3986 URI 授权，即主机和可选端口。

### RKE2 Install.sh 脚本安装

`install.sh` 可以通过将 `INSTALL_RKE2_ARTIFACT_PATH` 变量设置为包含预下载工件的路径来在离线模式下使用。这将通过正常安装运行，包括创建 systemd 单元。

1. 从 releases 页面将安装脚本、rke2、rke2-images 和 sha256sum 存档下载到一个目录中，如下所示：
```bash
mkdir /root/rke2-artifacts && cd /root/rke2-artifacts/
curl -OLs https://github.com/rancher/rke2/releases/download/v1.21.5%2Brke2r2/rke2-images.linux-amd64.tar.zst
curl -OLs https://github.com/rancher/rke2/releases/download/v1.21.5%2Brke2r2/rke2.linux-amd64.tar.gz
curl -OLs https://github.com/rancher/rke2/releases/download/v1.21.5%2Brke2r2/sha256sum-amd64.txt
curl -sfL https://get.rke2.io --output install.sh
```
2. 接下来，使用该目录运行 install.sh，如下例所示：
```bash
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh install.sh
```
3. 按照[此处](quickstart.md#2-启用-rke2-server-服务)的概述启用并运行该服务。
