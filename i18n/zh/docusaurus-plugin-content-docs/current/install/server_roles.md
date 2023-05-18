---
title: "管理 Server 角色"
---

默认情况下，启动 RKE2 将运行所有 control-plane 组件，包括 apiserver、controller-manager、scheduler 和 etcd。你可以通过禁用特定组件来将 control-plane 和 etcd 角色拆分到单独的节点上。

## 专用 `etcd` 节点
要创建仅具有 `etcd` 角色的 Server，请部署一个禁用所有 Control Plane 组件的配置：
```yaml
# /etc/rancher/rke2/config.yaml
disable-apiserver: true
disable-controller-manager: true
disable-scheduler: true
```

第一个节点将启动 etcd，然后等待其他 `etcd` 和/或 `control-plane` 节点加入。在加入启用了 `control-plane` 组件的其他 server 之前，集群将无法使用。

## 专用 `control-plane` 节点
:::info
专用 `control-plane` 节点不能是集群中的第一个 server。在加入专用 `control-plane` 节点之前，必须有一个具有 `etcd` 角色的现有节点。
:::

要创建仅具有 `control-plane` 角色的 server，请部署一个禁用 etcd 的配置：
```yaml
# /etc/rancher/rke2/config.yaml
server: https://<etcd-only-node>:9345
disable-etcd: true
```

创建专用 Server 节点后，所选角色将在 `kubectl get node` 中可见：
```bash
$ kubectl get nodes
NAME           STATUS   ROLES                       AGE     VERSION
rke2-server-1   Ready    etcd                        5h39m   v1.26.4+rke2r1
rke2-server-2   Ready    control-plane,master        5h39m   v1.26.4+rke2r1
```

## 将角色添加到现有 server

如果在删除了 disable 标志的情况下重启 RKE2，你可以将角色添加到现有的专用节点。例如，要将 `control-plane` 角色添加到专用的 `etcd` 节点，你可以从配置文件中删除 `disable-apiserver disable-controller-manager disable-scheduler` 行，并重启服务。
