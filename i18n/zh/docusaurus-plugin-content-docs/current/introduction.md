---
slug: "/"
sidebar_position: 1
title: "介绍"
---

![](/img/logo-horizontal-rke2.svg#gh-light-mode-only)![](/img/logo-horizontal-rke2-dark.svg#gh-dark-mode-only)

RKE2，也称为 RKE Government，是 Rancher 的下一代 Kubernetes 发行版。

它是一个[完全合规的 Kubernetes 发行版](https://landscape.cncf.io/card-mode?selected=rke-government)，专注于安全和合规性。

为了实现这些目标，RKE2 会：

- 提供[默认值和配置选项](security/hardening_guide.md)，让集群能使用最少的人员干预通过 CIS Kubernetes Benchmark [v1.6](security/cis_self_assessment16.md) 或 [v1.23](security/cis_self_assessment123.md)
- 启用 [FIPS 140-2 合规](security/fips_support.md)
- 在我们的构建流水线中使用 [trivy](https://github.com/aquasecurity/trivy) 定期扫描组件以查找 CVE

## 与 RKE 或 K3s 的差别？

RKE2 完美结合了 1.x 版本的 RKE（以下简称 RKE1）和 K3s。

它继承了 K3s 的可用性、易操作性和部署模型。

它还继承了 RKE1 与上游 Kubernetes 的紧密结合关系。为了优化边缘部署，K3s 在某些地方与上游 Kubernetes 有所不同，但 RKE1 和 RKE2 可以与上游保持紧密一致。

重要的是，RKE2 不像 RKE1 一样依赖 Docker。RKE1 使用 Docker 来部署和管理 control plane 组件以及 Kubernetes 的容器运行时。RKE2 将 control plane 组件作为由 kubelet 管理的静态 pod 启动。嵌入式容器运行时是 containerd。

## 为什么有两个名字？
它被称为 RKE Government，目的是传达其当前针对的主要用例和部门。

它也被称为 RKE 2，因为它是 Rancher Kubernetes Engine 针对数据中心用例的下一次迭代。该发行版独立运行，我们正在进行它与 Rancher 的集成工作。一旦 RKE 2 与 RKE 的功能对等，我们会让 RKE 2 成为 Rancher 中的一个选项。我们也在开发从 RKE 迁移到 RKE2 的升级路径。

## 安全

Rancher Labs 会负责任地披露问题，并致力于在合理的时间内解决所有问题。要报告安全漏洞，请发送电子邮件到 [security@rancher.com](mailto:security@rancher.com)。
