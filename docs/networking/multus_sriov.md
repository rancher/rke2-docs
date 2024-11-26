---
title: Multus and SR-IOV
---


## Using Multus

[Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) is a CNI plugin that enables attaching multiple network interfaces to pods. Multus does not replace CNI plugins, instead it acts as a CNI plugin multiplexer. Multus is useful in certain use cases, especially when pods are network intensive and require extra network interfaces that support dataplane acceleration techniques such as SR-IOV.

Multus can not be deployed standalone. It always requires at least one conventional CNI plugin that fulfills the Kubernetes cluster network requirements. That CNI plugin becomes the default for Multus, and will be used to provide the primary interface for all pods.

To enable Multus, add multus as the first list entry in the cni config key, followed by the name of the plugin you want to use alongside Multus (or `none` if you will provide your own default plugin). Note that multus must always be in the first position of the list. For example, to use Multus with canal as the default plugin you could specify:

```yaml
# /etc/rancher/rke2/config.yaml
cni:
- multus
- canal
```

This can also be specified with command-line arguments, i.e. `--cni=multus,canal` or `--cni=multus --cni=canal`.

For more information about Multus, refer to the [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni/tree/master/docs) documentation.

## Using Multus with Cilium

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

Any CNI plugin can be used as secondary CNI plugin for Multus to provide additional network interfaces attached to a pod. However, it is most common to use the CNI plugins maintained by the containernetworking team (bridge, host-device, macvlan, etc) as secondary CNI plugins for Multus. These containernetworking plugins are automatically deployed when installing Multus. For more information about these plugins, refer to the [containernetworking plugins](https://www.cni.dev/plugins/current) documentation.

To use any of these plugins, a proper NetworkAttachmentDefinition object will need to be created to define the configuration of the secondary network. The definition is then referenced by pod annotations, which Multus will use to provide extra interfaces to that pod. An example using the macvlan cni plugin with Multus is available [in the multus-cni repo](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md#storing-a-configuration-as-a-custom-resource).

## Multus IPAM plugin options

<Tabs groupId = "MultusIPAMplugins">
<TabItem value="host-local" default>
host-local IPAM plugin allocates ip addresses out of a set of address ranges. It stores the state locally on the host filesystem, therefore ensuring uniqueness of IP addresses on a single host. Therefore, we don't recommend it for multi-node clusters. This IPAM plugin does not require any extra deployment. For more information: https://www.cni.dev/plugins/current/ipam/host-local/.
</TabItem>
<TabItem value="Multus DHCP daemon" default>

Multus provides an optional daemonset to deploy the DHCP daemon required to run the [DHCP IPAM plugin](https://www.cni.dev/plugins/current/ipam/dhcp/).

You can do this by using the following [HelmChartConfig](../helm.md#customizing-packaged-components-with-helmchartconfig):
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
<TabItem value="Whereabouts" default>

[Whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts) is an IP Address Management (IPAM) CNI plugin that assigns IP addresses cluster-wide.
RKE2 includes the option to use Whereabouts with Multus to manage the IP addresses of the additional interfaces created through Multus.
In order to do this, you need to use [HelmChartConfig](../helm.md#customizing-packaged-components-with-helmchartconfig) to configure the Multus CNI to use Whereabouts.

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

## Using Multus with SR-IOV

Using the SR-IOV CNI with Multus can help with data-plane acceleration use cases, providing an extra interface in the pod that can achieve very high throughput. SR-IOV will not work in all environments, and there are several requirements
that must be fulfilled to consider the node as SR-IOV capable:

* Physical NIC must support SR-IOV (e.g. by checking /sys/class/net/$NIC/device/sriov_totalvfs)
* The host operating system must activate IOMMU virtualization
* The host operating system includes drivers capable of doing sriov (e.g. i40e, vfio-pci, etc)

The SR-IOV CNI plugin cannot be used as the default CNI plugin for Multus; it must be deployed alongside both Multus and a traditional CNI plugin. The SR-IOV CNI helm chart can be found in the `rancher-charts` Helm repo. For more information see [Rancher Helm Charts documentation](https://ranchermanager.docs.rancher.com/pages-for-subheaders/helm-charts-in-rancher).

After installing the SR-IOV CNI chart, the SR-IOV operator will be deployed. Then, the user must specify what nodes in the cluster are SR-IOV capable by labeling them with `feature.node.kubernetes.io/network-sriov.capable=true`:

```bash
kubectl label node $NODE-NAME feature.node.kubernetes.io/network-sriov.capable=true
```

Once labeled, the sriov-network-config Daemonset will deploy a pod to the node to collect information about the network interfaces. That information is available through the `sriovnetworknodestates` Custom Resource Definition. A couple of
minutes after the deployment, there will be one `sriovnetworknodestates` resource per node, with the name of the node as the resource name.

NOTE: the SR-IOV CNI chart from `rancher-charts` now includes the `node-feature-discovery` chart as an automatic dependency. This chart deploys a small daemonset that automatically labels each node based on the capabilities detected on that node. This works for both hardware and software features. In particular, `node-feature-discovery` can automatically add the label `feature.node.kubernetes.io/network-sriov.capable=true` when it detects a compatible node.
For more information, see the [NFD documentation](https://kubernetes-sigs.github.io/node-feature-discovery/v0.11/get-started/introduction.html).

However, the latest versions of the sriov-network-operator also include a whitelist of supported hardware so sriov will actually be available only with the NICs on [that list](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/supported-hardware.md). If you want to use the SR-IOV CNI with a NIC that is not on the list, you will need to update the `supported-nic-ids` configMap yourself.

For more information about how to use the SR-IOV operator, please refer to [sriov-network-operator](https://github.com/k8snetworkplumbingwg/sriov-network-operator/blob/master/doc/quickstart.md#configuration)
