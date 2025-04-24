---
title: Network Options
---

Kubernetes requires installation of one or more CNI Plugins to provide Pod networking. RKE2 bundles four primary CNI Plugins: Canal, Cilium, Calico, and Flannel. Only Calico and Flannel support Microsoft Windows. RKE2 also includes Multus as a secondary CNI Plugin, which must be enabled alongside a primary CNI Plugin. For more information, see the [Multus and SR-IOV](multus_sriov.md) documentation.

Canal is the default CNI Plugin, but all bundled plugins are supported.  Bundled CNI Plugins are installed via Helm chart, and can be customized by deploying a HelmChartConfig with additional chart values. For more information on using HelmChartConfig resources, see the [Helm Integration](../helm.md) documentation, and the CNI-specific examples provided below.

## Select a CNI Plugin

Use the `cni` [configuration file key](../install/configuration.md) to select the CNI Plugin you wish to use. If you do not want to use any of the bundled CNI Plugins, you can set `cni` to `none`. Note that nodes will remain NotReady and be tainted unschedulable until a CNI Plugin is installed. 

```yaml
# /etc/rancher/rke2/config.yaml
cni: canal
```

Bundled CNI Plugins are provided as AddOns that deploy a HelmChart resource, as described in the [Helm Integration](../helm.md) documentation. CNI Plugin charts are named `rke2-<CNI-PLUGIN-NAME>` and can be found in the `kube-system` namespace.

To customize the Helm chart values for a bundled CNI Plugin chart, you must create a HelmChartConfig resource that matches the name and namespace of its corresponding HelmChart. See the tabs below for examples of customizing the chart values for each of the bundled CNI Plugins.

Default chart values can be found by browsing the [RKE2 charts repository](https://github.com/rancher/rke2-charts/tree/main/charts), and referencing `values.yaml` for the version of the chart bundled with your RKE2 version.

<Tabs groupId = "CNIplugin" queryString>
<TabItem value="Canal CNI Plugin" default>

Canal uses Flannel for inter-node traffic and Calico for intra-node traffic and network policies. By default, it will use vxlan encapsulation to create an overlay network among nodes. For example, to override the flannel interface, you can apply the following chart values:

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

Starting with RKE2 v1.23 it is possible to use flannel's [wireguard backend](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md#wireguard) for in-kernel WireGuard encapsulation and encryption ([Users of kernels < 5.6 need to install a module](https://www.wireguard.com/install/)). This can be achieved using the following chart values:

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

Please check [Known issues and Limitations](../known_issues.md) if you experience IP allocation problems.

</TabItem>
<TabItem value="Cilium CNI Plugin" default>

When using Cilium, you must ensure that nodes have a supported kernel version (>= 4.9.17) and they meet the [requirements](https://docs.cilium.io/en/stable/operations/system_requirements/). To override the default options, please use a HelmChartConfig resource. The HelmChartConfig resource must match the name and namespace of its corresponding HelmChart. For example, to enable eni:

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

Cilium includes advanced features to fully replace kube-proxy and implement the routing of services using eBPF instead of iptables. It is not recommended to replace kube-proxy by Cilium if your kernel is not v5.8 or newer, as important bug fixes and features will be missing. To activate this mode, deploy rke2 with `disable-kube-proxy: true` in the configuration file, and the following chart values:

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
    k8sServiceHost: "localhost"
    k8sServicePort: "6443"
```

For more information, please check the [upstream docs](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)

Cilium includes also an observability platform called [Hubble](https://docs.cilium.io/en/stable/overview/intro/#what-is-hubble)
To enable Hubble, use the following chart values:

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
Cilium is currently not supported on Windows.
:::

</TabItem>
<TabItem value="Calico CNI Plugin" default>
For example, to change the interface MTU, you can use the following chart values:

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

Because of a kernel bug in versions previous to 5.7, Calico disables hardware checksum offload. That config caps TCP performance to ~2.5Gbps. If you require higher throughput and have a kernel version greater than 5.7, you can enable the checksum offloading by using the following HelmChartConfig:

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
    felixConfiguration:
      featureDetectOverride: "ChecksumOffloadBroken=false"
```

For more information about values available for the Calico chart, please refer to the [rke2-charts repository](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-calico/rke2-calico/v3.26.300/values.yaml)

:::note
Calico requires the iptables or xtables-nft package  to be installed on the node.
:::

</TabItem>
<TabItem value="Flannel CNI Plugin" default>
:::note
Flannel is available as of February 2024 releases: v1.29.2, v1.28.7, v1.27.11, v1.26.14.  
Only the `vxlan` backend is supported.
:::

For example, to change the interface MTU, you can use the following chart values:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-flannel-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-flannel
  namespace: kube-system
spec:
  valuesContent: |-
    flannel:
      mtu: 9000
```

:::warning
Flannel does not support network policies. Therefore, it is not recommended for hardened installations.
:::

</TabItem>
</Tabs>

## Dual-stack configuration

IPv4/IPv6 dual-stack networking enables the allocation of both IPv4 and IPv6 addresses to Pods and Services. To configure RKE2 in dual-stack mode, in the control-plane nodes, you must set a valid IPv4/IPv6 dual-stack cidr for pods and services. To do so, use the `cluster-cidr` and `service-cidr` configuration file keys:

```yaml
#/etc/rancher/rke2/config.yaml
cluster-cidr: "10.42.0.0/16,2001:cafe:42::/56"
service-cidr: "10.43.0.0/16,2001:cafe:43::/112"
```

Each CNI Plugin may require a different configuration for dual-stack:

<Tabs groupId = "CNIplugin" queryString>
<TabItem value="Canal CNI Plugin" default>

Canal automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration. Dual-stack is currently not supported in the windows installations of RKE2.

</TabItem>
<TabItem value="Cilium CNI Plugin" default>

Cilium automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration.

</TabItem>
<TabItem value="Calico CNI Plugin" default>

Calico automatically detects the RKE2 configuration for dual-stack and does not need any extra configuration. When deployed in dual-stack mode, it creates two different ippool resources. Note that when using dual-stack, calico leverages BGP instead of VXLAN encapsulation. Dual-stack and BGP are currently not supported in the windows installations of RKE2.
</TabItem>
<TabItem value="Flannel CNI Plugin" default>

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
