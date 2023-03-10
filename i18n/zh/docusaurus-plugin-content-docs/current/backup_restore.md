---
title: "Etcd 备份与恢复"
---

# Etcd 备份与恢复

在本节中，你将学习如何创建 RKE2 集群数据的备份以及如何使用备份恢复集群。

**注意**：`/var/lib/rancher/rke2` 是 RKE2 的默认数据目录，但是你可以通过 `data-dir` 参数自行进行配置。

### 创建快照

快照是默认启动的。

快照目录默认为 `/var/lib/rancher/rke2/server/db/snapshots`。

要配置快照间隔或保留快照的数量，请参阅[选项](#选项)。

在 RKE2 中，快照会存储在每个 etcd 节点上。如果你有多个 etcd 或 etcd + control plane 节点，你将拥有本地 etcd 快照的多个副本。

你可以在 RKE2 运行时使用 `etcd-snapshot` 子命令手动执行快照。例如：`rke2 etcd-snapshot save --name pre-upgrade-snapshot`。有关 etcd-snapshot 子命令的完整列表，请参阅[子命令页面](reference/subcommands.md#etcd-snapshot)。

## 集群重置

RKE2 启用了一项功能，可以通过传递 `--cluster-reset` 标志将集群重置为一个成员集群。将此标志传递给 RKE2 server 时，它将使用相同的数据目录重置集群，数据 etcd 的目录存在于 `/var/lib/rancher/rke2/server/db/etcd` 中，这个标志可以在集群丢失仲裁时传递。

要传递重置标志，首先你需要停止 RKE2 服务（如果 RKE2 是通过 systemd 启用的）：

```bash
systemctl stop rke2-server
rke2 server --cluster-reset
```

**结果**：日志中的一条消息表示 RKE2 可以在没有标志的情况下重新启动。再次启动 RKE2，它应该将 RKE2 作为一个成员集群启动。

### 将快照恢复到现有节点

使用备份恢复 RKE2 时，旧的数据目录将被移动到 `/var/lib/rancher/rke2/server/db/etcd-old-%date%/`。然后 RKE2 将尝试通过创建一个新的数据目录来恢复快照，并使用一个具有一个 etcd 成员的新 RKE2 集群启动 etcd。

1. 如果通过 systemd 启用，则必须在所有 Server 节点上停止 RKE2 服务。使用以下命令执行此操作：
```bash
systemctl stop rke2-server
```

2. 接下来，使用以下命令在第一个 Server 节点上启动快照恢复：
```bash
rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
```

3. 恢复完成后，在第一个 Server 节点上启动 rke2-server 服务，如下所示：
```
systemctl start rke2-server
```

4. 删除其他 Server 节点上的 rke2 db 目录，如下：
```
rm -rf /var/lib/rancher/rke2/server/db
```

5. 使用以下命令在其他 Server 节点上启动 rke2-server 服务：
```
systemctl start rke2-server
```

**结果**：成功恢复后，日志中的一条消息表明 etcd 正在运行，RKE2 可以在没有标志的情况下重启。再次启动 RKE2，RKE2 应该会成功运行并通过指定的快照恢复。

RKE2 重置集群时会在 `/var/lib/rancher/rke2/server/db/reset-flag` 中创建一个空文件。该文件留在原地是没有问题的，但必须删除它才能执行后续的重置或恢复。RKE2 正常启动时会删除该文件。


### 将快照恢复到新节点

**警告**：对于 rke2 v.1.20.9 及之前的所有版本，由于存在一个已知问题，即引导数据可能无法在恢复时保存（步骤 1 -下面的 3 假定了这种情况），因此你需要先备份和恢复证书。请参阅下面的[注意事项](#恢复快照的其他注意事项)，了解特定版本的恢复注意事项。

1. 备份 `/var/lib/rancher/rke2/server/cred`、`/var/lib/rancher/rke2/server/tls`、`/var /lib/rancher/rke2/server/token` 和 `/etc/rancher`

2. 将上面步骤 1 中的证书恢复到第一个新 Server 节点。

3. 在第一个新 Server 节点上安装 rke2 v1.20.8+rke2r1，如下所示：
```
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.20.8+rke2r1" sh -
```

4. 如果 RKE2 已启用，请停止所有 Server 节点上的 RKE2 服务，并使用以下命令在第一个 Server 节点上启动快照恢复：
```
systemctl stop rke2-server
rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
```

5. 恢复完成后，在第一个 Server 节点上启动 rke2-server 服务，如下所示：
```
systemctl start rke2-server
```

6. 你可以根据标准 [RKE2 HA 安装文档](install/ha.md#3-启动其他-server-节点)继续向集群添加新的 Server 和 Worker 节点。


### 恢复快照的其他注意事项

* 执行备份恢复时，用户不需要使用创建快照时使用的 RKE2 版本。用户可以使用更新的版本进行恢复。如果你在恢复时更改版本，请注意正在使用哪个 etcd 版本。

* 快照默认启用，并且每 12 小时获取一次。快照写入到 `${data-dir}/server/db/snapshots`，默认 `${data-dir}` 为 `/var/lib/rancher /rke2`。

#### rke2 v1.20.11+rke2r1 的要求

* 使用备份将 RKE2 恢复到使用 rke2 v1.20.11+rke2r1 的新节点时，请运行 `rke2-killall.sh` 确保所有 pod 在初始恢复后已停止，如下所示：

   ```bash
   curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.20.11+rke2r1
   rke2 server \
   --cluster-reset \
   --cluster-reset-restore-path=<PATH-TO-SNAPSHOT> \
   --token=<token used in the original cluster>
   rke2-killall.sh
   ```
* 恢复完成后，在第一个 Server 节点上启动 rke2-server 服务，如下所示：
   ```
   systemctl enable rke2-server
   systemctl start rke2-server
   ```

### 选项

这些选项可以在配置文件中设置：

| 选项 | 描述 |
| ----------- | --------------- |
| `etcd-disable-snapshots` | 禁用自动 etcd 快照 |
| `etcd-snapshot-schedule-cron` value | cron 规范中的快照间隔时间。eg. 每 4 小时 `0 */4 * * *`（默认值：`0 */12 * * *`） |
| `etcd-snapshot-retention` value | 要保留的快照数量（默认值：5） |
| `etcd-snapshot-dir` value | 保存数据库快照的目录。（默认位置：`${data-dir}/db/snapshots`） |
| `cluster-reset` | 忘记所有对等点，成为新集群的唯一成员。也可以使用环境变量 `[$RKE2_CLUSTER_RESET]` 进行设置。 |
| `cluster-reset-restore-path` value | 要恢复的快照文件路径 |

### S3 兼容 API 支持

RKE2 支持向具有 S3 兼容 API 的系统写入 etcd 快照和从系统中恢复 etcd 快照。S3 支持按需和计划快照。

以下参数已添加到 `server` 子命令中。`etcd-snapshot` 子命令也存在这些标志，但是删除了 `--etcd-s3` 部分以避免冗余。

| 选项 | 描述 |
| ----------- | --------------- |
| `--etcd-s3` | 启用备份到 S3 |
| `--etcd-s3-endpoint` | S3 端点网址 |
| `--etcd-s3-endpoint-ca` | S3 自定义 CA 证书，用于连接到 S3 端点 |
| `--etcd-s3-skip-ssl-verify` | 禁用 S3 SSL 证书验证 |
| `--etcd-s3-access-key` | S3 access key |
| `--etcd-s3-secret-key` | S3 secret key |
| `--etcd-s3-bucket` | S3 存储桶名称 |
| `--etcd-s3-region` | S3 区域/存储桶位置（可选）。默认为 us-east-1 |
| `--etcd-s3-folder` | S3 文件夹 |

执行按需的 etcd 快照并将其保存到 S3：

```
rke2 etcd-snapshot \
  --s3 \
  --s3-bucket=<S3-BUCKET-NAME> \
  --s3-access-key=<S3-ACCESS-KEY> \
  --s3-secret-key=<S3-SECRET-KEY>
```

要从 S3 中执行按需的 etcd 快照还原，首先确保 RKE2 没有运行。然后运行以下命令：

```
rke2 server \
  --cluster-reset \
  --etcd-s3 \
  --cluster-reset-restore-path=<SNAPSHOT-NAME> \
  --etcd-s3-bucket=<S3-BUCKET-NAME> \
  --etcd-s3-access-key=<S3-ACCESS-KEY> \
  --etcd-s3-secret-key=<S3-SECRET-KEY>
```
