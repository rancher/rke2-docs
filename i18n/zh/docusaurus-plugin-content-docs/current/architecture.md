---
title: 下一代 Kubernetes 发行版剖析
sidebar_label: 架构
weight: 204
---

### 架构概述

在 RKE2 中，我们吸取了开发和维护轻量级 [Kubernetes][io-kubernetes] 发行版 [K3s][io-k3s] 的经验，致力于构建一个同样具备 [K3s][io-k3s] 易用性的企业级发行版。
换言之，在最简单的情况下，RKE2 是一个二进制文件，需要在 [Kubernetes][io-kubernetes] 集群的所有节点上进行安装和配置。一旦启动，RKE2 就能够引导和监督每个节点上的角色合适的 Agent，同时从网络上获取所需的内容。

![架构概览](/img/overview.png "RKE2 架构概览")

RKE2 汇集了许多开源技术：

- [K3s][io-k3s]
   - [Helm Controller][gh-helm-controller]
- [K8s][io-kubernetes]
   - [API Server][gh-kube-apiserver]
   - [Controller Manager][gh-kube-controller-manager]
   - [Kubelet][gh-kubelet]
   - [Scheduler][gh-kube-scheduler]
   - [Proxy][gh-kube-proxy]
- [etcd][io-etcd]
- [runc][gh-runc]
- [containerd][io-containerd]/[cri][gh-cri-api]
- [CNI][gh-cni]: Canal ([Calico][org-projectcalico] &amp; [Flannel][gh-flannel]), [Cilium][io-cilium] 或 [Calico][org-projectcalico]
- [CoreDNS][io-coredns]
- [NGINX Ingress Controller][io-ingress-nginx]
- [Metrics Server][gh-metrics-server]
- [Helm][sh-helm]

除了 NGINX Ingress Controller 之外，它们都使用 [Go+BoringCrypto][gh-goboring] 进行编译和静态链接。

### 进程生命周期

#### 内容引导

