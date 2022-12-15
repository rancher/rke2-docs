---
title: Windows 卸载
---

# Windows 卸载

> **注意**：卸载 RKE2 Windows Agent 会删除所有节点数据。

不同的 RKE2 安装方法对应的卸载流程不同。

## Tarball 方法

要从系统中卸载使用 tarball 安装的 RKE2 Windows Agent，你只需运行以下命令。这将关闭所有 RKE2 Windows 进程，删除 RKE2 Windows 二进制文件，并清理 RKE2 使用的文件。

```powershell
c:/usr/local/bin/rke2-uninstall.ps1
```
