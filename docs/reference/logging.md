---
title: "Logging"
---

When running with systemd, the main RKE2 logs will be created in `/var/log/syslog` and viewed using `journalctl -u rke2-server` or `journalctl -u rke2-agent`.

The Containerd logs are written to `/var/lib/rancher/rke2/agent/containerd/containerd.log`.

The kubelet logs are written to `/var/lib/rancher/rke2/agent/logs/kubelet.log`.

Etcd and the Kubernetes control-plane components run as static Pods in the `kube-system` namespace.

Logs from each Kubernetes Pod can be accessed with `kubectl`:

```
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml logs -n kube-system -l component=kube-apiserver
```

Logs from each container can be accessed with `crictl`:

```
# list running containers
/var/lib/rancher/rke2/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock ps
# get logs from container by container id
/var/lib/rancher/rke2/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock logs <container_id>
```