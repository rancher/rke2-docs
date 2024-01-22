---
title: Agent Configuration Reference
---

This is a reference to all parameters that can be used to configure the rke2 agent. Note that while this is a reference to the command line arguments, the best way to configure RKE2 is using the [configuration file](../install/configuration.md#configuration-file).

### Common
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| config | Path to config file | /etc/rancher/rke2/config.yaml | RKE2_CONFIG_FILE |
| debug | Turn on debug logs  |  | RKE2_DEBUG |
| data-dir | Folder to hold state  | "/var/lib/rancher/rke2" |  |
### Cluster
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| token | Token to use for authentication  | RKE2_TOKEN |
| token-file | Token file to use for authentication  | RKE2_TOKEN_FILE |
| server | Server to connect to  | RKE2_URL |
### Node
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| node-name | Node name  |  | RKE2_NODE_NAME |
| with-node-id | Append id to node name |  |  |
| node-label | Registering and starting kubelet with set of labels |  |  |
| node-taint | Registering kubelet with set of taints |  |  |
| image-credential-provider-bin-dir | The path to the directory where credential provider plugin binaries are located  | "/var/lib/rancher/credentialprovider/bin" |  |
| image-credential-provider-config | The path to the credential provider plugin config file  | "/var/lib/rancher/credentialprovider/config.yaml" |  |
| selinux | Enable SELinux in containerd  |  | RKE2_SELINUX |
| lb-server-port | Local port for supervisor client load-balancer. If the supervisor and apiserver are not colocated an additional port 1 less than this port will also be used for the apiserver client load-balancer.  | 6444 | RKE2_LB_SERVER_PORT |
| protect-kernel-defaults | Kernel tuning behavior. If set, error if kernel tunables are different than kubelet defaults. |  |  |
### Runtime
| Flag | Description | Default |
| --- | --- | --- |
| container-runtime-endpoint | Disable embedded containerd and use the CRI socket at the given path; when used with --docker this sets the docker socket path |  |
| default-runtime | Set the default runtime in containerd |  |
| snapshotter | Override default containerd snapshotter  | "overlayfs" |
| private-registry | Private registry configuration file  | "/etc/rancher/rke2/registries.yaml" |
### Containerd
| Flag | Description |
| --- | --- |
| disable-default-registry-endpoint | Disables containerd's fallback default registry endpoint when a mirror is configured for that registry |
### Networking
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| node-ip | IPv4/IPv6 addresses to advertise for node |  |
| node-external-ip | IPv4/IPv6 external IP addresses to advertise for node |  |
| resolv-conf | Kubelet resolv.conf file  | RKE2_RESOLV_CONF |
### Components
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| kubelet-arg | Customized flag for kubelet process |  |
| kube-proxy-arg | Customized flag for kube-proxy process |  |
| control-plane-resource-requests | Control Plane resource requests  | RKE2_CONTROL_PLANE_RESOURCE_REQUESTS |
| control-plane-resource-limits | Control Plane resource limits  | RKE2_CONTROL_PLANE_RESOURCE_LIMITS |
| control-plane-probe-configuration | Control Plane Probe configuration  | RKE2_CONTROL_PLANE_PROBE_CONFIGURATION |
| kube-apiserver-extra-mount | kube-apiserver extra volume mounts  | RKE2_KUBE_APISERVER_EXTRA_MOUNT |
| kube-scheduler-extra-mount | kube-scheduler extra volume mounts  | RKE2_KUBE_SCHEDULER_EXTRA_MOUNT |
| kube-controller-manager-extra-mount | kube-controller-manager extra volume mounts  | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_MOUNT |
| kube-proxy-extra-mount | kube-proxy extra volume mounts  | RKE2_KUBE_PROXY_EXTRA_MOUNT |
| etcd-extra-mount | etcd extra volume mounts  | RKE2_ETCD_EXTRA_MOUNT |
| cloud-controller-manager-extra-mount | cloud-controller-manager extra volume mounts  | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_MOUNT |
| kube-apiserver-extra-env | kube-apiserver extra environment variables  | RKE2_KUBE_APISERVER_EXTRA_ENV |
| kube-scheduler-extra-env | kube-scheduler extra environment variables  | RKE2_KUBE_SCHEDULER_EXTRA_ENV |
| kube-controller-manager-extra-env | kube-controller-manager extra environment variables  | RKE2_KUBE_CONTROLLER_MANAGER_EXTRA_ENV |
| kube-proxy-extra-env | kube-proxy extra environment variables  | RKE2_KUBE_PROXY_EXTRA_ENV |
| etcd-extra-env | etcd extra environment variables  | RKE2_ETCD_EXTRA_ENV |
| cloud-controller-manager-extra-env | cloud-controller-manager extra environment variables  | RKE2_CLOUD_CONTROLLER_MANAGER_EXTRA_ENV |
### Image
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| kube-apiserver-image | Override image to use for kube-apiserver  | RKE2_KUBE_APISERVER_IMAGE |
| kube-controller-manager-image | Override image to use for kube-controller-manager  | RKE2_KUBE_CONTROLLER_MANAGER_IMAGE |
| cloud-controller-manager-image | Override image to use for cloud-controller-manager  | RKE2_CLOUD_CONTROLLER_MANAGER_IMAGE |
| kube-proxy-image | Override image to use for kube-proxy  | RKE2_KUBE_PROXY_IMAGE |
| kube-scheduler-image | Override image to use for kube-scheduler  | RKE2_KUBE_SCHEDULER_IMAGE |
| pause-image | Override image to use for pause  | RKE2_PAUSE_IMAGE |
| runtime-image | Override image to use for runtime binaries (containerd, kubectl, crictl, etc)  | RKE2_RUNTIME_IMAGE |
| etcd-image | Override image to use for etcd  | RKE2_ETCD_IMAGE |
### Cloud Provider
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| cloud-provider-name | Cloud provider name  | RKE2_CLOUD_PROVIDER_NAME |
| cloud-provider-config | Cloud provider configuration file path  | RKE2_CLOUD_PROVIDER_CONFIG |
### Security
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| profile | Validate system configuration against the selected benchmark (valid items: cis, cis-1.23 (deprecated))  | RKE2_CIS_PROFILE |
| audit-policy-file | Path to the file that defines the audit policy configuration  | RKE2_AUDIT_POLICY_FILE |
| pod-security-admission-config-file | Path to the file that defines Pod Security Admission configuration  | RKE2_POD_SECURITY_ADMISSION_CONFIG_FILE |
### Experimental
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| kubelet-path | Override kubelet binary path  | RKE2_KUBELET_PATH |
