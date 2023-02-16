---
title: 默认 Pod 安全标准
---

本文档描述了 RKE2 如何配置 `PodSecurityStandards` 和 `NetworkPolicies` 来确保默认安全，同时还为操作人员提供了最大的配置灵活性。

:::caution 版本
本文档适用于 RKE2 v1.25 及更新版本，请参阅 [Pod 安全策略文档](./pod_security_policies.md)了解 RKE2 v1.24 及更低版本的默认策略。
:::

#### Pod 安全标准

从 Kubernetes v1.25.0 版本开始，Pod Security Policies (PSP) 从 Kubernetes 中完全移除，取而代之的是 [Pod Security Admission (PSA)](https://kubernetes.io/docs/concepts/security/pod-security-admission/)。默认的 Pod Security Admission 配置文件将在启动时添加到集群中，如下所示：

* 如果使用 `--profile=cis-1.23` 选项运行，RKE2 将通过配置文件应用受限的 Pod 安全标准，该配置文件将在整个集群中强制执行 `restricted` 模式，其中 `kube-system`、`cis-operator-system` 和 `tigera-operator` 命名空间除外，它们用于确保系统 Pod 能成功运行。

* 如果在没有 `--profile=cis-1.23` 选项的情况下运行，RKE2 将通过配置文件应用不受限制的 pod 安全标准，该配置文件将在整个集群中强制执行 `privileged` 模式，该模式允许集群中所有 pod 使用完全不受限的模式。

RKE2 会将这个配置文件放在 `/etc/rancher/rke2/rke2-pss.yaml`，配置文件的内容取决于你启动 RKE2 的 CIS 模式：

**CIS 模式**

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1beta1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "restricted"
      enforce-version: "latest"
      audit: "restricted"
      audit-version: "latest"
      warn: "restricted"
      warn-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces: [kube-system, cis-operator-system, tigera-operator]
```

**非 CIS 模式**

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1beta1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces: []
```

放好该配置文件后，RKE2 将使用 `--admission-control-config-file` 标志启动 kube-apiserver，该标志将设置为 PSA 配置文件的路径。

如果要覆盖默认的 pod 安全标准配置文件，可以将 `pod-security-admission-config-file: <path-to-custom-psa-config-file>` 传递给 RKE2 配置文件。

#### 网络策略

当 RKE2 使用 `profile: cis-1.23` 参数运行时，它会将两个网络策略应用到 `kube-system`、`kube-public` 和 `default` 命名空间并应用关联的注释。与 PSP 相同的逻辑将应用于这些策略和注释。开始时会检查每个命名空间的注解是否存在，如果存在，RKE2 不会执行任何操作。如果注释不存在，RKE2 将检查策略是否存在，如果存在，则重新创建它。

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
