---
title: "Helm 集成"
---

Helm 是 Kubernetes 的包管理工具。Helm Chart 为 Kubernetes YAML 清单文件提供了模板语法。通过 Helm，用户可以创建可配置的 deployment，而不仅仅只能使用静态文件。如果你需要创建自己的 Deployment 商店应用，请参见 [Helm 文档](https://helm.sh/docs/intro/quickstart/)。

RKE2 不需要任何特殊配置即可配合 Helm 命令行工具一起使用。请确保你已按照[集群访问](./cluster_access.md)部分正确设置了 kubeconfig。RKE2 包含一些其他功能，让你可以使用 [rancher/helm-release CRD](#使用-helm-crd) 更轻松地部署传统的 Kubernetes 资源清单和 Helm Chart。

本节涵盖以下主题：

- [自动部署清单和 Helm Chart](#自动部署清单和-helm-chart)
- [使用 Helm CRD](#使用-helm-crd)
- [使用 HelmChartConfig 自定义打包组件](#使用-helmchartconfig-自定义打包组件)

### 自动部署清单和 Helm Chart

在 `/var/lib/rancher/rke2/server/manifests` 中找到的 Kubernetes 清单都会以类似于 `kubectl apply` 的方式自动部署到 RKE2。以这种方式部署的清单作为 AddOn 自定义资源进行管理，你可以通过运行 `kubectl get addon -A` 查看它们。你能找到用于打包组件的 AddOn，例如 CoreDNS、Local-Storage、Nginx-Ingress 等。AddOn 由部署控制器自动创建，并根据它们在清单目录中的文件名命名。

你也可以将 Helm Chart 部署为 AddOn。RKE2 包含一个 [Helm Controller](https://github.com/k3s-io/helm-controller)，它使用 HelmChart 自定义资源定义 (CRD) 管理 Helm Chart。

### 使用 Helm CRD

[HelmChart 资源定义](https://github.com/k3s-io/helm-controller#helm-controller)捕获了你通常传递给 `helm` 命令行工具的大部分选项。以下示例说明了如何从默认 Chart 仓库部署 Grafana，并覆盖某些默认的 Chart 值。请注意，HelmChart 资源本身位于 `kube-system` 命名空间中，但 Chart 的资源将部署到 `monitoring` 命名空间。

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: grafana
  namespace: kube-system
spec:
  chart: stable/grafana
  targetNamespace: monitoring
  set:
    adminPassword: "NotVerySafePassword"
  valuesContent: |-
    image:
      tag: master
    env:
      GF_EXPLORE_ENABLED: true
    adminUser: admin
    sidecar:
      datasources:
        enabled: true
```

#### HelmChart 字段定义

| 字段 | 默认 | 描述 | Helm 参数/标志等效项 |
|-------|---------|-------------|-------------------------------|
| name |   | Helm Chart 名称 | NAME |
| spec.chart |   | 仓库中的 Helm Chart 名称，或 chart archive (.tgz) 的完整 HTTPS URL | CHART |
| spec.targetNamespace | default | Helm Chart 目标命名空间 | `--namespace` |
| spec.version |   | Helm Chart 版本（通过仓库安装时） | `--version` |
| spec.repo |   | Helm Chart 仓库 URL | `--repo` |
| spec.helmVersion | v3 | 要使用的 Helm 版本（`v2` 或 `v3`） |  |
| spec.bootstrap | False | 如果需要此 Chart 来引导集群（Cloud Controller Manager 等），请设置为 `True` |  |
| spec.set |   | 覆盖简单的默认 Chart 值。优先于通过 valuesContent 设置的选项。 | `--set` / `--set-string` |
| spec.valuesContent |   | 通过 YAML 文件内容覆盖复杂的默认 Chart 值 | `--values` |
| spec.chartContent |   | Base64 编码的 chart archive .tgz，覆盖 spec.chart | CHART |

### 使用 HelmChartConfig 自定义打包组件

为了允许覆盖部署为 HelmCharts（例如 Canal、CoreDNS、Nginx-Ingress 等）的打包组件的值，RKE2 支持通过 `HelmChartConfig` 资源进行自定义部署。`HelmChartConfig` 资源必须与对应的 HelmChart 名称和命名空间匹配，并且支持提供额外的 `valuesContent`，它作为附加值文件传递给 `helm` 命令。

> **注意**：HelmChart `spec.set` 值会覆盖 HelmChart 和 HelmChartConfig `spec.valuesContent` 设置。

例如，要自定义打包的 CoreDNS 配置，你可以创建一个名为 `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` 的文件并使用以下内容填充它:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-coredns
  namespace: kube-system
spec:
  valuesContent: |-
    image: coredns/coredns
    imageTag: v1.7.1
```
