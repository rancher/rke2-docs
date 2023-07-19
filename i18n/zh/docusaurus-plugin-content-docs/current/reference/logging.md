---
title: "日志"
---

使用 systemd 运行的时候，日志将发送到 Journald，你可以使用 `journalctl -u rke2-server` 或 `journalctl -u rke2-agent` 进行查看。某些 systemd 配置也可能将组合日志写入 `/var/log/syslog`，在这种情况下，RKE2 日志也将在那里可用。

Containerd 日志写入 `/var/lib/rancher/rke2/agent/containerd/containerd.log`。

kubelet 日志写入 `/var/lib/rancher/rke2/agent/logs/kubelet.log`。

Etcd 和 Kubernetes Control Plane 组件在 `kube-system` 命名空间中作为静态 Pod 运行。

你可以使用 `kubectl` 访问每个 Kubernetes Pod 的日志：

```
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml logs -n kube-system -l component=kube-apiserver
```

每个容器的日志都写入 `/var/log/pods`，你也可以使用 `crictl` 访问：

```
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
# 列出运行的容器
/var/lib/rancher/rke2/bin/crictl ps
# 通过容器 ID 获取容器日志
/var/lib/rancher/rke2/bin/crictl logs <container_id>
```
