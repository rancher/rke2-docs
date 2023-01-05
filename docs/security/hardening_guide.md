---
title: CIS Hardening Guide
---

This document provides prescriptive guidance for hardening a production installation of RKE2. It outlines the configurations and controls required to address Kubernetes benchmark controls from the Center for Internet Security (CIS).

For more details about evaluating a hardened cluster against the official CIS benchmark, refer to the CIS Benchmark [Self-Assessment Guide v1.23](cis_self_assessment123.md), or [Self-Assessment Guide v1.6](cis_self_assessment16.md) for RKE2 versions prior to v1.25.

RKE2 is designed to be "hardened by default" and pass the majority of the Kubernetes CIS controls without modification. There are a few notable exceptions to this that require manual intervention to fully pass the CIS Benchmark:

1. RKE2 will not modify the host operating system. Therefore, you, the operator, must make a few host-level modifications.
2. Certain CIS controls for Network Policies and Pod Security Standards (or Pod Security Policies (PSP) on RKE2 versions prior to v1.25) will restrict the functionality of the cluster. You must opt into having RKE2 configure these for you. To help ensure these requirements are met, RKE2 can be started with the `profile` flag set to `cis-1.23`, or `cis-1.6`. 

:::note
This guide assumes that RKE2 has been installed, but is not yet running. If you have already started RKE2, you will need to stop the RKE2 service.
:::

## Host-level requirements

There are two areas of host-level requirements: kernel parameters and etcd process/directory configuration. These are outlined in this section.

### Ensure `protect-kernel-defaults` is set

This is a kubelet flag that will cause the kubelet to exit if the required kernel parameters are unset or are set to values that are different from the kubelet's defaults.

When the `profile` flag is set, RKE2 will set the flag to `true`.

:::note
`protect-kernel-defaults` is exposed as a top-level flag for RKE2. If you have set `profile` to `cis-1.XX` and `protect-kernel-defaults` to `false` explicitly, RKE2 will exit with an error.
:::

RKE2 will also check the same kernel parameters that the kubelet does and exit with an error following the same rules as the kubelet. This is done as a convenience to help the operator more quickly and easily identify what kernel parameters are violating the kubelet defaults.

### Ensure etcd is configured properly

The CIS Benchmark requires that the etcd data directory be owned by the `etcd` user and group. This implicitly requires the etcd process run as the host-level `etcd` user. To achieve this, RKE2 takes several steps when started with a valid `cis-1.XX` profile:

1. Check that the `etcd` user and group exists on the host. If they don't, exit with an error.
2. Create etcd's data directory with `etcd` as the user and group owner.
3. Ensure the etcd process is run as the `etcd` user and group by setting the etcd static pod's `SecurityContext` appropriately.

### Setting up hosts

This section gives you the commands necessary to configure your host to meet the above requirements.

#### Set kernel parameters

When RKE2 is installed, it creates a sysctl config file to set the required parameters appropriately. However, it does not automatically configure the host to use this configuration. You must do this manually. The location of the config file depends on the installation method used.

If RKE2 was installed via RPM, YUM, or DNF (the default on OSes that use RPMs, such as CentOS), run the following commands:

```bash
sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
sudo systemctl restart systemd-sysctl
```

If RKE2 was installed via the tarball (the default on OSes that do not use RPMs, such as Ubuntu), run the following commands:

```bash
sudo cp -f /usr/local/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
sudo systemctl restart systemd-sysctl
```

If your system lacks the `systemd-sysctl.service` and/or the `/etc/sysctl.d` directory, you will want to make sure the sysctls are applied at boot by running the following command during start-up:

```bash
sudo sysctl -p /usr/local/share/rke2/rke2-cis-sysctl.conf
```

Please perform this step only on fresh installations, before actually using RKE2 to deploy Kubernetes. Many Kubernetes components, including CNI plugins, set up their own sysctls. Restarting the `systemd-sysctl` service on a running Kubernetes cluster can result in unexpected side-effects.

#### Create the etcd user
On some Linux distributions, the `useradd` command will not create a group. The `-U` flag is included below to account for that. This flag tells `useradd` to create a group with the same name as the user.

```bash
sudo useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
```

## RKE2 configuration

<Tabs groupId="rke2-version">
<TabItem value='v1.25 and Newer' default>

Below is the minimum necessary configuration needed for hardening RKE2 to pass CIS v1.23 hardened profile `rke2-cis-1.23-profile-hardened` available in Rancher.

```yaml
profile: "cis-1.23"           # CIS 4.2.6, 5.2.1, 5.2.8, 5.2.9, 5.3.2
```

</TabItem>
<TabItem value='v1.24 and Older'>

