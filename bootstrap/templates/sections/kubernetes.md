## Kubernetes Conventions

- Always set resource requests and limits for CPU and memory
- Use namespaces to isolate workloads
- Liveness and readiness probes on every container
- Never use `latest` tag in manifests — pin image digests or versions
- Store config in ConfigMaps, secrets in Secrets (never hardcoded)
- Use Helm or Kustomize for templating — no raw kubectl apply in CI
- Pod disruption budgets for high-availability workloads
- Labels: `app.kubernetes.io/name`, `app.kubernetes.io/version`
