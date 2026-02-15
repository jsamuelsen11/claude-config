# Plugin: ccfg-kubernetes

The Kubernetes infrastructure plugin. Provides manifest design, Helm chart engineering, and
deployment strategy agents, configuration validation, project scaffolding, and opinionated
conventions for consistent Kubernetes development. Focuses on manifest best practices, resource
management, security contexts, Helm patterns, and zero-downtime deployments. Safety is paramount —
never deploys to clusters or interacts with the Kubernetes API without explicit user confirmation.

## Directory Structure

```text
plugins/ccfg-kubernetes/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── k8s-specialist.md
│   ├── helm-engineer.md
│   └── deployment-strategist.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── k8s-conventions/
    │   └── SKILL.md
    ├── helm-patterns/
    │   └── SKILL.md
    └── deployment-patterns/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-kubernetes",
  "description": "Kubernetes infrastructure plugin: manifest design, Helm chart engineering, deployment strategy agents, configuration validation, project scaffolding, and conventions for consistent K8s development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": [
    "kubernetes",
    "k8s",
    "helm",
    "kustomize",
    "deployment",
    "manifest",
    "container-orchestration"
  ],
  "suggestedPermissions": {
    "allow": [
      "Bash(kubectl get:*)",
      "Bash(kubectl describe:*)",
      "Bash(kubectl logs:*)",
      "Bash(helm list:*)",
      "Bash(helm template:*)"
    ]
  }
}
```

## Agents (3)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                   | Role                                                                                              | Model  |
| ----------------------- | ------------------------------------------------------------------------------------------------- | ------ |
| `k8s-specialist`        | Kubernetes 1.28+, manifests, resource management, security contexts, RBAC, namespaces, networking | sonnet |
| `helm-engineer`         | Helm 3 charts, values.yaml design, Go templates, chart dependencies, hooks, chart testing         | sonnet |
| `deployment-strategist` | Rollout strategies, HPA/VPA, PDB, liveness/readiness/startup probes, observability                | sonnet |

No coverage command — coverage is a code concept, not an infrastructure concept. This is intentional
and differs from language plugins.

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-kubernetes:validate

**Purpose**: Run the full Kubernetes configuration quality gate suite in one command.

**Trigger**: User invokes before applying manifests or reviewing cluster configuration changes.

**Allowed tools**:
`Bash(kubeconform *), Bash(kubeval *), Bash(helm lint *), Bash(kube-linter *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Manifest syntax**: kubeconform or kubeval-aware if available (prefer kubeconform — actively
   maintained, supports CRDs); otherwise YAML structure validation — API version correctness
   (`apps/v1` not `extensions/v1beta1`), required fields (`metadata.name`, `metadata.labels`),
   selector consistency between Deployment and Service, valid container image references
2. **Resource management**: all containers must have `resources.requests` and `resources.limits`
   set. CPU/memory limits must be reasonable (flag `0`, unreasonably high values, or missing
   limits). Flag missing `ResourceQuota` and `LimitRange` on namespace definitions. For
   Deployment/StatefulSet workloads, flag missing liveness/readiness probes as WARN. For workloads
   with replicas > 1, flag missing PodDisruptionBudget as WARN. For workloads with variable load
   patterns, suggest HPA consideration (advisory only, not a gate)
3. **Security context**: `runAsNonRoot: true`, `readOnlyRootFilesystem: true` where practical,
   `allowPrivilegeEscalation: false`, dropped capabilities (`drop: ["ALL"]` + specific adds). Flag
   `privileged: true` containers. Verify `securityContext` set at both pod and container level
4. **Helm lint**: if Helm charts detected, run `helm lint` (if available) or validate `Chart.yaml`
   required fields, `values.yaml` structure, template syntax, no hardcoded values in templates
5. **Labels and annotations**: required labels present (`app.kubernetes.io/name`,
   `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`, `app.kubernetes.io/component`),
   consistent labeling across related resources (Deployment, Service, ConfigMap all share same app
   label)
6. **Policy-as-code** (detect-and-skip): if kube-linter, polaris, or conftest is available, run
   policy checks against manifests. Common rules: no containers running as root, no default
   namespace usage, no host network/PID, resource limits present. If no policy tool is available,
   skip this gate entirely and report as SKIPPED — advisory only, never a hard fail
7. Report pass/fail for each gate with output
8. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Manifest syntax**: Same as full mode (YAML and API version validation)
2. **Resource limits**: Presence check only (are requests/limits set?)
3. Report pass/fail — skips security context, Helm lint, and label checks for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — Kubernetes manifests, Helm charts, and kustomize overlays.
  Does not connect to a Kubernetes cluster by default. Live checks (cluster state, deployed
  resources, API server validation) require the `--live` flag and explicit user confirmation before
  any connection
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available (e.g., kubeval not installed,
  helm not available), skip that gate and report it as SKIPPED. Suggest installing the missing tool
- kubeval/kubeconform/helm lint detection: if available, invoke and parse output; if missing, use
  built-in heuristic checks and suggest installation
- Optional tooling (detect-and-skip): kubeval or kubeconform (manifest validation), helm lint (chart
  validation), kube-linter or polaris (policy-as-code). If not installed, use heuristic checks for
  the corresponding gate and suggest the missing tool in output
- Checks for presence of conventions document (`docs/infra/kubernetes-conventions.md` or similar).
  Reports SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-kubernetes:scaffold

**Purpose**: Initialize Kubernetes manifests, Helm charts, or kustomize configurations for projects.

**Trigger**: User invokes when setting up Kubernetes configuration in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=manifest|helm-chart|kustomize]`

