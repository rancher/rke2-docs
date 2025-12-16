---
title: Requirements
---

RKE2 is very lightweight, but has some minimum requirements as outlined below.

## Prerequisites

Two RKE2 nodes cannot have the same node name. By default, the node name is taken from the machine's hostname.

If two or more of your machines have the same hostname, you must do one of the following:

* Update the hostname to a unique value
* Set the `node-name` parameter in the config file to a unique value
* Set the `with-node-id` parameter in the config file to `true` to append a randomly generated ID number to the hostname.

:::info Version Gate

The `with-node-id` parameter is available starting with the 2023-05 releases (v1.27.2+rke2r1, v1.26.5+rke2r1, v1.25.10+rke2r1, v1.24.14+rke2r1).

:::

## Architecture

RKE2 is available for x86_64 and arm64/aarch64

## Operating Systems

### Linux

See the [RKE2 Support Matrix](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/rke2-v1-34) for all the OS versions that have been validated with RKE2. In general, RKE2 should work on any Linux distribution that uses systemd and iptables.

<Tabs>
<TabItem value="RHEL 10">
On RHEL 10 (and its derivates like Rocky Linux) an additional package is required to allow nf_conntrack.

```bash
sudo dnf install kernel-modules-extra -y
```
</TabItem>
</Tabs>

### Windows

:::info
Windows Support requires choosing Calico or Flannel as the CNI for the RKE2 cluster
:::

:::note
The Windows Server Containers feature needs to be enabled for the RKE2 Windows agent to work.
:::

The RKE2 Windows Node (Worker) agent has been tested and validated on the following operating systems, and their subsequent non-major releases:

* Windows Server 2019 LTSC (amd64) (OS Build 17763.2061)
* Windows Server 2022 LTSC (amd64) (OS Build 20348.169)

Open a new Powershell window with Administrator privileges
```powershell
powershell -Command "Start-Process PowerShell -Verb RunAs"
```

In the new Powershell window, run the following command.
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All
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

:::tip
If your node has NetworkManager installed and enabled, [ensure that it is configured to ignore CNI-managed interfaces.](../known_issues.md#networkmanager). If your node has Wicked installed and enabled, [ensure that the forwarding sysctl config is enabled](../known_issues.md#wicked)
:::

The RKE2 server needs port 6443 and 9345 to be accessible by other nodes in the cluster.

All nodes need to be able to reach other nodes over UDP port 8472 when Flannel VXLAN is used.

If you wish to utilize the metrics server, you will need to open port 10250 on each node.

:::warning
The VXLAN port on nodes should not be exposed to the world as it opens up your cluster network to be accessed by anyone. Run your nodes behind a firewall/security group that disables access to port 8472.
:::

### Inbound Network Rules

| Port        | Protocol | Source            | Destination       | Description
|-------------|----------|-------------------|-------------------|------------
| 6443        | TCP      | All RKE2 nodes    | RKE2 server nodes | Kubernetes API
| 9345        | TCP      | All RKE2 nodes    | RKE2 server nodes | RKE2 supervisor API
| 10250       | TCP      | All RKE2 nodes    | All RKE2 nodes    | kubelet metrics
| 2379        | TCP      | RKE2 server nodes | RKE2 server nodes | etcd client port
| 2380        | TCP      | RKE2 server nodes | RKE2 server nodes | etcd peer port
| 2381        | TCP      | RKE2 server nodes | RKE2 server nodes | etcd metrics port
| 30000-32767 | TCP      | All RKE2 nodes    | All RKE2 nodes    | NodePort port range


#### CNI Specific Inbound Network Rules

<Tabs groupId="cni-rules" queryString>
<TabItem value="Canal">

| Port        | Protocol | Source            | Destination       | Description
|-------------|----------|-------------------|-------------------|------------
| 8472        | UDP      | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with VXLAN
| 9099        | TCP      | All RKE2 nodes    | All RKE2 nodes    | Canal CNI health checks
| 51820       | UDP      | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with WireGuard IPv4
| 51821       | UDP      | All RKE2 nodes    | All RKE2 nodes    | Canal CNI with WireGuard IPv6/dual-stack

</TabItem>
<TabItem value="Cilium">

| Port        | Protocol | Source            | Destination       | Description
|-------------|----------|-------------------|-------------------|------------
| 8/0         | ICMP     | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI health checks
| 4240        | TCP      | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI health checks
| 8472        | UDP      | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI with VXLAN
| 51871       | UDP      | All RKE2 nodes    | All RKE2 nodes    | Cilium CNI with WireGuard

</TabItem>
<TabItem value="Calico">

| Port        | Protocol | Source            | Destination       | Description
|-------------|----------|-------------------|-------------------|------------
| 179         | TCP      | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with BGP
| 4789        | UDP      | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with VXLAN
| 5473        | TCP      | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with Typha
| 9098        | TCP      | All RKE2 nodes    | All RKE2 nodes    | Calico Typha health checks
| 9099        | TCP      | All RKE2 nodes    | All RKE2 nodes    | Calico health checks

</TabItem>
<TabItem value="Flannel">

| Port        | Protocol | Source            | Destination       | Description
|-------------|----------|-------------------|-------------------|------------
| 4789        | UDP      | All RKE2 nodes    | All RKE2 nodes    | Flannel CNI with VXLAN

</TabItem>
</Tabs>

### Windows Specific Inbound Network Rules

| Protocol | Port | Source            | Destination       | Description
|----------|------|-------------------|-------------------|---|
| UDP      | 4789 | All RKE2 nodes    | All RKE2 nodes    | Required for Calico and Flannel VXLAN
| TCP      | 179  | All RKE2 nodes    | All RKE2 nodes    | Calico CNI with BGP

Typically, all outbound traffic will be allowed.
