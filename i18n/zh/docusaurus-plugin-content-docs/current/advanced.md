---
# sidebar_label:
title: "高级选项和配置"
---


本文描述了用于运行和管理 RKE2 的高级设置：

## 证书轮换

默认情况下，RKE2 中的证书在 12 个月后过期。

如果证书已经过期或剩余的时间不足 90 天，则在 RKE2 重启时轮换证书。

从 v1.21.8+rke2r1 开始，你可以手动轮换证书。为此，建议先停止 rke2-server 进程，然后轮换证书，最后再次启动该进程：
```sh
systemctl stop rke2-server
rke2 certificate rotate
systemctl start rke2-server
```
你也可以通过传递 `--service` 标志来轮换单个服务，例如：`rke2 certificate rotate --service api-server`。有关详细信息，请参阅 [certificate 子命令](./reference/subcommands.md#certificate)。

## 自动部署清单

在 `/var/lib/rancher/rke2/server/manifests` 中找到的任何文件都会以类似于 `kubectl apply` 的方式自动部署到 Kubernetes。

有关使用清单目录部署 Helm Chart 的信息，请参阅 [Helm](helm.md) 章节。

## 配置 Containerd

RKE2 会在 `/var/lib/rancher/rke2/agent/etc/containerd/config.toml` 中为 containerd 生成 `config.toml`。

如果要对这个文件进行高级定制，你可以在同一目录中创建另一个名为 `config.toml.tmpl` 的文件，此文件将会代替默认设置。

`config.toml.tmpl` 是一个 Go 模板文件，并且 `config.Node` 结构会被传递给模板。有关如何使用该结构自定义配置文件的示例，请参见[此模板](https://github.com/k3s-io/k3s/blob/master/pkg/agent/templates/templates.go#L16-L32)。

## 配置 HTTP 代理

如果你运行 RKE2 的环境中只通过 HTTP 代理进行外部连接，你可以在 RKE2 的 systemd 服务上配置代理。RKE2 将使用这些代理设置，并向下传递到嵌入式 containerd 和 kubelet。

将必要的 `HTTP_PROXY`、`HTTPS_PROXY` 和 `NO_PROXY` 变量添加到 systemd 服务的环境文件中，通常是：

- `/etc/default/rke2-server`
- `/etc/default/rke2-agent`

RKE2 会自动将集群内部 Pod 和 Service IP 范围以及集群 DNS 域添加到 `NO_PROXY` 条目列表中。你需要确保 Kubernetes 节点本身使用的 IP 地址范围（即节点的公共和私有 IP）包含在 `NO_PROXY` 列表中，或者可以通过代理访问节点。

```
HTTP_PROXY=http://your-proxy.example.com:8888
HTTPS_PROXY=http://your-proxy.example.com:8888
NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

如果你想在不影响 RKE2 和 Kubelet 的情况下为 containerd 配置代理，你可以在变量前加上 `CONTAINERD_`：

```
CONTAINERD_HTTP_PROXY=http://your-proxy.example.com:8888
CONTAINERD_HTTPS_PROXY=http://your-proxy.example.com:8888
CONTAINERD_NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

## 节点标签和污点

RKE2 Agent 可以通过 `node-label` 和 `node-taint` 选项来配置，它们会为 kubelet 添加标签和污点。这两个选项只能在注册时添加标签和/或污点，因此它们只能被添加一次，之后不能再通过运行 rke2 命令来移除。

如果你想在节点注册后更改节点标签和污点，你需要使用 `kubectl`。关于如何添加[污点](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/)和[节点标签](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/#add-a-label-to-a-node)的详细信息，请参阅官方 Kubernetes 文档。

# Agent 节点注册的工作原理

Agent 节点通过 `rke2 agent` 进程发起的 WebSocket 连接进行注册，连接由作为 agent 进程一部分运行的客户端负载均衡器维护。

Agent 将使用 join token 的集群 Secret 以及随机生成的节点密码注册到 Server，密码存储在 `/etc/rancher/node/password` 中。Server 会将各个节点的密码存储为 Kubernetes Secret，后续的任何尝试都必须使用相同的密码。节点密码 Secret 存储在 `kube-system` 命名空间中，名称使用 `<host>.node-password.rke2` 模板。当相应的 Kubernetes 节点被删除时，这些 Secret 也会被删除。

注意：在 RKE2 v1.20.2 之前，Server 将密码存储在磁盘上的 `/var/lib/rancher/rke2/server/cred/node-passwd` 中。

如果 Agent 的 `/etc/rancher/node` 目录被删除，你需要在启动前为 Agent 重新创建密码文件，或者从 Server 或 Kubernetes 集群中删除该条目（取决于 RKE2版本）。

## 使用安装脚本启动 Server

安装脚本为 systemd 提供了单元，但默认情况下不启用或启动该服务。

使用 systemd 运行时，日志将在 `/var/log/syslog` 中创建，你可以通过 `journalctl -u rke2-server` 或 `journalctl -u rke2-agent` 查看日志。

使用安装脚本安装的示例：

```bash
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server
systemctl start rke2-server
```

:::note
中国用户，可以使用以下方法加速安装：
```
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
systemctl enable rke2-server
systemctl start rke2-server
```
:::

## 禁用 Server Chart

在集群引导期间与 `rke2` 绑在一起的 Server Chart 可以被禁用并替换。常见的用例是替换捆绑的 `rke2-ingress-nginx` Chart。

要禁用任何捆绑的系统 Chart，请在引导之前在配置文件中设置 `disable` 参数。要禁用的系统 Chart 完整列表：

- `rke2-canal`
- `rke2-coredns`
- `rke2-ingress-nginx`
- `rke2-metrics-server`

请注意，由于 server Chart 对集群的操作非常重要，因此集群操作人员需要确保已禁用或更换组件。有关集群中各个系统 Chart 角色的更多信息，请参阅[架构概述](./architecture.md#server-charts)。

## 在分类的 AWS 区域或具有自定义 AWS API 端点的网络上安装

在公共 AWS 区域，为确保 RKE2 支持云并且能够自动配置某些云资源，请使用以下内容配置 RKE2：

```yaml
# /etc/rancher/rke2/config.yaml
cloud-provider-name: aws
```

在分类区域（例如 SC2S 或 C2S）上安装 RKE2 时，你需要注意一些额外的条件，从而确保 RKE2 知道如何以及在哪里与适当的 AWS 端点进行安全通信。

0. 确保满足所有常见的 AWS 云提供商[先决条件](https://rancher.com/docs/rke/latest/en/config-options/cloud-providers/aws/)。它们与区域无关，并且始终是必需的。

1. 通过创建 `cloud.conf` 文件确保 RKE2 知道将 `ec2` 和 `elasticloadbalancing` 服务的 API 请求发送到哪里，以下是 `us-iso-east-1` (C2S) 区域的示例：

```yaml
# /etc/rancher/rke2/cloud.conf
[Global]
[ServiceOverride "ec2"]
  Service=ec2
  Region=us-iso-east-1
  URL=https://ec2.us-iso-east-1.c2s.ic.gov
  SigningRegion=us-iso-east-1
[ServiceOverride "elasticloadbalancing"]
  Service=elasticloadbalancing
  Region=us-iso-east-1
  URL=https://elasticloadbalancing.us-iso-east-1.c2s.ic.gov
  SigningRegion=us-iso-east-1
```

如果你使用的是[私有 AWS 端点](https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-services-overview.html)，请确保为每个私有端点使用适当的 `URL`。

2. 确保将适当的 AWS CA 包加载到系统的根 CA 信任库中。该操作可能已完成，具体取决于你使用的 AMI。

```bash
# on CentOS/RHEL 7/8
cp <ca.pem> /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

3. 使用在步骤 1 中创建的自定义 `cloud.conf` 配置 RKE2，以使用 `aws` 云提供商：

```yaml
# /etc/rancher/rke2/config.yaml
...
cloud-provider-name: aws
cloud-provider-config: "/etc/rancher/rke2/cloud.conf"
...
```

4. [正常安装](install/methods.md) RKE2（很可能使用[离线](install/airgap.md)安装）。

5. 使用 `kubectl get nodes --show-labels` 确认集群节点标签上是否存在 AWS 元数据，从而验证安装是否成功。

## Control Plane 组件资源请求/限制

以下选项在 RKE2 的 `server` 子命令下可用。这些选项允许为 RKE2 中的 control plane 组件指定 CPU 请求和限制。

```
   --control-plane-resource-requests value       (components) Control Plane resource requests [$RKE2_CONTROL_PLANE_RESOURCE_REQUESTS]
   --control-plane-resource-limits value         (components) Control Plane resource limits [$RKE2_CONTROL_PLANE_RESOURCE_LIMITS]
```

值是 `[controlplane-component]-(cpu|memory)=[desired-value]` 格式的逗号分隔列表。`controlplane-component` 的值可能是：
```
kube-apiserver
kube-scheduler
kube-controller-manager
kube-proxy
etcd
cloud-controller-manager
```

因此，示例配置值可能如下所示：

```yaml
# /etc/rancher/rke2/config.yaml
control-plane-resource-requests:
  - kube-apiserver-cpu=500m
  - kube-apiserver-memory=512M
  - kube-scheduler-cpu=250m
  - kube-scheduler-memory=512M
  - etcd-cpu=1000m
```

CPU/内存的单位值与 Kubernetes 资源单位相同（参见 [Kubernetes 中的资源限制](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes)）。

## 额外的 control plane 组件卷挂载

以下选项在 RKE2 的 `server` 子命令下可用。些选项指定主机路径，将节点文件系统中的目录挂载到与前缀名称相对应的静态 Pod 组件中。

| 标志 | ENV VAR |
| --- | --- |
| `--kube-apiserver-extra-mount` | RKE2_KUBE_APISERVER_EXTRA_MOUNT | kube-apiserver extra volume mounts |
| `--kube-scheduler-extra-mount` | RKE2_KUBE_SCHEDULER_EXTRA_MOUNT | kube-scheduler extra volume mounts |
| `--kube-controller-manager-extra-mount` | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_MOUNT |
| `--kube-proxy-extra-mount` | RKE2_KUBE_PROXY_EXTRA_MOUNT |
| `--etcd-extra-mount` | RKE2_ETCD_EXTRA_MOUNT |
| `--cloud-controller-manager-extra-mount` | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_MOUNT |


### RW 主机路径卷挂载
`/source/volume/path/on/host:/destination/volume/path/in/staticpod`

### RO 主机路径卷挂载
要将卷挂载为只读，在卷挂载的最后加上 `:ro`。
`/source/volume/path/on/host:/destination/volume/path/in/staticpod:ro`

通过在配置文件中以数组形式传递标志值，可以为同一个组件指定多个卷挂载。

```yaml
# /etc/rancher/rke2/config.yaml
kube-apiserver-extra-mount:
   - "/tmp/foo.yaml:/root/foo.yaml"
   - "/tmp/bar.txt:/etc/bar.txt:ro"
```

## 额外的 Control Plane 组件环境变量

以下选项在 RKE2 的 `server` 子命令下可用。这些选项以标准格式指定额外的环境变量，即 `KEY=VALUE`，用于与前缀名称相对应的静态 Pod 组件。

| 标志 | ENV VAR |
| --- | --- |
| `--kube-apiserver-extra-env` | RKE2_KUBE_APISERVER_EXTRA_ENV |
| `--kube-scheduler-extra-env` | RKE2_KUBE_SCHEDULER_EXTRA_ENV |
| `--kube-controller-manager-extra-env` | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_ENV |
| `--kube-proxy-extra-env` | RKE2_KUBE_PROXY_EXTRA_ENV |
| `--etcd-extra-env` | RKE2_ETCD_EXTRA_ENV |
| `--cloud-controller-manager-extra-env` | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_ENV |

通过在配置文件中以数组形式传递标志值，可以为同一个组件指定多个环境变量。

```yaml
# /etc/rancher/rke2/config.yaml
kube-apiserver-extra-env:
  - "MY_FOO=FOO"
  - "MY_BAR=BAR"
kube-scheduler-extra-env: "TZ=America/Los_Angeles"
```
