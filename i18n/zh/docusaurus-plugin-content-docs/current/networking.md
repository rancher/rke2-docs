---
title: "网络"
---

本文解释了 CoreDNS 和 Nginx-Ingress controller 如何在 RKE2 中工作。

有关 Canal 配置选项或如何设置你自己的 CNI，请参阅[安装网络选项](install/network_options.md)页面。

有关 RKE2 需要开放哪些端口，请参考[安装要求](install/requirements.md)。

- [CoreDNS](#coredns)
- [Nginx Ingress Controller](#nginx-ingress-controller)
- [没有主机名的节点](#没有主机名的节点)

## CoreDNS

CoreDNS 在启动 server 时默认部署。要禁用它，请在配置文件中使用 `disable: rke2-coredns` 选项运行每个 server。

如果你不安装 CoreDNS，则需要自己安装集群 DNS 提供程序。

默认情况下，CoreDNS 与 [autoscaler](https://github.com/kubernetes-incubator/cluster-proportional-autoscaler) 一起部署。要禁用它或更改配置，请使用 [HelmChartConfig](https://docs.rke2.io/helm/#customizing-packaged-components-with-helmchartconfig) 资源。

### NodeLocal DNSCache

[NodeLocal DNSCache](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/) 通过在每个节点上运行 DNS 缓存代理来提高性能。要激活此功能，请应用以下 HelmChartConfig：

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-coredns
  namespace: kube-system
spec:
  valuesContent: |-
    nodelocal:
      enabled: true
```
helm 控制器将使用新配置重新部署 coredns。请注意，nodelocal 会修改节点的 iptables 以拦截 DNS 流量。因此，在不重新部署的情况下激活然后停用此功能将导致 DNS 服务停止工作。

请注意，如果 kube-proxy 使用该模式，则必须以 ipvs 模式部署 NodeLocal DNSCache。要在此模式下部署，请应用以下 HelmChartConfig：

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-coredns
  namespace: kube-system
spec:
  valuesContent: |-
    nodelocal:
      enabled: true
      ipvs: true
```


## Nginx Ingress Controller

[nginx-ingress](https://github.com/kubernetes/ingress-nginx) 是一个由 NGINX 提供支持的 Ingress Controller，它使用 ConfigMap 来存储 NGINX 配置。

`nginx-ingress` 在启动 server 时默认部署。在默认配置中，Ingress Controller 将绑定端口 80 和 443，使这些端口无法用于集群中的 HostPort 或 NodePort 服务。

你可以通过创建 [HelmChartConfig 清单](helm.md#使用-helmchartconfig-自定义打包组件) 来指定配置选项，从而自定义 `rke2-ingress-nginx` HelmChart 值。例如，`/var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml` 中的 HelmChartConfig 具有如下内容，在存储 NGINX 配置的 ConfigMap 中，将 `use-forwarded-headers` 设为 `"true"`：
```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |-
    controller:
      config:
        use-forwarded-headers: "true"
```
有关更多信息，请参考官方 [nginx-ingress Helm 配置参数](https://github.com/kubernetes/ingress-nginx/tree/9c0a39636da11b7e262ddf0b4548c79ae9fa1667/charts/ingress-nginx#configuration)。

要禁用 NGINX Ingress Controller，请在配置文件中使用 `disable: rke2-ingress-nginx` 选项来启动每个 server。

## 没有主机名的节点

一些云提供商（例如 Linode）将创建以 “localhost” 作为主机名的主机，而其他云提供商可能根本没有设置主机名。这可能会导致域名解析出现问题。你可以使用 `node-name` 参数运行 RKE2，这将通过传递节点名称来解决此问题。
