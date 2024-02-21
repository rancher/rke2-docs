---
title: "Requirements"
---

RKE2 is very lightweight, but has some minimum requirements as outlined below.

## Prerequisites

Two rke2 nodes cannot have the same node name. By default, the node name is taken from the machine's hostname.

If two or more of your machines have the same hostname, you must do one of the following:

* Update the hostname to a unique value
* Set the `node-name` parameter in the config file to a unique value
* Set the `with-node-id` parameter in the config file to `true` to append a randomly generated ID number to the hostname.

:::info Version Gate

The `with-node-id` parameter is available starting with the 2023-05 releases (v1.27.2+rke2r1, v1.26.5+rke2r1, v1.25.10+rke2r1, v1.24.14+rke2r1).

:::

## Operating Systems

### Linux
RKE2 has been tested and validated on the following operating systems, and their subsequent non-major releases:

| Distro | Version |
| - | - |
| Ubuntu | 18.04, 20.04, 22.04 |
| CentOS/RHEL | 7.8 |
| Rocky/RHEL | 8.5, 9.1 |
| Oracle Linux | 8.7 |
| Amazon Linux | 2023 |
| SLES | 15 SP3, SP4 |
| OpenSUSE, SLE Micro | 5.1, 5.2, 5.3, 5.4 |

### Windows
:::warning Version Gate
Experimental as of [v1.21.3+rke2r1](https://github.com/rancher/rke2/releases/tag/v1.21.3%2Brke2r1)
:::

:::info
Windows Support requires choosing Calico or Flannel as the CNI for the RKE2 cluster
:::

The RKE2 Windows Node (Worker) agent has been tested and validated on the following operating systems, and their subsequent non-major releases:

* Windows Server 2019 LTSC (amd64) (OS Build 17763.2061)
* Windows Server 2022 LTSC (amd64) (OS Build 20348.169)

**Note** The Windows Server Containers feature needs to be enabled for the RKE2 Windows agent to work.

Open a new Powershell window with Administrator privileges
```powershell
powershell -Command "Start-Process PowerShell -Verb RunAs"
```

In the new Powershell window, run the following command.
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers –All
```

This will require a reboot for the `Containers` feature to properly function.

## Hardware

Hardware requirements scale based on the size of your deployments. Minimum recommendations are outlined here.

### Linux/Windows
*    RAM: 4GB Minimum (we recommend at least 8GB)
*    CPU: 2 Minimum (we recommend at least 4CPU)

### VM Sizing Guide
When limited on CPU and RAM on the control-plane + etcd nodes, there could be limitations for the amount of agent nodes that can be joined under standard workload conditions.

| Server CPU | Server RAM | Number of Agents |
| ---------- | ---------- | ---------------- |
| 2          | 4 GB       | 0-225            |
| 4          | 8 GB       | 226-450          |
| 8          | 16 GB      | 451-1300         |
| 16+        | 32 GB      | 1300+            |

It is recommended to join agent nodes in batches of 50 or less to allow the CPU to free up space, as there is a spike on node join. Remember to modify the default `cluster-cidr` if desiring more than 255 nodes!

This data was retrieved under specific test conditions. It will vary depending upon environment and workloads. The steps below give an overview of the test that was run to retrieve this. It was last performed on v1.27.4+rke2r1. All of the machines were provisioned in AWS with standard 20 GiB gp3 volumes.
1. Monitor resources on grafana using prometheus data source.
2. Deploy workloads in such a way to simulate continuous cluster activity:
    - A basic workload that scales up and down continuously
    - A workload that is deleted and recreated in a loop
    - A constant workload that contains multiple other resources including CRDs.
3. Join agent nodes in batches of 30-50 at a time.

#### Disks

RKE2 performance depends on the performance of the database, and since RKE2 runs etcd embeddedly and it stores the data dir on disk, we recommend using an SSD when possible to ensure optimal performance.

## Networking

:::tip Important
If your node has NetworkManager installed and enabled, [ensure that it is configured to ignore CNI-managed interfaces.](../known_issues.md#networkmanager). If your node has Wicked installed and enabled, [ensure that the forwarding sysctl config is enabled](../known_issues.md#wicked)
:::

The RKE2 server needs port 6443 and 9345 to be accessible by other nodes in the cluster.

All nodes need to be able to reach other nodes over UDP port 8472 when Flannel VXLAN is used.

If you wish to utilize the metrics server, you will need to open port 10250 on each node.

**Important:** The VXLAN port on nodes should not be exposed to the world as it opens up your cluster network to be accessed by anyone. Run your nodes behind a firewall/security group that disables access to port 8472.

### Inbound Network Rules

| Protocol | Port        | Source            | Destination       | Description
|----------|-------------|-------------------|-------------------|---|
| TCP      | 9345        | RKE2 agent nodes  | RKE2 server nodes | RKE2 supervisor API
| TCP      | 6443        | RKE2 agent nodes  | RKE2 server nodes | Kubernetes API
| UDP      | 8472        | All RKE2 nodes    | All RKE2 nodes    | Required only for Flannel VXLAN
| TCP      | 10250       | All RKE2 nodes    | All RKE2 nodes    | kubelet metrics
| TCP      | 2379        | RKE2 server nodes | RKE2 server nodes | etcd client port
| TCP      | 2380        | RKE2 server nodes | RKE2 server nodes | etcd peer port
| TCP      | 2381        | RKE2 server nodes | RKE2 server nodes | etcd metrics port
| TCP      | 30000-32767 | All RKE2 nodes    | All RKE2 nodes    | NodePort port range
| UDP      | 8472        | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI VXLAN
| TCP      | 4240        | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI health checks
| ICMP     | 8/0         | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI health checks
| TCP      | 179         | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with BGP
| UDP      | 4789        | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with VXLAN
| TCP      | 5473        | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with Typha
| TCP      | 9098        | All RKE2 nodes    | All RKE2 nodes    | Calico Typha health checks
| TCP      | 9099        | All RKE2 nodes    | All RKE2 nodes    | Calico health checks
| TCP      | 5473        | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with Typha
| UDP      | 8472        | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with VXLAN
| TCP      | 9099        | All RKE2 nodes    | All RKE2 nodes    | Canal CNI health checks
| UDP      | 51820       | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with WireGuard IPv4
| UDP      | 51821       | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with WireGuard IPv6/dual-stack
| UDP      | 4789        | All RKE2 nodes    | All RKE2 nodes    | Flannel CNI with VXLAN

### Windows Specific Inbound Network Rules

| Protocol | Port | Source            | Destination       | Description
|----------|------|-------------------|-------------------|---|
| UDP      | 4789 | All RKE2 nodes    | All RKE2 nodes    | Required for Calico and Flannel VXLAN
| TCP      | 179  | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with BGP

Typically, all outbound traffic will be allowed.