**Behavior**:

**manifest** (default):

1. Detect application type from project files (web service, background worker, cron job)
2. Generate Deployment + Service + ConfigMap/Secret stubs + Ingress (if web-facing)
3. Include resource requests/limits, security context, liveness/readiness probes,
   PodDisruptionBudget
4. Use namespace-scoped resources with explicit namespace
5. Include standard labels (`app.kubernetes.io/*` taxonomy)

**helm-chart**:

1. Generate Helm chart scaffold:

   ```text
   charts/<name>/
   ├── Chart.yaml
   ├── values.yaml
   ├── templates/
   │   ├── _helpers.tpl
   │   ├── deployment.yaml
   │   ├── service.yaml
   │   ├── ingress.yaml
   │   ├── configmap.yaml
   │   ├── serviceaccount.yaml
   │   └── hpa.yaml
   └── .helmignore
   ```

2. `values.yaml` with sensible defaults, documented sections, environment override pattern
3. Templates use standard Helm conventions (fullname helper, labels helper, selector labels)
4. Include `.helmignore` (exclude `.git`, tests, documentation)

**kustomize**:

1. Generate kustomize base + overlays structure:

   ```text
   k8s/
   ├── base/
   │   ├── kustomization.yaml
   │   ├── deployment.yaml
   │   └── service.yaml
   └── overlays/
       ├── dev/
       │   └── kustomization.yaml
       └── prod/
           └── kustomization.yaml
   ```

2. Base contains common resources with default configuration
3. Overlays use patches for per-environment differences (replica count, resource limits, image tags)

**Key rules**:

- Application type detection is best-effort — never prescribe an architecture
- Generated manifests include security context and resource limits by default
- Never includes real secrets — uses placeholder values or references to Secret/ExternalSecret
  objects
- Helm charts follow standard naming conventions (chart name helper, labels helper)
- If inside a git repo, ensure the output directory exists
- Scaffold recommends creating a conventions document at `docs/infra/kubernetes-conventions.md`. If
  the project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### k8s-conventions

**Trigger description**: "This skill should be used when working with Kubernetes manifests,
designing deployments, configuring services, or reviewing cluster configuration."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses specific label patterns, namespace strategies, or manifest organization, follow them.
If the project uses kustomize instead of Helm (or vice versa), work within that tool's patterns.
These preferences apply to new manifests and scaffold output only.

**Manifest structure rules**:

- API version: always use the stable API version (`apps/v1`, `networking.k8s.io/v1`), never
  beta/alpha versions in production
- Metadata: every resource must have `metadata.name`, `metadata.namespace` (except cluster-scoped),
  and `metadata.labels`
- Label taxonomy: use `app.kubernetes.io/*` labels — `name`, `version`, `component`, `part-of`,
  `managed-by`. Custom labels use org prefix (`mycompany.io/team`)
- Annotation patterns: `description` for human context, tool-specific annotations with tool prefix
- Validation tooling: prefer kubeconform over kubeval for offline manifest validation (actively
  maintained, CRD support). Use `--strict` mode to catch unknown fields

**Resource management rules**:

- Always set `resources.requests` and `resources.limits` on every container
- CPU in millicores (`100m` = 0.1 CPU), memory in `Mi`/`Gi` (binary units, not `M`/`G`)
- QoS classes: Guaranteed (requests == limits), Burstable (requests < limits), BestEffort (no
  requests/limits). Prefer Guaranteed for production workloads
