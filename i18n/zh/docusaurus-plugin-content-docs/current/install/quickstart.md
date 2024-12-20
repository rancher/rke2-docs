---
title: 快速开始
---

本指南帮助你使用默认选项快速启动集群。

> Kubernetes 新手？Kubernetes 官方文档介绍了一些很好的[基础知识教程](https://kubernetes.io/docs/tutorials/kubernetes-basics/)。

### 先决条件

- 确保你的环境满足[要求](requirements.md)。
   如果你的主机安装并启用了 NetworkManager，请[确保将其配置为忽略 CNI 管理的接口](../known_issues.md#networkmanager)。

- 对于 RKE2 1.21 及更高版本，如果主机内核支持 [AppArmor](https://apparmor.net/)，则在安装 RKE2 之前还必须具有 AppArmor 工具（通常可通过 `apparmor-parser` 包获得）。

- 必须以 root 用户或通过 `sudo` 执行 RKE2 安装。

### Server 节点安装
--------------
RKE2 提供了一个安装脚本，可以方便地将其作为服务安装在基于 systemd 的系统上。该脚本可在 https://get.rke2.io 获得。要使用此方法安装 RKE2，请执行以下操作：

#### 1. 运行安装程序

```sh
curl -sfL https://get.rke2.io | sh -
```

:::note
中国用户，可以使用以下方法加速安装：
```
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
```
:::

这会将 `rke2-server` 服务和 `rke2` 二进制文件安装到你的主机上。除非以 root 用户或通过 `sudo` 运行，否则它将失败。

#### 2. 启用 rke2-server 服务

```sh
systemctl enable rke2-server.service
```

#### 3. 启动服务

```sh
systemctl start rke2-server.service
```

#### 4. 如有需要，可以查看日志

```sh
journalctl -u rke2-server -f
```

运行此安装后：

* `rke2-server` 服务将会安装。`rke2-server` 服务将被配置为在节点重启后或进程崩溃或被杀死时自动重启。
* 其他实用程序将安装到 `/var/lib/rancher/rke2/bin/`，包括 `kubectl`、`crictl` 和 `ctr`。请注意，默认情况下它们不在你的路径上。
* 两个清理脚本 `rke2-killall.sh` 和 `rke2-uninstall.sh` 将安装到以下路径：
   - 如果是常规文件系统，则是 `/usr/local/bin`
   - 如果是只读和 brtfs 文件系统，则是 `/opt/rke2/bin`
   - 如果设置了 `INSTALL_RKE2_TAR_PREFIX`，则是 `INSTALL_RKE2_TAR_PREFIX/bin`
* [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) 文件将写入 `/etc/rancher/rke2/rke2.yaml`。
* 可用于注册其他 Server 或 Agent 节点的令牌将在 `/var/lib/rancher/rke2/server/node-token` 中创建。

:::note
如果要添加其他 Server 节点，则总数必须为奇数。仲裁要求节点数为奇数。有关详细信息，请参阅[高可用文档](ha.md)。
:::

### Linux Agent（Worker）节点安装

本节中的步骤需要 root 级别访问权限或 `sudo` 才能执行。

#### 1. 运行安装程序

```sh
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
```

:::note
中国用户，可以使用以下方法加速安装：
```
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_TYPE="agent" sh -
```
:::

这会将 `rke2-agent` 服务和 `rke2` 二进制文件安装到你的主机上。除非以 root 用户或通过 `sudo` 运行，否则它将失败。

#### 2. 启用 rke2-agent 服务

```sh
systemctl enable rke2-agent.service
```

#### 3. 配置 rke2-agent 服务

```sh
mkdir -p /etc/rancher/rke2/
vim /etc/rancher/rke2/config.yaml
```

config.yaml 的内容：

```yaml
server: https://<server>:9345
token: <token from server node>
```

:::note
`rke2 server` 进程在端口 `9345` 上侦听新节点注册。Kubernetes API 仍然照常在端口 `6443` 上提供服务。
:::

#### 4. 启动服务

```sh
systemctl start rke2-agent.service
```

**如有需要，可以查看日志**

```sh
journalctl -u rke2-agent -f
```

**注意**：每台主机必须具有唯一的主机名。如果你的主机没有唯一的主机名，请在 `config.yaml` 文件中设置 `node-name` 参数，并为每个节点提供一个有效且唯一的主机名。

有关 `config.yaml` 文件的更多信息，请参阅[安装选项文档](configuration.md#配置文件)。

### Windows Agent（Worker）节点安装
**Windows 支持目前处于实验阶段（从 v1.21.3+rke2r1 开始）**  
**Windows 支持要求选择 Calico 作为 RKE2 集群的 CNI**

#### 0. 准备 Windows Agent 节点
**注意**：需要启用 Windows Server Containers 功能才能使 RKE2 Agent 工作。

使用管理员权限打开一个新的 Powershell 窗口。
```powershell
powershell -Command "Start-Process PowerShell -Verb RunAs"
```

在新的 Powershell 窗口中，运行以下命令：
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName containers -All
```
需要重启才能使 `Containers` 功能正常运行。

#### 1. 下载安装脚本
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
```
此脚本会将 `rke2.exe` Windows 二进制文件下载到你的计算机上。

#### 2. 为 Windows 配置 rke2-agent
```powershell
New-Item -Type Directory c:/etc/rancher/rke2 -Force
Set-Content -Path c:/etc/rancher/rke2/config.yaml -Value @"
server: https://<server>:9345
token: <token from server node>
"@
```

有关 `config.yaml` 文件的更多信息，请参阅[安装选项文档](configuration.md#配置文件)。


#### 3. 配置 PATH
```powershell
$env:PATH+=";c:\var\lib\rancher\rke2\bin;c:\usr\local\bin"

[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";c:\var\lib\rancher\rke2\bin;c:\usr\local\bin",
    [EnvironmentVariableTarget]::Machine)
```
#### 4. 运行安装程序
```powershell
./install.ps1
```

#### 5. 启动 Windows RKE2 服务
```powershell
rke2.exe agent service --add
```
**注意**：每台主机必须具有唯一的主机名。

不要忘记使用以下命令启动 RKE2 服务：

```powershell
Start-Service rke2
```

如果想仅使用 CLI 参数，请使用所需参数运行二进制文件。

```powershell
rke2.exe agent --token <> --server <>
```
