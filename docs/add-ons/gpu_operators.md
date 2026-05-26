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

:::note
If validator pods fail with `failed to create fsnotify watcher: too many open files`, the node has exhausted its inotify limits. See [Kernel Parameters](../install/requirements.md#kernel-parameters) in the requirements documentation.
:::

:::note
On **NVSwitch-based systems** (DGX/HGX A100, H100, B100/B200, AWS p4d/p5d, etc.), Fabric Manager is **mandatory** — without it, GPUs may appear in `nvidia-smi` but CUDA workloads will not initialize. The host must have `nvidia-fabricmanager` installed and running, and `nvidia-driver-XXX` and `nvidia-fabricmanager-XXX` must be kept at the **exact same version**. A mismatch prevents NVLink from initializing and the `nvidia-operator-validator` pods crash on the `driver-validation` init container. See the NVIDIA GPU Operator [troubleshooting guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/troubleshooting.html).
:::

### Operator installation ###

Once the OS is ready and RKE2 is running, install the GPU Operator with the following yaml manifest:

<Tabs groupId="GPUoperator" queryString>
<TabItem value="v25.3.x">

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  version: v25.3.4
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
      - name: ACCEPT_NVIDIA_VISIBLE_DEVICES_ENVVAR_WHEN_UNPRIVILEGED
        value: "false"
      - name: ACCEPT_NVIDIA_VISIBLE_DEVICES_AS_VOLUME_MOUNTS
        value: "true"
    devicePlugin:
      env:
      - name: DEVICE_LIST_STRATEGY
        value: volume-mounts
```
:::info
The envvars `ACCEPT_NVIDIA_VISIBLE_DEVICES_ENVVAR_WHEN_UNPRIVILEGED`, `ACCEPT_NVIDIA_VISIBLE_DEVICES_AS_VOLUME_MOUNTS` and `DEVICE_LIST_STRATEGY` are required to properly isolate GPU resources as explained in this nvidia [doc](https://docs.google.com/document/d/1zy0key-EL6JH50MZgwg96RPYxxXXnVUdxLZwGiyqLd8/edit?tab=t.0)
:::

:::warning
The NVIDIA operator restarts containerd with a hangup call which restarts RKE2
:::

</TabItem>
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

</TabItem>

<TabItem value="v26.3.x" default>

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
  version: v26.3.1
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    cdi:
      nriPluginEnabled: true
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
  version: v26.3.1
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    cdi:
      nriPluginEnabled: true
    driver:
      repository: registry.suse.com/third-party/nvidia
      usePrecompiled: true
      version: 595 # This depends on the nvidia driver that works with your GPU architecture
```

:::info
NVIDIA GPU Operator v26.3.x recommends using [Node Resource Interface (NRI) specification](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/cdi.html#about-the-node-resource-interface-nri-plugin) and that simplifies operations: we don't need to pass any extra envvar and it does not require changing containerd configuration. It requires containerd 2.1
:::

:::info Version Gate
Containerd 2.1 is available as of September 2025 releases: v1.31.13+rke2r1, v1.32.9+rke2r1, v1.33.5+rke2r1, v1.34.1+rke2r1
:::

</TabItem>
</Tabs>

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
      # runtimeClassName: nvidia <== Only needed for v25.3.x
      containers:
      - name: cuda-container
        image: nvcr.io/nvidia/k8s/cuda-sample:nbody
        args: ["nbody", "-gpu", "-benchmark"]
        resources:
          limits:
            nvidia.com/gpu: 1
    ```
    
:::info Version Gate
Available as of October 2024 releases: v1.28.15+rke2r1, v1.29.10+rke2r1, v1.30.6+rke2r1, v1.31.2+rke2r1.
:::

RKE2 will now use `PATH` to find alternative container runtimes, in addition to checking the default paths used by the container runtime packages. In order to use this feature, you must modify the RKE2 service's PATH environment variable to add the directories containing the container runtime binaries.

It's recommended that you modify one of this two environment files:

- `/etc/default/rke2-server` # or rke2-agent
- `/etc/sysconfig/rke2-server` # or rke2-agent

This example will add the `PATH` in `/etc/default/rke2-server`:

```bash
echo PATH=$PATH >> /etc/default/rke2-server
```

:::warning
`PATH` changes should be done with care to avoid placing untrusted binaries in the path of services that run as root.
:::


