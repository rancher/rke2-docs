---
title: "Networking Services"
---

This page explains how CoreDNS and the Nginx-Ingress controller work within RKE2.

Refer to the [Basic Network Options](basic-network-options.md) page for details on Canal configuration options, or how to set up your own CNI.

For information on which ports need to be opened for RKE2, refer to the [Installation Requirements](../install/requirements.md).

## CoreDNS

CoreDNS is deployed by default when starting the server. To disable, run each server with `disable: rke2-coredns` option in your configuration file.

If you don't install CoreDNS, you will need to install a cluster DNS provider yourself.

CoreDNS is deployed with the [autoscaler](https://github.com/kubernetes-incubator/cluster-proportional-autoscaler) by default. To disable it or change its config, use the [HelmChartConfig](../helm.md#customizing-packaged-components-with-helmchartconfig) resource.

### NodeLocal DNSCache

[NodeLocal DNSCache](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/) improves the performance by running a dns caching agent on each node. To activate this feature, apply the following HelmChartConfig:

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
The helm controller will redeploy coredns with the new config. Please be aware that nodelocal modifies the iptables of the node to intercept DNS traffic. Therefore, activating and then deactivating this feature without redeploying, will cause the DNS service to stop working.

Note that NodeLocal DNSCache must be deployed in ipvs mode if kube-proxy is using that mode. To deploy it in this mode, apply the following HelmChartConfig:

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

[nginx-ingress](https://github.com/kubernetes/ingress-nginx) is an Ingress controller powered by NGINX that uses a ConfigMap to store the NGINX configuration.

`nginx-ingress` is deployed by default when starting the server. Ports 80 and 443 will be bound by the ingress controller in its default configuration, making these unusable for HostPort or NodePort services in the cluster.

Configuration options can be specified by creating a [HelmChartConfig manifest](../helm.md#customizing-packaged-components-with-helmchartconfig) to customize the `rke2-ingress-nginx` HelmChart values. For example, a HelmChartConfig at `/var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml` with the following contents sets `use-forwarded-headers` to `"true"` in the ConfigMap storing the NGINX config:
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
For more information, refer to the official [nginx-ingress Helm Configuration Parameters](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx#configuration).

To disable the NGINX ingress controller, start each server with the `disable: rke2-ingress-nginx` option in your configuration file.

## Service Load Balancer

Kubernetes Services can be of type LoadBalancer but it requires an external load balancer controller to implement things correctly and for example,provide the external-ip. RKE2 can optionally deploy a load balancer controller known as [ServiceLB](https://github.com/k3s-io/klipper-lb) that uses available host ports. For more information, please read the following [link](https://docs.k3s.io/networking/networking-services#service-load-balancer).

To enable serviceLB, use the flag `--serviceLB` when deploying RKE2 