---
title: Network Options
---

RKE2 requires a CNI plugin to connect pods and services. The Canal CNI plugin is the default but all CNI plugins are supported. All CNI
plugins get installed via a helm chart after the main components are up and running and can be customized by modifying the helm chart options.


## Install a CNI plugin

RKE2 integrates with four different CNI plugins: Canal, Cilium, Calico and Flannel. Note that only Calico and Flannel are options for RKE2 deployments with Windows nodes.

The next tabs inform how to deploy each CNI plugin and override the default options:

<Tabs groupId = "CNIplugin">
<TabItem value="Canal CNI plugin" default>

Canal means using Flannel for inter-node traffic and Calico for intra-node traffic and network policies. By default, it will use vxlan encapsulation to create an overlay network among nodes. Canal is deployed by default in RKE2 and thus nothing must be configured to activate it. To override the default Canal options you should create a HelmChartConfig resource. The HelmChartConfig resource must match the name and namespace of its corresponding HelmChart. For example to override the flannel interface, you can apply the following config:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      iface: "eth1"
```

Starting with RKE2 v1.23 it is possible to use flannel's [wireguard backend](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md#wireguard) for in-kernel WireGuard encapsulation and encryption ([Users of kernels < 5.6 need to install a module](https://www.wireguard.com/install/)). This can be achieved using the following config:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      backend: "wireguard"
```

After that, please restart the canal daemonset to use the newer config by executing: `kubectl rollout restart ds rke2-canal -n kube-system`

For more information about the full options of the Canal config please refer to the [rke2-charts](https://github.com/rancher/rke2-charts/blob/main-source/packages/rke2-canal/charts/values.yaml).

:::note
Canal requires the iptables or xtables-nft package to be installed on the node.
:::

:::warning
Canal is currently not supported on clusters with Windows nodes.
:::

Please check [Known issues and Limitations](../known_issues.md) if you experience IP allocation problems

</TabItem>
<TabItem value="Cilium CNI plugin" default>

To deploy Cilium, pass `cilium` as the value of the `--cni` flag. Ensure that the nodes have the right required kernel version (>= 4.9.17) and they meet the [requirements](https://docs.cilium.io/en/stable/operations/system_requirements/). To override the default options, please use a HelmChartConfig resource. The HelmChartConfig resource must match the name and namespace of its corresponding HelmChart. For example, to enable eni:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    eni:
      enabled: true
```

For more information about values available in the Cilium chart, please refer to the [rke2-charts repository](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-cilium/rke2-cilium/1.14.400/values.yaml)

Cilium includes advanced features to fully replace kube-proxy and implement the routing of services using eBPF instead of iptables. It is not recommended to replace kube-proxy by Cilium if your kernel is not v5.8 or newer, as important bug fixes and features will be missing. To activate this mode, deploy rke2 with the flag `--disable-kube-proxy` and the following cilium configuration:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: <KUBE_API_SERVER_IP>
    k8sServicePort: <KUBE_API_SERVER_PORT>
```

For more information, please check the [upstream docs](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)

Cilium includes also an observability platform called [Hubble](https://docs.cilium.io/en/stable/overview/intro/#what-is-hubble)
To enable Hubble the following configuration is required:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
```

:::warning
Cilium is currently not supported in the Windows installation of RKE2
:::

</TabItem>
<TabItem value="Calico CNI plugin" default>
To deploy Calico as the CNI plugin for RKE2 pass `calico` as the value of the `--cni` flag. To override the default options, please use a HelmChartConfig resource. The HelmChartConfig resource must match the name and namespace of its corresponding HelmChart. For example, to change the mtu:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-calico-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-calico
  namespace: kube-system
spec:
  valuesContent: |-
    installation:
      calicoNetwork:
        mtu: 9000
```

For more information about values available for the Calico chart, please refer to the [rke2-charts repository](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-calico/rke2-calico/v3.26.300/values.yaml)

:::note
Calico requires the iptables or xtables-nft package  to be installed on the node.
:::

</TabItem>
<TabItem value="Flannel CNI plugin" default>
Starting with RKE2 2024 Feb release (v1.29.2, v1.28.7, v1.27.11, v1.26.14), Flannel can be deployed as the CNI plugin. To do so, pass `flannel` as the value of the `--cni` flag.

:::note
Only vxlan backend is supported at this point
:::

:::warning
Flannel does not support network policies. Therefore, it is not recommended for hardened installations
:::
:::warning
Flannel support in RKE2 is currently experimental. Do not run it on production systems before extensive testing
:::

</TabItem>
</Tabs>

## Dual-stack configuration

IPv4/IPv6 dual-stack networking enables the allocation of both IPv4 and IPv6 addresses to Pods and Services. To configure RKE2 in dual-stack mode, in the control-plane nodes, you must set a valid IPv4/IPv6 dual-stack cidr for pods and services. To do so, use the flags `--cluster-cidr` and `--service-cidr` for example:

```yaml
#/etc/rancher/rke2/config.yaml
cluster-cidr: "10.42.0.0/16,2001:cafe:42::/56"
service-cidr: "10.43.0.0/16,2001:cafe:43::/112"
```

Each CNI plugin may require a different configuration for dual-stack:

<Tabs groupId = "CNIplugin">
<TabItem value="Canal CNI plugin" default>

Canal automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration. Dual-stack is currently not supported in the windows installations of RKE2.

</TabItem>
<TabItem value="Cilium CNI plugin" default>

Cilium automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration.

</TabItem>
<TabItem value="Calico CNI plugin" default>

Calico automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration. When deployed in dual-stack mode, it creates two different ippool resources. Note that when using dual-stack, calico leverages BGP instead of VXLAN encapsulation. Dual-stack and BGP are currently not supported in the windows installations of RKE2.
</TabItem>
<TabItem value="Flannel CNI plugin" default>

Flannel automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration.

</TabItem>
</Tabs>

## IPv6 setup

In case of IPv6 only configuration RKE2 needs to use `localhost` to access the liveness URL of the ETCD pod; check that your operating system configures `/etc/hosts` file correctly:

```bash
::1       localhost
```

## Nodes Without a Hostname

Some cloud providers, such as Linode, will create machines with "localhost" as the hostname and others may not have a hostname set at all. This can cause problems with domain name resolution. You can run RKE2 with the `node-name` parameter and this will pass the node name to resolve this issue.