---
title: "要求"
---

RKE2 非常轻量，但也有一些最低要求，如下所述。

## 先决条件

两个节点不能具有相同的主机名。

如果你所有节点的主机名都相同，请在 RKE2 配置文件中为集群的每个节点设置不同的 `node-name` 参数。

## 操作系统

### Linux
RKE2 已在以下操作系统及其后续非主要版本上进行了测试和验证：

* Ubuntu 18.04, 20.04, 22.04 (amd64)
* CentOS/RHEL 7.8 (amd64)
* Rocky/RHEL 8.5 (amd64)
* SLES 15 SP3, SP4
* OpenSUSE, SLE Micro 5.1, 5.2, 5.3 (amd64)

### Windows
:::caution 版本
从 [v1.21.3+rke2r1](https://github.com/rancher/rke2/releases/tag/v1.21.3%2Brke2r1) 开始作为实验性功能。
:::

:::info
Windows 支持要求选择 Calico 作为 RKE2 集群的 CNI。
:::

RKE2 Windows Node (Worker) agent 已在以下操作系统及其后续非主要版本上进行了测试和验证：

* Windows Server 2019 LTSC (amd64) (OS Build 17763.2061)
* Windows Server 2022 LTSC (amd64) (OS Build 20348.169)

**注意**：需要启用 Windows Server Containers 功能才能使 RKE2 Windows Agent 工作。

使用管理员权限打开一个新的 Powershell 窗口。
```powershell
powershell -Command "Start-Process PowerShell -Verb RunAs"
```

在新的 Powershell 窗口中，运行以下命令：
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers –All
```

需要重启才能使 `Containers` 功能正常运行。

## 硬件

硬件要求根据你部署的规模而变化。此处概述了最低建议。

### Linux/Windows
* RAM：最低 4 GB（建议至少 8 GB）
* CPU：最少 2（建议至少 4 CPU）

#### 磁盘

RKE2 的性能取决于数据库的性能。由于 RKE2 嵌入式运行 etcd 并将数据目录存储在磁盘上，我们建议尽可能使用 SSD 以确保最佳性能。

## 网络

:::tip 重要提示
如果你的节点安装并启用了 NetworkManager，请[确保将其配置为忽略 CNI 管理的接口](../known_issues.md#networkmanager)。如果你的节点安装并启用了 Wicked，请[确保转发 sysctl 配置已启用](../known_issues.md#wicked)。
:::

RKE2 server 需要开放端口 6443 和 9345 才能供集群中的其他节点访问。

使用 Flannel VXLAN 时，所有节点都需要能够通过 UDP 端口 8472 访问其他节点。

如果要使用 Metrics Server，则需要在每个节点上打开端口 10250。

**重要提示**：节点上的 VXLAN 端口会开放集群网络，让任何人均能访问集群。因此，不要将 VXLAN 端口暴露给外界。请使用禁用 8472 端口的防火墙/安全组来运行节点。

### 入站网络规则

| 协议 | 端口 | 源 | 描述 |
|-----|-----|----------------|---|
| TCP | 9345 | RKE2 Agent 节点 | Kubernetes API |
| TCP | 6443 | RKE2 Agent 节点 | Kubernetes API |
| UDP | 8472 | RKE2 Server 和 Agent 节点 | 只有 Flannel VXLAN 需要 |
| TCP | 10250 | RKE2 Server 和 Agent 节点 | kubelet |
| TCP | 2379 | RKE2 Server 节点 | etcd 客户端端口 |
| TCP | 2380 | RKE2 Server 节点 | etcd 对等端口 |
| TCP | 30000-32767 | RKE2 Server 和 Agent 节点 | NodePort 端口范围 |
| UDP | 8472 | RKE2 Server 和 Agent 节点 | Cilium CNI VXLAN |
| TCP | 4240 | RKE2 Server 和 Agent 节点 | Cilium CNI 健康检查 |
| ICMP | 8/0 | RKE2 Server 和 Agent 节点 | Cilium CNI 健康检查 |
| TCP | 179 | RKE2 Server 和 Agent 节点 | 使用 BGP 的 Calico CNI |
| UDP | 4789 | RKE2 Server 和 Agent 节点 | 使用 VXLAN 的 Calico CNI |
| TCP | 5473 | RKE2 Server 和 Agent 节点 | 使用 Typha 的 Calico CNI  |
| TCP | 9098 | RKE2 Server 和 Agent 节点 | Calico Typha 健康检查 |
| TCP | 9099 | RKE2 Server 和 Agent 节点 | Calico 健康检查 |
| TCP | 5473 | RKE2 Server 和 Agent 节点 | 使用 Typha 的 Calico CNI  |
| UDP | 8472 | RKE2 Server 和 Agent 节点 | 使用 VXLAN 的 Canal CNI |
| TCP | 9099 | RKE2 Server 和 Agent 节点 | Canal CNI 健康检查 |
| UDP | 51820 | RKE2 Server 和 Agent 节点 | 使用 WireGuard IPv4 的 Canal CNI |
| UDP | 51821 | RKE2 Server 和 Agent 节点 | 使用 WireGuard IPv6/双栈的 Canal CNI |

### Windows 特定的入站网络规则

| 协议 | 端口 | 源 | 描述 |
|-----|-----|----------------|---|
| UDP | 4789 | RKE2 Server 节点 | Calico 和 Flannel VXLAN 需要 |

所有出站流量通常都是允许的。
