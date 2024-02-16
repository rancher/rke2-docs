---
title: Token Management
---


## Server Token Rotation

:::info Version Gate
Available as of 2023-11 releases (v1.28.3+rke2r2, v1.27.7+rke2r2, v1.26.10+rke2r2, v1.25.15+rke2r2).
:::

The `rke2 token rotate` command allows you to rotate and replace the original token used for server bootstrap. After running the command on a single server, all servers and agents that used the original token should be restarted with the new token. The original token will be invalidated and cannot be used to join any new servers or agents to the cluster.

 Flag | Description | Default                                                                            
 ---- | ---- | ----
`--data-dir` value   | Folder to hold state | /var/lib/rancher/rke2 
`--kubeconfig` value | Kubeconfig for authentication to server | /etc/rancher/rke2/rke2.yaml 
`--server` value     | Server to connect to  | "https://127.0.0.1:9345"                                                    
`--token` value      | Existing token used to join a server or agent to a cluster | N/A
`--new-token` value  | New token to replace the original token | If not specified, a random 16 character token will be generated          

