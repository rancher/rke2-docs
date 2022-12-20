---
title: SELinux
---

RKE2 可以在支持 SELinux 的系统上运行，这是安装在 CentOS/RHEL 7 &amp; 8 时的默认设置。
支持该设置的[策略](https://github.com/rancher/rke2-selinux)是 [container-selinux](https://github.com/containers/container-selinux) 策略的一个特殊版本，用于 containerd。它解释了 containerd 安装在非标准位置的原因，以及为什么使用持久和短暂状态。

#### 自定义上下文标签

RKE2 将 control plane 服务作为静态 pod 运行，需要访问多个 [`container_var_lib_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L59) 位置。`etcd` 容器必须能够在 `/var/lib/rancher/rke2/server/db` 下读写，并与 `kube-apiserver`、`kube-controller-manager` 和 `kube-scheduler` 一起从 `/var/lib/rancher/rke2/server/tls` 读取。
为了不过度授权，例如 [`spc_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L47-L49)，RKE2 SELinux 策略引入了 [`rke2_service_db_t`](https://github.com/rancher/rke2-selinux/blob/v0.3.latest.1/rke2.te#L15-L21) 和 [`rke2_service_t`](https://github.com/rancher/rke2-selinux/blob/v0.3.latest.1/rke2.te#L15-L21) 上下文标签，分别为读写和只读访问。这些标签将仅适用于 RKE2 control plane 静态 pod。

#### 配置

RKE2 对 SELinux 的支持相当于一个配置项，即 `--selinux` 布尔标志。这是一个通向 [containerd/cri toml 的 CRI 部分的 `enable_selinux` 布尔值](https://github.com/containerd/cri/blob/release/1.4/docs/config.md)的通道。
如果 RKE2 是通过 tarball 安装的，那么 SELinux 将不会在没有额外配置的情况下启用。推荐的配置方法是使用 RKE2 `config.yaml` 中的一个条目，例如：

```yaml
# /etc/rancher/rke2/config.yaml is the default location
selinux: true
```

这相当于将 `--selinux` 标志传递给 `rke2 server` 或 `rke2 agent` 命令行或设置 `RKE2_SELINUX=true` 环境变量。
