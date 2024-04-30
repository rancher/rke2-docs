---
title: Resource Profiling
---

This section captures the results of tests to determine minimum resource requirements for RKE2.

## Scope of Resource Testing

The resource tests were intended to address the following problem statements:

- On a single-node cluster, determine the legitimate minimum amount of CPU and memory entire RKE2 server stack, assuming that a real workload will be deployed on the cluster.
- On an agent node, determine the legitimate minimum amount of CPU and memory that should be set aside for the kubelet and RKE2 agent components.

### Environment and Components

| Arch | OS | System | CPU | RAM | Disk | 
|------|----|--------|--|----|------|
| x86_64 | Ubuntu 22.04 | AWS c6id.xlarge | Intel Xeon Platinum 8375C CPU, 4 Core 2.90 GHz | 8 GB | NVME SSD |


The tested components are:

* RKE2 v1.27.12 with all packaged components enabled, canal as the CNI
* [Kubernetes Example Nginx Deployment](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/)

### Methodology

`systemd-cgtop` was used to track systemd cgroup-level CPU and memory utilization. 
- `system.slice/rke2-server.service` tracks resource utilization for both RKE2 and containerd components.
- `system.slice/rke2-agent.service` tracks resource utilization for the agent components.

Utilization figures were based on 95th percentile readings from steady state operation on nodes running the described workloads, giving an upper bounds on typical resource usage.

### RKE2 Server with a Workload

These are the requirements for a single-node cluster in which the RKE2 server shares resources with a [simple workload](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/).

| System | CPU Core Usage | Memory |
|--------|----------------| ------ |
| Intel 8375C | 17% of a core | 4977 MB |

### RKE2 Cluster with a Single Agent

These are the baseline requirements for a RKE2 cluster with a RKE2 server node and a RKE2 agent, but no workload.

| Node | System | CPU Core Usage | Memory |
| ---- | -------|----------------| ------ |
| Server | Intel 8375C | 18% of a core | 4804 MB |
| Agent  | Intel 8375C | 5% of a core | 3590 MB |
