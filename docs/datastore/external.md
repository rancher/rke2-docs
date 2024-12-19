---
title: External datastore
---

Using an external datastore means leveraging a database that resides outside the Kubernetes cluster. Instead of being contained within the cluster, Kubernetes access the external datastore over the network. This approach could be common for organizations with existing database infrastructure or those who have more experience operating an enterprise-grade SQL database like MySQL or PostgreSQL. The project [kine](https://github.com/k3s-io/kine) is used for SQL databases. The alternative to external datastore is [embedded datastore](embedded.md).

## Datastore options

:::warning Experimental
RKE2 external datastores support is experimental.
:::


* **External Database**  
  * [etcd](https://etcd.io/) (certified against version 3.5.4)
  * [MySQL](https://www.mysql.com) (certified against versions 5.7 and 8.0)
  * [MariaDB](https://mariadb.org/) (certified against version 10.6.8)
  * [PostgreSQL](https://www.postgresql.org/) (certified against versions 12.16, 13.12, 14.9 and 15.4)

:::warning Prepared Statement Support
RKE2 requires prepared statements support from the DB. This means that connection poolers such as [PgBouncer](https://www.pgbouncer.org/faq.html#how-to-use-prepared-statements-with-transaction-pooling) may require additional configuration to work with RKE2.
:::


### External Datastore Configuration Parameters
If you wish to use an external datastore such as PostgreSQL, MySQL, or etcd you must set the `datastore-endpoint` config so that RKE2 knows how to connect to it. You may also specify parameters to configure the authentication and encryption of the connection. The below table summarizes these options:

| Options | Environment Variable | Description
|---------|----------------------|------------
| `datastore-endpoint` | `RKE2_DATASTORE_ENDPOINT` | Specify a PostgreSQL, MySQL, or etcd connection string. This is a string used to describe the connection to the datastore. The structure of this string is specific to each backend and is detailed below. |
| `datastore-cafile` | `RKE2_DATASTORE_CAFILE` | TLS Certificate Authority (CA) file used to help secure communication with the datastore. If your datastore serves requests over TLS using a certificate signed by a custom certificate authority, you can specify that CA using this parameter so that the RKE2 client can properly verify the certificate. |
| `datastore-certfile` | `RKE2_DATASTORE_CERTFILE` | TLS certificate file used for client certificate based authentication to your datastore. To use this feature, your datastore must be configured to support client certificate based authentication. If you specify this parameter, you must also specify the `datastore-keyfile` parameter. |
| `datastore-keyfile` | `RKE2_DATASTORE_KEYFILE` | TLS key file used for client certificate based authentication to your datastore. See the previous `datastore-certfile` parameter for more details. |

### Datastore Endpoint Format and Functionality
As mentioned, the format of the value passed to the `datastore-endpoint` parameter is dependent upon the datastore backend. The following details this format and functionality for each supported external datastore.

<Tabs queryString="ext-db">
<TabItem value="PostgreSQL">


  A typical `datastore-endpoint` option for PostgreSQL has the following format:

  `postgres://username:password@hostname:port/database-name`

  More advanced configuration parameters are available. For more information on these, please see https://godoc.org/github.com/lib/pq.

  If you specify a database name and it does not exist, the server will attempt to create it.

  If you only supply `postgres://` as the endpoint, RKE2 will attempt to do the following:

  - Connect to localhost using `postgres` as the username and password
  - Create a database named `kubernetes`

</TabItem>
<TabItem value="MySQL / MariaDB">

  A typical `datastore-endpoint` option for MySQL and MariaDB has the following format:

  `mysql://username:password@tcp(hostname:3306)/database-name`

  More advanced configuration parameters are available. For more information, please see https://github.com/go-sql-driver/mysql#dsn-data-source-name

  If you specify a database name and it does not exist, the server will attempt to create it.

  If you only supply `mysql://` as the endpoint, RKE2 will attempt to do the following:

  - Connect to the MySQL socket at `/var/run/mysqld/mysqld.sock` using the `root` user and no password
  - Create a database with the name `kubernetes`

</TabItem>

<TabItem value="etcd">

  A typical `datastore-endpoint` option for etcd has the following format:

  `https://etcd-host-1:2379,https://etcd-host-2:2379,https://etcd-host-3:2379`

  The above assumes a typical three node etcd cluster. The parameter accepts comma separated etcd URLs.

</TabItem>
</Tabs>


## External database

### 1. Create an External Datastore

You will first need to create an external datastore for the cluster. See the [Datastore options](#datastore-options) section for more details.

### 2. Launch Server Nodes

RKE2 requires two or more server nodes for this HA configuration. See the [Requirements](../install/requirements.md) guide for minimum machine requirements.

When starting the `rke2-server` service on these nodes, you must set the `datastore-endpoint` option in the config so that RKE2 knows how to connect to the external datastore. The `token` option can also be used to set a deterministic token when adding nodes. When empty, this token will be generated automatically for further use.

For example, a `config.yaml` like the following could be used to config RKE2 with a MySQL database as the external datastore and set a token:

:::note 
The RKE2 config file needs to be created manually. You can do that by running touch /etc/rancher/rke2/config.yaml as a privileged user. 
:::

```yaml
datastore-endpoint: "mysql://username:password@tcp(hostname:3306)/database-name"
token: SECRET
```

The datastore endpoint format differs based on the database type. For details, refer to the section on [datastore endpoint formats.](#datastore-endpoint-format-and-functionality)

To configure TLS certificates when launching server nodes, refer to the [datastore configuration section.](#external-datastore-configuration-parameters)

By default, server nodes will be schedulable and thus your workloads can get launched on them. If you wish to have a dedicated control plane where no user workloads will run, you can use [taints](../advanced.md#node-labels-and-taints).

Once you've started the `rke2-server` process on all server nodes, ensure that the cluster has come up properly with `kubectl get nodes`. You should see your server nodes in the `Ready` state.

### 3. Optional: Join Additional Server Nodes

The same example config in Step 2 can be used to join additional server nodes, where the token from the first node needs to be used.

If the first server node was started without the `token` option, the token value can be retrieved from any server already joined to the cluster:

```bash
cat /var/lib/rancher/rke2/server/token
```

then you can install the second server with the `server` address in the config with the step 2:

```yaml
server: https://you-first-server-node-address:9345
datastore-endpoint: "mysql://username:password@tcp(hostname:3306)/database-name"
token: SECRET
```

There are a few config flags that must be the same in all server nodes:

- Network related flags: `cluster-dns`, `cluster-domain`, `cluster-cidr`, `service-cidr`
- Flags controlling the deployment of certain components: `disable-helm-controller` and any component passed to `disable`
- Feature related flags: `secrets-encryption`

:::note
Ensure that you retain a copy of this token as it is required when restoring from backup and adding nodes.
:::

### 4. Optional: Join Agent Nodes

Because RKE2 server nodes are schedulable by default, agent nodes are not required for a RKE2 cluster. However, you may wish to have dedicated agent nodes to run your apps and services.

You just need to specify the URL the agent should register to (either one of the server IPs or a fixed registration address) and the token it should use in the `config` file.

```yaml
server: https://you-first-server-node-address:9345
token: SECRET
```

and then you can install the agent:

```bash
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
```

