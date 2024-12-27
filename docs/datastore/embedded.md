---
title: Embedded datastore
---

Using an embedded datastore means leveraging a database that runs within the Kubernetes cluster, typically as a containerized service, e.g. etcd. This option simplifies deployment and could improve performance and security. The alternative is [external databases](external.md)

## Datastore options

:::warning Experimental
RKE2 officially supports Embedded etcd, embedded SQLite is considered experimental
:::

* **Embedded [Etcd](https://etcd.io/)**  
  Embedded Etcd is the default datastore, and will be used if no other datastore configuration is present.
* **Embedded [SQLite](https://www.sqlite.org/index.html)**  
  SQLite cannot be used on clusters with multiple servers. It uses project [kine](https://github.com/k3s-io/kine)



## Embedded [Etcd](https://etcd.io/)

Embedded Etcd is the default datastore, and will be used if no other datastore configuration is present.  It is the only embedded option that allows to deploy RKE2 in [HA mode](../install/ha.md). Unless explicitly unset, one etcd pod will be deployed per RKE2 server and all the etcd instances will maintain a quorum. RKE2 includes tools to easily create snapshots when using this datastore as explained in the [backup/restore](backup_restore.md).


## Embedded [SQLite](https://www.sqlite.org/index.html)

This embedded option is not recommended for production but can be useful if you need to run a simple, short-lived cluster, for example in a CI/CD environment. HA mode is not supported when deploying with SQLite.

### Single Server with SQLite

1. Set `disable-etcd` without the `server` parameter in the config file

```yaml
disable-etcd: true
```

2. Install RKE2 
```bash
curl -sfL https://get.rke2.io | sh -
```

3. Enable rke2-server service
```sh
systemctl enable rke2-server.service
```

4. start the rke2-server service

```sh
systemctl start rke2-server.service
```

You can follow the server starting by `kubectl get nodes` to see the server get the `Ready` status. See [Cluster access](../cluster_access.md) for more info about how to access RKE2.