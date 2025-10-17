---
title: CNCF AI Conformance
---

The [CNCF Kubernetes AI Conformance](https://docs.google.com/document/d/1hXoSdh9FEs13Yde8DivCYjjXyxa7j4J8erjZPEGWuzc/edit?tab=t.0) defines a set of additional capabilities, APIs, and configurations that a Kubernetes cluster MUST offer, on top of standard CNCF Kubernetes Conformance, to reliably and efficiently run AI/ML workloads.

This document demonstrates how some of these requirements can be met. For the rest, please refer to the SUSE AI document (TBD).

## Support Dynamic Resource Allocation (DRA) ##

[DRA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) is a new API that enables more flexible and fine-grained resource requests beyond simple counts.

It is GA since v1.34. The requirement states that it must be possible to verify that all the resource.k8s.io/v1 DRA API resources are enabled. This can be done by running:

```bash
kubectl api-resources --api-group=resource.k8s.io
```

The output should be:
```yaml
NAME                     SHORTNAMES   APIVERSION           NAMESPACED   KIND
deviceclasses                         resource.k8s.io/v1   false        DeviceClass
resourceclaims                        resource.k8s.io/v1   true         ResourceClaim
resourceclaimtemplates                resource.k8s.io/v1   true         ResourceClaimTemplate
resourceslices                        resource.k8s.io/v1   false        ResourceSlice
```

## Support the Gateway API ##

[Gateway API](https://gateway-api.sigs.k8s.io/) represents the next generation of Kubernetes ingress, load balancing and service mesh APIs.

To enable the Gateway API in RKE2, we must deploy with Traefik and enable its KuberneteGateway provider as explained in the [Ingress Controller docs](../networking/networking_services.md#ingress-controller)

The requirement states that it must be possible to verify that all the gateway.networking.k8s.io/v1 Gateway API resources are enabled. This can be done by running:

```bash
kubectl api-resources --api-group=gateway.networking.k8s.io/v1
```

The output should be:
```yaml
NAME              SHORTNAMES   APIVERSION                          NAMESPACED   KIND
gatewayclasses    gc           gateway.networking.k8s.io/v1        false        GatewayClass
gateways          gtw          gateway.networking.k8s.io/v1        true         Gateway
grpcroutes                     gateway.networking.k8s.io/v1        true         GRPCRoute
httproutes                     gateway.networking.k8s.io/v1        true         HTTPRoute
referencegrants   refgrant     gateway.networking.k8s.io/v1beta1   true         ReferenceGrant
```

To verify that Traefik is consuming Gateway API resources, you can create a GatewayClass:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: traefik
spec:
  controllerName: traefik.io/gateway-controller
```

Then, if you verify its status:
```yaml
kubectl get gatewayclass traefik -o jsonpath='{.status}'
```
It will say:
```json
"message":"Handled by Traefik controller","observedGeneration":1,"reason":"Handled","status":"True","type":"Accepted"
```

## Cluster autoscaler ##

If the platform provides a cluster autoscaler or an equivalent mechanism, it must be able to scale up/down node groups containing specific accelerator types based on pending pods requesting those accelerators. RKE2 is a Kubernetes distro and thus does not provide a cluster autoscaler. 

For reference, it'd be explained how to use the upstream [autoscaler](https://kubernetes.github.io/autoscaler) with Azure as an example.

1 - Create a [vmss](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview) with VMs that are equipped with GPUs.
2 - Deploy RKE2 with the following options:
```yaml
disable-cloud-controller: true # Only in rke2-server
kubelet-arg: # On both rke2-server and rke2-agent
- --cloud-provider=external
```

3 - Install the Azure CCM:
```bash
helm install --repo https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/helm/repo cloud-provider-azure --generate-name --set cloudControllerManager.imageRepository=mcr.microsoft.com/oss/kubernetes --set cloudControllerManager.imageName=azure-cloud-controller-manager --set cloudNodeManager.imageRepository=mcr.microsoft.com/oss/kubernetes --set cloudNodeManager.imageName=azure-cloud-node-manager --set cloudControllerManager.configureCloudRoutes=false --set cloudControllerManager.allocateNodeCidrs=false
```

4 - Create a correct `azure.json` and save it under `/etc/kubernetes/azure.json`. Make sure these two config options are present:
```json
  "useManagedIdentityExtension": false,
  "useInstanceMetadata": true
```
If it is correctly deployed, nodes should include a ProviderID. You can check it with:
```bash
kubectl get nodes -o yaml | grep ProviderID
```
This ID is picked from the Metadata of the instance. This can be checked with:
```bash
curl -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
```

5 - Install the upstream autoscaler. Firstly, create a correct values.yaml where we specify the vmss created in step 1 and other azure details. Then:
```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
helm install cluster-autoscaler autoscaler/cluster-autoscaler -f values.yaml
```
6 - If everything is correctly deployed, the autoscaler will detect if there is a pod requesting a GPU resource. If the cluster is unable to provide it, autoscaler will contact Azure and a new node with a GPU will be automatically created and added to the cluster.

## Horizontal pod autoscaler ##

This includes the ability to scale these Pods based on custom metrics relevant to AI/ML workloads. For that we use the [HorizontalPodAutoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) included by default in Kubernetes.

We can demonstrate this requirement by installing an ollama deployment in RKE2 and then using this manifest:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ollama-hpa
spec:
  scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: ollama
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Object
    object:
      describedObject:
        apiVersion: v1
        kind: Namespace
        name: suse-private-ai
      metric:
        name: gpu_utilization
      target:
        type: AverageValue
        averageValue: "70"
```

When increasing the load on ollama, the gpu utilization will reach 70 and that will trigger the deployment of new ollama pods. 

## Secure accelerator access ##

We must ensure that access to accelerators from within containers is properly isolated and mediated by the Kubernetes. In order to achieve this, we must install the NVIDIA GPU Operator as described in the [docs](../add-ons/gpu_operators.md#deploy-nvidia-operator).

Once that is done, please verify that the toolkit config under `/usr/local/nvidia/toolkit/.config/nvidia-container-runtime/config.toml` contains:
```yaml
accept-nvidia-visible-devices-as-volume-mounts = true
accept-nvidia-visible-devices-envvar-when-unprivileged = false
```
and the `device-plugin` deamonset includes the envvar:
```yaml
DEVICE_LIST_STRATEGY:        volume-mounts
```

If that is the case, you can verify this requirement by running the following three pods in a cluster with only one GPU:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark1
  namespace: default
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
  - name: cuda-container
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    command: ["/bin/bash", "-c"]
    args: 
      - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
    resources:
      limits:
        nvidia.com/gpu: 1
---
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark2
  namespace: default
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
  - name: cuda-container2
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    command: ["/bin/bash", "-c"]
    args: 
      - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
    resources:
      limits:
        nvidia.com/gpu: 1
---
apiVersion: v1
kind: Pod
metadata:
  name: nbody-gpu-benchmark3
  namespace: default
spec:
  restartPolicy: OnFailure
  runtimeClassName: nvidia
  containers:
  - name: cuda-container3
    image: nvcr.io/nvidia/k8s/cuda-sample:nbody
    command: ["/bin/bash", "-c"]
    args:
      - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
```

The first pod will run correctly and in the logs you will see that it is able to consume the GPU.

The second pod will not be scheduled by Kubernetes because the only GPU available in the cluster is already being consumed by the first pod.

The third pod will run but in the logs you will see that it does not find any GPU available. Therefore, the isolation is working.

