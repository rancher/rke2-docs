---
title: "Logging"
---

When running with systemd, logs are sent to journald and can be viewed using `journalctl -u rke2-server` or `journalctl -u rke2-agent`. Some systemd configurations may also write combined logs to `/var/log/syslog`, in which case the rke2 logs will also be available there.

The Containerd logs are written to `/var/lib/rancher/rke2/agent/containerd/containerd.log`.

The kubelet logs are written to `/var/lib/rancher/rke2/agent/logs/kubelet.log`.

Etcd and the Kubernetes control-plane components run as static Pods in the `kube-system` namespace.

Logs from each Kubernetes Pod can be accessed with `kubectl`:

```
/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml logs -n kube-system -l component=kube-apiserver
```

Logs from each container can be accessed with `crictl`:

```
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
# list running containers
/var/lib/rancher/rke2/bin/crictl ps
# get logs from container by container id
/var/lib/rancher/rke2/bin/crictl logs <container_id>
```