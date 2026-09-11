---
title: SELinux
---

RKE2 is compatible with SELinux-enabled systems, and running with SELinux in `Enforcing` mode is a supported configuration on the distributions where it is the default: SUSE Linux Enterprise Server, SLE Micro and MicroOS, and RHEL and its derivatives (CentOS, Rocky, Alma, Oracle Linux, Amazon Linux).

There are two independent requirements that must be fulfilled on **every** node — servers and agents alike — for RKE2 to work on an `Enforcing` node:

1. The `rke2-selinux` policy module is installed and loaded on the host.
2. RKE2 itself is started with SELinux support enabled (`selinux: true` in the config file, or `RKE2_SELINUX=true` in the environment).

Depending on how you install RKE2, you get both, or neither. See [How each install method handles SELinux](#how-each-install-method-handles-selinux).

The [policy](https://github.com/rancher/rke2-selinux) supporting this is a specialization of the
[container-selinux](https://github.com/containers/container-selinux) policy for containerd. It accounts
for the non-standard location(s) which containerd is installed and places persistent and ephemeral state.

:::note
`rke2-selinux` declares `Conflicts: k3s-selinux`. A node cannot have both policies installed; remove `k3s-selinux` before installing `rke2-selinux`.
:::

## How each install method handles SELinux

| Install method | `rke2-selinux` policy | `selinux: true` |
| --- | --- | --- |
| RPM — the `rpm.rancher.io` repositories, or `install.sh` on an RPM-based distribution | Installed automatically. `rke2-common` carries a hard `Requires: rke2-selinux`, so the package manager always pulls the policy in | Enabled automatically. The RPM ships `/etc/sysconfig/rke2-server` (or `/etc/sysconfig/rke2-agent`) containing `RKE2_SELINUX=true`, which the systemd unit reads |
| Tarball — `install.sh` with `INSTALL_RKE2_METHOD=tar`, or a manual binary install | **Not installed.** You must install it yourself | **Not enabled.** You must set it yourself |

This is the single most common source of surprise on `Enforcing` nodes: the tarball path of `install.sh` never installs the policy for you. All it does is check whether `rke2-selinux` is *already* installed and, if it is, run `restorecon` over the files it just wrote — because a tarball extraction does not apply the file contexts an RPM would. That relabel step can be turned off with `INSTALL_RKE2_SKIP_RESTORECON=true`.

:::warning
On an `Enforcing` node installed from the tarball, the order matters: **install `rke2-selinux` first, then install RKE2.** Installing the policy afterwards leaves the RKE2 files carrying the wrong contexts, and nothing relabels them for you. If you already did it the other way around, see [Relabeling an existing installation](#relabeling-an-existing-installation).
:::

## Checking the state of a node

Before and after installing, these four commands tell you everything you need to know:

```bash
# 1. Is SELinux enforcing, and which policy is loaded?
sestatus

# 2. Is the RKE2 policy module loaded?
semodule -l | grep rke2

# 3. Are the packages installed?
rpm -q rke2-selinux container-selinux

# 4. Once RKE2 is running, is the process in the right domain?
ps -eZ | grep 'rke2 \(server\|agent\)'
```

The last command should show the `rke2` process running in the `container_runtime_t` domain, for example:

```
system_u:system_r:container_runtime_t:s0 1234 ? 00:01:20 rke2
```

If it shows `unconfined_service_t` instead, the policy is either not installed or the RKE2 binary and systemd unit are not labeled correctly.

## Installing rke2-selinux on its own

`rke2-selinux` is published in the **common** RPM repository, which is separate from the version-specific RKE2 repository and contains nothing but this package. You can therefore add the common repository on its own and install the policy without adding any other RKE2 repository, and without installing RKE2 from RPM.

The policy is not tied to a particular RKE2 minor version — a single `rke2-selinux` release covers all supported RKE2 versions on that distribution.

<Tabs groupId="selinux-distro" queryString>
<TabItem value="SLES 16" default>

```bash
cat << EOF > /etc/zypp/repos.d/rancher-rke2-common-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/slemicro/noarch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

zypper --gpg-auto-import-keys install -y rke2-selinux
```

</TabItem>
<TabItem value="SLE Micro">

SLE Micro uses the same `slemicro` repository, but as an immutable distribution the install must go through `transactional-update` and only takes effect after a reboot:

```bash
cat << EOF > /etc/zypp/repos.d/rancher-rke2-common-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/slemicro/noarch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

transactional-update --no-selfupdate -d run zypper --gpg-auto-import-keys install -y rke2-selinux
reboot
```

</TabItem>
<TabItem value="MicroOS">

MicroOS uses the `microos` repository and, like SLE Micro, requires `transactional-update` and a reboot:

```bash
cat << EOF > /etc/zypp/repos.d/rancher-rke2-common-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/microos/noarch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

transactional-update --no-selfupdate -d run zypper --gpg-auto-import-keys install -y rke2-selinux
reboot
```

</TabItem>
<TabItem value="RHEL 8/9/10">

```bash
export LINUX_MAJOR=9 # or 8 or 10
cat << EOF > /etc/yum.repos.d/rancher-rke2-common-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/centos/${LINUX_MAJOR}/noarch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

yum -y install rke2-selinux
```

</TabItem>
</Tabs>

Replace `latest` with `stable` in both the repository name and the URL to track the stable channel instead. The `testing` channel is served from `rpm-testing.rancher.io`.

### Dependencies

`rke2-selinux` requires the following packages, which must be resolvable from your configured repositories (or already present, in an air-gapped environment):

* `container-selinux`
* `selinux-policy-base`
* `selinux-policy`
* `policycoreutils`
* `selinux-tools` (SUSE) or `libselinux-utils` (RHEL)

`container-selinux` is the important one: `rke2-selinux` builds on top of it, and a `container-selinux` that is too old for the `rke2-selinux` release you are installing will cause the install to fail.

### Air-gapped and offline installs

There is no repository to reach from an air-gapped node, so fetch the RPM and its dependencies on a machine that can reach the internet and copy them across.

The simplest source for the policy alone is the [rke2-selinux releases page](https://github.com/rancher/rke2-selinux/releases/latest), which publishes one `noarch` RPM per distribution — `.slemicro` (SLES / SLE Micro), `.sle` (MicroOS), `.el8`, `.el9` and `.el10`. Pick the one matching your OS:

```bash
# on a machine with network access
curl -sfLO https://github.com/rancher/rke2-selinux/releases/download/v0.23.stable.1/rke2-selinux-0.23-1.slemicro.noarch.rpm
```

To pull the policy together with everything it depends on, use your package manager's download-only mode on a connected machine **running the same OS version**:

```bash
# SUSE
zypper --pkg-cache-dir /root/rke2-selinux-rpms install --download-only -y rke2-selinux

# RHEL
dnf download --resolve --alldeps --destdir /root/rke2-selinux-rpms rke2-selinux
```

Copy the directory to each air-gapped node and install from the local files, before installing RKE2:

```bash
# SUSE
zypper --no-gpg-checks install -y /root/rke2-selinux-rpms/*.rpm

# RHEL
yum -y install /root/rke2-selinux-rpms/*.rpm
```

See the [air-gap install documentation](../install/airgap.md) for the rest of the offline install.

### Relabeling an existing installation

If RKE2 was installed from the tarball *before* `rke2-selinux`, the files on disk carry whatever contexts they inherited at extraction time, and the policy will not have been applied to them. Installing the policy afterwards does not retroactively relabel them.

Re-running `install.sh` fixes this, because it relabels once it detects the policy. To relabel by hand instead, without reinstalling:

```bash
restorecon -R -i -v /etc/systemd/system/rke2* /usr/local/lib/systemd/system/rke2* /usr/lib/systemd/system/rke2*
restorecon -R -i -v /usr/local/bin/rke2* /usr/bin/rke2*
restorecon -R -i -v /var/lib/rancher/rke2
systemctl daemon-reload
```

Then restart the RKE2 service.

:::note
The policy ships file contexts for the binary at `/usr/bin/rke2` and `/usr/local/bin/rke2` only. If you installed the tarball under a custom prefix with `INSTALL_RKE2_TAR_PREFIX` — which `install.sh` also does on its own, falling back to `/opt/rke2` when `/usr/local` is read-only or on a dedicated mount point — the binary is outside the paths the policy knows about. Add an equivalency rule for it:

```bash
semanage fcontext -a -t container_runtime_exec_t '/opt/rke2/bin/rke2'
restorecon -v /opt/rke2/bin/rke2
```
:::

### Reboot

In some circumstances, a reboot of the node is required after installing the `rke2-selinux` package and before starting the `rke2` service. If you encounter denials in your SELinux audit log despite having both `rke2-selinux` and `container-selinux` installed, reboot the node.

## Configuration

RKE2 support for SELinux amounts to a single configuration item, the `selinux` boolean entry in RKE2 `config.yaml` or the `RKE2_SELINUX=true` environment variable. This is a pass-through
to the [`enable_selinux` boolean in the cri section of the containerd/cri toml](https://github.com/containerd/cri/blob/release/1.4/docs/config.md).

RPM installations set this for you. Tarball and manual installations do not, so SELinux will not be enabled for containers without the configuration entry or the environment variable:

```yaml
# /etc/rancher/rke2/config.yaml is the default location
selinux: true
```

This must be set on every server and agent node. Enabling it on the servers alone leaves your agents running without SELinux labeling for containers.

Installing `rke2-selinux` and setting `selinux: true` are separate steps and neither implies the other. RKE2 logs a warning at startup when they disagree — see [Troubleshooting](#troubleshooting).

## Custom Context Labels

RKE2 runs control-plane services as static pods which require access to multiple
[`container_var_lib_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L59)
locations. The `etcd` container must be able to read-write under `/var/lib/rancher/rke2/server/db` and read,
along with `kube-apiserver`, `kube-controller-manager`, and `kube-scheduler`, from `/var/lib/rancher/rke2/server/tls`.
To make this work without over-privileging, e.g.,
[`spc_t`](https://github.com/containers/container-selinux/blob/RHEL7.5/container.te#L47-L49), the RKE2 SELinux policy
introduces its own context labels:

| Label | Applied to | Purpose |
| --- | --- | --- |
| [`rke2_service_db_t`](https://github.com/rancher/rke2-selinux/blob/v0.23.stable.1/policy/centos9/rke2.te#L22-L25) | The `etcd` static pod | Read-write access to the datastore under `/var/lib/rancher/rke2/server/db` |
| [`rke2_service_t`](https://github.com/rancher/rke2-selinux/blob/v0.23.stable.1/policy/centos9/rke2.te#L13-L17) | The remaining control-plane static pods | Read-only access to control-plane state |
| [`rke2_tls_t`](https://github.com/rancher/rke2-selinux/blob/v0.23.stable.1/policy/centos9/rke2.te#L34-L37) | `/var/lib/rancher/rke2/server/tls` | Certificates and keys read by the control-plane pods |

These labels are only applied to the RKE2 control-plane static pods; workload pods are unaffected and continue to use the standard `container_t` domain.

## Specific OS Requirements

<Tabs groupId="os-reqs" queryString>
<TabItem value="Amazon Linux 2">
Amazon Linux 2 requires additional selinux packages to be installed:

```bash
sudo amazon-linux-extras enable selinux-ng; sudo yum install selinux-policy-targeted -y
```

</TabItem>
</Tabs>

#### Calico support
If you choose to use Calico as your CNI with SELinux enabled, you will also need to install specific policies.

The package to install is provided by Tigera [here](https://downloads.tigera.io/ee/archives/calico-selinux-1.0-1.el9.noarch.rpm).

See Calico's [documentation](https://docs.tigera.io/calico-enterprise/latest/getting-started/install-on-clusters/requirements) for more details.

## Troubleshooting

### Warnings in the RKE2 log

RKE2 checks the host's SELinux state against its own configuration at startup and warns — it does not refuse to start — when the two do not line up:

`SELinux is enabled on this host, but rke2 has not been started with --selinux - containerd SELinux support is disabled`

The node is `Enforcing`, but RKE2 is running without `selinux: true`. Containers are not being labeled. Add the configuration entry and restart.

`SELinux is enabled for rke2 but process is not running in context 'container_runtime_t', rke2-selinux policy may need to be applied`

You asked for SELinux support, but the `rke2` process itself is not in the domain the policy defines. Either `rke2-selinux` is not installed, or it was installed after a tarball install and the files were never relabeled. See [Relabeling an existing installation](#relabeling-an-existing-installation).

### Inspecting denials

```bash
# recent denials, when auditd is running
ausearch -m AVC,USER_AVC -ts recent

# when auditd is not running
journalctl -k --grep=AVC

# a human-readable explanation of what was denied and why
ausearch -m AVC,USER_AVC -ts recent | audit2why
```

If denials persist immediately after installing the policy, reboot the node before investigating further — a stale policy load accounts for a good share of them.

### Known limitations

* Istio fails by default on `Enforcing` nodes. See [Known Issues](../known_issues.md#istio-in-selinux-enforcing-system-fails-by-default).
* `rke2-uninstall.sh` removes the policy module with `semodule -r rke2` as part of the cleanup. On RPM-based installs it also removes the `rke2-selinux` package. If you plan to reinstall RKE2 on the same node, expect to install the policy again.
