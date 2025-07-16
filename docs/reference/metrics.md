---
title: Metrics
---

import Label from '@site/src/components/Label';

RKE2 provides metrics for monitoring the health and performance of the cluster.

## Accessing Metrics

Metrics are exposed by the kubelet and can be accessed via the `/metrics` endpoint on each node at port `9345`

```sh
kubectl get --server https://192.168.0.192:9345 --raw /metrics
```

## List of Metrics

Most of the exposed metrics are upstream Kubernetes metrics, see the [Kubernetes Metrics documentation](https://kubernetes.io/docs/reference/instrumentation/metrics//) for more information.


### rke2_loadbalancer_server_connections

Count of current connections to loadbalancer server.
- Type: Gauge
- Labels: <Label>name</Label> <Label>server</Label>

### rke2_loadbalancer_server_health

Current health value of loadbalancer server. A value of 1 indicates healthy, 0 indicates unhealthy.
- Type: Gauge
- Labels: <Label>name</Label> <Label>server</Label>

### rke2_loadbalancer_dial_duration_seconds

A histogram of the time taken to dial a connection to a backend server.
- Type: Histogram
- Labels: <Label>name</Label> <Label>status</Label>

### rke2_certificate_expiration_seconds

Remaining lifetime on the certificate.
- Type: Gauge
- Labels: <Label>subject</Label> <Label>usage</Label>

### rke2_etcd_snapshot_save_duration_seconds

Total time taken to complete the etcd snapshot process.
- Type: Histrogram
- Labels: <Label>status</Label>

### rke2_etcd_snapshot_save_local_duration_seconds

Total time taken to save a local snapshot file.
- Type: Histrogram
- Labels: <Label>status</Label>

### rke2_etcd_snapshot_save_s3_duration_seconds

Total time taken to upload a snapshot file to S3.
- Type: Histrogram
- Labels: <Label>status</Label>

### rke2_etcd_snapshot_reconcile_duration_seconds

Total time taken to sync the list of etcd snapshots.
- Type: Histrogram
- Labels: <Label>status</Label>

### rke2_etcd_snapshot_reconcile_local_duration_seconds

Total time taken to list local snapshot files.
- Type: Histrogram
- Labels: <Label>status</Label>

### rke2_etcd_snapshot_reconcile_s3_duration_seconds

Total time taken to list S3 snapshot files.
- Type: Histrogram
- Labels: <Label>status</Label>