---
title: SELinux
---

RKE2 is compatible with SELinux-enabled systems, which is the default configuration on CentOS/RHEL systems starting from version 7.
The [policy](https://github.com/rancher/rke2-selinux) supporting this is a specialization of the 
[container-selinux](https://github.com/containers/container-selinux) policy for containerd. It accounts
for the non-standard location(s) which containerd is installed and places persistent and ephemeral state.

Note: In some circumstances, a reboot of the node may be required after installing the rke2-selinux package and before starting the rke2 service. If you encounter denials in your selinux audit log despite installation of the rke2-selinux and container-selinux packages, please reboot the node.

## Custom Context Labels

RKE2 runs control-plane services as static pods which require access to multiple
[`container_var_lib_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L59)
locations. The `etcd` container must be able to read-write under `/var/lib/rancher/rke2/server/db` and read,
along with `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler`, from `/var/lib/rancher/rke2/server/tls`.
To make this work without over-privileging, e.g.,
[`spc_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L47-L49), the RKE2 SELinux policy
introduces the [`rke2_service_db_t`](https://github.com/rancher/rke2-selinux/blob/v0.3.latest.1/rke2.te#L15-L21) and 
[`rke2_service_t`](https://github.com/rancher/rke2-selinux/blob/v0.3.latest.1/rke2.te#L9-L13) context labels for
read-write and read-only access, respectively. These labels will only be applied to the RKE2 control-plane static pods.  

## Specific OS Requirements

<Tabs groupId="os-reqs" queryString>
<TabItem value="Amazon Linux 2">
Amazon Linux 2 requires additional selinux packages to be installed:

```bash
sudo amazon-linux-extras enable selinux-ng; sudo yum install selinux-policy-targeted -y
```

</TabItem>
</Tabs>


## Configuration

RKE2 support for SELinux amounts to a single configuration item, the `selinux` boolean entry in RKE2 `config.yaml` or the `RKE2_SELINUX=true` environment variable. This is a pass-through
to the [`enable_selinux` boolean in the cri section of the containerd/cri toml](https://github.com/containerd/cri/blob/release/1.4/docs/config.md).

SELinux comes as default for rpms installation, but if the install method was tarball then SELinux will not be enabled without the configuration entry or the environment variable, e.g.:

```yaml
# /etc/rancher/rke2/config.yaml is the default location
selinux: true
```

#### Calico support
If you choose to use Calico as your CNI with SELinux enabled, you will also need to install specific policies.

The package to install is provided by Tigera [here](https://downloads.tigera.io/ee/archives/calico-selinux-1.0-1.el9.noarch.rpm).

See Calico's [documentation](https://docs.tigera.io/calico-enterprise/latest/getting-started/install-on-clusters/requirements) for more details.