- Set `ResourceQuota` and `LimitRange` on all namespaces to prevent resource exhaustion
- Start with conservative limits, right-size based on VPA recommendations

**Security rules**:

- Pod security standards: use `restricted` profile in production namespaces
- `securityContext` at both pod level (`runAsNonRoot: true`, `fsGroup`) and container level
  (`allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`)
- RBAC: least privilege, one `ServiceAccount` per workload, avoid `cluster-admin` binding
- `NetworkPolicy`: default-deny ingress on all namespaces, allow specific traffic patterns
- Never mount service account tokens unless needed (`automountServiceAccountToken: false`)

**Namespace rules**:

- Per-environment (`dev`, `staging`, `prod`) or per-team — choose one pattern and be consistent
- `ResourceQuota` and `LimitRange` on every namespace
- Label namespaces for pod security admission (`pod-security.kubernetes.io/enforce: restricted`)

### helm-patterns

**Trigger description**: "This skill should be used when designing Helm charts, writing values.yaml,
creating templates, managing chart dependencies, or testing Helm releases."

**Contents**:

- **Chart structure**: `Chart.yaml` must include `apiVersion: v2`, `name`, `version` (chart
  version), `appVersion` (application version), `description`. Use `type: application` (default) or
  `type: library` for shared helpers
- **Values design**: `values.yaml` is the chart's public API — document every value with comments.
  Prefer flat structure over deeply nested (`replicaCount: 3` over `deployment.replicas: 3`).
  Provide sensible defaults that work out-of-the-box. Use environment override files
  (`values-dev.yaml`, `values-prod.yaml`) for per-environment configuration
- **Template patterns**: use `_helpers.tpl` for reusable template functions (fullname, labels,
  selector labels). Use `{{ include }}` over `{{ template }}` (include captures output for piping).
  Use `{{- if .Values.ingress.enabled }}` for conditional resources. Use
  `{{ toYaml .Values.resources | nindent 12 }}` for structured value injection
- **Chart testing**: `helm template` for local rendering validation. `helm lint` for chart structure
  validation. `ct` (chart-testing) for PR-based chart testing. `helm test` for post-install
  validation hooks
- **Dependencies**: declare in `Chart.yaml` `dependencies:` block. Use `condition:` for optional
  dependencies (`redis.enabled`). Use `alias:` for multiple instances of same chart. Run
  `helm dependency update` to manage lock file

### deployment-patterns

**Trigger description**: "This skill should be used when implementing deployment strategies,
configuring autoscaling, setting up probes, managing disruption budgets, or designing zero-downtime
deployments."

**Contents**:

- **Rollout strategies**: `RollingUpdate` (default) — set `maxSurge: 25%` and `maxUnavailable: 0`
  for zero-downtime, increase `maxSurge` for faster rollouts. `Recreate` — for stateful workloads
  needing exclusive access (databases, file locks). Use `kubectl rollout status` to monitor,
  `kubectl rollout undo` to rollback
- **Probes**: liveness (restart container on failure — use for deadlock detection), readiness
  (remove from Service endpoints — use for startup and overload), startup (delay liveness/readiness
  — use for slow-starting containers). Use HTTP probes for web services, TCP for ports, exec for
  custom checks. Set `initialDelaySeconds` (10-30s), `periodSeconds` (10s), `failureThreshold` (3)
  thoughtfully — too aggressive causes flapping
- **Autoscaling**: HPA on CPU/memory for reactive scaling (set target utilization 70-80%). VPA in
  recommend-only mode for right-sizing insights (don't auto-apply in production). KEDA for
  event-driven scaling (queue depth, custom metrics). Don't use HPA and VPA on the same metric
- **Disruption management**: `PodDisruptionBudget` on all production workloads — `minAvailable: 1`
  or `maxUnavailable: 1` (choose based on replica count). Topology spread constraints
  (`topologySpreadConstraints`) for zone/node distribution. `podAntiAffinity` to spread replicas
  across failure domains
- **Zero-downtime deployments**: `preStop` lifecycle hook with sleep (allow LB to drain:
  `sleep 15`). Set `terminationGracePeriodSeconds` to match application drain time (default 30s,
  increase for long-running requests). Readiness probe must fail before pod receives SIGTERM. Use
  `maxUnavailable: 0` in rolling update strategy
