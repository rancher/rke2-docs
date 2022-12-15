---
title: FIPS 140-2 启用
---

FIPS 140-2 是美国联邦政府的安全标准，用于批准加密模块。本文解释了如何使用 FIPS 验证的加密库构建 RKE2。

## 使用 FIPS 兼容的 Go 编译器

你可以在[此处](https://go.googlesource.com/go/+/dev.boringcrypto)找到所使用的 Go 编译器。系统的每个组件都是用这个编译器的版本来构建的，与其他情况下使用的标准 Go 编译器版本一致。

这个版本的 Go 用经过 FIPS 验证的 BoringCrypto 模块取代了标准 Go 加密库。有关详细信息，请参阅 GoBoring 的 [readme](https://github.com/golang/go/blob/dev.boringcrypto/README.boringcrypto.md)。该模块最初由 NIST 验证为 [Rancher Kubernetes 加密库](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/3836)，用于支持更广泛的系统。但是，由于 SP 800-56A Rev3 引入的更改，此验证现在已成为历史。目前正在进行此模块的重新验证，以使该模块恢复到活动的 FIPS 140-2 状态。

### 集群组件中的 FIPS 支持

RKE2 系统的大部分组件都是使用 GoBoring Go 编译器实现静态编译的。从组件的角度来看，RKE2 被分成了若干部分。下面的列表包含了这些部分和相关的组件。

* Kubernetes
   * API Server
   * Controller Manager
   * Scheduler
   * Kubelet
   * Kube Proxy
   * Metric Server
   * Kubectl

* Helm Chart
   * Flannel
   * Calico
   * CoreDNS

## 运行时

为了确保系统架构的各方面都使用符合 FIPS 140-2 标准的算法实现，RKE2 运行时包含了用符合 FIPS 标准的 Go 编译器静态编译的实用程序。这确保了从 Kubernetes 守护程序到容器协调机制的所有层面都是合规的。

* etcd
* containerd
   * containerd-shim
   * containerd-shim-runc-v1
   * containerd-shim-runc-v2
   * ctr
* crictl
* runc

## CNI

从 v1.21.2 开始，RKE2 支持通过 `--cni` 标志选择不同的 CNI，并绑定了多个 CNI，包括 Canal（默认）、Calico、Cilium 和 Multus。其中，只有 Canal（默认）是为符合 FIPS 标准而重建的。

## Ingress

RKE2 附带了 NGNIX 作为其默认的 ingress provider。从 v1.21+ 开始，此组件符合 FIPS 标准。NGINX ingress 有两个主要的子组件：

- controller - 负责监控/更新 Kubernetes 资源并相应地配置 server
- server - 负责接收和路由流量

Controller 是用 Go 编写的，因此使用我们 [FIPS 兼容的 Go 编译器](./fips_support.md#使用-fips-兼容的-go-编译器)进行编译。

server 是用 C 编写的，还需要 OpenSSL 才能正常运行。因此，它利用 FIPS 验证的 OpenSSL 版本来实现 FIPS 合规。
