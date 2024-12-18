---
title: 自动升级
---

### 概述

你可以使用 Rancher 的 system-upgrade-controller 管理 RKE2 集群升级。这是一种 Kubernetes 原生的集群升级方法。它利用[自定义资源定义（custom resource definition，CRD）](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources)、`计划`和[控制器](https://kubernetes.io/docs/concepts/architecture/controller/)，根据配置的计划安排升级。

计划定义了升级的策略和要求。本文档将提供适用于升级 RKE2 集群的默认计划。有关更高级的计划配置选项，请参阅 [CRD](https://github.com/rancher/system-upgrade-controller/blob/master/pkg/apis/upgrade.cattle.io/v1/types.go)。

控制器通过监控计划和选择要运行升级 [job](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) 的节点来安排升级。计划通过[标签选择器](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)定义应该升级哪些节点。job 成功运行完成时，控制器将相应地标记它运行的节点。

> **注意**：启动的升级 job 必须具有高权限。它配置了以下内容：
>
- 主机 `IPC`、`NET` 和 `PID` 命名空间
- `CAP_SYS_BOOT` 能力
- 挂载在 `/host` 的主机根目录，具有读写权限

有关 system-upgrade-controller 的设计和架构，以及它与 RKE2 集成的更多详细信息，请参阅以下 Git 仓库：

- [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller)
- [rke2-upgrade](https://github.com/rancher/k3s-upgrade)

要以这种方式自动升级，你必须：

1. 将 system-upgrade-controller 安装到集群中
2. 配置计划


### 安装 system-upgrade-controller
system-upgrade-controller 可以作为 Deployment 安装到你的集群中。Deployment 需要 ServiceAccount、clusterRoleBinding 和 configmap。要安装这些组件，请运行以下命令：
```
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.9.1/system-upgrade-controller.yaml
```
控制器可以通过前面提到的 configmap 进行配置和自定义，但控制器必须重新部署才能应用更改。


### 配置计划
建议你至少创建两个计划：升级 server（master/control plane）节点的计划和升级 agent（worker）节点的计划。根据需要，你可以创建其他计划来控制跨节点的升级回滚。以下两个示例计划会将你的集群升级到 rke2 v1.23.1+rke2r2。创建计划后，控制器将选择它们并开始升级你的集群。
```
# Server plan
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: server-plan
  namespace: system-upgrade
  labels:
    rke2-upgrade: server
spec:
  concurrency: 1
  nodeSelector:
    matchExpressions:
       - {key: rke2-upgrade, operator: Exists}
       - {key: rke2-upgrade, operator: NotIn, values: ["disabled", "false"]}
       # When using k8s version 1.19 or older, swap control-plane with master
       - {key: node-role.kubernetes.io/control-plane, operator: In, values: ["true"]}
  serviceAccountName: system-upgrade
  cordon: true
#  drain:
#    force: true
  upgrade:
    image: rancher/rke2-upgrade
  version: v1.23.1-rke2r2
---
# Agent plan
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: agent-plan
  namespace: system-upgrade
  labels:
    rke2-upgrade: agent
spec:
  concurrency: 2
  nodeSelector:
    matchExpressions:
      - {key: rke2-upgrade, operator: Exists}
      - {key: rke2-upgrade, operator: NotIn, values: ["disabled", "false"]}
      # When using k8s version 1.19 or older, swap control-plane with master
      - {key: node-role.kubernetes.io/control-plane, operator: NotIn, values: ["true"]}
  prepare:
    args:
    - prepare
    - server-plan
    image: rancher/rke2-upgrade
  serviceAccountName: system-upgrade
  cordon: true
  drain:
    force: true
  upgrade:
    image: rancher/rke2-upgrade
  version: v1.23.1-rke2r2

```


关于这些计划，有几个重要的事情需要注意：

1. 计划必须在部署控制器的同一命名空间中创建。

2. `concurrency` 字段表示可以同时升级多少个节点。

3. `server-plan` 通过指定一个标签选择器来选择 Server 节点，该标签选择器会选择具有 `node-role.kubernetes.io/control-plane` 标签的节点（`node-role.kubernetes.io/master` 适用于 1.19 或更早版本）。`agent-plan` 通过指定一个标签选择器来选择没有该标签的节点，从而锁定 agent 节点。你也可以选择包含其他标签，如上例所示，它要求标签 “rke2-upgrade” 存在并且值不是 “disabled” 或 “false”。

4. `agent-plan` 中的 `prepare` 步骤会使该计划等待 `server-plan` 完成后再执行升级 job。

5. 两个计划都将 `version` 字段设置为 v1.23.1+rke2r2。或者，你可以省略 `version` 字段并将 `channel` 字段设置为解析到 RKE2 版本的 URL。这将导致控制器监控该 URL，并在它解析到新版本时随时升级集群。这适用于[版本 channels](manual_upgrade#版本-channels)。因此，你可以用下面的 channel 配置计划，从而确保你的集群总是自动升级到 RKE2 的最新稳定版本。
```
apiVersion: upgrade.cattle.io/v1
kind: Plan
...
spec:
  ...
  channel: https://update.rke2.io/v1-release/channels/stable

```

如前所述，一旦控制器检测到已创建计划，升级就会立即开始。更新计划将导致控制器重新评估计划并确定是否需要再次升级。

你可以通过 kubectl 查看计划和 job 来监控升级进度：
```
kubectl -n system-upgrade get plans -o yaml
kubectl -n system-upgrade get jobs -o yaml
```
