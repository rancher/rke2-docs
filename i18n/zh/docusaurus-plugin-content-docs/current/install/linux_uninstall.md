---
title: Linux 卸载
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Linux 卸载

:::note
卸载 RKE2 会删除集群数据和所有脚本。
:::

不同的 RKE2 安装方法对应的卸载流程不同。

## RPM 方法

要从系统中卸载通过 RPM 安装的 RKE2，只需以 root 用户或通过 `sudo` 运行你的 RKE2 版本对应的命令。这将关闭 RKE2 进程，删除 RKE2 RPM，并清理 RKE2 使用的文件。

<Tabs>
<TabItem value="v1.18.13+rke2r1 及更新版本" default>

附带的 `rke2-uninstall.sh` 脚本将在卸载过程中删除相应的 RPM 包。你只需运行以下命令：

```bash
/usr/bin/rke2-uninstall.sh
```
</TabItem>

<TabItem value="v1.18.11+rke2r1 - v1.18.12+rke2r1" default>

在调用 `rke2-uninstall.sh` 脚本后，你需要手动删除 RKE2 RPM。

```sh
/usr/bin/rke2-uninstall.sh
yum remove -y 'rke2-*'
rm -rf /run/k3s
```
</TabItem>

<TabItem value="v1.18.10+rke2r1 及以前的版本" default>

基于 RPM 的安装没有打包 `rke2-uninstall.sh` 脚本。以下说明介绍了如何下载和使用必要的脚本。

首先，删除对应的 RKE2 包和 `/run/k3s` 目录。

```bash
yum remove -y 'rke2-*'
rm -rf /run/k3s
```

运行这些命令后会下载 rke2-uninstall.sh 和 rke2-killall.sh 脚本。这两个脚本将停止任何正在运行的容器和进程，清理使用的进程，并最终从系统中删除 RKE2。运行以下命令。

```bash
curl -sL https://raw.githubusercontent.com/rancher/rke2/master/bundle/bin/rke2-uninstall.sh --output rke2-uninstall.sh
chmod +x rke2-uninstall.sh
mv rke2-uninstall.sh /usr/local/bin

curl -sL https://raw.githubusercontent.com/rancher/rke2/master/bundle/bin/rke2-killall.sh --output rke2-killall.sh
chmod +x rke2-killall.sh
mv rke2-killall.sh /usr/local/bin

```

现在运行 rke2-uninstall.sh 脚本。这也将调用 rke2-killall.sh。

```bash
/usr/local/bin/rke2-uninstall.sh
```
</TabItem>

</Tabs>


## Tarball 方法

要从系统中卸载通过 Tarball 方法安装的 RKE2，只需运行以下命令。这将终止进程，删除 RKE2 二进制文件，并清理 RKE2 使用的文件。

```bash
/usr/local/bin/rke2-uninstall.sh
```
