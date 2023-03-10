---
title: 高可用
---

本文介绍了如何安装高可用 (HA) 的 RKE2 集群。一个高可用的 RKE2 集群由以下部分组成：

* 一个**固定的注册地址**，放在 Server 节点的前面，允许其他节点注册到集群
* 运行 etcd、Kubernetes API 和其他 control plane 服务的奇数个（推荐三个）**Server 节点**
* 零个或多个 **Agent 节点**，用于运行你的应用和服务

Agent 通过固定注册地址注册。然而，当 RKE2 启动 kubelet 并且必须连接到 Kubernetes api-server 时，它通过 `rke2 agent` 进程进行连接，该进程充当客户端负载均衡器。

设置 HA 集群需要以下步骤：

1. 配置固定注册地址
1. 启动第一个 Server 节点
1. 加入额外的 Server 节点
1. 加入 Agent 节点

### 1. 配置固定的注册地址

第一个以外的 Server 节点和所有 Agent 节点都需要一个 URL 来注册。这可以是任何 server 节点的 IP 或主机名，但在许多情况下，随着节点的创建和销毁，它们可能会随着时间的推移而改变。因此，你应该在 Server 节点前面有一个稳定的端点。

你可以使用许多方法来设置此端点，例如：

* 4 层 (TCP) 负载均衡器
* 轮询 DNS
* 虚拟或弹性 IP 地址

这个端点也可以用来访问 Kubernetes API。因此，你可以修改 [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) 文件来指向它，而不是特定的节点。

请注意，`rke2 server` 进程在端口 `9345` 上侦听新节点注册。Kubernetes API 照常在端口 `6443` 上提供服务。你可以相应地配置负载均衡器。

### 2. 启动第一个 Server 节点
第一个 Server 节点会建立其他 Server 或 Agent 节点在连接集群时用于注册的 Secret 令牌。

要将你自己的预共享 secret 指定为令牌，请在启动时设置 `token` 参数。

如果你不指定预共享 secret，RKE2 会生成一个预共享 secret 并将它放在 `/var/lib/rancher/rke2/server/node-token` 中。

为了避免固定注册地址的证书错误，请在启动 Server 时设置 `tls-san` 参数。这个选项在 Server 的 TLS 证书中增加一个额外的主机名或 IP 作为 Subject Alternative Name。如果你想通过 IP 和主机名访问，你可以将它指定为一个列表。

第一台 Server 的 RKE2 配置文件示例：

:::note
RKE2 配置文件需要手动创建。你可以通过以特权用户身份运行 `touch /etc/rancher/rke2/config.yaml` 来实现这一点。
:::

```yaml
token: my-shared-secret
tls-san:
  - my-kubernetes-domain.com
  - another-kubernetes-domain.com
```

#### 2a. 可选：考虑 Server 节点污点
默认情况下，Server 节点是可调度的，因此你的工作负载可以在它们上启动。如果你希望拥有一个不会运行用户工作负载的专用 control plane，你可以使用污点（taint）。`node-taint` 参数允许你配置带有污点的节点。以下是将节点污点添加到配置文件的示例：
```yaml
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
```

注意：所有节点都具有 `CriticalAddonsOnly` 污点时，NGINX Ingress 和 Metrics Server 插件将**不**部署。如果你的 Server 节点有该污点，这些插件将保持挂起状态，直到没有污点的 Agent 节点添加到集群中。

### 3. 启动其他 Server 节点
其他 Server 节点的启动与第一个节点非常相似，只是你必须指定 `server` 和 `token` 参数，以便它们可以成功连接到初始 Server 节点。

其他 Server 节点的 RKE2 配置文件示例：

```yaml
server: https://my-kubernetes-domain.com:9345
token: my-shared-secret
tls-san:
  - my-kubernetes-domain.com
  - another-kubernetes-domain.com

```

如前所述，你的 Server 节点总数必须为奇数。

### 4. 确认集群正常运行
在所有 Server 节点上启动了 `rke2 server` 进程后，确保集群已经正常启动，请运行以下命令：

```bash
/var/lib/rancher/rke2/bin/kubectl get nodes \
  --kubeconfig /etc/rancher/rke2/rke2.yaml
```

你应该看到 server 节点处于 Ready 状态。

:::note
默认情况下，任何 `kubectl` 命令都需要 root 用户访问权限，除非提供了 `RKE2_KUBECONFIG_MODE` 覆盖。有关更多信息，请参阅[集群访问页面](https://docs.rke2.io/cluster_access)。
:::

### 5. 可选：加入 Agent 节点

因为 RKE2 Server 节点默认是可调度的，所以 HA RKE2 Server 集群的最小节点数是三个 Server 节点和零个 Agent 节点。要添加用于运行应用程序和服务的节点，请将 Agent 节点加入到你的集群中。

在 HA 集群中加入 Agent 节点与[在单个 Server 集群中加入 Agent 节点](quickstart.md#linux-agent-worker-节点安装)是一样的。你只需要指定 Agent 应该注册的 URL 和要使用的 Token 即可。

```yaml
server: https://my-kubernetes-domain.com:9345
token: my-shared-secret
```
