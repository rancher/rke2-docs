---
title: Rolling Back RKE2
---

You can roll back the RKE2 Kubernetes version after an upgrade, using a combination of RKE2 binary downgrade and datastore restoration. Rollback can be performed on clusters of all types, including a single-node SQLite, an external datastore, or an embedded etcd. When rolling back to a previous Kubernetes minor version, you must have a datastore snapshot taken on the Kubernetes minor version you wish to roll back to.

:::warning
If you cannot restore the database, you cannot roll back to a previous minor version.
:::

## Important Considerations

- **Backups:** Before upgrading, ensure you have a valid database or etcd snapshot from your cluster running the older version of RKE2. Without a backup, a rollback is impossible.
- **Potential Data Loss:** The `rke2-killall.sh` script forcefully terminates RKE2 processes and may result in data loss if applications are not properly shut down.
- **Version Specifics:** Always verify RKE2 and component versions before and after the rollback.

## Rolling Back an RKE2 Cluster

<Tabs>
<TabItem value='SQLite'>

To roll back an RKE2 cluster when using a SQLite database, replace the `.db` file with the copy of the `.db` file you made while backing up your database.

</TabItem>

<TabItem value='Embedded etcd' default>

To roll back an RKE2 cluster when using an embedded etcd (default), follow these steps:

1. If the cluster is running and the Kubernetes API is available, gracefully stop workloads by draining all nodes:

    ```bash
    kubectl drain --ignore-daemonsets --delete-emptydir-data <NODE-ONE-NAME> <NODE-TWO-NAME> <NODE-THREE-NAME> ...
    ```

2. On each node, stop the RKE2 service and all running pod processes:

    ```bash
    rke2-killall.sh
    ```

3. On each node, roll back the RKE2 binary to the previous version.

    - Clusters with Internet Access:

      - Server nodes:

        ```bash
        curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vX.Y.Zrke2r1 sh -
        ```

      - Agent nodes:

        ```bash
        curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vX.Y.Zrke2r1 INSTALL_RKE2_TYPE=agent sh -
        ```

    - Air-gapped Clusters:

      - Download the artifacts and run the [install script](../install/airgap.md#2-install-rke2) locally.

4. On the first server node or the node without a `server:` entry in its [RKE2 config file](../install/configuration.md), initiate the cluster restore. Refer to the [Snapshot Restore Steps](../datastore/backup_restore.md#restoring-a-snapshot-to-existing-nodes) for more information:

    ```bash
    rke2 server --cluster-reset --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
    ```

    :::warning
    This overwrites all data in the etcd datastore. Verify the snapshot's integrity before restoring. Be aware that large snapshots can take a long time to restore.
    :::

5. Start the RKE2 service on the first server node:

    ```bash
    systemctl start rke2-server
    ```

6. On the other server nodes, remove the RKE2 database directory:

    ```bash
    rm -rf /var/lib/rancher/rke2/server/db
    ```

7. Start the RKE2 service on the other server nodes:

    ```bash
    systemctl start rke2-server
    ```

8. Start the RKE2 service on all agent nodes:

    ```bash
    systemctl start rke2-agent
    ```

9. Verify the RKE2 service status with `systemctl status rke2-server` or `systemctl status rke2-agent`.

</TabItem>

<TabItem value='External Database'>

To roll back an RKE2 cluster when using an external database (e.g., PostgreSQL, MySQL), follow these steps:

1. If the cluster is running and the Kubernetes API is available, gracefully stop workloads by draining all nodes:

    ```bash
    kubectl drain --ignore-daemonsets --delete-emptydir-data <NODE-ONE-NAME> <NODE-TWO-NAME> <NODE-THREE-NAME> ...
    ```

    :::note

    This process may disrupt running applications.

    :::

2. On each node, stop the RKE2 service and all running pod processes:

    ```bash
    rke2-killall.sh
    ```

3. Restore a database snapshot taken before upgrading RKE2 and verify the integrity of the database. For example, if you're using PostgreSQL, run the following command:

    ```bash
    pg_restore -U <DB-USER> -d <DB-NAME> <BACKUP-FILE>
    ```

4. On each node, roll back the RKE2 binary to the previous version.

    - Clusters with Internet Access:

      - Server nodes:

        ```bash
        curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vX.Y.Zrke2r1 sh -
        ```

      - Agent nodes:

        ```bash
        curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vX.Y.Zrke2r1 INSTALL_RKE2_TYPE=agent sh -
        ```

    - Air-gapped Clusters:

      - Download the artifacts and run the [install script](../install/airgap.md#2-install-rke2) locally.

5. Start the RKE2 service on each node:

    ```bash
    systemctl start rke2-server #or rke2-agent
    ```

6. Verify the RKE2 service status with `systemctl status rke2-server` or `systemctl status rke2-agent`.

</TabItem>
</Tabs>

## Verification

After the rollback, verify the following:

- RKE2 version: `rke2 --version`
- Kubernetes cluster health: `kubectl get nodes`
- Application functionality.
- Check the RKE2 logs for errors.