Below is the minimum necessary configuration needed for hardening RKE2 to pass CIS v1.6 hardened profile `rke2-cis-1.6-profile-hardened` available in Rancher.

```yaml
profile: "cis-1.6"           # CIS 4.2.6, 5.2.1, 5.2.8, 5.2.9, 5.3.2
```

</TabItem>
</Tabs>

The configuration file must be named `config.yaml` and placed in `/etc/rancher/rke2`. The directory needs to be created prior to installing RKE2.

When the `profile` flag is set it does the following:

<Tabs groupId="rke2-version">
<TabItem value='v1.25 and Newer' default>

1. Checks that host-level requirements have been met. If they haven't, RKE2 will exit with a fatal error describing the unmet requirements.

2. Applies network policies that allow the cluster to pass associated controls.

3. Configures the Pod Security Admission Controller to enforce restricted mode in all namespaces, with the exception of the `kube-system`, `cis-operator-system`, and `tigera-operator` namespaces.
   These namespaces are exempted to allow system pods to run without restrictions, which is required for proper operation of the cluster.  
   For more information about the PSA configuration, see the default [Pod Security Admission configurations](pod_security_standards.md#pod-security-standards).  
   For more information about Pod Security Standards, please refer to the [official documentation](https://kubernetes.io/docs/concepts/security/pod-security-standards/).


:::note
The only valid value for the profile flag is `cis-1.23`. It accepts a string value to allow for other profiles in the future.
:::

</TabItem>

<TabItem value='v1.24 and Older'>

1. Checks that host-level requirements have been met. If they haven't, RKE2 will exit with a fatal error describing the unmet requirements.
2. Applies network policies that allow the cluster to pass associated controls.
3. Configures runtime pod security policies that allow the cluster to pass associated controls.

:::note
The only valid values for the profile flag are `cis-1.5` or `cis-1.6`.  
The self-assessment guide for CIS v1.5 (`cis-1.5`) was removed from this documentation, since this version is applicable only to Kubernetes v1.15 which is not supported anymore. The profile, however, is still available in RKE2.
:::

</TabItem>
</Tabs>

## Kubernetes runtime requirements

The runtime requirements to pass the CIS Benchmark are centered around pod security and network policies. Most of this is automatically handled by RKE2 when using a valid `cis-1.XX` profile, but some additional operator intervention is required.

### Pod Security

RKE2 always runs with some amount of pod security. 

<Tabs groupId="rke2-version">
<TabItem value='v1.25 and Newer' default>

On v1.25 and newer, [Pod Security Admission (PSA)](https://kubernetes.io/docs/concepts/security/pod-security-admission/) are used for pod security. A default Pod Security Admission config file will be added to the cluster upon startup as follows:

With the `cis-1.23` profile:
*  RKE2 will apply a restricted pod security standard via a configuration file which will enforce `restricted` mode throughout the cluster with an exception to the `kube-system` and `cis-operator-system` namespaces to ensure successful operation of system pods.

Without the `cis-1.23` profile:
* RKE2 will apply a nonrestricted pod security standard via a configuration file which will enforce `privileged` mode throughout the cluster which allows a completely unrestricted mode to all pods in the cluster.

See the [Pod Security Policies](pod_security_standards.md) page for more details.
</TabItem>

<TabItem value='v1.24 and Older'>
On v1.24 and older, the `PodSecurityPolicy` admission controller is always enabled. A policy is applied based on the profile passed to RKE2.

With the `cis-1.6` profile:
* RKE2 will put a much more restrictive set of policies in place. These policies meet the requirements outlined in section 5.2 of the CIS Benchmark.

Without the `cis-1.6` profile:
* RKE2 will put an unrestricted policy in place that allows Kubernetes to run as though the `PodSecurityPolicy` admission controller was not enabled.

See the [Pod Security Policies](pod_security_policies.md) page for more details.
</TabItem>
</Tabs>

:::note
The Kubernetes control plane components and critical additions such as CNI, DNS, and Ingress are ran as pods in the `kube-system` namespace. Therefore, this namespace will have a policy that is less restrictive so that these components can run properly.
:::

### Network Policies

When ran with a valid "cis-1.XX" profile, RKE2 will put `NetworkPolicies` in place that passes the CIS Benchmark for Kubernetes' built-in namespaces. These namespaces are: `kube-system`, `kube-public`, `kube-node-lease`, and `default`.

The `NetworkPolicy` used will only allow pods within the same namespace to talk to each other. The notable exception to this is that it allows DNS requests to be resolved.

:::caution Operator Intervention Required
Operators must manage network policies as normal for additional namespaces that are created.
:::

### Configure `default` service account

**Set `automountServiceAccountToken` to `false` for `default` service accounts**

Kubernetes provides a `default` service account which is used by cluster workloads where no specific service account is assigned to the pod. Where access to the Kubernetes API from a pod is required, a specific service account should be created for that pod, and rights granted to that service account. The `default` service account should be configured such that it does not provide a service account token and does not have any explicit rights assignments.

For each namespace including `default` and `kube-system` on a standard RKE2 install, the `default` service account must include this value:

```yaml
automountServiceAccountToken: false
```

:::caution Operator Intervention Required

For namespaces created by the cluster operator, the following script and configuration file can be used to configure the `default` service account.

The configuration below must be saved to a file called `account_update.yaml`.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
automountServiceAccountToken: false
```

Create a bash script file called `account_update.sh`. Be sure to `sudo chmod +x account_update.sh` so the script has execute permissions.

```bash
#!/bin/bash -e

for namespace in $(kubectl get namespaces -A -o=jsonpath="{.items[*]['metadata.name']}"); do
  echo -n "Patching namespace $namespace - "
  kubectl patch serviceaccount default -n ${namespace} -p "$(cat account_update.yaml)"
done
```

Execute this script to apply the `account_update.yaml` configuration to `default` service account in all namespaces.

:::

### API Server audit configuration

CIS requirements 1.2.22 to 1.2.25 are related to configuring audit logs for the API Server. When RKE2 is started with the `profile` flag set, it will automatically configure hardened `--audit-log-` parameters in the API Server to pass those CIS checks.

RKE2's default audit policy is configured to not log requests in the API Server. This is done to allow cluster operators flexibility to customize an audit policy that suits their auditing requirements and needs, as these are specific to each users' environment and policies.

A default audit policy is created by RKE2 when started with the `profile` flag set. The policy is defined in `/etc/rancher/rke2/audit-policy.yaml`.

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
metadata:
  creationTimestamp: null
rules:
- level: None
```

:::caution Operator Intervention Required
To start logging requests to the API Server, at least `level` parameter must be modified, for example, to `Metadata`. Detailed information about policy configuration for the API server can be found in the Kubernetes [documentation](https://kubernetes.io/docs/tasks/debug-application-cluster/audit/).

After adapting the audit policy, RKE2 must be restarted to load the new configuration.

```shell
sudo systemctl restart rke2-server.service
```
:::

API Server audit logs will be written to `/var/lib/rancher/rke2/server/logs/audit.log`.

## Known issues

The following are controls that RKE2 currently does not pass. Each gap will be explained and whether it can be passed through manual operator intervention or if it will be addressed in a future release.

### Control 1.1.12
Ensure that the etcd data directory ownership is set to `etcd:etcd`.

**Rationale**  
etcd is a highly-available key-value store used by Kubernetes deployments for persistent storage of all of its REST API objects. This data directory should be protected from any unauthorized reads or writes. It should be owned by `etcd:etcd`.

**Remediation**  
This can be remediated by creating an `etcd` user and group as described [above](#create-the-etcd-user).

### Control 5.1.5
Ensure that default service accounts are not actively used

**Rationale**  
Kubernetes provides a `default` service account which is used by cluster workloads where no specific service account is assigned to the pod.

Where access to the Kubernetes API from a pod is required, a specific service account should be created for that pod, and rights granted to that service account.

The `default` service account should be configured such that it does not provide a service account token and does not have any explicit rights assignments.

This can be remediated by updating the `automountServiceAccountToken` field to `false` for the `default` service account in each namespace.

**Remediation**  
You can manually update this field on service accounts in your cluster to pass the control as described [above](#configure-default-service-account).

### Control 5.3.2
Ensure that all Namespaces have Network Policies defined

**Rationale**  
Running different applications on the same Kubernetes cluster creates a risk of one compromised application attacking a neighboring application. Network segmentation is important to ensure that containers can communicate only with those they are supposed to. A network policy is a specification of how selections of pods are allowed to communicate with each other and other network endpoints.

Network Policies are namespace scoped. When a network policy is introduced to a given namespace, all traffic not allowed by the policy is denied. However, if there are no network policies in a namespace all traffic will be allowed into and out of the pods in that namespace.

**Remediation**  
This can be remediated by starting RKE2 with the `profile` flag set in the configuration file as described [above](#rke2-configuration).

## Conclusion

If you have followed this guide, your RKE2 cluster will be configured to pass the CIS Kubernetes Benchmark. You can review our CIS Benchmark Self-Assessment Guide [v1.6](cis_self_assessment16.md) or [v1.23](cis_self_assessment123.md) to understand how we verified each of the benchmarks and how you can do the same on your cluster.
