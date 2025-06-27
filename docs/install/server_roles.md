---
title: Managing Server Roles
---

By default, starting the RKE2 will run all control-plane components, including the apiserver, controller-manager, scheduler, and etcd. It is possible to disable specific components in order to split the control-plane and etcd roles on to separate nodes.

## Dedicated `etcd` Nodes
To create a server with only the `etcd` role, deploy a config with all the control-plane components disabled:
```yaml
# /etc/rancher/rke2/config.yaml
disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true
```

This first node will start etcd, and wait for additional `etcd` and/or `control-plane` nodes to join. The cluster will not be usable until you join an additional server with the `control-plane` components enabled.

## Dedicated `control-plane` Nodes
:::info
A dedicated `control-plane` node cannot be the first server in the cluster; there must be an existing node with the `etcd` role before joining dedicated `control-plane` nodes.
:::

To create a server with only the `control-plane` role, deploy a config with etcd disabled:
```yaml
# /etc/rancher/rke2/config.yaml
server: https://<etcd-only-node>:9345
disable-etcd: true
```

After creating dedicated server nodes, the selected roles will be visible in `kubectl get node`:
```bash
$ kubectl get nodes
NAME           STATUS   ROLES                       AGE     VERSION
rke2-server-1   Ready    etcd                        5h39m   v1.26.4+rke2r1
rke2-server-2   Ready    control-plane,master        5h39m   v1.26.4+rke2r1
```

## Adding Roles To Existing Servers

Roles can be added to existing dedicated nodes by restarting RKE2 with the disable flags removed. For example, if you want to add the `control-plane` role to a dedicated `etcd` node, you can remove the `disable-apiserver disable-controller-manager disable-scheduler` lines from the config file, and restart the service.
