---
sidebar_label: "Known Issues and Limits"
title: "Known Issues and Limitations"
---

This section contains current known issues and limitations with rke2. If you come across issues with rke2 not documented here, please open a new issue [here](https://github.com/rancher/rke2/issues).

## Firewalld conflicts with default networking

Firewalld conflicts with RKE2's default Canal (Calico + Flannel) networking stack. To avoid unexpected behavior, firewalld should be disabled on systems running RKE2.

## NetworkManager

NetworkManager manipulates the routing table for interfaces in the default network namespace where many CNIs, including RKE2's default, create veth pairs for connections to containers. This can interfere with the CNI’s ability to route correctly. As such, if installing RKE2 on a NetworkManager enabled system, it is highly recommended to configure NetworkManager to ignore calico/flannel related network interfaces. In order to do this, create a configuration file called `rke2-canal.conf` in `/etc/NetworkManager/conf.d` with the contents:
```bash
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
```

If you have not yet installed RKE2, a simple `systemctl reload NetworkManager` will suffice to install the configuration. If performing this configuration change on a system that already has RKE2 installed, a reboot of the node is necessary to effectively apply the changes.

In some operating systems like RHEL 8.4, NetworkManager includes two extra services called `nm-cloud-setup.service` and `nm-cloud-setup.timer`.  These services add a routing table that interfere with the CNI plugin's configuration. Unfortunately, there is no config that can avoid that as explained in the [issue](https://github.com/rancher/rke2/issues/1053). Therefore, if those services exist, they should be disabled. 
:::info
  Before NetworkManager-1.30.0-11.el8_4, the node must also be rebooted after disabling the extra services.
:::

## Istio in Selinux Enforcing System Fails by Default

This is due to just-in-time kernel module loading of rke2, which is disallowed under Selinux unless the container is privileged.
To allow Istio to run under these conditions, it requires two steps:
1. [Enable CNI](https://istio.io/latest/docs/setup/additional-setup/cni/) as part of the Istio install. Please note that this [feature](https://istio.io/latest/about/feature-stages/) is still in Alpha state at the time of this writing.
Ensure `values.cni.cniBinDir=/opt/cni/bin` and `values.cni.cniConfDir=/etc/cni/net.d`
2. After the install is complete, there should be `cni-node` pods in a CrashLoopBackoff. Manually edit their daemonset to include `securityContext.privileged: true` on the `install-cni` container.

This can be performed via a custom overlay as follows:
```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    cni:
      enabled: true
      k8s:
        overlays:
        - apiVersion: "apps/v1"
          kind: "DaemonSet"
          name: "istio-cni-node"
          patches:
          - path: spec.template.spec.containers.[name:install-cni].securityContext.privileged
            value: true
  values:
    cni:
      image: rancher/mirrored-istio-install-cni:1.9.3
      excludeNamespaces:
      - istio-system
      - kube-system
      logLevel: info
      cniBinDir: /opt/cni/bin
      cniConfDir: /etc/cni/net.d
```

For more information regarding exact failures with detailed logs when not following these steps, please see [Issue 504](https://github.com/rancher/rke2/issues/504).

## Control Groups V2

RKE2 v1.19.5+ ships with `containerd` v1.4.x or later, hence should run on cgroups v2 capable systems.  
Older versions (< 1.19.5) are shipped with containerd 1.3.x fork (with back-ported SELinux commits from 1.4.x)
which does not support cgroups v2 and requires a little up-front configuration:

Assuming a `systemd`-based system, setting the [systemd.unified_cgroup_hierarchy=0](https://www.freedesktop.org/software/systemd/man/systemd.html#systemd.unified_cgroup_hierarchy)
kernel parameter will indicate to systemd that it should run with hybrid (cgroups v1 + v2) support.
Combined with the above, setting the [systemd.legacy_systemd_cgroup_controller](https://www.freedesktop.org/software/systemd/man/systemd.html#systemd.legacy_systemd_cgroup_controller)
kernel parameter will indicate to systemd that it should run with legacy (cgroups v1) support.
As these are kernel command-line arguments they must be set in the system bootloader so that they will be
passed to `systemd` as PID 1 at `/sbin/init`.

See:

- [grub2 manual](https://www.gnu.org/software/grub/manual/grub/grub.html#linux)
- [systemd manual](https://www.freedesktop.org/software/systemd/man/systemd.html#Kernel%20Command%20Line)
- [cgroups v2](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)


## Calico with vxlan encapsulation

Calico hits a kernel bug when using vxlan encapsulation and the checksum offloading of the vxlan interface is on.
The issue is described in the [calico project](https://github.com/projectcalico/calico/issues/4865) and in
[rke2 project](https://github.com/rancher/rke2/issues/1541). The workaround we are applying is disabling the checksum
offloading by default by applying the value `ChecksumOffloadBroken=true` in the [calico helm chart](https://github.com/rancher/rke2-charts/blob/main/charts/rke2-calico/rke2-calico/v3.25.001/values.yaml#L75-L76).

This issue has been observed in Ubuntu 18.04, Ubuntu 20.04 and openSUSE Leap 15.3

## Wicked

Wicked configures the networking settings of the host based on the sysctl configuration files (e.g. under /etc/sysctl.d/ directory). Even though rke2 is setting parameters such as `/net/ipv4/conf/all/forwarding` to 1, that configuration could be reverted by Wicked whenever it reapplies the network configuration (there are several events that result in reapplying the network configuration as well as rcwicked restart during updates). Consequently, it is very important to enable ipv4 (and ipv6 in case of dual-stack) forwarding in sysctl configuration files. For example, it is recommended to create a file with the name `/etc/sysctl.d/90-rke2.conf` containing these parameters (ipv6 only needed in case of dual-stack):

```bash
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding=1
```

## Canal and IP exhaustion ##

There are two possible reasons for this:

1. `iptables` binary is not installed in the host and there is a pod defining a hostPort. The pod will be given an IP but its creation will fail and Kubernetes will not cease trying to recreate it, consuming one IP every time it tries. Error messages similar to the following will appear in the containerd log. This is the log showing the error:

```console
plugin type="portmap" failed (add): failed to open iptables: exec: "iptables": executable file not found in $PATH 
```
Please install iptables or xtables-nft package to resolve this problem


2. By default Canal keeps track of pod IPs by creating a lock file for each IP in `/var/lib/cni/networks/k8s-pod-network`. Each IP belongs to a single pod and will be deleted as soon as the pod is removed. However, in the unlikely event that containerd loses track of the running pods, lock files may be leaked and Canal will not be able to reuse those IPs anymore. If this occurs, you may experience IP exhaustion errors, for example:


```console
failed to allocate for range 0: no IP addresses available in range set
```
There are two ways to resolve this. You can either manually remove unused IPs from that directory or drain the node, run rke2-killall.sh, start the rke2 systemd service and uncordon the node. If you need to undertake any of these actions, please report the problem via GitHub, making sure to specify how it was triggered.

## Ingress in CIS Mode

By default, when RKE2 is run with a CIS profile selected by the `profile` parameter, it applies network policies that can be restrictive for ingress. This, coupled with the `rke2-ingress-nginx` chart having `hostNetwork: false` by default, requires users to set network policies of their own to allow access to the ingress URLs. Below is an example networkpolicy that allows ingress to any workload in the namespace it is applied in. See https://kubernetes.io/docs/concepts/services-networking/network-policies/ for more configuration options.
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-to-backends
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: rke2-ingress-nginx
  policyTypes:
  - Ingress
```
For more information, refer to comments on https://github.com/rancher/rke2/issues/3195.

# Upgrading Hardened Clusters from v1.24.x to v1.25.x

Kubernetes removed PodSecurityPolicy from v1.25 in favor of Pod Security Standards. You can read more about PSS in the [upstream documentation](https://kubernetes.io/docs/concepts/security/pod-security-standards/). For RKE2, there are some manual steps that must be taken if the `profile` flag has been set on the nodes.

1. On all nodes, update the `profile` value to `cis-1.23`, but do not restart or upgrade RKE2 yet.
2. Perform the upgrade as normal. If using [Automated Upgrades](./upgrade/automated_upgrade.md), ensure that the namespace where the `system-upgrade-controller` pod is running in is setup to be privileged in accordance with the [Pod Security levels](https://kubernetes.io/docs/concepts/security/pod-security-admission/#pod-security-levels):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: system-upgrade
  labels:
    # This value must be privileged for the controller to run successfully.
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: v1.25
    # We are setting these to our _desired_ `enforce` level, but note that these below values can be any of the available options.
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/audit-version: v1.25
    pod-security.kubernetes.io/warn: privileged
    pod-security.kubernetes.io/warn-version: v1.25
```
