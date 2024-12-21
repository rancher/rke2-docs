---
title: Windows 离线安装
---

**Windows 支持目前处于实验阶段（从 v1.21.3+rke2r1 开始）**  
**Windows 支持要求选择 Calico 作为 RKE2 集群的 CNI**

你可以通过两种不同的方法在离线环境中使用 RKE2 Windows Agent (Worker) 节点。你需要先完成 RKE2 [离线设置](./airgap.md)。

你可以使用 `rke2-windows-<BUILD_VERSION>-amd64-images.tar.gz` 压缩包发布工件进行部署，也可以使用私有镜像仓库进行部署。根据我们已验证的 [Windows 版本](requirements.md#windows)，我们目前为 Windows 发布了三个 tarball 工件。

- rke2-windows-1809-amd64-images.tar.gz
- rke2-windows-2004-amd64-images.tar.gz
- rke2-windows-20H2-amd64-images.tar.gz

步骤中提到的所有文件都可以从[此处](https://github.com/rancher/rke2/releases)所需 RKE2 版本的 asset 中获取。

#### 准备 Windows Agent 节点
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

## Windows Tarball 方法

1. 从 RKE2 release artifacts 列表下载 RKE2 版本的 Windows 镜像 tarball 和二进制文件。

   #### 使用 tar.gz 镜像 tarball

   - **Windows Server 2019 LTSC (amd64) (OS Build 17763.2061)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-1809-amd64-images.tar.gz -OutFile /var/lib/rancher/rke2/agent/images/rke2-windows-1809-amd64-images.tar.gz
   ```


   - **Windows Server SAC 2004 (amd64) (OS Build 19041.1110)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'  
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-2004-amd64-images.tar.gz -OutFile c:/var/lib/rancher/rke2/agent/images/rke2-windows-2004-amd64-images.tar.gz
   ```

   - **Windows Server SAC 20H2 (amd64) (OS Build 19042.1110)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'  
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-20H2-amd64-images.tar.gz -OutFile c:/var/lib/rancher/rke2/agent/images/rke2-windows-20H2-amd64-images.tar.gz
   ```

   #### 使用 tar.zst 镜像 tarball

   - **Windows Server 2019 LTSC (amd64) (OS Build 17763.2061)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'  
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-1809-amd64-images.tar.zst -OutFile /var/lib/rancher/rke2/agent/images/rke2-windows-1809-amd64-images.tar.zst
   ```


   - **Windows Server SAC 2004 (amd64) (OS Build 19041.1110)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'  
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-2004-amd64-images.tar.zst -OutFile c:/var/lib/rancher/rke2/agent/images/rke2-windows-2004-amd64-images.tar.zst
   ```

   - **Windows Server SAC 20H2 (amd64) (OS Build 19042.1110)**

   ```powershell
   $ProgressPreference = 'SilentlyContinue'
   Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-20H2-amd64-images.tar.zst -OutFile c:/var/lib/rancher/rke2/agent/images/rke2-windows-20H2-amd64-images.tar.zst
   ```

   - 使用 `rke2-windows-<BUILD_VERSION>-amd64.tar.gz` 或 `rke2-windows-<BUILD_VERSION>-amd64.tar.zst`。与 pigz 相比，Zstandard 支持更好的压缩比和更快的解压缩速度。

2. 确保节点上存在 `/var/lib/rancher/rke2/agent/images/` 目录。

   ```powershell
   New-Item -Type Directory c:\usr\local\bin -Force
   New-Item -Type Directory c:\var\lib\rancher\rke2\bin -Force
   ```

3. 将压缩包复制到节点上的`/var/lib/rancher/rke2/agent/images/`，需要保留文件扩展名。

4. [安装 RKE2](#安装-windows-rke2)

## 私有镜像仓库方法
从 RKE2 v1.20 开始，私有镜像仓库支持遵循 [containerd 镜像仓库配置](./private_registry.md)中的所有设置。其中包括端点覆盖和传输协议（HTTP/HTTPS）、身份验证、证书验证等。

在 RKE2 v1.20 之前，私有镜像仓库必须使用 TLS，并使用主机 CA 捆绑包信任的证书。如果镜像仓库使用的是自签名证书，你可以使用 `update-ca-certificates` 将证书添加到主机 CA 捆绑包。镜像仓库还必须允许匿名（未经身份验证）访问。

1. 将所有必需的系统镜像添加到你的私有镜像仓库。你可以从与上述每个压缩包对应的 `.txt` 文件中获取镜像列表，也可以对离线镜像压缩包使用 `docker load`，然后标记并推送加载的镜像。
2. 如果在镜像仓库上使用私有或自签名证书，请将镜像仓库的 CA 证书添加到 containerd 镜像仓库配置中，如果使用 v1.20 之前的版本，则添加到操作系统的受信任证书中。
3. 使用 `system-default-registry` 参数[安装 RKE2](#安装-windows-rke2)，或使用 [containerd 镜像仓库配置](./private_registry.md)将你的镜像仓库用作 docker.io 的 mirror。

## 安装 Windows RKE2

这些步骤只能在完成 [Tarball 方法](#windows-tarball-方法)或[私有镜像仓库方法](#私有镜像仓库方法)之一后执行。

1. 获取 Windows RKE2 二进制文件 `rke2-windows-amd64.exe`。确保二进制文件名为 `rke2.exe` 并将其放在 `c:/usr/local/bin` 中。
```powershell
Invoke-WebRequest https://github.com/rancher/rke2/releases/download/v1.21.4%2Brke2r2/rke2-windows-amd64.exe -OutFile c:/usr/local/bin/rke2.exe
```

2. 为 Windows 配置 rke2-agent
```powershell
New-Item -Type Directory c:/etc/rancher/rke2 -Force
Set-Content -Path c:/etc/rancher/rke2/config.yaml -Value @"
server: https://<server>:9345
token: <token from server node>
"@
```

有关 `config.yaml` 文件的更多信息，请参阅[安装选项文档](configuration.md#配置文件)。

3. 配置 PATH
```powershell
$env:PATH+=";c:\var\lib\rancher\rke2\bin;c:\usr\local\bin"

[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";c:\var\lib\rancher\rke2\bin;c:\usr\local\bin",
    [EnvironmentVariableTarget]::Machine)
```

4. 通过使用所需参数运行二进制文件来启动 RKE2 Windows 服务。有关其他参数，请参阅 [Windows Agent 配置参考](../reference/windows_agent_config.md)。

```powershell
c:\usr\local\bin\rke2.exe agent service --add
```

例如，如果使用私有镜像仓库方法，你的配置文件将具有以下内容：
```yaml
system-default-registry: "registry.example.com:5000"
```

**注意**：`system-default-registry` 参数必须仅指定有效的 RFC 3986 URI 授权，即主机和可选端口。

如果想仅使用 CLI 参数，请使用所需参数运行二进制文件。

```powershell
c:/usr/local/bin/rke2.exe agent --token <> --server <>
```
