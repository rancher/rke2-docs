---
title: 网络选项
---

RKE2 需要一个 CNI 插件来连接 pod 和服务。Canal CNI 插件是默认插件，从一开始就被支持。RKE2 v1.21 开始支持另外两个 CNI 插件，分别是 Calico 和 Cilium。在主要组件启动并运行后，所有 CNI 插件均通过 helm chart 安装，并且可以通过修改 helm chart 选项进行自定义。

本文介绍了设置 RKE2 时可用的网络选项：

- [安装 CNI 插件](#安装-cni-插件)
- [双栈配置](#双栈配置)
- [使用 Multus](#使用-multus)

## 安装 CNI 插件

下面的选项卡介绍了如何部署各个 CNI 插件并覆盖默认选项：

<Tabs groupId = "CNIplugin">
<TabItem value="Canal CNI 插件" default>

Canal 表示使用 Flannel 处理节点间的流量，使用 Calico 处理节点内流量和网络策略。默认情况下，它将使用 vxlan 封装在节点之间创建覆盖网络。Canal 默认部署在 RKE2 中，因此不需要额外配置来激活它。要覆盖默认的 Canal 选项，你需要创建一个 HelmChartConfig 资源。HelmChartConfig 资源必须与其对应 HelmChart 的名称和命名空间相匹配。例如，如果要覆盖 Flannel 接口，你可以应用以下配置：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      iface: "eth1"
```

从 RKE2 v1.23 开始，你可以使用 Flannel 的 [wireguard 后端](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md#wireguard) 进行内核 WireGuard 封装和加密（[内核版本 < 5.6 的用户需要安装模块](https://www.wireguard.com/install/)）。可以使用以下配置来实现：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      backend: "wireguard"
```

然后，请通过执行以下命令重启 canal daemonset 以使用更新的配置：`kubectl rollout restart ds rke2-canal -n kube-system`

有关 Canal 配置完整选项的更多信息，请参阅 [rke2-charts](https://github.com/rancher/rke2-charts/blob/main-source/packages/rke2-canal/charts/values.yaml)。

:::note
Canal 要求在节点上安装 iptables 或 xtables-nft 包。
:::

:::caution
具有 Windows 节点的集群目前不支持 Canal。
:::

如果你遇到 IP 分配问题，请参阅[已知问题和限制](../known_issues.md)。

</TabItem>
<TabItem value="Cilium CNI 插件" default>

从 RKE2 v1.21 开始，Cilium 可以部署为 CNI 插件。为此，将 `cilium` 作为 `--cni` 标志的值传递。确保节点具有所需的内核版本 (>= 4.9.17) 并且满足[要求](https://docs.cilium.io/en/stable/operations/system_requirements/)。要覆盖默认选项，请使用 HelmChartConfig 资源。HelmChartConfig 资源必须与其对应 HelmChart 的名称和命名空间相匹配。例如，启用 eni：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    eni:
      enabled: true
```

有关 Cilium Chart 中可用值的更多信息，请参阅 [rke2-charts 仓库](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-cilium/rke2-cilium/1.12.301/values.yaml)。

Cilium 包括了一些高级功能，可以完全替代 kube-proxy，并使用 eBPF 代替 iptables 实现服务路由。如果你的内核不是 v5.8 或更新版本，不建议用 Cilium 替换 kube-proxy，因为重要的错误修复和功能将丢失。要激活此模式，请使用标志 `--disable-kube-proxy` 和以下 Cilium 配置部署 RKE2：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: strict
    k8sServiceHost: <KUBE_API_SERVER_IP>
    k8sServicePort: <KUBE_API_SERVER_PORT>
    cni:
      chainingMode: "none"
```

有关更多信息，请查看[上游文档](https://docs.cilium.io/en/v1.12/gettingstarted/kubeproxy-free/)。

:::caution
RKE2 的 Windows 安装目前不支持 Cilium。
:::

</TabItem>
<TabItem value="Calico CNI 插件" default>
从 RKE2 v1.21 开始，Calico 可以部署为 CNI 插件。为此，将 `calico` 作为 `--cni` 标志的值传递。要覆盖默认选项，请使用 HelmChartConfig 资源。HelmChartConfig 资源必须与其对应 HelmChart 的名称和命名空间相匹配。例如，要更改 mtu：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-calico-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-calico
  namespace: kube-system
spec:
  valuesContent: |-
    installation:
      calicoNetwork:
        mtu: 9000
```

有关 Calico chart 中可用值的更多信息，请参阅 [rke2-charts 仓库](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-calico/rke2-calico/v3.25.001/values.yaml)。

:::note
Calico 要求在节点上安装 iptables 或 xtables-nft 包。
:::

</TabItem>
</Tabs>

## 双栈配置

IPv4/IPv6 双栈网络支持将 IPv4 和 IPv6 地址分配给 Pod 和 Service。该功能从 RKE2 v1.21 开始受支持，v1.23 开始稳定，但默认不激活。要正确激活它，必须相应配置 RKE2 和所选的 CNI 插件。要在双栈模式下配置 RKE2，在 control plane 节点中，你必须为 pod 和service 设置有效的 IPv4/IPv6 双栈 cidr。为此，请使用标志 `--cluster-cidr` 和 `--service-cidr`。例如：

```yaml
#/etc/rancher/rke2/config.yaml
cluster-cidr: "10.42.0.0/16,2001:cafe:42::/56"
service-cidr: "10.43.0.0/16,2001:cafe:43::/112"
```

每个 CNI 插件都需要不同的双栈配置：

<Tabs groupId = "CNIplugin">
<TabItem value="Canal CNI 插件" default>

Canal 自动检测双栈的 RKE2 配置，不需要额外配置。RKE2 的 Windows 安装目前不支持双栈。

</TabItem>
<TabItem value="Cilium CNI 插件" default>

Cilium 自动检测双栈的 RKE2 配置，不需要额外配置。

</TabItem>
<TabItem value="Calico CNI 插件" default>

Calico 自动检测双栈的 RKE2 配置，不需要额外配置。当以双栈模式部署时，它会创建两个不同的 ippool 资源。请注意，在使用双栈时，calico 利用 BGP 而不是 VXLAN 封装。RKE2 的 Windows 安装目前不支持双栈和 BGP。
</TabItem>
</Tabs>

## IPv6 设置

在只配置 IPv6 的情况下，RKE2 需要使用 `localhost` 来访问 ETCD pod 的 liveness URL。检查你的操作系统是否正确配置了 `/etc/hosts` 文件：

```bash
::1       localhost
```

## 使用 Multus

从 RKE2 v1.21 开始，你可以部署 Multus CNI meta-plugin。请注意，这是针对高级用户的。

[Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) 是一个 CNI 插件，可以将多个网络接口附加到 pod。Multus 不会取代 CNI 插件，而是充当 CNI 插件多路复用器。Multus 在某些用例中很有用，特别是当 pod 是网络密集型的，需要额外的网络接口来支持数据平面加速技术，如 SR-IOV。

Multus 不能独立部署。它总是需要至少一个满足 Kubernetes 集群网络要求的常规 CNI 插件。该 CNI 插件成为 Multus 的默认插件，并将用于为所有 pod 提供主要接口。

要启用 Multus，请将 Multus 添加为 cni 配置项中的第一个列表条目，然后是要与 Multus 一起使用的插件的名称（如果你提供自己的默认插件，则为 `none`）。请注意，Multus 必须始终位于列表的第一个位置。例如，要使用带有 Canal 的 Multus 作为默认插件，你可以指定：

```yaml
# /etc/rancher/rke2/config.yaml
cni:
- multus
- canal
```

你也可以用命令行参数来指定，即 `--cni=multus,canal` 或 `--cni=multus --cni=canal`。

有关 Multus 的更多信息，请参阅 [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs) 文档。

## 结合使用 Multus 与 Cilium

要结合使用 Cilium 与 Multus，你需要禁用 `exclusive` 配置。
你可以使用以下 HelmChartConfig 来执行此操作：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    cni:
      exclusive: false
```

## 结合使用 Multus 与 containernetworking 插件

任何 CNI 插件都可以用作 Multus 的辅助 CNI 插件，用于提供附加到 pod 的额外网络接口。然而，最常见的是使用 containernetworking 团队（网桥、主机设备、macvlan 等）维护的 CNI 插件作为 Multus 的辅助 CNI 插件。安装 Multus 时会自动部署这些 containernetworking 插件。有关这些插件的更多信息，请参阅 [containernetworking 插件](https://www.cni.dev/plugins/current) 文档。

要使用这些插件中的任何一个，你需要创建一个 NetworkAttachmentDefinition 对象来定义辅助网络的配置。然后 pod 注释引用该定义，Multus 将使用这些注释为该 pod 提供额外的接口。[multus-cni repo](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md#storing-a-configuration-as-a-custom-resource) 中提供了将 macvlan CNI 插件与 Mu 一起使用的示例。

## 结合使用 Multus 与 Whereabouts CNI

[Whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts) 是一个 IP 地址管理 (IPAM) CNI 插件，可在集群范围内分配 IP 地址。
从 RKE2 1.22 开始，RKE2 包括了使用 Whereabouts 与 Multus 来管理通过 Multus 创建的附加接口 IP 地址的选项。
为此，你需要使用 [HelmChartConfig](../helm.md#使用-helmchartconfig-自定义打包组件) 配置 Multus CNI 以使用 Whereabouts。

你可以使用以下 HelmChartConfig 来执行此操作：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    rke2-whereabouts:
      enabled: true
```

这将为 Multus 配置 Chart 以使用 `rke2-whereabouts` 作为依赖项。

如果要自定义 Whereabouts 镜像：

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    rke2-whereabouts:
      enabled: true
      image:
        repository: ghcr.io/k8snetworkplumbingwg/whereabouts
        tag: latest-amd64
```

注意：你需要在启动 RKE2 之前写这个文件。

## 结合使用 Multus 与 SR-IOV

**v1.21.2+rke2r1 添加了 SR-IOV 实验性支持，并从 2023 年 4 月的 v1.26.4+rke2r1、v1.25.9+rke2r1 和 v1.24.13+rke2r1 版本开始提供全面支持。**

将 SR-IOV CNI 与 Multus 结合使用可用于数据平面加速的用例，在 pod 中提供额外的接口来实现非常高的吞吐量。SR-IOV 不会在所有环境下工作，必须满足几个要求才能将节点视为支持 SR-IOV 的节点：

* 物理 NIC 必须支持 SR-IOV（例如通过检查 /sys/class/net/$NIC/device/sriov_totalvfs）
* 主机操作系统必须激活 IOMMU 虚拟化
* 主机操作系统包括能够执行 sriov（例如 i40e、vfio-pci 等）的驱动程序

SR-IOV CNI 插件不能用作 Multus 的默认 CNI 插件。它必须与 Multus 和传统的 CNI 插件一起部署。你可以在 `rancher-charts` Helm 仓库中找到 SR-IOV CNI helm chart。有关详细信息，请参阅 [Rancher Helm Chart 文档](https://ranchermanager.docs.rancher.com/pages-for-subheaders/helm-charts-in-rancher)。

安装 SR-IOV CNI chart 后，将部署 SR-IOV operator。然后，用户必须通过 `feature.node.kubernetes.io/network-sriov.capable=true` 标记来指定集群中支持 SR-IOV 的节点：

```bash
kubectl label node $NODE-NAME feature.node.kubernetes.io/network-sriov.capable=true
```

标记后，sriov-network-config Daemonset 将在节点中部署一个 pod，用来收集网络接口的信息。该信息可通过 `sriovnetworknodestates` 自定义资源定义获得。部署几分钟后，每个节点将有一个 `sriovnetworknodestates` 资源，资源名称是节点名称。

注意：来自 `rancher-charts` 的 SR-IOV CNI Chart 现在已包含 `node-feature-discovery` Chart 作为自动依赖项。该 Chart 部署了一个小型守护程序集，它会根据在节点上检测到的功能自动标记每个节点。这适用于硬件和软件功能。值得关注的是 `node-feature-discovery` 可以在检测到兼容节点时自动添加标签 `feature.node.kubernetes.io/network-sriov.capable=true`。
有关详细信息，请参阅 [NFD 文档](https://kubernetes-sigs.github.io/node-feature-discovery/v0.11/get-started/introduction.html)。

但是，最新版本的 sriov-network-operator 包含了支持硬件的白名单，因此 sriov 实际上仅适用于[该列表](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/supported-hardware.md)中的 NIC。如果要将 SR-IOV CNI 与不在列表中的 NIC 一起使用，则需要自行更新 `supported-nic-ids` configMap。

有关 SR-IOV Operator 的使用方法，请参阅 [sriov-network-operator](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/quickstart.md#configuration)。
