---
title: 卸载
---

:::caution
卸载 RKE2 会删除集群数据和所有脚本。
:::

## Linux 卸载

不同的 RKE2 安装方法对应的卸载流程不同。

### RPM 方法

要从系统中卸载通过 RPM 安装的 RKE2，只需以 root 用户或通过 `sudo` 运行你的 RKE2 版本对应的命令。这将关闭 RKE2 进程，删除 RKE2 RPM，并清理 RKE2 使用的文件。

```bash
/usr/bin/rke2-uninstall.sh
```

### Tarball 方法

要从系统中卸载通过 Tarball 方法安装的 RKE2，只需运行以下命令。这将终止进程，删除 RKE2 二进制文件，并清理 RKE2 使用的文件。

```bash
/usr/local/bin/rke2-uninstall.sh
```


## Windows 卸载

要从系统中卸载使用 tarball 安装的 RKE2 Windows Agent，你只需运行以下命令。这将关闭所有 RKE2 Windows 进程，删除 RKE2 Windows 二进制文件，并清理 RKE2 使用的文件。

```powershell
c:/usr/local/bin/rke2-uninstall.ps1
```