RKE2 从 RKE2 Runtime 镜像中提取二进制文件和清单来运行 _server_ 和 _agent_ 节点。
换言之，RKE2 默认通过扫描 `/var/lib/rancher/rke2/agent/images/*.tar` 获取 [`rancher/rke2-runtime`](https://hub.docker.com/r/rancher/rke2-runtime/tags) 镜像（带有与 `rke2 --version` 输出相关的标签），如果找不到它，则会尝试从网络拉取（即 Docker Hub）。然后，RKE2 从镜像中提取 `/bin/`，将其展开为 `/var/lib/rancher/rke2/data/${RKE2_DATA_KEY}/bin`，其中 `${RKE2_DATA_KEY}` 表示镜像的唯一字符串标识。

为了使 RKE2 按预期工作，运行时镜像必须至少提供：

- **`containerd`** ([CRI][gh-cri-api])
- **`containerd-shim`**（如果 `containerd` 停止，shims wrap `runc` 任务并且不会随之停止）
- **`containerd-shim-runc-v1`**
- **`containerd-shim-runc-v2`**
- **`kubelet`** (Kubernetes node agent)
- **`runc`** (OCI runtime)

运行时镜像还提供了以下操作工具：

- **`ctr`**（底层 `containerd` 维护检查）
- **`crictl`**（底层 CRI 维护和检查）
- **`kubectl`**（kubernetes 集群维护检查）
- **`socat`**（`containerd` 使用它来进行端口转发）

提取二进制文件后，RKE2 将从镜像中将 Chart 提取到 `/var/lib/rancher/rke2/server/manifests` 目录。

#### 初始化 Server

在嵌入式 K3s 引擎中，server 是专门的 agent 进程，换言之，它会在节点容器运行时启动后再启动。

##### 准备组件

###### `kube-apiserver`

拉取 `kube-apiserver` 镜像，如果没有显示，则启动一个 goroutine 来等待 `etcd`，然后在 `/var/lib/rancher/rke2/agent/pod-manifests/` 中写入静态 pod 定义。

###### `kube-controller-manager`

拉取 `kube-controller-manager` 镜像，如果没有显示，则启动一个 goroutine 来等待 `kube-apiserver`，然后在 `/var/lib/rancher/rke2/agent/pod-manifests/` 中写入静态 pod 定义。

###### `kube-scheduler`

拉取 `kube-scheduler` 镜像，如果没有显示，则启动一个 goroutine 来等待 `kube-apiserver`，然后在 `/var/lib/rancher/rke2/agent/pod-manifests/` 中写入静态 pod 定义。

##### 启动集群

在 goroutine 中启动 HTTP 服务器来侦听其他集群 server/agent，然后初始化/加入集群。

###### `etcd`

拉取 `etcd` 镜像，如果没有显示，则启动一个 goroutine 来等待 `kubelet`，然后在 `/var/lib/rancher/rke2/agent/pod-manifests/` 中写入静态 pod 定义。

###### `helm-controller`

`kube-apiserver` 准备就绪后，启动 goroutine 来启动嵌入式 `helm-controller`。

#### 初始化 Agent

Agent 进程入口点。对于 server 进程，嵌入式 K3s 引擎会直接调用它。

##### 容器运行时

###### `containerd`

生成 `containerd` 进程并监听终止。如果 `containerd` 退出，那么 `rke2` 进程也会退出。

##### Node Agent

###### `kubelet`

生成并监督 `kubelet` 进程。如果 `kubelet` 退出，那么 `rke2` 将尝试重启它。
`kubelet` 运行后，它将启动任何可用的静态 pod。对于 server，这意味着 `etcd` 和 `kube-apiserver` 将依次启动，允许其余组件通过静态 pod 启动，从而连接到 `kube-apiserver` 并开始处理。

##### Server Charts

在 Server 节点上，`helm-controller` 可以将在 `/var/lib/rancher/rke2/server/manifests` 中找到的任何 Chart 应用于集群。

- rke2-canal.yaml or rke2-cilium.yaml (daemonset, bootstrap)
- rke2-coredns.yaml (deployment, bootstrap)
- rke2-ingress-nginx.yaml (deployment)
- rke2-kube-proxy.yaml (daemonset, bootstrap)
- rke2-metrics-server.yaml (deployment)


#### 守护进程

RKE2 进程现在将无限期运行，直到它收到 SIGTERM 或 SIGKILL，或者 `containerd` 进程退出。

[gh-k3s]: <https://github.com/k3s-io/k3s> "K3s - Lightweight Kubernetes"
[io-k3s]: <https://k3s.io> "K3s - 轻量级 Kubernetes"
[gh-kubernetes]: <https://github.com/kubernetes/kubernetes> "Production-Grade Container Orchestration"
[io-kubernetes]: <https://kubernetes.io> "生产级容器编排"
[gh-kube-apiserver]: <https://github.com/kubernetes/kubernetes/tree/master/cmd/kube-apiserver> "Kube API Server"
[gh-kube-controller-manager]: <https://github.com/kubernetes/kubernetes/tree/master/cmd/kube-controller-manager> "Kube Controller Manager"
[gh-kube-proxy]: <https://github.com/kubernetes/kubernetes/tree/master/cmd/kube-proxy> "Kube Proxy"
[gh-kube-scheduler]: <https://github.com/kubernetes/kubernetes/tree/master/cmd/kube-scheduler> "Kube Scheduler"
[gh-kubelet]: <https://github.com/kubernetes/kubernetes/tree/master/cmd/kubelet> "Kubelet"
[gh-cri-api]: <https://github.com/kubernetes/cri-api> "容器运行时接口"
[gh-containerd]: <https://github.com/containerd/containerd> "An open and reliable container runtime"
[io-containerd]: <https://containerd.io> "开放可靠的容器运行时"
[gh-coredns]: <https://github.com/coredns/coredns> "DNS and Service Discovery"
[io-coredns]: <https://coredns.io> "DNS 和服务发现"
[gh-ingress-nginx]: <https://github.com/kubernetes/ingress-nginx> "NGINX Ingress Controller for Kubernetes"
[io-ingress-nginx]: <https://kubernetes.github.io/ingress-nginx> "用于 Kubernetes 的 NGINX Ingress Controller"
[gh-metrics-server]: <https://github.com/kubernetes-sigs/metrics-server> "资源使用数据的集群范围聚合器"
[org-projectcalico]: <https://docs.projectcalico.org/about/about-calico> "项目 Calico"
[gh-flannel]: <https://github.com/coreos/flannel> "专为 Kubernetes 设计的容器网络结构"
[io-cilium]: <https://cilium.io> "基于 eBPF 的网络、观测和安全"
[gh-etcd]: <https://github.com/etcd-io/etcd> "A distributed, reliable key-value store for the most critical data of a distributed system"
[io-etcd]: <https://etcd.io> "用于分布式系统最关键数据的分布式、可靠的键值存储"
[gh-helm]: <https://github.com/helm/helm> "The Kubernetes Package Manager"
[sh-helm]: <https://helm.sh> "Kubernetes 包管理器"
[gh-helm-controller]: <https://github.com/k3s-io/helm-controller> "Helm Chart CRD"
[gh-cni]: <https://github.com/containernetworking/cni> "容器网络接口"
[gh-runc]: <https://github.com/opencontainers/runc> "根据 OCI 规格生成和运行容器的 CLI 工具"
[gh-goboring]: <https://github.com/golang/go/tree/dev.boringcrypto/misc/boring> "Go+BoringCrypto"
