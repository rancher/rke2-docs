---
title: "Helm Integration"
---

Helm is the package management tool of choice for Kubernetes. Helm charts provide templating syntax for Kubernetes YAML manifest documents. With Helm we can create configurable deployments instead of just using static files. For more information about creating your own catalog of deployments, check out the docs at [https://helm.sh/docs/intro/quickstart/](https://helm.sh/docs/intro/quickstart/).

RKE2 does not require any special configuration to use with Helm command-line tools. Just be sure you have properly set up your kubeconfig as per the section about [cluster access](./cluster_access.md). RKE2 does include some extra functionality to make deploying both traditional Kubernetes resource manifests and Helm Charts even easier with the [rancher/helm-release CRD.](#using-the-helm-crd)

This section covers the following topics:

- [Automatically Deploying Manifests and Helm Charts](#automatically-deploying-manifests-and-helm-charts)
- [Using the Helm CRD](#using-the-helm-crd)
- [Customizing Packaged Components with HelmChartConfig](#customizing-packaged-components-with-helmchartconfig)

### Automatically Deploying Manifests and Helm Charts

Any Kubernetes manifests found in `/var/lib/rancher/rke2/server/manifests` will automatically be deployed to RKE2 in a manner similar to `kubectl apply`. Manifests deployed in this manner are managed as AddOn custom resources, and can be viewed by running `kubectl get addon -A`. You will find AddOns for packaged components such as CoreDNS, Nginx-Ingress, etc. AddOns are created automatically by the deploy controller, and are named based on their filename in the manifests directory.

It is also possible to deploy Helm charts as AddOns. RKE2 includes a [Helm Controller](https://github.com/k3s-io/helm-controller/) that manages Helm charts using a HelmChart Custom Resource Definition (CRD).

### Using the Helm CRD

The [HelmChart resource definition](https://github.com/k3s-io/helm-controller#helm-controller) captures most of the options you would normally pass to the `helm` command-line tool. Here's an example of how you might deploy Grafana from the default chart repository, overriding some of the default chart values. Note that the HelmChart resource itself is in the `kube-system` namespace, but the chart's resources will be deployed to the `monitoring` namespace.

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: grafana
  namespace: kube-system
spec:
  chart: stable/grafana
  targetNamespace: monitoring
  set:
    adminPassword: "NotVerySafePassword"
  valuesContent: |-
    image:
      tag: master
    env:
      GF_EXPLORE_ENABLED: true
    adminUser: admin
    sidecar:
      datasources:
        enabled: true
```

An example of deploying a helm chart from a private repo with authentication:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  namespace: kube-system
  name: example-app
spec:
  targetNamespace: example-space
  createNamespace: true
  version: v1.2.3
  chart: example-app
  repo: https://secure-repo.example.com
  authSecret:
    name: example-repo-auth
  repoCAConfigMap:
    name: example-repo-ca
  valuesContent: |-
    image:
      tag: v1.2.2
---
apiVersion: v1
kind: Secret
metadata:
  namespace: kube-system
  name: example-repo-auth
type: kubernetes.io/basic-auth
stringData:
  username: user
  password: pass
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: kube-system
  name: example-repo-ca
data:
  ca.crt: |-
    -----BEGIN CERTIFICATE-----
    <YOUR CERTIFICATE>
    -----END CERTIFICATE-----
```

#### HelmChart Field Definitions

| Field | Default | Description | Helm Argument / Flag Equivalent |
|-------|---------|-------------|-------------------------------|
| metadata.name |   | Helm Chart name | NAME |
| spec.chart |   | Helm Chart name in repository, or complete HTTPS URL to chart archive (.tgz) | CHART |
| spec.targetNamespace | default | Helm Chart target namespace | `--namespace` |
| spec.createNamespace | false | Create target namespace if not present | `--create-namespace` |
| spec.version |   | Helm Chart version (when installing from repository) | `--version` |
| spec.repo |   | Helm Chart repository URL | `--repo` |
| spec.repoCA | | Verify certificates of HTTPS-enabled servers using this CA bundle. Should be a string containing one or more PEM-encoded CA Certificates. | `--ca-file` |
| spec.repoCAConfigMap | | Reference to a ConfigMap containing CA Certificates to be be trusted by Helm. Can be used along with or instead of `repoCA` | `--ca-file` |
| spec.helmVersion | v3 | Helm version to use (`v2` or `v3`) |  |
| spec.bootstrap | False | Set to True if this chart is needed to bootstrap the cluster (Cloud Controller Manager, etc) |  |
| spec.set |   | Override simple default Chart values. These take precedence over options set via valuesContent. | `--set` / `--set-string` |
| spec.jobImage |   | Specify the image to use when installing the helm chart. E.g. rancher/klipper-helm:v0.3.0 . | |
| spec.backOffLimit | 1000 | Specify the number of retries before considering a job failed. | |
| spec.timeout | 300s | Timeout for Helm operations, as a [duration string](https://pkg.go.dev/time#ParseDuration) (`300s`, `10m`, `1h`, etc) | `--timeout` |
| spec.failurePolicy | reinstall | Set to `abort` which case the Helm operation is aborted, pending manual intervention by the operator. | |
| spec.authSecret | | Reference to Secret of type `kubernetes.io/basic-auth` holding Basic auth credentials for the Chart repo. | |
| spec.authPassCredentials | false | Pass Basic auth credentials to all domains. | `--pass-credentials` |
| spec.dockerRegistrySecret | | Reference to Secret of type `kubernetes.io/dockerconfigjson` holding Docker auth credentials for the OCI-based registry acting as the Chart repo. | |
| spec.valuesContent |   | Override complex default Chart values via YAML file content | `--values` |
| spec.chartContent |   | Base64-encoded chart archive .tgz - overrides spec.chart | CHART |

### Customizing Packaged Components with HelmChartConfig

To allow overriding values for packaged components that are deployed as HelmCharts (such as Canal, CoreDNS, Nginx-Ingress, etc), RKE2 supports customizing deployments via a `HelmChartConfig` resources. The `HelmChartConfig` resource must match the name and namespace of its corresponding HelmChart, and supports providing additional `valuesContent`, which is passed to the `helm` command as an additional value file.

:::note
HelmChart `spec.set` values override HelmChart and HelmChartConfig `spec.valuesContent` settings.
:::

For example, to customize the packaged CoreDNS configuration, you can create a file named `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` and populate it with the following content:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-coredns
  namespace: kube-system
spec:
  valuesContent: |-
    image: coredns/coredns
    imageTag: v1.7.1
```

You can find all the packaged Helm charts including their documentation and default values in the [RKE2 charts repository](https://github.com/rancher/rke2-charts/tree/main/charts).

#### File Naming Requirements

The `AddOn` name for each file in the manifest directory is derived from the file basename. 
Ensure that all files within the manifests directory (or within any subdirectories) have names that are unique, and adhere to Kubernetes [object naming restrictions](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/).
Care should also be taken not to conflict with names in use by the default RKE2 packaged components, even if those components are disabled.

An example of an error that would be reported if the file name contains underscores:
> `Failed to process config: failed to process /var/lib/rancher/rke2/server/manifests/example_manifest.yaml:
   Addon.k3s.cattle.io "example_manifest" is invalid: metadata.name: Invalid value: "example_manifest": 
   a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character
   (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')`