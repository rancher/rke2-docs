---
title: Secret 加密
---

## Secret 加密配置

RKE2 支持静态加密 Secret，并将自动执行以下操作：

- 生成 AES-CBC 密钥
- 使用密钥生成加密配置文件：

```yaml
{
  "kind": "EncryptionConfiguration",
  "apiVersion": "apiserver.config.k8s.io/v1",
  "resources": [
    {
      "resources": [
        "secrets"
      ],
      "providers": [
        {
          "aescbc": {
            "keys": [
              {
                "name": "aescbckey",
                "secret": "xxxxxxxxxxxxxxxxxxx"
              }
            ]
          }
        },
        {
          "identity": {}
        }
      ]
    }
  ]
}
```

- 将配置作为 encryption-provider-config 传递给 Kubernetes APIServer

一旦启用，任何创建的 Secret 都将使用此密钥进行加密。请注意，如果你禁用加密，那么任何加密的 secret 将无法读取，直到你使用相同的密钥再次启用加密。

## Secret 加密工具
_从 v1.21.8+rke2r1 起可用_

RKE2 包含一个实用的[子命令](../reference/subcommands.md#secrets-encrypt) `secrets-encrypt`，它允许管理员执行以下任务：

- 添加新的加密密钥
- 轮换和删除加密密钥
- 重新加密 Secret

> **警告**：如果你在轮换 Secret 加密密钥时没有遵循正确的程序，数据可能永久丢失。因此，请谨慎操作。

### 单 Server 加密密钥轮换

要在单节点集群上轮换 Secret 加密密钥：

1. 准备：

   ```
   rke2 secrets-encrypt prepare
   ```

2. 重启 `kube-apiserver` pod：

   ```
   # Get the kube-apiserver container ID
   export CONTAINER_RUNTIME_ENDPOINT="unix:///var/run/k3s/containerd/containerd.sock"
   crictl ps --name kube-apiserver
   # Stop the pod
   crictl stop <CONTAINER_ID>
   ```

3. 轮换：

   ```
   rke2 secrets-encrypt rotate
   ```

4. 再次重启 `kube-apiserver` pod。
5. 重新加密：

   ```
   rke2 secrets-encrypt reencrypt
   ```


### 多 Server 加密密钥轮换
要在 HA 设置上轮换 Secret 加密密钥：

> **注意**：在本示例中，3 个 server 组成一个 HA 集群，它们分别称为 S1、S2、S3。虽然不是必需的，但建议你选择一个 Server 节点来运行 `secrets-encrypt` 命令。

1. 准备 S1

   ```
   rke2 secrets-encrypt prepare
   ```

2. 依次重启 S1、S2、S3
   ```
   systemctl restart rke2-server.service
   ```
   等待 systemctl 命令返回，然后重启下一个 server。

3. 轮换 S1

   ```
   rke2 secrets-encrypt rotate
   ```

4. 依次重启 S1、S2、S3

5. 在 S1 上重新加密

   ```
   rke2 secrets-encrypt reencrypt
   ```
   重新加密完成后，你可以通过 `journalctl -u rke2-server` 或 `rke2 secrets-encrypt status` 查看日志。完成后，状态将返回 `reencrypt_finished`。

6. 依次重启 S1、S2、S3

### Secret 加密状态
`secrets-encrypt status` 子命令会显示节点上 Secret 加密的当前状态信息。

单 Server 节点上的命令示例：
```
$ rke2 secrets-encrypt status
Encryption Status: Enabled
Current Rotation Stage: start
Server Encryption Hashes: All hashes match

Active  Key Type  Name
------  --------  ----
 *      AES-CBC   aescbckey

```

以下是另一个关于 HA 集群的例子，在轮换密钥后，重启 server 之前：
```
$ rke2 secrets-encrypt status
Encryption Status: Enabled
Current Rotation Stage: rotate
Server Encryption Hashes: hash does not match between node-1 and node-2

Active  Key Type  Name
------  --------  ----
 *      AES-CBC   aescbckey-2021-12-10T22:54:38Z
        AES-CBC   aescbckey

```

各部分详情如下：

- __Encryption Status__：显示节点上的 Secret 加密是禁用还是启用的
- __Current Rotation Stage__：表示节点上当前的轮换阶段  
   Stage 可能是：`start`，`prepare`，`rotate`，`reencrypt_request`，`reencrypt_active`，`reencrypt_finished`
- __Server Encryption Hashes__：对 HA 集群有用，表明所有 server 是否与本地文件处于同一阶段。这可用于确定在进入下一阶段之前是否需要重启 server。在上面的 HA 例子中，node-1 和 node-2 的哈希值不同，说明它们目前没有相同的加密配置。重启 server 将同步它们的配置。
- __Key Table__：汇总在节点上找到的 Secret 加密密钥的信息。
   * __Active__：“*”表示当前使用了哪些密钥（如果有的话）进行Secret 加密。Kubernetes 使用 active 密钥来加密新的 Secret。
   * __Key Type__：RKE2 仅支持 `AES-CBC` 密钥类型。详情请参见[此处](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#providers)。
   * __Name__：加密密钥的名称。