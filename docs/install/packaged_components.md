---
title: Managing Packaged Components
---

## Auto-Deploying Manifests (AddOns)

On server nodes, any file found in `/var/lib/rancher/rke2/server/manifests` will automatically be deployed to Kubernetes in a manner similar to `kubectl apply`, both on startup and when the file is changed on disk. Deleting files out of this directory will not delete the corresponding resources from the cluster.

Manifests are tracked as `AddOn` custom resources in the `kube-system` namespace. Any errors or warnings encountered when applying the manifest file may be seen by using `kubectl describe` on the corresponding `AddOn`, or by using `kubectl get event -n kube-system` to view all events for that namespace, including those from the deploy controller.

### Packaged Components

RKE2 comes with a number of packaged components that are deployed as AddOns via the manifests directory, for example `rke2-coredns`, `rke2-metrics-server`, `rke2-ingress-nginx` and so on.

Manifests for packaged components are managed by RKE2, and should not be altered. The files are re-written to disk whenever RKE2 is started, in order to ensure their integrity.

### User AddOns

You may place additional files in the manifests directory for deployment as an `AddOn`. Each file may contain multiple Kubernetes resources, delimited by the `---` YAML document separator. For more information on organizing resources in manifests, see the [Managing Resources](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/) section of the Kubernetes documentation.

#### File Naming Requirements

The `AddOn` name for each file in the manifest directory is derived from the file basename. 
Ensure that all files within the manifests directory (or within any subdirectories) have names that are unique, and adhere to Kubernetes [object naming restrictions](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/).
Care should also be taken not to conflict with names in use by the default RKE2 packaged components, even if those components are disabled.

:::danger
If you have multiple server nodes, and place additional AddOn manifests on more than one server, it is your responsibility to ensure that files stay in sync across those nodes. RKE2 does not sync AddOn content between nodes, and cannot guarantee correct behavior if different servers attempt to deploy conflicting manifests.
:::

## Disabling Manifests

There are two ways to disable deployment of specific content from the manifests directory.

### Using the `--disable` flag

The AddOns for packaged components listed above, in addition to AddOns for any additional manifests placed in the `manifests` directory, can be disabled with the `--disable` flag. Disabled AddOns are actively uninstalled from the cluster, and the source files deleted from the `manifests` directory.

For example, to disable the metrics-server from being installed on a new cluster, or to uninstall it and remove the manifest from an existing cluster, you can start RKE2 with `--disable=rke2-metrics-server`. Multiple items can be disabled by separating their names with commas, or by repeating the flag.

### Using .skip files

For any file under `/var/lib/rancher/rke2/server/manifests`, you can create a `.skip` file which will cause RKE2 to ignore the corresponding manifest. The contents of the `.skip` file do not matter, only its existence is checked. Note that creating a `.skip` file after an AddOn has already been created will not remove or otherwise modify it or the resources it created; the file is simply treated as if it did not exist.

## Helm AddOns

For information about managing Helm charts via auto-deploying manifests, refer to the section about [Helm.](../helm.md)



