---
title: Multus
---

## Using Multus

[Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) is a CNI Plugin that enables attaching multiple network interfaces to pods. Multus does not replace CNI Plugins, instead it acts as a CNI Plugin multiplexer. Multus is useful in certain use cases, especially when pods are network intensive and require extra network interfaces that support dataplane acceleration techniques such as SR-IOV.

Multus can not be deployed standalone. It always requires at least one conventional CNI Plugin that fulfills the Kubernetes cluster network requirements. That CNI Plugin becomes the default for Multus, and will be used to provide the primary interface for all pods.

To enable Multus, specify `multus` as the first list entry in the `cni` configuration file key, followed by the name of the plugin you want to use alongside Multus (or `none` if you will provide your own default plugin). Note that multus must always be in the first position of the list. For example, to use Multus with Canal as the primary CNI Plugin:

```yaml
# /etc/rancher/rke2/config.yaml
cni:
- multus
- canal
```

For more information about Multus, refer to the [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs) documentation.

## Using Multus with Cilium
:::info Version Gate
Disabling the `exclusive` flag is not required starting with November 2025 releases: v1.31.14+rke2r1, v1.32.10+rke2r1,v1.33.6+rke2r1 and v1.34.2+rke2r1.
:::

To use Cilium with Multus the `exclusive` config needs to be disabled.
You can do this by using the following HelmChartConfig:

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
    cni:
      exclusive: false
```

## Using Multus with the containernetworking plugins

Any CNI Plugin can be used as secondary CNI Plugin for Multus to provide additional network interfaces attached to a pod. However, it is most common to use the CNI Plugins maintained by the Kubernetes ContainerNetworking team (bridge, host-device, macvlan, etc) as secondary CNI Plugins for Multus. The Kubernetes ContainerNetworking team plugins are automatically deployed when installing Multus. For more information about these plugins, refer to the [ContainerNetworking Plugins](https://www.cni.dev/plugins/current) documentation.

To use any of these plugins, a proper NetworkAttachmentDefinition object will need to be created to define the configuration of the secondary network. The definition is then referenced by pod annotations, which Multus will use to provide extra interfaces to that pod. An example using the `macvlan` CNI Pllugin with Multus is available [in the multus-cni repo](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md#storing-a-configuration-as-a-custom-resource).

## Multus IPAM plugin options

<Tabs groupId="MultusIPAMplugins">
<TabItem value="host-local" default>
host-local IPAM plugin allocates ip addresses out of a set of address ranges. It stores the state locally on the host filesystem, therefore ensuring uniqueness of IP addresses on a single host. Therefore, we don't recommend it for multi-node clusters. This IPAM plugin does not require any extra deployment. For more information: https://www.cni.dev/plugins/current/ipam/host-local/.
</TabItem>
<TabItem value="Multus DHCP daemon">

Multus provides an optional daemonset to deploy the DHCP daemon required to run the [DHCP IPAM plugin](https://www.cni.dev/plugins/current/ipam/dhcp/).

You can do this by using the following [HelmChartConfig](../add-ons/helm.md#customizing-packaged-components-with-helmchartconfig):
```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    manifests:
      dhcpDaemonSet: true
```

This will configure the chart for Multus to deploy the DHCP daemonset.
This feature is available starting with the 2024-01 releases (v1.29.1+rke2r1, v1.28.6+rke2r1, v1.27.10+rke2r1, v1.26.13+rke2r1).

NOTE: You should write this file before starting rke2.
</TabItem>
<TabItem value="Whereabouts">

[Whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts) is an IP Address Management (IPAM) CNI Plugin that assigns IP addresses cluster-wide.
RKE2 includes the option to use Whereabouts with Multus to manage the IP addresses of the additional interfaces created through Multus.
In order to do this, you need to use [HelmChartConfig](../add-ons/helm.md#customizing-packaged-components-with-helmchartconfig) to configure the Multus CNI to use Whereabouts.

You can do this by using the following HelmChartConfig:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    rke2-whereabouts:
      enabled: true
```

This will configure the chart for Multus to use `rke2-whereabouts` as a dependency.

NOTE: You should write this file before starting rke2.
</TabItem>
</Tabs>

## Using Multus with the "thick plugin" option (Experimental)
:::info Version Gate
This feature is available starting with versions v1.31.11+rke2r1, v1.32.7+rke2r1 and v1.33.3+rke2r1.
:::

rke2 now supports deploying Multus with a new architecture called ["thick plugin"](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/thick-plugin.md).

You can enable with this HelmChartConfig:
```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    thickPlugin:
      enabled: true
```

### Enabling Multus Dynamic Networks Controller
One use case for using Multus "thick plugin" is to deploy the [Dynamic Networks Controller](https://github.com/k8snetworkplumbingwg/multus-dynamic-networks-controller). This is done through the following HelmChartConfig:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-multus-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-multus
  namespace: kube-system
spec:
  valuesContent: |-
    thickPlugin:
      enabled: true
    dynamicNetworksController:
      enabled: true
```
:::note
The Dynamic Networks Controller can be deployed only with Multus in "thick plugin" mode. 
:::

## Using Multus with SR-IOV

Using the SR-IOV CNI with Multus can help with data-plane acceleration use cases, providing an extra interface in the pod that can achieve very high throughput. Complete deployment steps, prerequisites, and hardware compatibility details can be found in the [SR-IOV Network Operator Quickstart Guide](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/quickstart.md)

For fully validated configurations and enterprise-grade infrastructure support for SR-IOV in RKE2, refer to [SUSE Telco Cloud](https://documentation.suse.com/suse-edge/3.5/html/edge/atip-features.html#sriov)
