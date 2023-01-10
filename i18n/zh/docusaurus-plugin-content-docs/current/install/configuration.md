---
title: 配置选项
---

本文介绍了设置 RKE2 时可用的配置选项：

- [配置 Linux 安装脚本](#配置-linux-安装脚本)
- [配置 Windows 安装脚本](#配置-windows-安装脚本)
- [配置 RKE2 Server 节点](#配置-rke2-server-节点)
- [配置 Linux RKE2 Agent 节点](#配置-linux-rke2-agent-节点)
- [配置 Windows RKE2 Agent 节点](#配置-windows-rke2-agent-节点)
- [使用配置文件](#配置文件)
- [在直接运行二进制文件时配置](#在直接运行二进制文件时配置)

配置 RKE2 的主要方法是使用它的[配置文件](#配置文件)。你也可以使用命令行参数和环境变量，但 RKE2 作为 systemd 服务安装，因此这些方法较为复杂。

### 配置 Linux 安装脚本

如[快速入门指南](quickstart.md)中所述，你可以使用 <https://get.rke2.io> 上提供的安装脚本将 RKE2 安装为服务。

此命令最简单的形式是以 root 用户身份或通过 `sudo` 运行，如下所示：

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

使用该方法安装 RKE2 时，你可以使用以下环境变量来配置安装：

| 环境变量 | 描述 |
|-----------------------------|---------------------------------------------|
| `INSTALL_RKE2_VERSION` | 从 GitHub 下载的 RKE2 版本。如果未指定，将尝试从 `stable` channel 下载最新版本。如果在基于 RPM 的系统上安装并且 `stable` channel 中不存在所需的版本，则也应设置 `INSTALL_RKE2_CHANNEL`。 |
| `INSTALL_RKE2_TYPE` | 要创建的 systemd 服务类型，可以是 "server" 或 "agent"，默认值是 "server"。 |
| `INSTALL_RKE2_CHANNEL_URL` | 用于获取 RKE2 下载 URL 的 Channel URL。默认为 `https://update.rke2.io/v1-release/channels`。 |
| `INSTALL_RKE2_CHANNEL` | 用于获取 RKE2 下载 URL 的 Channel。默认为 `stable`。可选项：`stable`、`latest`、`testing`。 |
| `INSTALL_RKE2_METHOD` | 安装方法。默认是基于 RPM 的系统 `rpm`，所有其他系统都是 `tar`。 |

这个安装脚本很简单，会执行以下操作：

1. 根据以上参数获取需要安装的版本。如果没有指定参数，将使用最新的官方版本。
2. 确定并执行安装方法。有两种方法：rpm 和 tar。如果设置了 `INSTALL_RKE2_METHOD` 变量，将遵守该变量，否则，将在使用此包管理系统的操作系统上使用 `rpm`。在其他系统上将使用 tar。如果使用 tar，脚本将简单地解压缩所需版本的 tar 包。如果使用 rpm，将设置一个 yum 仓库，并使用 yum 安装 rpm。

### 配置 Windows 安装脚本
**Windows 支持目前处于实验阶段（从 v1.21.3+rke2r1 开始）**  
**Windows 支持要求选择 Calico 作为 RKE2 集群的 CNI**

正如[快速入门指南](quickstart.md)中所述，你可以使用位于 [https://github.com/rancher/rke2/blob/master/install.ps1](https://github.com/rancher/rke2/blob/master/install.ps1) 的安装脚本在 Windows Agent 节点上安装 RKE2。

此命令的最简单形式如下：

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
```

使用该方法安装 Windows RKE2 agent 时，你可以传入以下参数配置安装脚本：

```console
SYNTAX

install.ps1 [[-Channel] <String>] [[-Method] <String>] [[-Type] <String>] [[-Version] <String>] [[-TarPrefix] <String>] [-Commit] [[-AgentImagesDir] <String>] [[-ArtifactPath] <String>] [[-ChannelUrl] <String>] [<CommonParameters>]

OPTIONS

-Channel           Channel to use for fetching RKE2 download URL (Default: "stable")
-Method            The installation method to use. Currently tar or choco installation supported. (Default: "tar")
-Type              Type of RKE2 service. Only the "agent" type is supported on Windows. (Default: "agent")
-Version           Version of rke2 to download from Github
-TarPrefix         Installation prefix when using the tar installation method. (Default: `C:/usr/local` unless `C:/usr/local` is read-only or has a dedicated mount point, in which case `C:/opt/rke2` is used instead)
-Commit            (experimental/agent) Commit of RKE2 to download from temporary cloud storage. If set, this forces `--Method=tar`. Intended for development purposes only.
-AgentImagesDir    Installation path for airgap images when installing from CI commit. (Default: `C:/var/lib/rancher/rke2/agent/images`)
-ArtifactPath      If set, the install script will use the local path for sourcing the `rke2.windows-$SUFFIX` and `sha256sum-$ARCH.txt` files rather than the downloading the files from GitHub. Disabled by default.
```

### 其他 Windows 安装脚本使用示例
#### 安装最新版本而不是稳定版

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
./install.ps1 -Channel Latest
```

#### 使用 Tar 安装方法安装最新版本

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
./install.ps1 -Channel Latest -Method Tar
```
### 配置 RKE2 Server 节点

关于配置 RKE2 Server 的详细信息，请参阅 [Server 配置参考](../reference/server_config.md)。

### 配置 Linux RKE2 Agent 节点

关于配置 RKE2 Agent 的详细信息，请参阅 [Agent 配置参考](../reference/linux_agent_config.md)

### 配置 Windows RKE2 Agent 节点

有关配置 RKE2 Windows Agent 的详细信息，请参阅 [Windows Agent 配置参考](../reference/windows_agent_config.md)。

### 配置文件

默认情况下，RKE2 将使用 `/etc/rancher/rke2/config.yaml` YAML 文件中的值来启动。

下面是一个 `server` 配置文件的基本示例：

```yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "foo.local"
node-label:
  - "foo=bar"
  - "something=amazing"
```

配置文件参数直接映射到 CLI 参数，可重复的 CLI 参数呈现为 YAML 列表。

下面展示了一个仅使用 CLI 参数的相同配置：

```bash
rke2 server \
  --write-kubeconfig-mode "0644"    \
  --tls-san "foo.local"             \
  --node-label "foo=bar"            \
  --node-label "something=amazing"
```

也可以同时使用配置文件和 CLI 参数。 在这种情况下，值将从两个来源加载，但 CLI 参数将优先。 对于 `--node-label` 等可重复参数，CLI 参数将覆盖列表中的所有值。

最后，配置文件的位置可以通过 CLI 参数 `--config FILE, -c FILE` 或者环境变量 `$RKE2_CONFIG_FILE` 来改变。

### 在直接运行二进制文件时配置

如前所述，安装脚本主要与将 RKE2 配置为服务运行有关。如果你选择不使用该脚本，只需从我们的 [releases 页面](https://github.com/rancher/k3s/releases/latest)下载二进制文件，将文件放在你的路径上并执行即可运行 RKE2。RKE2 二进制文件支持以下命令：

| 命令 | 描述 |
--------|------------------
| `rke2 server` | 运行 RKE2 management server，它还将启动 Kubernetes control plane 组件，例如 API Server、controller-manager 和 scheduler。仅在 Linux 上支持。 |
| `rke2 agent` | 运行 RKE2 Node Agent。这将使 RKE2 作为 Worker 节点运行，同时启动 Kubernetes 节点服务 `kubelet` 和 `kube-proxy`。在 Linux 和 Windows 上支持。 |
| `rke2 help` | 显示命令列表或某个命令的帮助 |

`rke2 server` 和 `rke2 agent` 命令有额外的配置选项，你可以通过 `rke2 server --help` 或 `rke2 agent --help` 查看帮助。
