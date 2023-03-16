---
sidebar_label: "已知问题和限制"
title: "已知问题和限制"
---

本文介绍了 RKE2 当前已知的问题和限制。如果你遇到本文未记录的 RKE2 问题，请[提交一个新 issue](https://github.com/rancher/rke2/issues)。

## firewalld 与默认网络冲突

Firewalld 与 RKE2 的默认 Canal（Calico + Flannel）网络堆栈冲突。为避免意外，请在运行 RKE2 的系统上禁用 firewalld。

## NetworkManager

NetworkManager 会控制默认网络命名空间中接口的路由表，其中许多 CNI（包括 RKE2 的默认 CNI）会为连接到容器而创建 veth 对。这会干扰 CNI 进行正确路由。因此，如果在启用 NetworkManager 的系统上安装 RKE2，强烈建议你将 NetworkManager 配置为忽略 calico/flannel 相关的网络接口。为此，在 `/etc/NetworkManager/conf.d` 中创建名为 `rke2-canal.conf` 的配置文件，内容如下：
```bash
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
```

如果你还没有安装 RKE2，使用简单的 `systemctl reload NetworkManager` 就足以安装配置。如果在已安装 RKE2 的系统上执行此配置更改，则需要重启节点才能应用更改。

在某些操作系统（如 RHEL 8.4）中，NetworkManager 包含两个额外的服务，分别称为 `nm-cloud-setup.service` 和 `nm-cloud-setup.timer`。这些服务增加了一个路由表，干扰了 CNI 插件的配置。但是，现在没有可以避免这种情况的任何配置，如[问题](https://github.com/rancher/rke2/issues)中所述。因此，如果存在这些服务，则应将其禁用。
:::info
在 NetworkManager-1.30.0-11.el8_4 之前，节点也必须在禁用额外服务后重启。
:::

## Selinux 执行系统中的 Istio 默认失败

这是由 RKE2 的实时内核模块加载导致的，除非容器具有特权，否则在 Selinux 下不允许这样做。
要让 Istio 在这些条件下运行，需要两个步骤：
1. [启用 CNI](https://istio.io/latest/docs/setup/additional-setup/cni/) 作为 Istio 安装的一部分。请注意，此[功能](https://istio.io/latest/about/feature-stages/)在撰写本文时仍处于 Alpha 状态。
   确保 `values.cni.cniBinDir=/opt/cni/bin` 和 `values.cni.cniConfDir=/etc/cni/net.d`
2. 安装完成后，CrashLoopBackoff 中应该有 `cni-node` pod。手动编辑他们的守护进程以在 `install-cni` 容器中包含 `securityContext.privileged: true`。

这可以通过自定义覆盖来执行，如下所示：
```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    cni:
      enabled: true
      k8s:
        overlays:
        - apiVersion: "apps/v1"
          kind: "DaemonSet"
          name: "istio-cni-node"
          patches:
          - path: spec.template.spec.containers.[name:install-cni].securityContext.privileged
            value: true
  values:
    cni:
      image: rancher/mirrored-istio-install-cni:1.9.3
      excludeNamespaces:
      - istio-system
      - kube-system
      logLevel: info
      cniBinDir: /opt/cni/bin
      cniConfDir: /etc/cni/net.d
```

有关不遵循这些步骤时故障的详细日志，请参阅 [issue 504](https://github.com/rancher/rke2/issues)。

## Control Groups V2

RKE2 v1.19.5+ 内置 `containerd` v1.4.x 或更高版本，因此应该在支持 cgroups v2 的系统上运行。  
旧版本 (< 1.19.5) 内置 containerd 1.3.x 分支（从 1.4.x 向后移植 SELinux commits），它不支持 cgroups v2，需要一些前期配置：

假设使用基于 `systemd` 的系统，设置 [systemd.unified_cgroup_hierarchy=0](https://www.freedesktop.org/software/systemd/man/systemd.html#systemd.unified_cgroup_hierarchy) 内核参数将向 systemd 表明它应该以混合 (cgroups v1 + v2) 方式运行。
结合上述情况，设置 [systemd.legacy_systemd_cgroup_controller](https://www.freedesktop.org/software/systemd/man/systemd.html#systemd.legacy_systemd_cgroup_controller) 内核参数将向 systemd 表明它应该以旧版（cgroups v1）的方式运行。
由于这些参数是内核命令行参数，因此必须在系统引导程序中设置，以便在 `/sbin/init` 作为 PID 1 传递给 `systemd`。

参阅：

- [grub2 手册](https://www.gnu.org/software/grub/manual/grub/grub.html#linux)
- [systemd 手册](https://www.freedesktop.org/software/systemd/man/systemd.html#Kernel%20Command%20Line)
- [cgroups v2](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)


## Calico 与 vxlan 封装

在使用 vxlan 封装以及启用了 vxlan 接口的校验和卸载时，Calico 遇到了一个内核错误。
[calico 项目](https://github.com/projectcalico/calico/issues/4865) 和 [rke2项目](https://github.com/rancher/rke2/issues)中描述了该问题。我们的临时解决方法是，在 [calico helm chart](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-calico/rke2-calico/v3.25.001/values.yaml#L75-L76) 中使用 `ChecksumOffloadBroken=true` 的值，从而默认禁用校验和卸载。

此问题已在 Ubuntu 18.04、Ubuntu 20.04 和 openSUSE Leap 15.3 中发现。

## Wicked

Wicked 根据 sysctl 配置文件（例如 `/etc/sysctl.d/` 目录下）配置主机的网络设置。即使 RKE2 正在将 `/net/ipv4/conf/all/forwarding` 之类的参数设置为 1，但是只要重新应用网络配置（有几个事件会导致网络配置重新应用以及 rcwicked 在更新期间重启），Wicked 就可以恢复该配置。因此，在 sysctl 配置文件中启用 ipv4（和双栈情况下的 ipv6）转发非常重要。例如，建议创建一个名为 `/etc/sysctl.d/90-rke2.conf` 的文件，文件包含以下参数（仅在双栈下才需要 ipv6）：

```bash
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding=1
```

## Canal 和 IP 地址枯竭
##

两个可能的原因如下：

1. `iptables` 二进制文件未安装在主机中，并且有一个定义 hostPort 的 pod。Pod 将获得一个 IP，但它的创建将失败，而且 Kubernetes 不会停止尝试重新创建它，每次尝试都会消耗一个 IP。containerd 日志中会出现类似如下的错误信息。这是显示错误的日志：

```console
plugin type="portmap" failed (add): failed to open iptables: exec: "iptables": executable file not found in $PATH
```
请安装 iptables 或 xtables-nft 包来解决这个问题


2. 默认情况下，Canal 通过在 `/var/lib/cni/networks/k8s-pod-network` 中为每个 IP 创建一个锁定文件来跟踪 pod IP。每个 IP 都属于一个 pod，一旦 pod 被删除，IP 就会被删除。然而，万一 containerd 无法跟踪正在运行的 pod，锁定文件可能会泄露，Canal 将无法再重用这些 IP。如果发生这种情况，你可能会遇到 IP 地址枯竭的错误，例如：


```console
failed to allocate for range 0: no IP addresses available in range set
```
有两种方法可以解决这个问题。你可以从该目录中手动删除未使用的 IP 或清空节点，运行 rke2-killall.sh，启动 rke2 systemd 服务并取消对节点的封锁。如果你需要执行这些操作，请通过 GitHub 报告问题，请确保说明问题是如何触发的。

## CIS 模式下的 Ingress

默认情况下，当 RKE2 使用由 `profile` 参数选择的 CIS 配置文件运行时，它会应用可以限制 Ingress 的网络策略。此外，`rke2-ingress-nginx` chart 的默认设置为 `hostNetwork: false`，因此，用户需要设置自己的网络策略来允许访问 Ingress URL。以下是一个网络策略示例，该示例允许进入它所应用的命名空间中的任何工作负载。有关更多配置选项，请参阅[此处](https://kubernetes.io/docs/concepts/services-networking/network-policies/)。
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-to-backends
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: rke2-ingress-nginx
  policyTypes:
  - Ingress
```
有关更多信息，请参阅[此 issue](https://github.com/rancher/rke2/issues/3195) 上的评论。

## 将强化集群从 v1.24.x 升级到 v1.25.x {#hardened-125}

Kubernetes 从 v1.25 中删除了 PodSecurityPolicy，以支持 Pod Security Standard（PSS）。你可以在[上游文档](https://kubernetes.io/docs/concepts/security/pod-security-standards/)中阅读有关 PSS 的更多信息。对于 RKE2，如果在节点上设置了 `profile` 标志，则必须手动执行一些步骤。

1. 在所有节点上，将 `profile` 值更新为 `cis-1.23`，但不要重启或升级 RKE2。
2. 正常执行升级。如果使用[自动升级](./upgrade/automated_upgrade.md)，请确保运行 `system-upgrade-controller` pod 的命名空间按照 [Pod 安全级别](https://kubernetes.io/docs/concepts/security/pod-security-admission/#pod-security-levels)的要求设置为 privileged。
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: system-upgrade
  labels:
    # This value must be privileged for the controller to run successfully.
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: v1.25
    # We are setting these to our _desired_ `enforce` level, but note that these below values can be any of the available options.
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/audit-version: v1.25
    pod-security.kubernetes.io/warn: privileged
    pod-security.kubernetes.io/warn-version: v1.25
```
