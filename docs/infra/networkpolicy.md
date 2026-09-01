## Network Policy (Security Model)

This chart enforces **namespace-scoped network isolation** using Kubernetes `NetworkPolicy`.

### Configuration

```yaml
networkPolicy:
  enabled: true
  allowedNamespaces:
    - inference
    - indexing
    - monitoring
    - kube-prometheus-stack
  allowInternetEgress: true
```

---

## What it does (mental model)

Think of each pod as being placed inside a **default-deny network sandbox**:

```
            +----------------------+
            |   Pod (isolated)     |
            |  default DENY ALL    |
            +----------+-----------+
                       |
        +--------------+----------------+
        |                               |
 allowedNamespaces               allowed egress
 (inbound traffic)              (outbound traffic)
```

---

## Ingress rules

Only pods from the following namespaces are allowed to call the service:

* `inference`
* `indexing`
* `monitoring`
* `kube-prometheus-stack`

This is enforced using:

* `namespaceSelector` on `kubernetes.io/metadata.name`

Effect:

* Cross-namespace access is explicitly controlled
* Any namespace not listed is implicitly blocked

---

## Egress rules

### DNS (always allowed)

Pods can resolve DNS via `kube-dns`.

### Internet access (configurable)

```yaml
allowInternetEgress: true
```

When enabled:

* Outbound traffic to `0.0.0.0/0` is allowed

Typical use cases:

* HuggingFace model downloads
* External API calls
* Package fetch during cold start

---

## Security posture

| Mode                        | Behavior                                           |
| --------------------------- | -------------------------------------------------- |
| `enabled: false`            | No network isolation (cluster default rules apply) |
| `enabled: true`             | Default-deny + explicit allow rules                |
| `allowInternetEgress: true` | Controlled external connectivity enabled           |

---

## Operational notes

* Requires Kubernetes NetworkPolicy support (CNI-dependent)
* Does not work without a NetworkPolicy-capable CNI (e.g., Calico, Cilium)
* Namespace allow-list is the primary access control boundary
* ServiceAccounts are NOT used for network enforcement here (namespace-scoped model)

---

## Recommendation

For production:

* Keep `enabled: true`
* Minimize `allowedNamespaces`
* Set `allowInternetEgress: false` if models are pre-cached or mirrored internally
