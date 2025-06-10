---
# sidebar_label: 
title: "Advanced Options and Configuration"
---


This section contains advanced information describing the different ways you can run and manage RKE2.

## Certificate Rotation

By default, certificates in RKE2 expire in 12 months.

If the certificates are expired or have fewer than 90 days remaining before they expire, the certificates are rotated when RKE2 is restarted.

Certificates can also be rotated manually. To do this, it is best to stop the rke2-server process, rotate the certificates, then start the process up again: 
```sh
systemctl stop rke2-server
rke2 certificate rotate
systemctl start rke2-server
```
To renew agent certificates, restart rke2-agent in agent nodes. Agent certificates are renewed every time the agent starts.
```sh
systemctl restart rke2-agent
```
It is also possible to rotate an individual service by passing the `--service` flag, for example: `rke2 certificate rotate --service api-server`. See [Certificate Management](./security/certificates.md#rotating-client-and-server-certificates-manually) for more details.

## Auto-Deploying Manifests

Any file found in `/var/lib/rancher/rke2/server/manifests` will automatically be deployed to Kubernetes in a manner similar to `kubectl apply`.

For information about deploying Helm charts using the manifests directory, refer to the section about [Helm.](helm.md)

## Configuring containerd

:::info Version Gate
RKE2 includes containerd 2.0 as of the February 2025 releases: v1.31.6+rke2r1 and v1.32.2+rke2r1.  
Be aware that containerd 2.0 prefers config version 3, while containerd 1.7 prefers config version 2.
:::

RKE2 will generate a configuration file for containerd at `/var/lib/rancher/rke2/agent/etc/containerd/config.toml`, using values specific to the current cluster and node configuration.

For advanced customization, you can create a containerd config template in the same directory:
* For containerd 2.0, place a version 3 configuration template in `config-v3.toml.tmpl`  
  See the [containerd 2.0 documentation](https://github.com/containerd/containerd/blob/release/2.0/docs/cri/config.md) for more information.
* For containerd 1.7 and earlier, place a version 2 configuration template in `config.toml.tmpl`  
  See the [containerd 1.7 documentation](https://github.com/containerd/containerd/blob/release/1.7/docs/cri/config.md) for more information.

Containerd 2.0 is backwards compatible with prior config versions, and RKE2 will continue to render legacy version 2 configuration from `config.toml.tmpl` if `config-v3.toml.tmpl` is not found.

The template file is rendered into the containerd config using the [`text/template`](https://pkg.go.dev/text/template) library.
See `ContainerdConfigTemplateV3` and `ContainerdConfigTemplate` in [`templates.go`](https://github.com/k3s-io/k3s/blob/master/pkg/agent/templates/templates.go) for the default template content.
The template is executed with a [`ContainerdConfig`](https://github.com/k3s-io/k3s/blob/master/pkg/agent/templates/templates.go#L22-L33) struct as its dot value (data argument).

### Base template

You can extend the RKE2 base template instead of copy-pasting the complete stock template out of the source code. This is useful if you need to build on the existing configuration, and add a few extra lines at the end.

```toml
#/var/lib/rancher/rke2/agent/etc/containerd/config-v3.toml.tmpl

{{ template "base" . }}

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.'custom']
  runtime_type = "io.containerd.runc.v2"
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.'custom'.options]
  BinaryName = "/usr/bin/custom-container-runtime"
  SystemdCgroup = true
```

:::warning
For best results, do NOT simply copy a prerendered `config.toml` into the template and make your desired changes. Use the base template, or provide a full template based on the defaults linked above.
:::

## Configuring an HTTP proxy

If you are running RKE2 in an environment, which only has external connectivity through an HTTP proxy, you can configure your proxy settings on the RKE2 systemd service. These proxy settings will then be used in RKE2 and passed down to the embedded containerd and kubelet.

Add the necessary `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` variables to the environment file of your systemd service, usually:

- `/etc/default/rke2-server`
- `/etc/default/rke2-agent`

RKE2 will automatically add the cluster internal Pod and Service IP ranges and cluster DNS domain to the list of `NO_PROXY` entries. You should ensure that the IP address ranges used by the Kubernetes nodes themselves (i.e. the public and private IPs of the nodes) are included in the `NO_PROXY` list, or that the nodes can be reached through the proxy.

```
HTTP_PROXY=http://your-proxy.example.com:8888
HTTPS_PROXY=http://your-proxy.example.com:8888
NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

If you want to configure the proxy settings for containerd without affecting RKE2 and the Kubelet, you can prefix the variables with `CONTAINERD_`:

```
CONTAINERD_HTTP_PROXY=http://your-proxy.example.com:8888
CONTAINERD_HTTPS_PROXY=http://your-proxy.example.com:8888
CONTAINERD_NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

## Node Labels and Taints

RKE2 agents can be configured with the options `node-label` and `node-taint` which adds a label and taint to the kubelet. The two options only add labels and/or taints at registration time, and can only be added once and not removed after that through rke2 commands.

If you want to change node labels and taints after node registration you should use `kubectl`. Refer to the official Kubernetes documentation for details on how to add [taints](https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/) and [node labels](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/#add-a-label-to-a-node).

# How Agent Node Registration Works

Agent nodes are registered via a websocket connection initiated by the `rke2 agent` process, and the connection is maintained by a client-side load balancer running as part of the agent process.

Agents register with the server using the cluster secret portion of the join token, along with a randomly generated node-specific password, which is stored on the agent at `/etc/rancher/node/password`. The server will store the passwords for individual nodes as Kubernetes secrets, and any subsequent attempts must use the same password. Node password secrets are stored in the `kube-system` namespace with names using the template `<host>.node-password.rke2`. These secrets are deleted when the corresponding Kubernetes node is deleted.

If the `/etc/rancher/node` directory of an agent is removed, the password file should be recreated for the agent prior to startup, or the entry removed from the server or Kubernetes cluster (depending on the RKE2 version).

## Starting the Server with the Installation Script

The installation script provides units for systemd, but does not enable or start the service by default.

When running with systemd, logs will be created in `/var/log/syslog` and viewed using `journalctl -u rke2-server` or `journalctl -u rke2-agent`.

An example of installing with the install script:

```bash
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server
systemctl start rke2-server
```

## Disabling Server Charts

The server charts bundled with `rke2` deployed during cluster bootstrapping can be disabled and replaced with alternatives.  A common use case is replacing the bundled `rke2-ingress-nginx` chart with an alternative.

To disable any of the bundled system charts, set the `disable` parameter in the config file before bootstrapping. An example of disabling all available system charts is:

```yaml
# /etc/rancher/rke2/config.yaml
disable:
  - rke2-coredns
  - rke2-ingress-nginx
  - rke2-metrics-server
  - rke2-snapshot-controller
  - rke2-snapshot-controller-crd
  - rke2-snapshot-validation-webhook
```

:::warning 
It is the cluster operator's responsibility to ensure that components are disabled or replaced with care, as the server charts play important roles in cluster operability.  Refer to the [architecture overview](./architecture.md#server-charts) for more information on the individual system charts role within the cluster.
:::

## Installation on classified AWS regions or networks with custom AWS API endpoints

In public AWS regions, to ensure RKE2 is cloud-enabled, and capable of auto-provisioning certain cloud resources, config RKE2 with:

```yaml
# /etc/rancher/rke2/config.yaml
cloud-provider-name: aws
```

When installing RKE2 on classified regions (such as SC2S or C2S), there are a few additional pre-requisites to be aware of to ensure RKE2 knows how and where to securely communicate with the appropriate AWS endpoints:

0. Ensure all the common AWS cloud-provider [prerequisites](https://rancher.com/docs/rke/latest/en/config-options/cloud-providers/aws/) are met.  These are independent of regions and are always required.

1. Ensure RKE2 knows where to send API requests for `ec2` and `elasticloadbalancing` services by creating a `cloud.conf` file, the below is an example for the `us-iso-east-1` (C2S) region:

```yaml
# /etc/rancher/rke2/cloud.conf
[Global]
[ServiceOverride "ec2"]
  Service=ec2
  Region=us-iso-east-1
  URL=https://ec2.us-iso-east-1.c2s.ic.gov
  SigningRegion=us-iso-east-1
[ServiceOverride "elasticloadbalancing"]
  Service=elasticloadbalancing
  Region=us-iso-east-1
  URL=https://elasticloadbalancing.us-iso-east-1.c2s.ic.gov
  SigningRegion=us-iso-east-1
```

Alternatively, if you are using [private AWS endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-services-overview.html), ensure the appropriate `URL` is used for each of the private endpoints.

2. Ensure the appropriate AWS CA bundle is loaded into the system's root ca trust store.  This may already be done for you depending on the AMI you are using.

```bash
# on CentOS/RHEL 7/8
cp <ca.pem> /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

3. Configure RKE2 to use the `aws` cloud-provider with the custom `cloud.conf` created in step 1:

```yaml
# /etc/rancher/rke2/config.yaml
...
cloud-provider-name: aws
cloud-provider-config: "/etc/rancher/rke2/cloud.conf"
...
```

4. [Install](install/methods.md) RKE2 normally (most likely in an [airgapped](install/airgap.md) capacity)

5. Validate successful installation by confirming the existence of AWS metadata on cluster node labels with `kubectl get nodes --show-labels`

## Control Plane Component Resource Requests/Limits

The following options are available under the `server` sub-command for RKE2. The options allow for specifying CPU requests and limits for the control plane components within RKE2.

```
   --control-plane-resource-requests value       (components) Control Plane resource requests [$RKE2_CONTROL_PLANE_RESOURCE_REQUESTS]
   --control-plane-resource-limits value         (components) Control Plane resource limits [$RKE2_CONTROL_PLANE_RESOURCE_LIMITS]
```

Values are a comma-delimited list of `[controlplane-component]-(cpu|memory)=[desired-value]`. The possible values for `controlplane-component` are:
```
kube-apiserver
kube-scheduler
kube-controller-manager
kube-proxy
etcd
cloud-controller-manager
```

Thus, an example config may value may look like:

```yaml
# /etc/rancher/rke2/config.yaml
control-plane-resource-requests:
  - kube-apiserver-cpu=500m
  - kube-apiserver-memory=512M
  - kube-scheduler-cpu=250m
  - kube-scheduler-memory=512M
  - etcd-cpu=1000m
```

The unit values for CPU/memory are identical to Kubernetes resource units (See: [Resource Limits in Kubernetes](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes))

## Extra Control Plane Component Volume Mounts

The following options are available under the `server` sub-command for RKE2. These options specify host-path mounting of directories from the node filesystem into the static pod component that corresponds to the prefixed name.

| Flag | ENV VAR | 
| --- | --- |
| kube-apiserver-extra-mount | RKE2_KUBE_APISERVER_EXTRA_MOUNT | kube-apiserver extra volume mounts |
| kube-scheduler-extra-mount | RKE2_KUBE_SCHEDULER_EXTRA_MOUNT | kube-scheduler extra volume mounts |
| kube-controller-manager-extra-mount | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_MOUNT |
| kube-proxy-extra-mount | RKE2_KUBE_PROXY_EXTRA_MOUNT |
| etcd-extra-mount | RKE2_ETCD_EXTRA_MOUNT |
| cloud-controller-manager-extra-mount | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_MOUNT |


### RW Host Path Volume Mount
`/source/volume/path/on/host:/destination/volume/path/in/staticpod`

### RO Host Path Volume Mount
In order to mount a volume as read only, append `:ro` to the end of the volume mount.
`/source/volume/path/on/host:/destination/volume/path/in/staticpod:ro`

Multiple volume mounts can be specified for the same component by passing the flag values as an array in the config file.

:::info Version Gate
Prior to April 2024 releases (v1.27.13+rke2r1, v1.28.9+rke2r1, v1.29.4+rke2r1), only directories can be mounted.
:::

```yaml
# /etc/rancher/rke2/config.yaml
kube-apiserver-extra-mount: 
   - "/tmp/foo:/root/foo"
   - "/tmp/bar.txt:/etc/bar.txt:ro" 
```

## Extra Control Plane Component Environment Variables

The following configuration options are available to the `server` sub-command for RKE2. These options specify additional environment variables in standard format i.e. `KEY=VALUE` for the static pod component that corresponds to the prefixed name.

| Flag | ENV VAR |
| --- | --- |
| kube-apiserver-extra-env | RKE2_KUBE_APISERVER_EXTRA_ENV |
| kube-scheduler-extra-env | RKE2_KUBE_SCHEDULER_EXTRA_ENV |
| kube-controller-manager-extra-env | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_ENV |
| kube-proxy-extra-env | RKE2_KUBE_PROXY_EXTRA_ENV |
| etcd-extra-env | RKE2_ETCD_EXTRA_ENV |
| cloud-controller-manager-extra-env | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_ENV |

Multiple environment variables can be specified for the same component by passing the flag values as an array in the config file.

```yaml
# /etc/rancher/rke2/config.yaml
kube-apiserver-extra-env:
  - "MY_FOO=FOO"
  - "MY_BAR=BAR"
kube-scheduler-extra-env: "TZ=America/Los_Angeles"
```

## Deploy NVIDIA operator

The [NVIDIA operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html) allows administrators of Kubernetes clusters to manage GPUs just like CPUs. It includes everything needed for pods to be able to operate GPUs.

### Host OS requirements ###

To expose the GPU to the pod correctly, the NVIDIA kernel drivers and the `libnvidia-ml` library must be correctly installed in the host OS. The NVIDIA Operator can automatically install drivers and libraries on some operating systems; check the NVIDIA documentation for information on [supported operating system releases](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#supported-operating-systems-and-kubernetes-platforms). Installation of the NVIDIA components on your host OS is out of the scope of this document; reference the NVIDIA documentation for instructions.

The following three commands should return a correct output if the kernel driver was correctly installed:

1 - `lsmod | grep nvidia`

Returns a list of nvidia kernel modules, for example:

```
nvidia_uvm           2129920  0
nvidia_drm            131072  0
nvidia_modeset       1572864  1 nvidia_drm
video                  77824  1 nvidia_modeset
nvidia               9965568  2 nvidia_uvm,nvidia_modeset
ecc                    45056  1 nvidia
```

2 - `cat /proc/driver/nvidia/version`

returns the NVRM and GCC version of the driver. For example:

```
NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  555.42.06  Release Build  (abuild@host)  Thu Jul 11 12:00:00 UTC 2024
GCC version:  gcc version 7.5.0 (SUSE Linux) 
```

3 - `find /usr/ -iname libnvidia-ml.so`

returns a path to the `libnvidia-ml.so` library. For example:

```
/usr/lib64/libnvidia-ml.so
```

This library is used by Kubernetes components to interact with the kernel driver.


### Operator installation ###

Once the OS is ready and RKE2 is running, install the GPU Operator with the following yaml manifest:
```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: https://helm.ngc.nvidia.com/nvidia
  chart: gpu-operator
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
```
:::warning
The NVIDIA operator restarts containerd with a hangup call which restarts RKE2
:::

After one minute approximately, you can make the following checks to verify that everything worked as expected:

1 - Assuming the drivers and `libnvidia-ml.so` library were previously installed, check if the operator detects them correctly:
```
kubectl get node $NODENAME -o jsonpath='{.metadata.labels}' | grep "nvidia.com/gpu.deploy.driver"
```
You should see the value `pre-installed`. If you see `true`, the drivers were not correctly installed. If the [pre-requirements](#host-os-requirements) were correct, it is possible that you forgot to reboot the node after installing all packages.

You can also check other driver labels with:
```
kubectl get node $NODENAME -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com"
```
You should see labels specifying driver and GPU (e.g. nvidia.com/gpu.machine or nvidia.com/cuda.driver.major)

2 - Check if the gpu was added (by nvidia-device-plugin-daemonset) as an allocatable resource in the node:
```
kubectl get node $NODENAME -o jsonpath='{.status.allocatable}' | jq
```
You should see `"nvidia.com/gpu":` followed by the number of gpus in the node

3 - Check that the container runtime binary was installed by the operator (in particular by the `nvidia-container-toolkit-daemonset`):
```
ls /usr/local/nvidia/toolkit/nvidia-container-runtime
```

4 - Verify if containerd config was updated to include the nvidia container runtime:
```
grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml
```

5 - Run a pod to verify that the GPU resource can successfully be scheduled on a pod and the pod can detect it
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark
  namespace: default
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
  - name: cuda-container
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    args: ["nbody", "-gpu", "-benchmark"]
    resources:
      limits:
        nvidia.com/gpu: 1
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: all
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: compute,utility
```

:::info Version Gate
Available as of October 2024 releases: v1.28.15+rke2r1, v1.29.10+rke2r1, v1.30.6+rke2r1, v1.31.2+rke2r1.
:::

RKE2 will now use `PATH` to find alternative container runtimes, in addition to checking the default paths used by the container runtime packages. In order to use this feature, you must modify the RKE2 service's PATH environment variable to add the directories containing the container runtime binaries.

It's recommended that you modify one of this two environment files:

- /etc/default/rke2-server # or rke2-agent
- /etc/sysconfig/rke2-server # or rke2-agent

This example will add the `PATH` in `/etc/default/rke2-server`:

```bash
echo PATH=$PATH >> /etc/default/rke2-server
```

:::warning
`PATH` changes should be done with care to avoid placing untrusted binaries in the path of services that run as root.
:::


