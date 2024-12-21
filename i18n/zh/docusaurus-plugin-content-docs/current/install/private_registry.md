---
title: "Containerd 镜像仓库配置"
---

Containerd 可以配置为连接到私有镜像仓库，并使用仓库在每个节点上拉取私有镜像。

启动时，RKE2 会检查 `/etc/rancher/rke2/` 中是否存在 `registries.yaml` 文件，并指示 containerd 使用该文件中定义的镜像仓库。如果你想使用私有的镜像仓库，你需要在每个使用镜像仓库的节点上以 root 身份创建这个文件。

请注意，server 节点默认是可以调度的。如果你没有在 server 节点上设置污点，而且希望在 server 节点上运行工作负载，请确保在每个 server 节点上创建 `registries.yaml` 文件。

**注意**：在 RKE2 v1.20 之前，初始 RKE2 节点引导不支持 containerd 镜像仓库配置，仅可用于节点加入集群后启动的 Kubernetes 工作负载。如果你计划使用此 containerd 镜像仓库功能来引导节点，请参阅[离线安装文档](./airgap.md)。

Containerd 中的配置可以用于通过 TLS 连接到私有镜像仓库，也可以与启用验证的镜像仓库连接。下一节将解释 `registries.yaml` 文件，并给出在 RKE2 中使用私有镜像仓库配置的不同例子。

## 镜像仓库配置文件

该文件由两个主要部分组成：

- mirrors
- configs

### Mirrors

Mirrors 是用于定义私有镜像仓库名称和端点的指令。私有镜像仓库可以用作默认 docker.io 镜像仓库的本地 mirror，也可以用于在名称中指定了镜像仓库的镜像。

例如，以下配置将从位于 `https://registry.example.com:5000` 的私有镜像仓库中拉取 `library/busybox:latest` 和 `registry.example.com/library/busybox:latest`：

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
  registry.example.com:
    endpoint:
      - "https://registry.example.com:5000"
```

每个 mirror 都必须有一个名称和一组端点。从镜像仓库中拉取镜像时，containerd 会逐个尝试这些端点 URL，并使用第一个有效的 URL。

**注意**：如果没有配置端点，containerd 假定镜像仓库可以通过 HTTPS 端口 443 进行匿名访问，并且使用主机操作系统信任的证书。有关更多信息，请参阅 [containerd 文档](https://github.com/containerd/containerd/blob/master/docs/cri/registry.md#configure-registry-endpoint)。

#### 重写

每个镜像都可以有一组重写。重写可以根据正则表达式来改变镜像的标签。如果 mirror 仓库中的组织/项目结构与上游不同，这将很有用。

例如，以下配置将从 `registry.example.com:5000/mirrorproject/rancher-images/rke2-runtime:v1.23.5-rke2r1` 无感知地拉取 `rancher/rke2-runtime:v1.23.5-rke2r1` 镜像：

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
    rewrite:
      "^rancher/(.*)": "mirrorproject/rancher-images/$1"
```

### Configs

configs 部分定义了每个 mirror 的 TLS 和凭证配置。对于每个 mirror，你可以定义 `auth` 和/或 `tls`。TLS 部分包括：

| 指令 | 描述 |
----------|------------
| `cert_file` | 客户端证书路径，用于向镜像仓库进行身份验证 |
| `key_file` | 客户端密钥路径，用于向镜像仓库进行身份验证 |
| `ca_file` | 定义用于验证镜像仓库服务器证书文件的 CA 证书路径 |
| `insecure_skip_verify` | 定义是否应跳过镜像仓库的 TLS 验证的布尔值 |

凭证由用户名/密码或身份验证令牌组成：

- 用户名：私有镜像仓库基本身份验证的用户名
- 密码：私有镜像仓库基本身份验证的用户密码
- auth：私有镜像仓库基本身份验证的身份验证令牌

以下是在不同模式下使用私有镜像仓库的基本例子：

### 使用 TLS

下面的例子展示了使用 TLS 时，如何在每个节点上配置 `/etc/rancher/rke2/registries.yaml`。

*具有身份验证：*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    auth:
      username: xxxxxx # this is the registry username
      password: xxxxxx # this is the registry password
    tls:
      cert_file:            # path to the cert file used to authenticate to the registry
      key_file:             # path to the key file for the certificate used to authenticate to the registry
      ca_file:              # path to the ca file used to verify the registry's certificate
      insecure_skip_verify: # may be set to true to skip verifying the registry's certificate
```

*没有身份验证：*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    tls:
      cert_file:            # path to the cert file used to authenticate to the registry
      key_file:             # path to the key file for the certificate used to authenticate to the registry
      ca_file:              # path to the ca file used to verify the registry's certificate
      insecure_skip_verify: # may be set to true to skip verifying the registry's certificate
```

### 没有 TLS

以下示例展示了_不_使用 TLS 时，如何在每个节点上配置 `/etc/rancher/rke2/registries.yaml`。

*具有身份验证的纯文本 HTTP：*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry.example.com:5000"
configs:
  "registry.example.com:5000":
    auth:
      username: xxxxxx # this is the registry username
      password: xxxxxx # this is the registry password
```

*没有身份验证的纯文本 HTTP：*

```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry.example.com:5000"
```

> 如果使用不带 TLS 的纯文本 HTTP 镜像仓库，则需要指定 `http://` 作为端点 URI 方案，否则会默认为 `https://`。

要使镜像仓库更改生效，你需要在节点上启动 RKE2 之前配置此文件，或者在每个配置的节点上重启 RKE2。
