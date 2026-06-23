---
title: Cluster Load Balancer
---


:::note
This guide is provided as-is and does not indicate official SUSE endorsement or support of HAProxy or other external load balancers. 

:::tip
External load-balancers should not be confused with the optional ServiceLB, which is an embedded controller that allows for use of Kubernetes LoadBalancer Services without deploying a third-party load-balancer controller. For more details, see [Service Load Balancer](./networking_services.md#service-load-balancer).

External load-balancers can be used to provide a fixed registration address for registering nodes, or for external access to the Kubernetes API Server. For exposing LoadBalancer Services, external load-balancers can be used alongside or instead of ServiceLB, but in most cases, replacement load-balancer controllers such as MetalLB or Kube-VIP are a better choice.
:::

## Prerequisites

All nodes in this example are running Ubuntu 24.04.

Three nodes will be used as servers and have hostnames and IPs of: 
* server-1: `10.10.10.50`
* server-2: `10.10.10.51`
* server-3: `10.10.10.52`

Two additional nodes for load balancing are configured with hostnames and IPs of:
* lb-1: `10.10.10.98`
* lb-2: `10.10.10.99`

Three additional nodes exist with hostnames and IPs of:
* agent-1: `10.10.10.101`
* agent-2: `10.10.10.102`
* agent-3: `10.10.10.103`

## Setup Load Balancer
[HAProxy](http://www.haproxy.org/) is an open source option that provides a TCP load balancer. It also supports HA for the load balancer itself, ensuring redundancy at all levels. See [HAProxy Documentation](http://docs.haproxy.org/2.8/intro.html) for more info.

Additionally, we will use Keepalived to generate a virtual IP (VIP) that will be used to access the cluster. See [Keepalived Documentation](https://www.keepalived.org/documentation/) for more info.


1) Install HAProxy and Keepalived:

```bash
sudo apt-get install haproxy keepalived
```

2) Add the following to `/etc/haproxy/haproxy.cfg` on lb-1 and lb-2:

```
frontend rke2-frontend
    bind *:9345
    mode tcp
    option tcplog
    default_backend rke2-backend

frontend k8s-api-frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s-api-backend

backend rke2-backend
    mode tcp
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s
    server server-1 10.10.10.50:9345 check
    server server-2 10.10.10.51:9345 check
    server server-3 10.10.10.52:9345 check

backend k8s-api-backend
    mode tcp
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s
    server server-1 10.10.10.50:6443 check
    server server-2 10.10.10.51:6443 check
    server server-3 10.10.10.52:6443 check
```

**Note:** Binding port 6443 is only useful if you want to connect to the API Server through HAProxy.

3) Add the following to `/etc/keepalived/keepalived.conf` on lb-1 and lb-2:

```
global_defs {
  enable_script_security
  script_user root
}

vrrp_script chk_haproxy {
    script 'killall -0 haproxy' # faster than pidof
    interval 2
}

vrrp_instance haproxy-vip {
    interface <INTERFACE> # e.g. eth0
    state <STATE> # MASTER on lb-1, BACKUP on lb-2
    priority <PRIORITY> # 200 on lb-1, 100 on lb-2

    virtual_router_id 51

    virtual_ipaddress {
        10.10.10.100/24
    }

    track_script {
        chk_haproxy
    }
}
```

4) Restart HAProxy and Keepalived on lb-1 and lb-2:

```bash
systemctl restart haproxy
systemctl restart keepalived
```

## Setup the servers
Deploy a [HA RKE2 cluster with embedded etcd](../install/ha.md) on the 3 server nodes.

All server nodes should include the shared token and the load balancer VIP in `tls-san`:
```yaml
# /etc/rancher/rke2/config.yaml
token: "lb-cluster-gd"
tls-san:
  - "10.10.10.100"
```

For server nodes beyond the first, also set `server: https://10.10.10.100:9345` as shown in the [HA installation guide](../install/ha.md).

<details>
<summary>**eBPF dataplane**</summary>
To enable Calico's eBPF dataplane with the benefits of an HA control plane, add `disable-kube-proxy: true` in the configuration file and use the following HelmChartConfig:

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-calico
  namespace: kube-system
spec:
  valuesContent: |-
    installation:
      calicoNetwork:
        kubeProxyManagement: Enabled
        linuxDataplane: BPF
    kubernetesServiceEndpoint:
      host: "10.10.10.100"
      port: "6443"
```
</details>

## Setup the agents
On agent-1, agent-2, and agent-3, use the following in your `config.yaml` to join the cluster:

```yaml
server: "https://10.10.10.100:9345"
token: "lb-cluster-gd"
```

You can now use `kubectl` from server nodes to interact with the cluster.
```bash
root@server-1 $ kubectl get nodes -A
NAME       STATUS   ROLES                    AGE     VERSION
agent-1    Ready    <none>                   32s     v1.36.1+rke2r2
agent-2    Ready    <none>                   20s     v1.36.1+rke2r2
agent-3    Ready    <none>                   9s      v1.36.1+rke2r2
server-1   Ready    control-plane,etcd       4m22s   v1.36.1+rke2r2
server-2   Ready    control-plane,etcd       3m58s   v1.36.1+rke2r2
server-3   Ready    control-plane,etcd       3m12s   v1.36.1+rke2r2
```
