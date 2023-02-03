---
title: 默认 Pod 安全策略
---

本文档描述了 RKE2 如何配置 `PodSecurityPolicies` 和 `NetworkPolicies` 来确保默认安全，同时还为操作人员提供了最大的配置灵活性。

:::caution 版本
本文档适用于 RKE2 v1.24 及更早版本，请参阅 [Pod 安全标准文档](./pod_security_standards.md)了解 RKE2 v1.25 及更高版本的默认策略。
:::

#### Pod 安全策略

RKE2 可以在有或没有 `profile: cis-1.6` 配置参数的情况下运行。这将导致它在启动时应用不同的 `PodSecurityPolicies` (PSP)。

* 如果使用 `cis-1.6` 配置文件运行，RKE2 将对除 `kube-system` 之外的所有命名空间应用名为 `global-restricted-psp` 的限制性策略。`kube-system` 命名空间需要一个名为 `system-unrestricted-psp` 的低限制策略才能启动关键组件。
* 如果在没有 `cis-1.6` 配置文件的情况下运行，RKE2 将应用一个名为 `global-unrestricted-psp` 的完全不受限制的策略，相当于在没有启用 PSP 准入控制器的情况下运行。

RKE2 将在初始启动时实施这些策略，但之后不会修改它们，除非如下文所述由集群操作员明确触发。这是为了让操作员能够完全控制 PSP，而不被 RKE2 的默认值所干扰。

PSP 的创建和应用由 `kube-system` 命名空间上是否存在某些注释来控制。它们直接映射到可以创建的 PSP：

* `psp.rke2.io/global-restricted`
* `psp.rke2.io/system-unrestricted`
* `psp.rke2.io/global-unrestricted`

在启动时对策略及其注释执行以下逻辑：

* 如果注释存在，RKE2 将继续执行而不采取进一步操作。
* 如果注解不存在，RKE2 会检查相关策略是否存在，如果存在，则删除并重新创建，同时将注解添加到命名空间中。
* 对于 `global-unrestricted-psp`，不会重新创建策略。这是为了在不降低集群安全性的情况下在 CIS 和非 CIS 模式之间移动。
* 在创建策略的时候，集群角色和集群角色绑定也被创建，从而确保默认使用合适的策略。

因此，在初始启动后，操作员可以修改或删除 RKE2 的策略，RKE2 将尊重这些变化。此外，要 "重置" 一个策略，操作者只需要从 `kube-system` 命名空间中删除相关的注释，然后重新启动 RKE2。

这些策略概述如下，以最受限制的 `global-restricted` PSP 开始。

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: global-restricted-psp
spec:
  privileged: false                # CIS - 5.2.1
  allowPrivilegeEscalation: false  # CIS - 5.2.5
  requiredDropCapabilities:        # CIS - 5.2.7/8/9
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  hostNetwork: false               # CIS - 5.2.4
  hostIPC: false                   # CIS - 5.2.3
  hostPID: false                   # CIS - 5.2.2
  runAsUser:
    rule: 'MustRunAsNonRoot'       # CIS - 5.2.6
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false
```

如果 RKE2 在非 CIS 模式下启动，则会像上面一样检查注释，但是产生的 pod 安全策略是宽松的。见下文。

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: global-unrestricted-psp
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

这两种情况都应用了 "system unrestricted policy"。见下文。

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: system-unrestricted-psp
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

要查看系统上当前部署的 pod 安全策略，请运行以下命令：

```bash
kubectl get psp -A
```

#### 网络策略

当 RKE2 使用 `profile: cis-1.6` 参数运行时，它会将两个网络策略应用到 `kube-system`、`kube-public` 和 `default` 命名空间并应用关联的注释。与 PSP 相同的逻辑将应用于这些策略和注释。开始时会检查每个命名空间的注解是否存在，如果存在，RKE2 不会执行任何操作。如果注释不存在，RKE2 将检查策略是否存在，如果存在，则重新创建它。

应用的第一个策略是将网络流量限制为仅命名空间本身。见下文。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  managedFields:
  - apiVersion: networking.k8s.io/v1
    fieldsType: FieldsV1
    fieldsV1:
      f:spec:
        f:ingress: {}
        f:policyTypes: {}
  name: default-network-policy
  namespace: default
spec:
  ingress:
  - from:
    - podSelector: {}
  podSelector: {}
  policyTypes:
  - Ingress
```

第二个策略应用到 `kube-system` 命名空间并允许 DNS 流量。见下文。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  managedFields:
  - apiVersion: networking.k8s.io/v1
    fieldsV1:
      f:spec:
        f:ingress: {}
        f:podSelector:
          f:matchLabels:
        f:policyTypes: {}
  name: default-network-dns-policy
  namespace: kube-system
spec:
  ingress:
  - ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
  podSelector:
    matchLabels:
  policyTypes:
  - Ingress
```

RKE2 将 `default-network-policy` 策略和 `np.rke2.io` 注释应用于所有内置命名空间。`kube-system` 命名空间还获得了 `default-network-dns-policy` 策略和应用于它的 `np.rke2.io/dns` 注解。

要查看系统上当前部署的网络策略，请运行以下命令：

```bash
kubectl get networkpolicies -A
```
