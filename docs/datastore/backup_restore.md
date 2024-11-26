---
title: Backup and Restore
---

:::warning Backup and restore for external databases or sqlite
Snapshots are for embedded etcd only, if you use another datastore with `datastore-endpoint` config go to [Experimental](backup_restore.md#external-db-backups-experimental)
:::

## Creating Snapshots

Snapshots are enabled by default.

The snapshot directory defaults to `/var/lib/rancher/rke2/server/db/snapshots`.

To configure the snapshot interval or the number of retained snapshots, refer to the [options.](#options)

In RKE2, snapshots are stored on each etcd node. If you have multiple etcd or etcd + control-plane nodes, you will have multiple copies of local etcd snapshots.

You can take a snapshot manually while RKE2 is running with the `etcd-snapshot` subcommand. For example: `rke2 etcd-snapshot save --name pre-upgrade-snapshot`.

## Cluster Reset

RKE2 enables a feature to reset the cluster to one member cluster by passing `--cluster-reset` flag, when passing this flag to rke2 server it will reset the cluster with the same data dir in place, the data directory for etcd exists in `/var/lib/rancher/rke2/server/db/etcd`, this flag can be passed in the events of quorum loss in the cluster.

To pass the reset flag, first you need to stop RKE2 service if its enabled via systemd:

```bash
systemctl stop rke2-server
rke2 server --cluster-reset
```

**Result:**  A message in the logs say that RKE2 can be restarted without the flags. Start rke2 again and it should start rke2 as a 1 member cluster.

### Restoring a Snapshot to Existing Nodes

When RKE2 is restored from backup, the old data directory will be moved to `/var/lib/rancher/rke2/server/db/etcd-old-%date%/`. RKE2 will then attempt to restore the snapshot by creating a new data directory and start etcd with a new RKE2 cluster with one etcd member.

1. You must stop RKE2 service on all server nodes if it is enabled via systemd. Use the following command to do so:
```bash
systemctl stop rke2-server
```

2. Next, you will initiate the restore from snapshot on the first server node with the following commands:
```bash
rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
```

3. Once the restore process is complete, start the rke2-server service on the first server node as follows:
```
systemctl start rke2-server
```

4. Remove the rke2 db directory on the other server nodes as follows:
```
rm -rf /var/lib/rancher/rke2/server/db
```

5. Start the rke2-server service on other server nodes with the following command:
```
systemctl start rke2-server
```

**Result:**  After a successful restore, a message in the logs says that etcd is running, and RKE2 can be restarted without the flags. Start RKE2 again, and it should run successfully and be restored from the specified snapshot.

When rke2 resets the cluster, it creates an empty file at `/var/lib/rancher/rke2/server/db/reset-flag`. This file is harmless to leave in place, but must be removed in order to perform subsequent resets or restores. This file is deleted when rke2 starts normally.


### Restoring a Snapshot to New Nodes

1. Back up the token server: `/var/lib/rancher/rke2/server/token` in case you will not use the same one. Token server is used to decrypt the bootstrap data inside the snapshot

2. Stop RKE2 service on all server nodes if it is enabled and initiate the restore from snapshot on the first server node with the following commands:
```
systemctl stop rke2-server
rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
  --token=<BACKED-UP-TOKEN-VALUE>
```

3. Once the restore process is complete, start the rke2-server service on the first server node as follows:
```
systemctl start rke2-server
```
:::warning
The node where the snapshot was taken will appear as NotReady
:::


4. You can continue to add new server and worker nodes to cluster per standard [RKE2 HA installation documentation](../install/ha.md#3-launch-additional-server-nodes).


### Other Notes on Restoring a Snapshot

* When performing a restore from backup, users do not need to restore a snapshot using the same version of RKE2 with which the snapshot was created. Users may restore using a more recent version. Be aware when changing versions at restore which etcd version is in use.

* By default, snapshots are enabled and are scheduled to be taken every 12 hours. The snapshots are written to `${data-dir}/server/db/snapshots` with the default `${data-dir}` being `/var/lib/rancher/rke2`.

## S3 Compatible API Support

RKE2 supports writing etcd snapshots to and restoring etcd snapshots from systems with S3-compatible APIs. S3 support is available for both on-demand and scheduled snapshots.

The arguments below exist for both the `server` and `etcd-snapshot` subcommands. 

| Options | Description |
| ----------- | --------------- |
| `--etcd-s3` | Enable backup to S3 |
| `--etcd-s3-endpoint` | S3 endpoint url |
| `--etcd-s3-endpoint-ca` | S3 custom CA cert to connect to S3 endpoint |
| `--etcd-s3-skip-ssl-verify` | Disables S3 SSL certificate validation |
| `--etcd-s3-access-key` |  S3 access key |
| `--etcd-s3-secret-key` | S3 secret key |
| `--etcd-s3-bucket` | S3 bucket name |
| `--etcd-s3-region` | S3 region / bucket location (optional). defaults to us-east-1 |
| `--etcd-s3-folder` | S3 folder |
| `--etcd-s3-insecure` | Disables S3 over HTTPS |
| `--etcd-s3-timeout` | S3 timeout. Defaults to 30s |

:::info Flag Aliases
For the `etcd-snapshot` subcommand, the `--etcd-s3` flags are aliased to `--s3`.
:::

To perform an on-demand etcd snapshot and save it to S3:

```
rke2 etcd-snapshot save \
  --s3 \
  --s3-bucket=<S3-BUCKET-NAME> \
  --s3-access-key=<S3-ACCESS-KEY> \
  --s3-secret-key=<S3-SECRET-KEY>
```

To perform an S3 etcd snapshot restore, first make sure that RKE2 isn't running. Then execute the following commands:

```
rke2 server \
  --cluster-reset \
  --etcd-s3 \
  --cluster-reset-restore-path=<SNAPSHOT-NAME> \
  --etcd-s3-bucket=<S3-BUCKET-NAME> \
  --etcd-s3-access-key=<S3-ACCESS-KEY> \
  --etcd-s3-secret-key=<S3-SECRET-KEY>
```

## Snapshot Configuration

### Options

These options can be set in the [configuration file](../install/configuration.md):

| Options | Description |
| ----------- | --------------- |
| `etcd-disable-snapshots` | Disable automatic etcd snapshots |
| `etcd-snapshot-schedule-cron` value  |  Snapshot interval time in cron spec. eg. every 4 hours `0 */4 * * *`. Defaults is every 12 hours `0 */12 * * *` |
| `etcd-snapshot-retention` value  | Number of snapshots to retain. Defaults to 5 |
| `etcd-snapshot-dir` value  | Directory to save db snapshots. Default location: `${data-dir}/db/snapshots` |
| `cluster-reset`  | Forget all peers and become sole member of a new cluster. This can also be set with the environment variable `[$RKE2_CLUSTER_RESET]` |
| `cluster-reset-restore-path` value | Path to snapshot file to be restored |
| `etcd-snapshot-compress`        | Compress etcd snapshots |

### List Snapshots

You can list local snapshots with the `etcd-snapshot ls` subcommand. 

### Prune Snapshots

Snapshots are pruned automatically when the number of snapshots exceeds the configured retention count. The oldest snapshots are removed first. 

You can manually prune "on-demand" snapshots down to a smaller amount using the following command:
```
rke2 etcd-snapshot prune --etcd-snapshot-retention <NUM-OF-SNAPSHOTS-TO-RETAIN>
```

You can manually prune "scheduled" snapshots down to a smaller amount using the following command:
```
rke2 etcd-snapshot prune --name etcd-snapshot --etcd-snapshot-retention <NUM-OF-SNAPSHOTS-TO-RETAIN>
```

## External DB Backups (Experimental)

:::warning
In addition to backing up the datastore itself, you must also back up the server token file at `/var/lib/rancher/rke2/server/token`.
You must restore this file, or pass its value into the `token` option, when restoring from backup.
If you do not use the same token value when restoring, the snapshot will be unusable, as the token is used to encrypt confidential data within the datastore itself.
:::

### Backup and Restore with SQLite

No special commands are required to back up or restore the SQLite datastore.

* To back up the SQLite datastore, take a copy of `/var/lib/rancher/rke2/server/db/`.
* To restore the SQLite datastore, restore the contents of `/var/lib/rancher/rke2/server/db` (and the token, as discussed above).

### Backup and Restore with External Datastore

When an external datastore is used, backup and restore operations are handled outside of RKE2. The database administrator will need to back up the external database, or restore it from a snapshot or dump.

We recommend configuring the database to take recurring snapshots.

For details on taking database snapshots and restoring your database from them, refer to the official database documentation:

- [Official MySQL documentation](https://dev.mysql.com/doc/refman/8.0/en/replication-snapshot-method.html)
- [Official PostgreSQL documentation](https://www.postgresql.org/docs/8.3/backup-dump.html)
- [Official etcd documentation](https://etcd.io/docs/latest/op-guide/recovery/)

