---
title: RKE2 security responder
---

The RKE2 security responder is an optional component that helps identify security updates for the RKE2 version running in your cluster. It collects non-identifying cluster metadata and sends it to an endpoint. The endpoint returns information about newer versions and security advisories that may apply to the cluster. The source code for the security responder project is available in the [`rancher/rke2-security-responder` GitHub repository](https://github.com/rancher/rke2-security-responder).

:::info Version Gate
The RKE2 security responder is available beginning with RKE2 v1.37 as an opt-out component.
:::

## How it works

The security responder runs as a Kubernetes `CronJob` in the `kube-system` namespace. It runs every eight hours, collects the configured metadata, sends one request, and exits. It does not run as a persistent daemon or continuously monitor workloads.

The default schedule is:

```text
0 */8 * * *
```

The responder retries a failed request up to three times. If the request cannot be completed, the failure does not affect the cluster and no data is queued for later delivery. The responder also operates in disconnected and air-gapped environments without requiring a successful request.


### Typical output

You can view the responder's output in the logs of the Pod created for a scheduled run. A successful response can look like this:

```text
time="2026-08-28T09:42:04Z" level=info msg="response received" intervalMinutes=60 newer=13 versions=34
time="2026-08-28T09:42:04Z" level=warning msg="The RKE2 version v1.34.7+rke2r1 includes CVEs. These are the 5 most relevant: CVE-2026-27145, CVE-2026-29181, CVE-2026-33814, CVE-2026-33818, CVE-2026-35469. Please upgrade to a newer version to fix security vulnerabilities"
time="2026-08-28T09:42:04Z" level=info msg="available version" releaseDate="2026-08-04T21:12:44Z" releaseNotesURL="https://github.com/rancher/rke2/releases/tag/v1.36.3%2Brke2r1" version=v1.36.3+rke2r1
time="2026-08-28T09:42:04Z" level=info msg="available version" releaseDate="2026-08-04T20:04:30Z" releaseNotesURL="https://github.com/rancher/rke2/releases/tag/v1.34.10%2Brke2r1" version=v1.34.10+rke2r1
```

The messages indicate the following:

- `response received` confirms that the endpoint responded. `versions` is the total number of versions returned, `newer` is the number newer than the running RKE2 version, and `intervalMinutes` is the server-provided recommendation for the next check interval.
- The `warning` message indicates that the running RKE2 version has known CVEs and lists the five most relevant CVEs.
- Each `available version` message identifies a newer RKE2 release, its release date, and a link to its release notes. Upgrade to a release that addresses the reported vulnerabilities.

## Inspect the output

```bash
kubectl get cronjob -n kube-system rke2-security-responder
```

Each CronJob run creates a Job and a short-lived Pod. To retrieve the logs, first list the responder Jobs and identify the run you want to inspect:

```bash
kubectl get jobs -n kube-system
```

Then substitute the selected Job name in the following command:

```bash
kubectl logs -n kube-system job/<job-name>
```
You should see something similar to what is shown as typical output in the above section


## Data collected

The responder collects the following metadata, depending on the configured [collection mode](#collection-mode):

| Field | Description |
|-------|-------------|
| `kubernetesVersion` | Kubernetes version reported by the cluster. |
| `clusteruuid` | UID of the `kube-system` namespace, used to avoid counting the same cluster more than once. |
| `serverNodeCount` / `agentNodeCount` | Number of control-plane and agent nodes. |
| `serverCPU` / `agentCPU` | Total allocatable CPU, in millicores, for control-plane and agent nodes. |
| `serverMemory` / `agentMemory` | Total allocatable memory, in bytes, for control-plane and agent nodes. |
| `cni-plugin` / `cni-version` | CNI plugin and version, when detected. |
| `ingress-controller` / `ingress-version` | Ingress controller and version, when detected. |
| `operating-system` / `os` | Operating system information reported by the nodes. |
| `kernel` | Kernel version reported by the nodes. |
| `arch` | Node architecture. |
| `node-info-consistent` | Whether node operating system information is consistent across the cluster. |
| `selinux` | SELinux status, when detected. |
| `gpuNodeCount` / `gpu-vendor` | GPU node count and vendor, when detected. |
| `gpu-operator` / `gpu-operator-version` | GPU operator and version, when detected. |
| `rancher-managed` | Whether Rancher Manager manages the cluster. |
| `rancher-version` | Rancher Manager version, when detected. |
| `rancher-install-uuid` | Rancher Manager installation UUID, when detected. |
| `rancher-prime` | Whether the cluster uses a Rancher Prime distribution. |
| `system-default-registry` | The observed system default registry, when configured. |
| `ip-stack` | Cluster IP stack configuration: IPv4-only, IPv6-only, or dual-stack. |

The `clusteruuid` is derived from the Kubernetes `kube-system` namespace UID. It is used only for report deduplication and is not tied to an account, organization, or person.

## Collection mode

The `mode` Helm value controls how much cluster metadata is included in the report.

| Mode | Description |
|------|-------------|
| `recommended` | Sends the complete set of supported metadata. This is the default. |
| `minimal` | Reduces the report by redacting node counts, resource totals, and Rancher version and installation UUID. |

In `minimal` mode, the redacted numeric fields are sent as `-1`. This value means that the field was intentionally not reported; it does not represent the actual number of nodes or resources. The redacted Rancher fields are sent as empty strings.

The following information remains available in `minimal` mode:

- Kubernetes version and cluster UUID
- Operating system, kernel, architecture, SELinux status, and node information consistency
- CNI plugin, ingress controller, and IP stack configuration
- GPU vendor and operator information, when detected
- Whether Rancher Manager manages the cluster
- Rancher Prime distribution information and observed system default registry

## Privacy

The security responder does not collect:

- Workload data, pod contents, logs, or secrets
- Hostnames, cluster names, company names, or other identifying labels
- IP addresses as payload fields
- Configuration file contents beyond the specific metadata listed above

Requests are processed through Scarf for metadata enrichment. Scarf is an open-source artifact analytics platform that collects aggregate, non-personally identifiable telemetry to help us understand project adoption. It is well known and approved for usage in CNCF projects.


## Changing default options

It is possible to change the default behavior by using a `HelmChartConfig`. The `HelmChartConfig` must be named `rke2-security-responder` and be created in the `kube-system` namespace.

The following example changes the schedule to once per day at midnight (`0 0 * * *`) and enables `minimal` collection mode:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
    name: rke2-security-responder
    namespace: kube-system
spec:
    valuesContent: |-
        mode: minimal
        schedule: "0 0 * * *"
```

## Disable the security responder

The security responder is enabled by default. To disable it, add the following to the RKE2 configuration on each server node:

```yaml
# /etc/rancher/rke2/config.yaml
disable:
    - rke2-security-responder
```

Restart RKE2 after changing the configuration. RKE2 removes the packaged component and no further reports are collected.

:::note
Use `minimal` mode when you want to reduce the metadata shared while retaining security update notifications. Disable the component when you do not want any data to leave the cluster.
:::
