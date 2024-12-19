---
title: Secrets Encryption
---

## Secrets Encryption Config

RKE2 supports [encrypting secrets at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/), and will do the following automatically:

- Generate an AES-CBC key
- Generate an encryption config file with the generated key:

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

- Pass the config to the Kubernetes APIServer as encryption-provider-config

Once enabled any created secret will be encrypted with this key. Note that if you disable encryption then any encrypted secrets will not be readable until you enable encryption again using the same key.

## Secrets Encryption Tool

:::info Version Gate
Available as of [v1.21.8+rke2r1](https://github.com/rancher/rke2/releases/tag/v1.21.8%2Brke2r1)
:::

RKE2 contains a subcommand `secrets-encrypt`, which allows administrators to perform the following tasks:

- Adding new encryption keys
- Rotating and deleting encryption keys
- Reencrypting secrets

:::danger
Failure to follow proper procedure when rotating secrets encryption keys can cause permanent data loss. [Creating a snapshot](../datastore/backup_restore.md) before rotating is recommended. Proceed with caution.
:::

<!-- ### New Encryption Key Rotation

:::warning Experimental Version Gate
Available as of [v1.28.1+rke2r1](https://github.com/rancher/rke2/releases/tag/v1.28.1%2Brke2r1). This new version of the tool utilizes K8s [automatic config reloading](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#configure-automatic-reloading) which is currently in beta. GA is expected in v1.29.0

For older releases, see [Encryption Key Rotation Classic](#encryption-key-rotation-classic)
:::

<Tabs groupId="se">
<TabItem value="Single-Server" default>

To rotate secrets encryption keys on a single-server cluster:

1. Rotate secrets encryption keys
    ```
    rke2 secrets-encrypt rotate-keys
    ```

2. Wait for reencryption to finish. Watch the server logs, or wait for:
    ```bash
    $ rke2 secrets-encrypt status
    Encryption Status: Enabled
    Current Rotation Stage: reencrypt_finished
    ```

</TabItem>
<TabItem value="High-Availability">

To rotate secrets encryption keys on HA setups:

:::note
In this example, 3 servers are used to for a HA cluster, referred to as S1, S2, S3. It is recommended that you pick one server node from which to run the `secrets-encrypt` commands.
:::

1. Rotate secrets encryption keys on S1

    ```bash
    rke2 secrets-encrypt rotate-keys
    ```

2. Wait for reencryption to finish. Watch the server logs, or wait for:
    ```bash
    $ rke2 secrets-encrypt status
    Encryption Status: Enabled
    Current Rotation Stage: reencrypt_finished
    ```
    :::info
    RKE2 will reencrypt ~5 secrets per second. Clusters with large # of secrets can take several minutes to reencrypt. You can track progress in the server logs.
    ::: 

3. Sequentially Restart RKE2 on S1, S2, S3
    ```
    systemctl restart rke2-server.service
    ```
    Wait for the systemctl command to return before restarting the next server.


</TabItem>
</Tabs> -->

### Encryption Key Rotation Classic

<Tabs groupId="se" queryString>
<TabItem value="Single-Server" default>

To rotate secrets encryption keys on a single-node cluster:

1. Prepare:

    ```
    rke2 secrets-encrypt prepare
    ```

2. Restart the `kube-apiserver` pod:

    ```
    # Get the kube-apiserver container ID
    export CONTAINER_RUNTIME_ENDPOINT="unix:///var/run/k3s/containerd/containerd.sock"
    crictl ps --name kube-apiserver
    # Stop the pod
    crictl stop <CONTAINER_ID>
    ```

3. Rotate:

    ```
    rke2 secrets-encrypt rotate
    ```

4. Restart the `kube-apiserver` pod again
5. Reencrypt:

    ```
    rke2 secrets-encrypt reencrypt
    ```
</TabItem>
<TabItem value="High-Availability">

To rotate secrets encryption keys on HA setups:

:::note
In this example, 3 servers are used to for a HA cluster, referred to as S1, S2, S3. While not required, it is recommended that you pick one server node from which to run the `secrets-encrypt` commands.
:::

1. Prepare on S1

    ```
    rke2 secrets-encrypt prepare
    ```

2. Sequentially Restart S1, S2, S3
    ```
    systemctl restart rke2-server.service
    ```
    Wait for the systemctl command to return before restarting the next server.

3. Rotate on S1

    ```
    rke2 secrets-encrypt rotate
    ```

4. Sequentially Restart S1, S2, S3

5. Reencrypt on S1

    ```
    rke2 secrets-encrypt reencrypt
    ```
    Wait until reencryption is finished, either via server logs `journalctl -u rke2-server` or via `rke2 secrets-encrypt status`. The status will return `reencrypt_finished` when done.

6. Sequentially Restart S1, S2, S3

</TabItem>
</Tabs>

### Secrets Encryption Status
The `secrets-encrypt status` subcommand displays information about the current status of secrets encryption on the node.

An example of the command on a single-server node:  
```
$ rke2 secrets-encrypt status
Encryption Status: Enabled
Current Rotation Stage: start
Server Encryption Hashes: All hashes match

Active  Key Type  Name
------  --------  ----
 *      AES-CBC   aescbckey

```

Another example on HA cluster, after rotating the keys, but before restarting the servers:  
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

Details on each section are as follows:  

- __Encryption Status__: Displayed whether secrets encryption is disabled or enabled on the node  
- __Current Rotation Stage__: Indicates the current rotation stage on the node.  
  Stages are: `start`, `prepare`, `rotate`, `reencrypt_request`, `reencrypt_active`, `reencrypt_finished`  
- __Server Encryption Hashes__: Useful for HA clusters, this indicates whether all servers are on the same stage with their local files. This can be used to identify whether a restart of servers is required before proceeding to the next stage. In the HA example above, node-1 and node-2 have different hashes, indicating that they currently do not have the same encryption configuration. Restarting the servers will sync up their configuration.

| Key Table | Description |
| -------- | ----------- |
| Active | The `*` indicates which, if any, of the keys are currently used for secrets encryption. The active key is used by Kubernetes to encrypt any new secrets. |
| Key Type | RKE2 only supports the `AES-CBC` key type. Find more info [here.](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#providers) |
| Name | Name of the encryption key. Default is `aescbckey-<DATE_AND_TIME>`.|
