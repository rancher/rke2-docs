---
title: 安装方法
---

**重要**：如果你的节点安装并启用了 NetworkManager，请[确保将其配置为忽略 CNI 管理的接口](../known_issues.md#networkmanager)。

RKE2 可以通过多种方式安装到系统中，其中两种是首选和受支持的方法。这两种方法分别是 tarball 和 RPM。快速入门中提到的安装脚本是对这两种方法的一种封装。

本文件更详细地解释了这些安装方法。

### Tarball

要安装 RKE2，你首先需要获得安装脚本。这可以通过多种方式实现。

在这里，你可以获得脚本并立即开始安装。

```sh
# curl -sfL https://get.rke2.io | sudo sh -
curl -sfL https://get.rke2.io | sh -
```

:::note
中国用户，可以使用以下方法加速安装：
```
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
```
:::

你也可以下载安装脚本并添加可执行权限。

```sh
curl -sfL https://get.rke2.io --output install.sh
chmod +x install.sh
```

#### 安装

默认安装最新的 RKE2 版本，不需要其他限定符。但是，如果你想指定一个版本，你需要设置 `INSTALL_RKE2_CHANNEL` 环境变量。下面是一个示例：

```bash
INSTALL_RKE2_CHANNEL=latest ./install.sh
```

安装脚本被执行时，它会判断系统的类型。如果使用是 RPM 的操作系统（比如 CentOS 或 RHEL），它将执行基于 RPM 的安装，否则脚本会默认为 tarball。下面介绍了基于 RPM 的安装。

下来，安装脚本下载 tarball，通过比较 SHA256 哈希值进行验证，最后将内容提取到 `/usr/local`。如果需要，操作者可以在安装后自由移动文件。这个操作只是提取 tarball，并没有做其他系统的修改。

Tarball 结构/内容：

* bin - 包含 RKE2 可执行文件以及 `rke2-killall.sh` 和 `rke2-uninstall.sh` 脚本
* lib - 包含 server 和 agent systemd 单元文件
* share - 包含 RKE2 许可证以及 RKE2 在 CIS 模式下运行时使用的 sysctl 配置文件

要进一步配置系统，请参阅 [server](../reference/server_config.md) 或 [agent](../reference/linux_agent_config.md) 文档。

### RPM

要启动 RPM 的安装过程，你需要获得上面提到的安装脚本。该脚本将检查你的系统是否有 `rpm`、`yum` 或 `dnf`，如果存在任何一个，它会确定系统是基于 Redhat 的，并且启动 RPM 安装过程。

安装文件时使用前缀 `/usr` 而不是 `/usr/local`。

#### 仓库

RKE2 的签名 RPM 在 `rpm-testing.rancher.io` 和 `rpm.rancher.io` RPM 仓库中发布。如果你在支持 RPM 的节点上运行 https://get.rke2.io 脚本，它将默认使用这些 RPM 仓库。你也可以自行安装它们。

RPM 提供 `systemd` 单元来管理 `rke2`，但需要在首次启动服务之前通过配置文件进行配置。

#### Enterprise Linux 7

要使用 RPM 仓库，在 CentOS 7 或 RHEL 7 系统上运行以下 bash 代码片段：

```bash
cat << EOF > /etc/yum.repos.d/rancher-rke2-1-18-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/centos/7/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key

[rancher-rke2-1-18-latest]
name=Rancher RKE2 1.18 Latest
baseurl=https://rpm.rancher.io/rke2/latest/1.18/centos/7/x86_64
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF
```

#### Enterprise Linux 8

要使用 RPM 仓库，在 CentOS 8 或 RHEL 8 系统上运行以下 bash 代码片段：

```bash
cat << EOF > /etc/yum.repos.d/rancher-rke2-1-18-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/centos/8/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key

[rancher-rke2-1-18-latest]
name=Rancher RKE2 1.18 Latest
baseurl=https://rpm.rancher.io/rke2/latest/1.18/centos/8/x86_64
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF
```

#### 安装

配置仓库后，你可以运行以下任一命令：

```sh
yum -y install rke2-server
```

或者

```sh
yum -y install rke2-agent
```

RPM 将安装相应的 `rke2-server.service` 或 `rke2-agent.service` systemd 单元，你可以使用 `systemctl start rke2-server` 进行调用。请确保在启动之前配置 `rke2`，可以按照下面的`配置文件`说明进行操作。

### 手动

RKE2 二进制文件是静态编译和链接的，这使得 RKE2 二进制文件可以跨 Linux 发行版移植，而无需担心依赖性问题。最简单的安装方法是下载二进制文件，确保文件可执行，然后将其复制到 `${PATH}`，通常是 `/usr/local/bin`。第一次执行后，RKE2 将创建所有必要的目录和文件。要进一步配置系统，请参阅[配置文件](configuration.md)文档。
