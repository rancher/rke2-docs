---
title: GPU Operators
---

## Deploy NVIDIA operator

The [NVIDIA operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html) allows administrators of Kubernetes clusters to manage GPUs just like CPUs. It includes everything needed for pods to be able to operate GPUs.

### Host OS requirements

To expose the GPU to the pod correctly, the NVIDIA kernel drivers and the `libnvidia-ml` library must be correctly installed in the host OS (Operating System). The NVIDIA Operator can automatically install drivers and libraries on some operating systems; check the NVIDIA documentation for information on [supported operating system releases](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#supported-operating-systems-and-kubernetes-platforms).

Starting with GPU Operator v26.3.x, the operator can also manage driver and library installation on any operating system, provided the OS vendor or administrator supplies a compatible driver container image. 

Installation of the NVIDIA components on your host OS is out of the scope of this document; reference the NVIDIA documentation for instructions.

<details>
<summary>**Checks for pre-installed NVIDIA drivers/libraries**</summary>


The following three commands should return a correct output if the kernel driver was correctly installed:

1.  `lsmod | grep nvidia`

    Returns a list of nvidia kernel modules, for example:

    ```
    nvidia_uvm           2129920  0
    nvidia_drm            131072  0
    nvidia_modeset       1572864  1 nvidia_drm
    video                  77824  1 nvidia_modeset
    nvidia               9965568  2 nvidia_uvm,nvidia_modeset
    ecc                    45056  1 nvidia
    ```

2.  `cat /proc/driver/nvidia/version`

    returns the NVRM and GCC version of the driver. For example:

    ```
    NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  555.42.06  Release Build  (abuild@host)  Thu Jul 11 12:00:00 UTC 2024
    GCC version:  gcc version 7.5.0 (SUSE Linux) 
    ```

3.  `find /usr/ -iname libnvidia-ml.so`

    returns a path to the `libnvidia-ml.so` library. For example:

    ```
    /usr/lib64/libnvidia-ml.so
    ```

    This library is used by Kubernetes components to interact with the kernel driver.
</details>

### Operator installation ###

Once the OS is ready and RKE2 is running, install the GPU Operator with the following yaml manifest:

<Tabs groupId="GPUoperator" queryString>
<TabItem value="v25.10.x">

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v25.10.1
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
```

:::info
NVIDIA GPU Operator v25.10.x uses [Container Device Interface (CDI) specification](https://github.com/cncf-tags/container-device-interface/blob/main/SPEC.md) and that simplifies operations: we don't need to pass extra envvars to comply with the security requirements and the workloads don't need to pass the `runtimeClassName: nvidia` anymore. It requires containerd 2.0
:::

:::warning
The NVIDIA operator restarts containerd with a hangup call which restarts RKE2
:::

:::danger End of Support
Per NVIDIA's [GPU Operator life cycle policy](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#nvidia-gpu-operator-life-cycle), v25.10.x (and all older major versions) is now **End of Support** and no longer receives patch, bug fix, or CVE updates. Please upgrade to a currently supported major version.
:::

</TabItem>

<TabItem value="v26.3.x">

There are two installation options available.

If drivers and libraries are pre-installed or you are using a [supported operating system by nvidia](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#supported-operating-systems-and-kubernetes-platforms), please use the following manifest 

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v26.3.3
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
```

If your operating system vendor supplies a compatible driver image, you can use the `driver` value field to point to it. For example, in SLES 16.0, you can use the following manifest:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v26.3.3
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
    driver:
      repository: registry.suse.com/third-party/nvidia
      usePrecompiled: true
      version: 595 # This depends on the nvidia driver that works with your GPU architecture
```

:::warning Deprecated
Per NVIDIA's [GPU Operator life cycle policy](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#nvidia-gpu-operator-life-cycle), v26.3.x is now **Deprecated**: it still receives critical bug fix and CVE patch updates, but no new features. We recommend moving to v26.7.x below.
:::

</TabItem>

<TabItem value="v26.7.x" default>

There are two installation options available.

If drivers and libraries are pre-installed or you are using a [supported operating system by nvidia](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#supported-operating-systems-and-kubernetes-platforms), please use the following manifest

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v26.7.2
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
```

If your operating system vendor supplies a compatible driver image, you can use the `driver` value field to point to it. For example, in SLES 16.0, you can use the following manifest:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v26.7.2
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
    driver:
      repository: registry.suse.com/third-party/nvidia
      usePrecompiled: true
      version: 595 # This depends on the nvidia driver that works with your GPU architecture
```

:::info Minimum containerd version
Starting with v26.7.0, the GPU Operator requires containerd 2.0 or later.
:::

:::tip Dynamic Resource Allocation (DRA)
v26.7.x also supports installing with a `GPUCluster` custom resource instead of `ClusterPolicy`, enabling GPU allocation via native Kubernetes DRA. See the "DRA (Experimental)" tab.
:::

</TabItem>

<TabItem value="DRA (Experimental)">

v26.7.x introduces a `GPUCluster` custom resource as an alternative to `ClusterPolicy`. It deploys the DRA driver for NVIDIA GPUs and creates the `gpu.nvidia.com`, `mig.nvidia.com`, and `vfio.gpu.nvidia.com` `DeviceClass`es, enabling GPU allocation via native Kubernetes [Dynamic Resource Allocation](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) (`ResourceClaim`/`ResourceClaimTemplate`) instead of the classic device-plugin extended-resource model (`nvidia.com/gpu`).

:::warning
A cluster can run either `ClusterPolicy` or `GPUCluster`, not both. Per NVIDIA, in-place migration from an existing `ClusterPolicy` install to `GPUCluster` is not supported — if a `ClusterPolicy` resource already exists, use a new cluster for the `GPUCluster` workflow.
:::

:::info Minimum requirements
Kubernetes v1.34+ (for the `resource.k8s.io` `DeviceClass` API), NVIDIA driver 580 or later, and a container runtime with CDI support enabled.
:::

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v26.7.2
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
    clusterPolicy:
      deployCR: false
    gpuCluster:
      deployCR: true
    driver:
      nvidiaDriverCRD:
        enabled: true
      repository: registry.suse.com/third-party/nvidia
      usePrecompiled: true
      version: 595 # This depends on the nvidia driver that works with your GPU architecture
```

After a few minutes, verify the `GPUCluster` reconciled successfully:

```
kubectl get gpucluster gpu-cluster
```

Expected output:
```
NAME          STATUS   AGE
gpu-cluster   ready    8m
```

Confirm the `DeviceClass`es were created:

```
kubectl get deviceclass
```

Expected output:
```
NAME                                        AGE
compute-domain-daemon.nvidia.com            7m
compute-domain-default-channel.nvidia.com   7m
gpu.nvidia.com                              7m
mig.nvidia.com                              7m
vfio.gpu.nvidia.com                         7m
```

Run a pod requesting a GPU via a `ResourceClaimTemplate` instead of the classic `nvidia.com/gpu` extended resource:

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: single-gpu
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
---
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark-dra
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-container
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    args: ["nbody", "-gpu", "-benchmark"]
    resources:
      claims:
      - name: gpu
  resourceClaims:
  - name: gpu
    resourceClaimTemplateName: single-gpu
```

Check that the `ResourceClaim` was allocated and the pod ran successfully:

```
kubectl get resourceclaim
kubectl logs nbody-gpu-benchmark-dra
```

</TabItem>

<TabItem value="NRI (Experimental)">

[Node Resource Interface (NRI) specification](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/cdi.html#about-the-node-resource-interface-nri-plugin) is a pluggable extension mechanism built into container runtimes like containerd and CRI-O that allows custom plugins to intercept container lifecycle events on a node. It is considered the future integration mechanism for GPUs.

:::warning
NVIDIA considers NRI as experimental
:::

NRI is not tied to a specific GPU Operator release — it's enabled by adding the following to the `valuesContent` of whichever version's manifest you're using (`v26.3.x` or `v26.7.x` above):

```yaml
    cdi:
      nriPluginEnabled: true
```

:::info Version Gate
NRI requires containerd 2.1. Containerd 2.1 is available as of September 2025 releases: v1.31.13+rke2r1, v1.32.9+rke2r1, v1.33.5+rke2r1, v1.34.1+rke2r1
:::

</TabItem>
</Tabs>

:::note
The checks below apply to the `ClusterPolicy`-based (device-plugin) tabs above. If you installed with `GPUCluster`/DRA instead, see the verification steps in that tab instead — allocatable GPUs aren't exposed as the `nvidia.com/gpu` extended resource in DRA mode.
:::

After a few minutes, you can make the following checks to verify that everything worked as expected:

1. Assuming the drivers and `libnvidia-ml.so` library were previously installed, check if the operator detects them correctly:
    ```
    kubectl get node $NODENAME -o jsonpath='{.metadata.labels}' |  grep "nvidia.com"
    ```
    You should see labels specifying driver and GPU (e.g. nvidia.com/gpu.machine or nvidia.com/cuda.driver.major)

2. Check if the gpu was added (by nvidia-device-plugin-daemonset) as an allocatable resource in the node:
    ```
    kubectl get node $NODENAME -o jsonpath='{.status.allocatable}'
    ```
    You should see `"nvidia.com/gpu":` followed by the number of gpus in the node

3. Check that the container runtime binary exists (it gets installed by the `nvidia-container-toolkit-daemonset`):
    ```
    ls /usr/local/nvidia/toolkit/nvidia-container-runtime
    ```

4. (Only if not using NRI) Verify if containerd config was updated to include the nvidia container runtime:
    ```
    grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml
    ```

5. Run a pod to verify that the GPU resource can successfully be scheduled on a pod and the pod can detect it
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nbody-gpu-benchmark
      namespace: default
    spec:
      restartPolicy: OnFailure
      containers:
      - name: cuda-container
        image: nvcr.io/nvidia/k8s/cuda-sample:nbody
        args: ["nbody", "-gpu", "-benchmark"]
        resources:
          limits:
            nvidia.com/gpu: 1
    ```


