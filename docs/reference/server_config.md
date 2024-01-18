---
title: Server Configuration Reference
---

This is a reference to all parameters that can be used to configure the rke2 server. Note that while this is a reference to the command line arguments, the best way to configure RKE2 is using the [configuration file](../install/configuration.md#configuration-file).

## Critical Configuration Values

The following options must be set to the same value on all servers in the cluster. Failure to do so will cause new servers to fail to join the cluster.

* `agent-token`
* `cluster-cidr`
* `cluster-dns`
* `cluster-domain`
* `disable-cloud-controller`
* `disable-kube-proxy`
* `egress-selector-mode`
* `service-cidr`


### Common
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| config | Path to config file | /etc/rancher/rke2/config.yaml | RKE2_CONFIG_FILE |
| debug | Turn on debug logs  |  | RKE2_DEBUG |
| data-dir | Folder to hold state  | "/var/lib/rancher/rke2" |  |
### Listener
| Flag | Description | Default |
| --- | --- | --- |
| bind-address | rke2 bind address  | 0.0.0.0 |
| advertise-address | IPv4/IPv6 address that apiserver uses to advertise to members of the cluster  | node-external-ip/node-ip |
| tls-san | Add additional hostnames or IPv4/IPv6 addresses as Subject Alternative Names on the server TLS cert |  |
| tls-san-security | Protect the server TLS cert by refusing to add Subject Alternative Names not associated with the kubernetes apiserver service, server nodes, or values of the tls-san option  | true |
### Networking
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| cluster-cidr | IPv4/IPv6 network CIDRs to use for pod IPs  | 10.42.0.0/16 |  |
| service-cidr | IPv4/IPv6 network CIDRs to use for service IPs  | 10.43.0.0/16 |  |
| service-node-port-range | Port range to reserve for services with NodePort visibility  | "30000-32767" |  |
| cluster-dns | IPv4 Cluster IP for coredns service. Should be in your service-cidr range  | 10.43.0.10 |  |
| cluster-domain | Cluster Domain  | "cluster.local" |  |
| egress-selector-mode | One of 'agent', 'cluster', 'pod', 'disabled'  | "agent" |  |
| servicelb-namespace | Namespace of the pods for the servicelb component  | "kube-system" |  |
| cni | CNI Plugins to deploy, one of none, calico, canal, cilium; optionally with multus as the first value to enable the multus meta-plugin  | canal | RKE2_CNI |
### Client
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| write-kubeconfig | Write kubeconfig for admin client to this file  | RKE2_KUBECONFIG_OUTPUT |
| write-kubeconfig-mode | Write kubeconfig with this mode  | RKE2_KUBECONFIG_MODE |
### Helm
| Flag | Description |
| --- | --- |
| helm-job-image | Default image to use for helm jobs |
### Cluster
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| token | Shared secret used to join a server or agent to a cluster  | RKE2_TOKEN |
| token-file | File containing the token  | RKE2_TOKEN_FILE |
| agent-token | Shared secret used to join agents to the cluster, but not servers  | RKE2_AGENT_TOKEN |
| agent-token-file | File containing the agent secret  | RKE2_AGENT_TOKEN_FILE |
| server | Server to connect to, used to join a cluster  | RKE2_URL |
| cluster-reset | Forget all peers and become sole member of a new cluster  | RKE2_CLUSTER_RESET |
### Database
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| cluster-reset-restore-path | Path to snapshot file to be restored |  |  |
| etcd-expose-metrics | Expose etcd metrics to client interface.  | false |  |
| etcd-disable-snapshots | Disable automatic etcd snapshots |  |  |
| etcd-snapshot-name | Set the base name of etcd snapshots  | etcd-snapshot-&lt;unix-timestamp&gt;) |  |
| etcd-snapshot-schedule-cron | Snapshot interval time in cron spec. eg. every 5 hours '0 */5 * * *'  | "0 */12 * * *" |  |
| etcd-snapshot-retention | Number of snapshots to retain  | 5 |  |
| etcd-snapshot-dir | Directory to save db snapshots.  | $&#123;data-dir&#125;/db/snapshots |  |
| etcd-snapshot-compress | Compress etcd snapshot |  |  |
| etcd-s3 | Enable backup to S3 |  |  |
| etcd-s3-endpoint | S3 endpoint url  | "s3.amazonaws.com" |  |
| etcd-s3-endpoint-ca | S3 custom CA cert to connect to S3 endpoint |  |  |
| etcd-s3-skip-ssl-verify | Disables S3 SSL certificate validation |  |  |
| etcd-s3-access-key | S3 access key  |  | AWS_ACCESS_KEY_ID |
| etcd-s3-secret-key | S3 secret key  |  | AWS_SECRET_ACCESS_KEY |
| etcd-s3-bucket | S3 bucket name |  |  |
| etcd-s3-region | S3 region / bucket location (optional)  | "us-east-1" |  |
| etcd-s3-folder | S3 folder |  |  |
| etcd-s3-insecure | Disables S3 over HTTPS |  |  |
| etcd-s3-timeout | S3 timeout  | 5m0s |  |
### Flags
| Flag | Description |
| --- | --- |
| kube-apiserver-arg | Customized flag for kube-apiserver process |
| etcd-arg | Customized flag for etcd process |
| kube-controller-manager-arg | Customized flag for kube-controller-manager process |
| kube-scheduler-arg | Customized flag for kube-scheduler process |
| kube-cloud-controller-manager-arg | Customized flag for kube-cloud-controller-manager process |
### Components
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| disable | Do not deploy packaged components and delete any deployed components (valid items: rke2-coredns, rke2-ingress-nginx, rke2-metrics-server) |  |
| disable-scheduler | Disable Kubernetes default scheduler |  |
| disable-cloud-controller | Disable rke2 default cloud controller manager |  |
| disable-kube-proxy | Disable running kube-proxy |  |
| enable-servicelb | Enable rke2 default cloud controller manager's service controller  | RKE2_ENABLE_SERVICELB |
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
| embedded-registry | Enable embedded distributed container registry; requires use of embedded containerd |  |
| enable-pprof | Enable pprof endpoint on supervisor port |  |
| kubelet-path | Override kubelet binary path  | RKE2_KUBELET_PATH |
### Agent/Node
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| node-name | Node name  |  | RKE2_NODE_NAME |
| with-node-id | Append id to node name |  |  |
| node-label | Registering and starting kubelet with set of labels |  |  |
| node-taint | Registering kubelet with set of taints |  |  |
| image-credential-provider-bin-dir | The path to the directory where credential provider plugin binaries are located  | "/var/lib/rancher/credentialprovider/bin" |  |
| image-credential-provider-config | The path to the credential provider plugin config file  | "/var/lib/rancher/credentialprovider/config.yaml" |  |
| protect-kernel-defaults | Kernel tuning behavior. If set, error if kernel tunables are different than kubelet defaults. |  |  |
| selinux | Enable SELinux in containerd  |  | RKE2_SELINUX |
| lb-server-port | Local port for supervisor client load-balancer. If the supervisor and apiserver are not colocated an additional port 1 less than this port will also be used for the apiserver client load-balancer.  | 6444 | RKE2_LB_SERVER_PORT |
### Agent/Runtime
| Flag | Description | Default | Enviroment Variable |
| --- | --- | --- | --- |
| container-runtime-endpoint | Disable embedded containerd and use the CRI socket at the given path; when used with --docker this sets the docker socket path |  |  |
| default-runtime | Set the default runtime in containerd |  |  |
| snapshotter | Override default containerd snapshotter  | "overlayfs" |  |
| private-registry | Private registry configuration file  | "/etc/rancher/rke2/registries.yaml" |  |
| system-default-registry | Private registry to be used for all system images  |  | RKE2_SYSTEM_DEFAULT_REGISTRY |
### Agent/Containerd
| Flag | Description |
| --- | --- |
| disable-default-registry-endpoint | Disables containerd's fallback default registry endpoint when a mirror is configured for that registry |
### Agent/Networking
| Flag | Description | Enviroment Variable |
| --- | --- | --- |
| node-ip | IPv4/IPv6 addresses to advertise for node |  |
| node-external-ip | IPv4/IPv6 external IP addresses to advertise for node |  |
| resolv-conf | Kubelet resolv.conf file  | RKE2_RESOLV_CONF |
### Agent/Flags
| Flag | Description |
| --- | --- |
| kubelet-arg | Customized flag for kubelet process |
| kube-proxy-arg | Customized flag for kube-proxy process |
