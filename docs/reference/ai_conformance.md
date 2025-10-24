---
title: CNCF AI Conformance
---

The [CNCF Kubernetes AI Conformance](https://docs.google.com/document/d/1hXoSdh9FEs13Yde8DivCYjjXyxa7j4J8erjZPEGWuzc/edit?tab=t.0) defines a set of additional capabilities, APIs, and configurations that a Kubernetes cluster MUST offer, on top of standard CNCF Kubernetes Conformance, to reliably and efficiently run AI/ML workloads.

This document demonstrates how these requirements can be met using RKE2 v1.34.1+rke2r1.

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

## Gang Scheduling ##

A gang scheduling solution, that ensures all-or-nothing scheduling for distributed AI workloads, must be possible to install (e.g. Kueue or Volcano).

We will install Volcano in RKE2 and make a quick test:
```bash
helm repo add volcano-sh https://volcano-sh.github.io/helm-charts
helm repo update
helm install volcano volcano-sh/volcano -n volcano-system --create-namespace
```
That should install three deployments in the volcano-system namespace:
```
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/volcano-admission     1/1     1            1           130m
deployment.apps/volcano-controllers   1/1     1            1           130m
deployment.apps/volcano-scheduler     1/1     1            1           130m
```

This is enough evidence for the requirement, however, let's test if it is working correctly. In a cluster with two GPUs, we can create a gang job with two tasks which require an nvidia GPU:

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: gpu-nbody-gang-job
  namespace: default
spec:
  minAvailable: 2 
  schedulerName: volcano
  
  tasks:
    - name: nbody-task-1
      replicas: 1
      template:
        spec:
          restartPolicy: OnFailure
          runtimeClassName: nvidia 
          containers:
            - name: cuda-container-1
              image: nvcr.io/nvidia/k8s/cuda-sample:nbody
              command: ["/bin/bash", "-c"]
              args:  
                - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
              resources:
                limits:
                  nvidia.com/gpu: 1
    
    - name: nbody-task-2
      replicas: 1
      template:
        spec:
          restartPolicy: OnFailure
          runtimeClassName: nvidia
          containers:
            - name: cuda-container-2
              image: nvcr.io/nvidia/k8s/cuda-sample:nbody
              command: ["/bin/bash", "-c"]
              args:  
                - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
              resources:
                limits:
                  nvidia.com/gpu: 1
```

After a few seconds, we should see both pods running. 

If we start again and now modify the manifest and use: `minAvailable: 3` add a third task:
```yaml
    - name: nbody-task-3
      replicas: 1
      template:
        spec:
          restartPolicy: OnFailure
          runtimeClassName: nvidia
          containers:
            - name: cuda-container-3
              image: nvcr.io/nvidia/k8s/cuda-sample:nbody
              command: ["/bin/bash", "-c"]
              args:  
                - "while true; do sleep 5 && cuda-samples/nbody -gpu -benchmark; done"
              resources:
                limits:
                  nvidia.com/gpu: 1
```

We'll see that the three pods will not run with STATUS Pending:
```bash
default          gpu-nbody-gang-job-nbody-task-1-0                             0/1     Pending     0          50s 
default          gpu-nbody-gang-job-nbody-task-2-0                             0/1     Pending     0          50s
default          gpu-nbody-gang-job-nbody-task-3-0                             0/1     Pending     0          50s
```

Demonstrating that gang scheduling is working as expected.


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

## Accelerator Performance Metrics ##

The requirement states that it must be possible to allow for the installation and successful operation of at least one accelerator metrics solution that exposes fine-grained performance metrics via a standardized, machine-readable metrics endpoint. This must include a core set of metrics for per-accelerator utilization and memory usage.

If the NVIDIA GPU operator is installed as described in the [docs](../add-ons/gpu_operators.md#deploy-nvidia-operator), a daemonset with the name `nvidia-dcgm-exporter` is deployed together with the service `nvidia-dcgm-exporter`. We can query this service to collect the required GPU metrics: accelerator utilization, memory usage, temperature, power usage, etc.

From within the cluster, for example if we ssh into one cluster node:

```bash
# Get the clusterIP
svcIP=$(kubectl get svc nvidia-dcgm-exporter -n gpu-operator -o jsonpath='{.spec.clusterIP}')
# Get the port
svcPort=$(kubectl get svc nvidia-dcgm-exporter -n gpu-operator -o jsonpath='{.spec.ports[0].port}')
# Output the metrics
curl -sL http://${svcIP}:${svcPort}/metrics
```

That will show the metrics exposed using the OpenMetrics text format. In the next section, it is explained how to use Prometheus and Grafana to consume those.


## AI Job & Inference Service Metrics ##

It is required that there is a system which is capable of discovering and collecting metrics from workloads the expose the in a standard format.

We can use Prometheus/Grafana for that. First we install them:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
>   --namespace monitoring \
>   --create-namespace
```

Once everything is running, we must create a ServiceMonitor that will scrape the metrics from any workload. As an example, we will tell Prometheus to collect metrics from the DCGM, a component present in the NVIDIA GPU Operator and described in the previous section:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-monitor
  namespace: monitoring
  labels:
    release: prometheus-stack 
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  namespaceSelector:
    matchNames:
      - gpu-operator
  endpoints:
  - port: gpu-metrics
    path: /metrics
    interval: 15s
```

After a few minutes, the Grafana board will show the DCGM metrics, for example: `DCGM_FI_DEV_GPU_UTIL`.

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


## Robust CRD and Controller Operation ##

The requirement states that at least one complex AI operator with CRD can be installed and functions reliably. To test it, it recommends checking that CRDs are correctly registered and any invalid configuration is rejected by an admission webhook.

We are going to install Kubeflow in RKE2 to verify this requirement.

Unfortunately, kubeflow does not include a helm chart, but there is a workaround we can use to install it:

```bash
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.8.0"
```

After some seconds, everything should be up and running and we should be able to verify that CRDs are installed and the webhook is registered:

```bash
$> kubectl get crds | grep kubeflow
mpijobs.kubeflow.org                                       2025-10-24T13:04:27Z
mxjobs.kubeflow.org                                        2025-10-24T13:04:27Z
paddlejobs.kubeflow.org                                    2025-10-24T13:04:28Z
pytorchjobs.kubeflow.org                                   2025-10-24T13:04:28Z
tfjobs.kubeflow.org                                        2025-10-24T13:04:29Z
xgboostjobs.kubeflow.org                                   2025-10-24T13:04:29Z

$> kubectl get validatingwebhookconfigurations
validator.training-operator.kubeflow.org   5          10m

$> kubectl get pods -n kubeflow
NAME                                READY   STATUS    RESTARTS   AGE
training-operator-f7d4b59f6-vdnh9   1/1     Running   0          9m54s
```

If now we try running a TFJob which is missing a field, for example:
```yaml
# saved as invalid-tfjob.yaml
apiVersion: kubeflow.org/v1
kind: TFJob
metadata:
  name: tfjob-invalid-test
spec:
  tfReplicaSpecs:
    Chief:
      replicas: 1
      template:
        spec:
          containers:
            - name: tensorflow 
              # INTENTIONAL ERROR: Missing the 'image' field
              # image: tensorflow/tensorflow:latest
              # command: ["/bin/bash", "-c"]
              # args: ["echo 'Chief running'; sleep 10;"]
```

We get the expected error from the admission webhook:
```bash
Error from server (Forbidden): error when creating "invalid-tfjob.yaml": admission webhook "validator.tfjob.training-operator.kubeflow.org" denied the request: spec.tfReplicaSpecs[Chief].template.spec.containers[0].image: Required value: must be required
```

If we remove the comments in the previous example and re-try it, we can see how it works

