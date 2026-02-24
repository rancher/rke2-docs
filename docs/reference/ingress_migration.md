---
title: Ingress-Nginx to Traefik Migration Guide
---

The Kubernetes Ingress NGINX project has announced its [retirement in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/). As a result, RKE2 is transitioning to Traefik as the default ingress controller for new clusters starting with RKE2 v1.36.

To support existing RKE2 clusters, a migration path is available pior to v1.36 to help users transition from Ingress NGINX to Traefik with minimal disruption.

This guide will provide step-by-step instructions as a general process for converting an RKE2 cluster from using Ingress NGINX to Traefik as the ingress controller.

SUSE Rancher Prime LTS customers will receive Ingress NGINX [support through November 2027](https://www.suse.com/c/trade-the-ingress-nginx-retirement-for-up-to-2-years-of-rke2-support-stability/).

## Prerequisites
- A RKE2 cluster that is using Ingress NGINX as the ingress controller. The RKE2 version must be one of the following: 
    - v1.32 >= v1.32.11+rke2r1
    - v1.33 >= v1.33.7+rke2r1
    - v1.34 >= v1.34.3+rke2r1 
    - Any release > v1.35
- While Traefik includes a compatibility layer for interpreting Ingress NGINX annotations, not all annotations are supported. Review the [Traefik & Ingresses with NGINX Annotations documentation](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress-nginx/#annotations-support) to ensure your existing Ingress resources are compatible. You can also use the [Traefik Ingress NGINX Annotations Discovery Tool](https://github.com/traefik/ingress-nginx-migration?tab=readme-ov-file#installation) to help identify any unsupported annotations in your cluster.

## Migration Overview

Migration
The migration process involves four main phases on your RKE2 cluster:

Phase 1: Enable Traefik alongside Ingress NGINX, using temporary non-conflicting ports for Traefik.

Phase 2: Replicating the ingress objects, they can be exposed by both Ingress NGINX and Traefik. We can use this phase to verify that Traefik can handle the existing ingress objects without disruption.

Phase 3: Once the testing using Traefik is complete, remove Ingress NGINX.

Phase 4: Cleanup and removal of duplicated ingress resources 

## Phase 1: Dual ingress controller setup
In this phase, you enable Traefik as a secondary Ingress Controller and configure it to use temporary ports to avoid conflict with the existing Ingress NGINX controller. You also enable the Ingress NGINX provider that allows Traefik to interpret Ingress NGINX annotations.

#### 1. Assign `ingressClassName: nginx` to existing ingresses
    
First, ensure all existing Ingress resources are explicitly bound to the Ingress NGINX controller to prevent any race conditions when Traefik is deployed.

This command finds all Ingress resources across all namespaces and patches them to set the ingressClassName to `nginx`.

```
kubectl get ingress --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' --no-headers | while read NS NAME; do
    echo "Patching Ingress: $NS/$NAME"
    kubectl patch ingress "$NAME" -n "$NS" --type=merge -p '{"spec": {"ingressClassName": "nginx"}}'
done
```

<details>
    <summary>Verification of IngressClass assignment</summary>
    
    Run this command to quickly verify that all your Ingress resources now have their ingressClassName explicitly set to nginx.
    ```
    kubectl get ingress --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ICLASS:.spec.ingressClassName'
    ```
    
    If any Ingress resource shows `none` or a different class in the ICLASS column, you must investigate and manually patch those resources before proceeding to the next step.
</details>
    
#### 2. Update RKE2 configuration

Edit the RKE2 server configuration file (/etc/rancher/rke2/config.yaml) to enable both controllers:
```
# /etc/rancher/rke2/config.yaml
ingress-controller:
- ingress-nginx
- traefik
```

:::caution For airgap installations
If you are using the Image Tarball, note that Traefik is not included in the default rke2-images.linux-amd64.tar.zst asset (example assuming amd64), and you will need to download the additional rke2-images-traefik.linux-amd64.tar.zst tarball, and place it in the corresponding folder on the airgap node.
:::
    
#### 3. Configure Traefik ports and compatibility settings

Create the HelmChartConfig manifest on your server node (e.g. `/var/lib/rancher/rke2/server/manifests/rke2-traefik-config.yaml`). This manifest performs three functions:

- Sets Traefik to use non-conflicting ports (8000 and 8443).
- Enables Ingress NGINX compatibility mode for annotations (--providers.kubernetesIngressNGINX).
- Disables the published service to avoid race conditions with Ingress NGINX.

```
# rke2-traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
    name: rke2-traefik
    namespace: kube-system
spec:
    valuesContent: |-
    ports:
        web:
        hostPort: 8000
        websecure:
        hostPort: 8443
    providers:
        kubernetesIngressNginx:
        enabled: true
        ingressClass: "rke2-ingress-nginx-migration"
        controllerClass: "rke2.​cattle.​io/ingress-nginx-migration"
```

#### 4. Restart RKE2

Restart the rke2-server service in all CP nodes to apply the configuration changes:
```
sudo systemctl restart rke2-server
```

Wait for the cluster to become ready. Verify that both rke2-ingress-nginx-controller and rke2-traefik DaemonSets must be running:
```
kubectl get daemonset -n kube-system
```

#### 5. Verify Functionality

- Existing Ingress NGINX Ingresses: Verify that your existing Ingresses are still reachable on the standard ports (80/443).

- New Traefik Ingresses: You can now deploy new Ingress resources specifying the traefik class to test your new controller, using the temporary ports (8000/8443) for access.

- Verify Traefik DaemonSet manifest: The DaemonSet includes hostPort: 8000, and hostPort: 8443.

- There is a new ingressClass with name “rke2-ingress-nginx-migration”.

- Verify that the Ingressnginx provider is started. In the traefik logs:
    ```
    INF Starting provider *ingressnginx.Provider
    ```

## Phase 2: Parallel migration and validation

The goal is to validate that Traefik can correctly handle traffic and NGINX annotations by processing duplicated Ingress resources.

:::caution Rancher Ingress Warning
RKE2 clusters with Rancher installed include the Rancher Ingress resource. Please see SUSE Rancher Support for guidance on specific steps to migrate the Rancher Ingress resource.
:::

#### 1. Duplicate and reclassify Ingresses
For every critical Ingress resource (currently using `ingressClassName: nginx`), create a copy of the manifest with only one change: set the class name to `rke2-ingress-nginx-migration`.

Apply these new, duplicated Ingress manifests. 

You can use the script below as a suggested way to achieve this.

<details>
<summary>Ingress duplication script</summary>
```
#!/bin/bash
# This script duplicates all Ingress resources that currently use 'ingress-nginx',
# assigns the duplicate a new name, changes the ingressClassName to 'rke2-ingress-nginx-migration',
# and applies the new resource to the cluster.

echo "Starting automated Ingress duplication and reclassification..."

# Use kubectl to get all Ingresses that use the 'ingress-nginx' class.
# Use 'jq' to process the JSON output for modification.
kubectl get ingress --all-namespaces -o json | \
jq -c '.items[] | select(.spec.ingressClassName == "nginx")' | \
while read -r INGRESS; do
    
    # 1. Extract Name and Namespace for logging
    NS=$(echo "$INGRESS" | jq -r '.metadata.namespace')
    NAME=$(echo "$INGRESS" | jq -r '.metadata.name')
    NEW_NAME="${NAME}-traefik"

    echo "Processing Ingress: $NS/$NAME"

    # 2. Modify the Ingress object using jq
    #    - Remove 'status' (read-only field)
    #    - Remove system-generated fields like 'resourceVersion', 'uid', 'creationTimestamp', etc.
    #    - Rename the object by appending '-traefik'
    #    - Change 'ingressClassName' from 'nginx' to 'rke2-ingress-nginx-migration'
    MODIFIED_INGRESS=$(echo "$INGRESS" | jq \
        'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"], .status, .metadata.managedFields)' | \
        jq --arg NEW_NAME "$NEW_NAME" '.metadata.name = $NEW_NAME | .spec.ingressClassName = "rke2-ingress-nginx-migration"')

    # 3. Apply the modified (duplicated) Ingress resource
    echo "$MODIFIED_INGRESS" | kubectl apply -f -
    echo "  -> Created duplicate Ingress: $NS/$NEW_NAME"
done

echo "Ingress duplication complete."
```
</details>

#### 2. Test services via both controllers

Your services should now be accessible via two separate routes (hostPorts):

- Ingress NGINX access: `http://<Node_IP>` (ports 80/443)

- Traefik access: `http://<Node_IP>:8000` (ports 8000/8443)

Note that Traefik provides also a ClusterIP service by default.

Thoroughly test all services accessed via the Traefik port (8000/8443), ensuring all Nginx-specific features (annotations) are handled correctly by Traefik's compatibility layer.

#### 3. (Optional) Configure external load balancer
If you use an external load balancer (LB) to route traffic to your Kubernetes cluster, add Traefik as a backend using the Traefik node route (http://&lt;Node_IP&gt;:8000).

Refer to the [Traefik Migration Guide](https://doc.traefik.io/traefik/migrate/nginx-to-traefik/#step-3-shift-traffic-to-traefik) for either DNS-Based migration or External Load Balancer with Weighted Traffic strategies. Take into account that the guide expects both ingresses to include a service with a LoadBalancer address but this guide is assuming node ports are used

:::important Health Check!
Ingress NGINX and Traefik use different health check endpoints. Ensure your LB configuration is updated accordingly:
- Ingress NGINX: `/healthz`
- Traefik: `/ping`
:::

## Phase 3: Final switchover and port reassignment 

Once validation is complete, you will uninstall Ingress NGINX and switch Traefik to the standard ports. Note that uninstalling Ingress NGINX might take a while because of how Kubernetes handles the teardown of resources and webhooks. If downtime is very important for you, you should consider splitting this phase in two: first uninstall Ingress NGINX while keeping Traefik listening on the 8000/8443 ports and then, once Ingress NGINX is removed, change Traefik ports.

#### 1. Uninstall Ingress NGINX
Edit the RKE2 server configuration file (`/etc/rancher/rke2/config.yaml`) to set Traefik as the only Ingress Controller:

```
# /etc/rancher/rke2/config.yaml
ingress-controller: 
- traefik
```

If downtime is important and you’d like to split this phase, you should restart RKE2 at this point and don’t move to the next step (configure Traefik for Standard Ports) until Ingress NGINX is completely removed.

#### 2. Configure Traefik for Standard Ports
Update the HelmChartConfig manifest (`/var/lib/rancher/rke2/server/manifests/rke2-traefik-config.yaml`) to remove the custom port configuration.
```
# rke2-traefik-config.yaml

apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
    name: rke2-traefik
    namespace: kube-system
spec:
    valuesContent: |-
    providers:
        kubernetesIngressNginx:
        enabled: true
        ingressClass: "rke2-ingress-nginx-migration"
        controllerClass: "rke2.​cattle.​io/ingress-nginx-migration"
```

#### 3. Restart RKE2
Restart the rke2-server service in all CP nodes:
```
sudo systemctl restart rke2-server
```

After a few seconds, helm-controller will detect the new configurations for both Ingress NGINX controller (remove) and Traefik (redeploy).

#### 4. Final verification on standard ports
Verify that the Ingress NGINX DaemonSet is gone.

Verify that your services are now accessible via the duplicated Traefik Ingresses on the standard ports (80/443).

 

## Phase 4: Cleanup 

#### 1. Remove Ingress NGINX Objects
Delete the legacy Ingress objects that were bound to `ingressClassName: nginx`. For example, you can use the following script which removes all ingress objects which do not include the word traefik in their class

```
kubectl get ingress --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ICLASS:.spec.ingressClassName' --no-headers | awk '$3 == "nginx" {print; exit}' | while read NS NAME ICLASS; do
    echo "Deleting legacy Ingress: $NS/$NAME"
    kubectl delete ingress "$NAME" -n "$NS"
done
```

## Additional Notes

- By default the Ingress NGINX provider reads ingressClassName = nginx. We decided to change this and use a “bridge” ingressClass (rke2-ingress-nginx-migration) to avoid two problems:

    1 - Potential race conditions as both ingress controllers would read the same ingress resource and could try to update the status at the same time.

    2 - The ingressClass nginx gets removed automatically when Ingress NGINX is uninstalled in Phase 3.

- Ingress NGINX might take a long time to be removed.