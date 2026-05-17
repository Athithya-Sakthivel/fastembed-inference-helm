# CUDA Support

## Default mode (CPU)

This chart runs in **CPU mode by default**.

```yaml
global:
  cuda: false
```

All provided images are:

* CPU-only
* Small/quantized model optimized
* No CUDA runtime included

This is intentional for:

* portability across clusters
* lower cost
* simpler ops (no GPU drivers/tooling)

---

## When GPU is used

GPU is only active when **all conditions are met**:

1. `global.cuda: true`
2. service `gpuCount > 0`
3. GPU-enabled node exists
4. GPU-compatible image is used

```yaml
dense:
  gpuCount: 1

reranker:
  gpuCount: 1
```

`sparse` is typically CPU-only.

---

## Important constraint

`gpuCount` alone does nothing.

GPU execution requires:

* CUDA-enabled image
* Kubernetes GPU resources (`nvidia.com/gpu`)
* Matching driver stack

---

## Custom images required

Default images are **not CUDA-enabled**.

To use GPU:

* Build your own image
* Include CUDA runtime + ML backend (PyTorch/ONNX GPU)
* Deploy to GPU nodes

---

## Kubernetes GPU requirement

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

---

## Recommendation

* Keep `cuda: false` for most deployments
* Enable GPU only for:

  * high-throughput reranking
  * large-scale embedding workloads

