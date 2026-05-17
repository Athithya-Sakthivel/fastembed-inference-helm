# FastEmbed Inference Helm Chart

A production-ready Helm chart for deploying a suite of stateless, scalable text embedding and reranking microservices. Built on top of [Qdrant's FastEmbed](https://github.com/qdrant/fastembed) library, this chart provides standard REST APIs for Dense, Sparse, and Reranker models, complete with Prometheus metrics, network policies, and GPU support.

## Overview

This Helm chart packages three independent but related inference services:

| Service  | Description                                      | Default Model                           | Default Port |
| -------- | ------------------------------------------------ | --------------------------------------- | ------------ |
| **Dense**  | Generates dense vector embeddings from text.     | `BAAI/bge-small-en-v1.5`                | `8200`       |
| **Sparse** | Generates sparse vector embeddings for text.     | `Qdrant/minicoil-v1`                 | `8201`       |
| **Reranker** | Re-ranks a list of documents based on a query. | `Xenova/ms-marco-MiniLM-L-6-v2`        | `8202`       |

Each service is deployed as a separate Kubernetes Deployment, exposed via a ClusterIP Service, and can be independently scaled, configured, and enabled or disabled.

## Architecture

```
                 ┌─────────────────────────────────────┐
                 │  Kubernetes Cluster                  │
                 │                                      │
┌──────────┐     │  ┌───────────┐   ┌──────────────┐   │
│ Client/  │────▶│  │  Dense    │   │  Reranker    │   │
│ RAG App  │     │  │  Service  │   │  Service     │   │
└──────────┘     │  │  (8200)   │   │  (8202)      │   │
                 │  └───────────┘   └──────────────┘   │
                 │  ┌───────────┐                       │
                 │  │  Sparse   │                       │
                 │  │  Service  │                       │
                 │  │  (8201)   │                       │
                 │  └───────────┘                       │
                 │                                      │
                 │  ┌──────────────────────────────┐    │
                 │  │ Prometheus Metrics Endpoint  │    │
                 │  │ (/metrics on each service)   │    │
                 │  └──────────────────────────────┘    │
                 └─────────────────────────────────────┘
```

## Prerequisites

- Kubernetes 1.21+
- Helm 3.8+
- (Optional) A CNI plugin that supports `NetworkPolicy` (e.g., Calico, Cilium) if network policies are enabled.
- (Optional) NVIDIA GPU operator and nodes with `nvidia.com/gpu` resources for GPU acceleration.
- (Optional) Prometheus Operator if using `monitoring.mode: servicemonitor`.

## Quick Start

Add the Helm repository and install the chart with default values:

```bash
kubectl create namespace fastembed

export HF_TOKEN=
kubectl create secret generic hf-token \
  --namespace fastembed \
  --from-literal=HF_TOKEN=$HF_TOKEN
  
helm install fastembed ./chart \
  --namespace fastembed \
  --values chart/values.yaml \
  --set global.huggingface.existingSecret=hf-token \
  --set global.networkPolicy.enabled=false \
  --set dense.preloadModel=true \
  --set sparse.preloadModel=true \
  --set reranker.preloadModel=true \
  --wait \
  --timeout 10m
```

This will deploy all three services in CPU-only mode with sensible defaults.

## Configuration

The chart is configured via a single `values.yaml` file. The primary configuration sections are:

### Global Settings

| Parameter                         | Description                                                                 | Default          |
| --------------------------------- | --------------------------------------------------------------------------- | ---------------- |
| `global.createNamespace`          | Create the release namespace if it doesn't exist.                           | `true`           |
| `global.cuda`                     | Master switch for GPU support. Requires GPU-compatible images.              | `false`          |
| `global.monitoring.enabled`       | Master switch to expose Prometheus `/metrics` endpoints on all services.    | `true`           |
| `global.monitoring.mode`          | Scrape mode: `static` (manual Prometheus config) or `servicemonitor` (CRD). | `static`         |
| `global.networkPolicy.enabled`    | Enforce namespace-based network isolation.                                  | `true`           |
| `global.networkPolicy.allowedNamespaces` | List of namespaces allowed to call these services.                    | `[inference, indexing, monitoring, kube-prometheus-stack]` |
| `global.huggingface.existingSecret` | Name of a Kubernetes Secret containing an `HF_TOKEN` for gated models.      | `""`             |

### Service-Specific Settings

Each service (`dense`, `sparse`, `reranker`) can be configured with the following common parameters:

| Parameter             | Description                                                              | Dense Default               | Sparse Default            | Reranker Default               |
| --------------------- | ------------------------------------------------------------------------ | --------------------------- | ------------------------- | ------------------------------ |
| `enabled`             | Enable or disable the service deployment.                                | `true`                      | `true`                    | `true`                         |
| `modelName`           | Model ID from Hugging Face Hub or a local path.                          | `BAAI/bge-small-en-v1.5`    | `Qdrant/minicoil-v1`    | `Xenova/ms-marco-MiniLM-L-6-v2` |
| `batchSize`           | Max number of texts/documents per request.                               | `16`                        | `16`                      | `16`                           |
| `gpuCount`            | Number of `nvidia.com/gpu` resources to request (only when `global.cuda: true`). | `1`                         | `0`                       | `1`                            |
| `port`                | Container HTTP port.                                                     | `8200`                      | `8201`                    | `8202`                         |
| `preloadModel`        | Load the ML model on startup instead of lazily on the first request.     | `false`                     | `false`                   | `true`                         |
| `replicas`            | Number of pods to run when HPA is disabled.                              | `1`                         | `1`                       | `1`                            |
| `hpa.enabled`         | Enable Horizontal Pod Autoscaling based on CPU.                          | `false`                     | `false`                   | `false`                        |
| `hpa.min`/`hpa.max`   | Min/Max replicas for HPA.                                                | `1` / `3`                   | `1` / `3`                 | `1` / `3`                      |
| `hpa.targetCPU`       | Target average CPU utilization for HPA.                                  | `60`                        | `60`                      | `60`                           |
| `pdb.enabled`         | Create a PodDisruptionBudget when `replicas > 1`.                        | `true`                      | `true`                    | `true`                         |

For a full list of all tunable parameters, see the [`values.yaml`](./chart/values.yaml) file.

## Monitoring & Observability

Each service exposes a rich set of Prometheus metrics at the `/metrics` endpoint, including:

- `dense|sparse|reranker_requests_total` - Total requests by status.
- `dense|sparse|reranker_request_duration_seconds` - Request latency histograms.
- `dense|sparse|reranker_requests_in_progress` - Gauge of in-flight requests.
- `dense|sparse|reranker_errors_total` - Error counts by type.

When `global.monitoring.mode: servicemonitor`, a Prometheus Operator `ServiceMonitor` is automatically created to scrape all services. For `static` mode, you must configure your Prometheus instance to scrape the service endpoints manually. See the [monitoring documentation](./docs/infra/monitoring.md) for examples.

## GPU Support

By default, the chart runs on CPU for maximum portability and simplicity. To enable GPU acceleration:

1. Set `global.cuda: true`.
2. Set the desired `gpuCount` on a service (e.g., `reranker.gpuCount: 1`).
3. Provide a **custom CUDA-enabled container image**. The default images are CPU-only.
4. Ensure your Kubernetes nodes have the necessary `nvidia.com/gpu` resources.

The `sparse` service is typically left on CPU. For detailed instructions, see the [CUDA documentation](./docs/infra/cuda.md).

## Network Security

The chart enforces a zero-trust networking model using Kubernetes `NetworkPolicy` resources when `global.networkPolicy.enabled: true`.

- **Default-Deny All**: All ingress to pods is denied by default.
- **Explicit Allowed Ingress**: Only pods in the namespaces listed under `allowedNamespaces` can reach the services.
- **Egress to DNS**: Always allowed.
- **Egress to Internet**: Controlled by `global.networkPolicy.allowInternetEgress`. This is required for Hugging Face model downloads on first use if models are not pre-cached.

See the [network policy documentation](./docs/infra/networkpolicy.md) for a detailed explanation.

## API Endpoints

All services share a common set of management endpoints.

### Dense Service (`:8200`)

- `POST /embed` - Generates dense embeddings for a list of texts.
- `GET /health` - Liveness check. Returns service status and configuration.
- `GET /readyz` - Readiness probe. Returns `200 OK` when the model is loaded and ready.
- `GET /metrics` - Prometheus metrics endpoint.

See the full [dense service documentation](./docs/images/dense.md) for usage examples and supported models.

### Sparse Service (`:8201`)

- `POST /embed` - Generates sparse embeddings (indices and values) for a list of texts.
- `GET /health` - Liveness check.
- `GET /readyz` - Readiness probe.
- `GET /metrics` - Prometheus metrics endpoint.

See the full [sparse service documentation](./docs/images/sparse.md) for usage examples and supported models.

### Reranker Service (`:8202`)

- `POST /rerank` - Re-ranks a list of documents based on a query string. Returns a list of relevance scores.
- `GET /health` - Liveness check.
- `GET /readyz` - Readiness probe.
- `GET /metrics` - Prometheus metrics endpoint.

See the full [reranker service documentation](./docs/images/reranker.md) for usage examples and supported models.

## Example Usage

**Generate embeddings (with `curl`):**
```bash
kubectl port-forward -n fastembed svc/<release-name>-dense-svc 8200:8200
```

Example:

```bash
kubectl port-forward -n fastembed svc/fastembed-dense-svc 8200:8200
```

```bash
curl -X POST http://localhost:8200/embed \
  -H "Content-Type: application/json" \
  -d '{"texts": ["Hello, world!", "Embed me please"]}'
```

**Check service health:**
```bash
curl http://localhost:8200/health
```

**Scrape metrics:**
```bash
curl http://localhost:8200/metrics
```


## Documentation

- **Service Docs**:
  - [Dense Embedding Service](docs/images/dense.md)
  - [Sparse Embedding Service](docs/images/sparse.md)
  - [Reranker Service](docs/images/reranker.md)
- **Infrastructure Docs**:
  - [CUDA / GPU Support](docs/infra/cuda.md)
  - [Monitoring & Metrics](docs/infra/monitoring.md)
  - [Network Policy Security Model](docs/infra/networkpolicy.md)
