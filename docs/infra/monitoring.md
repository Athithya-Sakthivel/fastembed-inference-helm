# Monitoring

This chart exposes metrics from all services (`dense`, `sparse`, `reranker`) via `/metrics`.

## Configuration

```yaml
monitoring:
  enabled: true
  mode: static   # static | servicemonitor

  serviceMonitor:
    interval: 30s
    scrapeTimeout: 10s
    path: /metrics
```
---

## Modes

### static

* No Prometheus Operator required
* Prometheus must be configured with manual scrape jobs
* Uses DNS-based service discovery

### servicemonitor

* Requires Prometheus Operator (ServiceMonitor CRD)
* Scraping is automatically handled by Prometheus

---

## Static Prometheus scrape job. Namespace `fastembed` may vary

Use this when `mode: static`:

```yaml
scrape_configs:
  - job_name: fastembed-dense
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets: ["rag-dense-model.fastembed.svc.cluster.local:8200"]

  - job_name: fastembed-sparse
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets: ["rag-sparse-model.fastembed.svc.cluster.local:8201"]

  - job_name: fastembed-reranker
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets: ["rag-reranker-model.fastembed.svc.cluster.local:8202"]
```

---

## Selection rule

* Use `static` for simplicity and maximum compatibility
* Use `servicemonitor` when Prometheus Operator is available
