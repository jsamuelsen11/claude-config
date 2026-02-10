---
description: >
  Run Kubernetes configuration quality gate suite (manifest syntax, resource management, security
  context, Helm lint, labels, policy-as-code)
argument-hint: '[--quick]'
allowed-tools:
  Bash(kubeconform *), Bash(kubeval *), Bash(helm lint *), Bash(kube-linter *), Bash(git *), Read,
  Grep, Glob
---

# validate

Comprehensive Kubernetes configuration validation suite that runs multiple quality gates against
repository artifacts without requiring cluster access. Validates manifest syntax, resource
management, security contexts, Helm charts, labeling conventions, and optional policy-as-code
checks.

## Usage

```bash
# Run full validation suite
/ccfg-kubernetes validate

# Run quick validation (syntax + resource limits only)
/ccfg-kubernetes validate --quick

# Typical CI/CD integration
/ccfg-kubernetes validate && kubectl apply -f k8s/
```

## Overview

### Full Mode Quality Gates

#### Gate 1: Manifest Syntax Validation

- Detect kubeconform/kubeval availability, use if present
- Fallback to YAML validation + semantic checks
- Verify API version correctness (apps/v1 not extensions/v1beta1)
- Validate required fields (metadata.name, metadata.labels)
- Check selector consistency between Deployment and Service
- Validate container image references
- Verify resource kind existence

#### Gate 2: Resource Management

- All containers MUST have resources.requests and resources.limits
- Flag missing CPU/memory requests as ERROR
- Flag missing CPU/memory limits as ERROR
- Detect unreasonable values (0, negative, >1000 cores, >1Ti memory)
- Check for ResourceQuota/LimitRange in namespaces (WARN if missing)
- Verify probes on Deployments (WARN if missing readinessProbe/livenessProbe)
- Check PodDisruptionBudget for replicas > 1 (WARN if missing)

#### Gate 3: Security Context

- Verify runAsNonRoot: true (container or pod level)
- Check readOnlyRootFilesystem: true
- Validate allowPrivilegeEscalation: false
- Verify capabilities drop ALL
- Flag privileged: true as ERROR
- Check securityContext at both pod and container levels
- Validate ServiceAccount configuration

#### Gate 4: Helm Lint

- Detect Helm charts (Chart.yaml presence)
- Run helm lint if helm binary available
- Fallback to Chart.yaml/values.yaml YAML validation
- Verify template syntax
- Check for required chart metadata
- Validate version constraints

#### Gate 5: Labels and Annotations

- Verify required app.kubernetes.io/\* labels present:
  - app.kubernetes.io/name
  - app.kubernetes.io/instance
  - app.kubernetes.io/version
  - app.kubernetes.io/component
  - app.kubernetes.io/part-of
  - app.kubernetes.io/managed-by
- Check label consistency across related resources
- Validate label value format (DNS subdomain)

#### Gate 6: Policy-as-Code (Detect-and-Skip)

- kube-linter: comprehensive K8s best practices
- polaris: configuration validation
- conftest: OPA policy testing
- Skip gracefully if tools not available
- Report which tools were used/skipped

### Quick Mode

Runs only:

1. Manifest syntax validation
2. Resource limits presence check (not deep validation)

Designed for rapid feedback during development.

## Key Rules

### Repository Artifacts Only

- Never connect to Kubernetes cluster by default
- Validate files in repository only
- No kubectl apply/get/describe commands
- All checks run locally

### Detect-and-Skip Pattern

- Check for tool availability before use
- Skip gracefully with informational message
- Never fail if optional tool missing
- Core validation always runs (YAML parsing, required fields)

### Never Disable Checks

- Never suggest adding validation-skip annotations
- Never recommend disabling security checks
- All failures must be fixed, not suppressed
- Report all issues, let humans decide priority

### Conventions Document

- Check for docs/infra/kubernetes-conventions.md
- Reference it in report if exists
- Suggest creating it if missing
- Align validation with documented standards

### Exit Codes

- 0: All gates passed
- 1: One or more gates failed
- Report summary at end regardless

## Step-by-Step Process

### Phase 1: Discovery and Initialization

#### Step 1.1: Locate Kubernetes Manifests

Discover all Kubernetes YAML files in repository:

```bash
# Find YAML files with Kubernetes API markers
find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  -exec grep -l "apiVersion:" {} \;
```

Alternative using Glob tool:

```text
Pattern: **/*.yaml
Pattern: **/*.yml
Filter: Contains "apiVersion:" (use Grep after Glob)
```

#### Step 1.2: Categorize Files

Separate discovered files into categories:

- Plain manifests: standalone YAML files
- Helm templates: files under templates/ directory
- Kustomize: directories with kustomization.yaml
- CRDs: files with kind: CustomResourceDefinition

```bash
# Check if file is Helm template
if [[ "$file" == */templates/* ]]; then
  category="helm-template"
fi

# Check if directory has kustomization
if [[ -f "$(dirname "$file")/kustomization.yaml" ]]; then
  category="kustomize"
fi
```

#### Step 1.3: Check Tool Availability

Detect validation tools and record availability:

```bash
# Check kubeconform
if command -v kubeconform >/dev/null 2>&1; then
  KUBECONFORM_AVAILABLE=true
  KUBECONFORM_VERSION=$(kubeconform -v 2>&1 | head -1)
fi

# Check kubeval
if command -v kubeval >/dev/null 2>&1; then
  KUBEVAL_AVAILABLE=true
  KUBEVAL_VERSION=$(kubeval --version 2>&1 | head -1)
fi

# Check helm
if command -v helm >/dev/null 2>&1; then
  HELM_AVAILABLE=true
  HELM_VERSION=$(helm version --short 2>&1)
fi

# Check kube-linter
if command -v kube-linter >/dev/null 2>&1; then
  KUBELINTER_AVAILABLE=true
  KUBELINTER_VERSION=$(kube-linter version 2>&1 | grep Version)
fi

# Check polaris
if command -v polaris >/dev/null 2>&1; then
  POLARIS_AVAILABLE=true
fi

# Check conftest
if command -v conftest >/dev/null 2>&1; then
  CONFTEST_AVAILABLE=true
fi
```

#### Step 1.4: Load Conventions

Check for project-specific conventions:

```bash
# Look for conventions document
if [[ -f "docs/infra/kubernetes-conventions.md" ]]; then
  CONVENTIONS_FOUND=true
  # Parse for custom rules (optional)
fi
```

#### Step 1.5: Initialize Tracking

Set up counters for reporting:

```bash
TOTAL_FILES=0
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
GATE1_PASS=0
GATE1_FAIL=0
GATE2_PASS=0
GATE2_FAIL=0
# ... etc for all gates
```

### Phase 2: Gate 1 - Manifest Syntax Validation

#### Step 2.1: Tool-Based Validation

If kubeconform or kubeval available, use them first:

```bash
# Using kubeconform (preferred)
if [[ "$KUBECONFORM_AVAILABLE" == "true" ]]; then
  for file in "${manifest_files[@]}"; do
    if kubeconform -summary -output json "$file" > /tmp/kubeconform-output.json 2>&1; then
      echo "PASS: $file (kubeconform)"
      ((GATE1_PASS++))
    else
      echo "FAIL: $file (kubeconform)"
      cat /tmp/kubeconform-output.json
      ((GATE1_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  done
fi

# Using kubeval (fallback)
if [[ "$KUBEVAL_AVAILABLE" == "true" ]] && [[ "$KUBECONFORM_AVAILABLE" != "true" ]]; then
  for file in "${manifest_files[@]}"; do
    if kubeval --strict "$file" 2>&1 | tee /tmp/kubeval-output.txt; then
      if ! grep -q "invalid" /tmp/kubeval-output.txt; then
        echo "PASS: $file (kubeval)"
        ((GATE1_PASS++))
      else
        echo "FAIL: $file (kubeval)"
        ((GATE1_FAIL++))
        ((TOTAL_ERRORS++))
      fi
    fi
  done
fi
```

#### Step 2.2: Fallback YAML Validation

If no tools available, parse YAML and check semantics:

```bash
# For each manifest file
for file in "${manifest_files[@]}"; do
  # Check YAML syntax with yq or python
  if command -v yq >/dev/null 2>&1; then
    if ! yq eval '.' "$file" >/dev/null 2>&1; then
      echo "ERROR: $file - Invalid YAML syntax"
      ((GATE1_FAIL++))
      ((TOTAL_ERRORS++))
      continue
    fi
  fi

  # Validate required fields present
  if ! grep -q "apiVersion:" "$file"; then
    echo "ERROR: $file - Missing apiVersion"
    ((GATE1_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  if ! grep -q "kind:" "$file"; then
    echo "ERROR: $file - Missing kind"
    ((GATE1_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  if ! grep -q "metadata:" "$file"; then
    echo "ERROR: $file - Missing metadata"
    ((GATE1_FAIL++))
    ((TOTAL_ERRORS++))
  fi
done
```

#### Step 2.3: API Version Validation

Check for deprecated API versions:

```bash
# Detect deprecated APIs
grep -n "apiVersion: extensions/v1beta1" "$file" && \
  echo "ERROR: $file - Deprecated API version extensions/v1beta1, use apps/v1"

grep -n "apiVersion: apps/v1beta1" "$file" && \
  echo "ERROR: $file - Deprecated API version apps/v1beta1, use apps/v1"

grep -n "apiVersion: apps/v1beta2" "$file" && \
  echo "ERROR: $file - Deprecated API version apps/v1beta2, use apps/v1"

# Check for valid current versions
VALID_APIS=("v1" "apps/v1" "batch/v1" "networking.k8s.io/v1" "rbac.authorization.k8s.io/v1")
```

#### Step 2.4: Required Fields Validation

Verify essential fields present:

```bash
# Check metadata.name present
if ! grep -q "^\s*name:" "$file"; then
  echo "ERROR: $file - Missing metadata.name"
  ((TOTAL_ERRORS++))
fi

# Check metadata.labels exists for workloads
if grep -q "kind: Deployment\|kind: StatefulSet\|kind: DaemonSet" "$file"; then
  if ! grep -q "^\s*labels:" "$file"; then
    echo "ERROR: $file - Missing metadata.labels on workload"
    ((TOTAL_ERRORS++))
  fi
fi
```

#### Step 2.5: Selector Consistency

Validate selector matching between resources:

```bash
# For Deployments, check spec.selector.matchLabels matches spec.template.metadata.labels
# This requires YAML parsing - use yq/python/read file

# Example with grep patterns (limited)
if grep -q "kind: Deployment" "$file"; then
  # Extract selector labels and template labels
  # Compare for consistency
  # Flag mismatches as ERROR
  echo "Checking selector consistency in $file..."
fi
```

#### Step 2.6: Image Reference Validation

Check container image references:

```bash
# Look for image: fields
grep -n "^\s*image:" "$file" | while read -r line; do
  image=$(echo "$line" | sed 's/.*image:\s*//' | tr -d '"' | tr -d "'")

  # Check for latest tag (warning)
  if [[ "$image" == *":latest" ]] || [[ "$image" != *:* ]]; then
    echo "WARN: $file:${line%%:*} - Image using :latest or no tag: $image"
    ((TOTAL_WARNINGS++))
  fi

  # Check for valid registry format
  if [[ ! "$image" =~ ^[a-z0-9.\-/:]+$ ]]; then
    echo "ERROR: $file:${line%%:*} - Invalid image reference: $image"
    ((TOTAL_ERRORS++))
  fi
done
```

#### Step 2.7: Multi-Document YAML

Handle files with multiple documents:

```bash
# Split YAML documents (separated by ---)
csplit -s -f /tmp/k8s-doc- "$file" '/^---$/' '{*}' 2>/dev/null || true

# Validate each document separately
for doc in /tmp/k8s-doc-*; do
  if [[ -s "$doc" ]]; then
    # Run validations on each document
    validate_document "$doc"
  fi
done

# Cleanup
rm -f /tmp/k8s-doc-*
```

### Phase 3: Gate 2 - Resource Management

#### Step 3.1: Identify Containers

Find all container definitions in manifests:

```bash
# Use Grep to find files with containers
grep -l "^\s*containers:" **/*.yaml

# For each file, extract container sections
```

#### Step 3.2: Check Resource Requests Presence

Verify every container has resource requests:

```bash
# Parse YAML to check resources.requests
# Pattern to detect missing requests:

# Look for container: section without resources.requests
for file in "${manifest_files[@]}"; do
  # Count containers
  container_count=$(grep -c "^\s*- name:" "$file" | grep -A 10 "containers:" || echo 0)

  # Count resources.requests
  requests_count=$(grep -c "requests:" "$file" || echo 0)

  if [[ $container_count -gt $requests_count ]]; then
    echo "ERROR: $file - Container(s) missing resources.requests"
    ((GATE2_FAIL++))
    ((TOTAL_ERRORS++))
  fi
done
```

#### Step 3.3: Check Resource Limits Presence

Verify every container has resource limits:

```bash
# Similar pattern for limits
for file in "${manifest_files[@]}"; do
  if grep -q "containers:" "$file"; then
    # Check if resources.limits present for each container
    if ! grep -q "limits:" "$file"; then
      echo "ERROR: $file - Container(s) missing resources.limits"
      ((GATE2_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  fi
done
```

#### Step 3.4: Validate Resource Values

Check for unreasonable resource values:

```bash
# Check for 0 or negative values
grep -n "cpu:.*['\"]0['\"]" "$file" && \
  echo "ERROR: $file - CPU value set to 0"

grep -n "memory:.*['\"]0['\"]" "$file" && \
  echo "ERROR: $file - Memory value set to 0"

# Check for unreasonably high values
grep -n "cpu:.*['\"][0-9]\{4,\}" "$file" && \
  echo "WARN: $file - CPU value >1000 cores seems excessive"

grep -n "memory:.*['\"][0-9]\{3,\}Gi" "$file" && \
  echo "WARN: $file - Memory >100Gi seems excessive"

# Check for missing units
grep -n "memory:.*['\"][0-9]\+['\"]$" "$file" && \
  echo "ERROR: $file - Memory value missing unit (Mi/Gi)"
```

#### Step 3.5: Check ResourceQuota

Verify namespaces have ResourceQuota:

```bash
# Find namespace definitions
namespace_files=$(grep -l "kind: Namespace" **/*.yaml)

for ns_file in $namespace_files; do
  ns_name=$(grep "name:" "$ns_file" | head -1 | awk '{print $2}')

  # Look for corresponding ResourceQuota
  if ! grep -r "kind: ResourceQuota" . | grep -q "namespace.*$ns_name"; then
    echo "WARN: Namespace $ns_name missing ResourceQuota definition"
    ((TOTAL_WARNINGS++))
  fi
done
```

#### Step 3.6: Check LimitRange

Verify namespaces have LimitRange:

```bash
# Similar pattern for LimitRange
for ns_file in $namespace_files; do
  ns_name=$(grep "name:" "$ns_file" | head -1 | awk '{print $2}')

  if ! grep -r "kind: LimitRange" . | grep -q "namespace.*$ns_name"; then
    echo "WARN: Namespace $ns_name missing LimitRange definition"
    ((TOTAL_WARNINGS++))
  fi
done
```

#### Step 3.7: Validate Probes

Check for health probes on Deployments:

```bash
# For each Deployment/StatefulSet
for file in $(grep -l "kind: Deployment\|kind: StatefulSet" **/*.yaml); do
  # Check for readinessProbe
  if ! grep -q "readinessProbe:" "$file"; then
    echo "WARN: $file - Missing readinessProbe on Deployment"
    ((TOTAL_WARNINGS++))
  fi

  # Check for livenessProbe
  if ! grep -q "livenessProbe:" "$file"; then
    echo "WARN: $file - Missing livenessProbe on Deployment"
    ((TOTAL_WARNINGS++))
  fi

  # Check for startupProbe (optional but recommended)
  if ! grep -q "startupProbe:" "$file"; then
    echo "INFO: $file - Consider adding startupProbe for slow-starting apps"
  fi
done
```

#### Step 3.8: Check PodDisruptionBudget

Verify PDB for high-availability workloads:

```bash
# For Deployments with replicas > 1
for file in $(grep -l "kind: Deployment" **/*.yaml); do
  replicas=$(grep "replicas:" "$file" | head -1 | awk '{print $2}')

  if [[ "$replicas" -gt 1 ]]; then
    deployment_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')

    # Look for corresponding PDB
    if ! grep -r "kind: PodDisruptionBudget" . | grep -q "$deployment_name"; then
      echo "WARN: Deployment $deployment_name (replicas=$replicas) missing PodDisruptionBudget"
      ((TOTAL_WARNINGS++))
    fi
  fi
done
```

### Phase 4: Gate 3 - Security Context

#### Step 4.1: Check runAsNonRoot

Verify containers/pods run as non-root:

```bash
# Check at pod level
if ! grep -q "runAsNonRoot: true" "$file"; then
  # Check at container level
  if grep -q "containers:" "$file"; then
    container_section=$(sed -n '/containers:/,/^[^ ]/p' "$file")
    if ! echo "$container_section" | grep -q "runAsNonRoot: true"; then
      echo "ERROR: $file - Missing runAsNonRoot: true (pod or container level)"
      ((GATE3_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  fi
fi
```

#### Step 4.2: Check readOnlyRootFilesystem

Verify read-only root filesystem:

```bash
# Check for readOnlyRootFilesystem
if grep -q "containers:" "$file"; then
  if ! grep -q "readOnlyRootFilesystem: true" "$file"; then
    echo "ERROR: $file - Missing readOnlyRootFilesystem: true"
    ((GATE3_FAIL++))
    ((TOTAL_ERRORS++))
  fi
fi
```

#### Step 4.3: Check allowPrivilegeEscalation

Verify privilege escalation disabled:

```bash
# Check for allowPrivilegeEscalation: false
if grep -q "containers:" "$file"; then
  if ! grep -q "allowPrivilegeEscalation: false" "$file"; then
    echo "ERROR: $file - Missing allowPrivilegeEscalation: false"
    ((GATE3_FAIL++))
    ((TOTAL_ERRORS++))
  fi
fi

# Flag if set to true
if grep -q "allowPrivilegeEscalation: true" "$file"; then
  echo "ERROR: $file - allowPrivilegeEscalation set to true (security risk)"
  ((GATE3_FAIL++))
  ((TOTAL_ERRORS++))
fi
```

#### Step 4.4: Check Capabilities

Verify capabilities dropped:

```bash
# Look for capabilities.drop: [ALL]
if grep -q "containers:" "$file"; then
  if ! grep -q "drop:" "$file"; then
    echo "ERROR: $file - Missing capabilities drop"
    ((GATE3_FAIL++))
    ((TOTAL_ERRORS++))
  else
    # Check if ALL is dropped
    if ! grep -A 1 "drop:" "$file" | grep -q "ALL"; then
      echo "WARN: $file - Should drop ALL capabilities"
      ((TOTAL_WARNINGS++))
    fi
  fi
fi

# Check for added capabilities
if grep -q "add:" "$file" | grep -A 2 "capabilities:"; then
  echo "WARN: $file - Capabilities being added, verify necessity"
  ((TOTAL_WARNINGS++))
fi
```

#### Step 4.5: Flag Privileged Containers

Check for privileged mode:

```bash
# Flag privileged: true
if grep -q "privileged: true" "$file"; then
  echo "ERROR: $file - Privileged container detected (major security risk)"
  ((GATE3_FAIL++))
  ((TOTAL_ERRORS++))
fi
```

#### Step 4.6: Verify SecurityContext Hierarchy

Check both pod and container security contexts:

```bash
# Pod-level securityContext
if grep -q "kind: Pod\|kind: Deployment\|kind: StatefulSet" "$file"; then
  if ! grep -q "^\s*securityContext:" "$file"; then
    echo "WARN: $file - Missing pod-level securityContext"
    ((TOTAL_WARNINGS++))
  fi

  # Container-level securityContext
  if ! grep -A 50 "containers:" "$file" | grep -q "securityContext:"; then
    echo "ERROR: $file - Missing container-level securityContext"
    ((GATE3_FAIL++))
    ((TOTAL_ERRORS++))
  fi
fi
```

#### Step 4.7: ServiceAccount Configuration

Verify ServiceAccount settings:

```bash
# Check for automountServiceAccountToken: false
if ! grep -q "automountServiceAccountToken: false" "$file"; then
  if grep -q "kind: Deployment\|kind: StatefulSet\|kind: Pod" "$file"; then
    echo "WARN: $file - Consider setting automountServiceAccountToken: false"
    ((TOTAL_WARNINGS++))
  fi
fi

# Check for explicit ServiceAccount
if grep -q "kind: Deployment\|kind: StatefulSet" "$file"; then
  if ! grep -q "serviceAccountName:" "$file"; then
    echo "INFO: $file - No explicit ServiceAccount specified (will use default)"
  fi
fi
```

#### Step 4.8: Check SELinux/AppArmor/Seccomp

Verify additional security profiles:

```bash
# Check for seccomp profile
if ! grep -q "seccompProfile:" "$file"; then
  echo "INFO: $file - Consider adding seccomp profile"
fi

# Check for AppArmor annotations
if ! grep -q "container.apparmor.security.beta.kubernetes.io" "$file"; then
  echo "INFO: $file - Consider adding AppArmor profile"
fi
```

### Phase 5: Gate 4 - Helm Lint

#### Step 5.1: Detect Helm Charts

Find Helm chart directories:

```bash
# Look for Chart.yaml files
chart_files=$(find . -name "Chart.yaml" -type f)

if [[ -z "$chart_files" ]]; then
  echo "INFO: No Helm charts detected, skipping Gate 4"
  GATE4_SKIP=true
fi
```

#### Step 5.2: Run Helm Lint

If Helm available, run helm lint:

```bash
if [[ "$HELM_AVAILABLE" == "true" ]]; then
  for chart_file in $chart_files; do
    chart_dir=$(dirname "$chart_file")

    echo "Running helm lint on $chart_dir..."
    if helm lint "$chart_dir" --strict > /tmp/helm-lint-output.txt 2>&1; then
      echo "PASS: $chart_dir (helm lint)"
      ((GATE4_PASS++))
    else
      echo "FAIL: $chart_dir (helm lint)"
      cat /tmp/helm-lint-output.txt
      ((GATE4_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  done
else
  echo "INFO: helm not available, falling back to manual validation"
fi
```

#### Step 5.3: Fallback Chart Validation

If helm not available, validate manually:

```bash
for chart_file in $chart_files; do
  chart_dir=$(dirname "$chart_file")

  # Validate Chart.yaml
  if ! grep -q "^apiVersion:" "$chart_file"; then
    echo "ERROR: $chart_file - Missing apiVersion"
    ((GATE4_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  if ! grep -q "^name:" "$chart_file"; then
    echo "ERROR: $chart_file - Missing name"
    ((GATE4_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  if ! grep -q "^version:" "$chart_file"; then
    echo "ERROR: $chart_file - Missing version"
    ((GATE4_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  # Check for values.yaml
  if [[ ! -f "$chart_dir/values.yaml" ]]; then
    echo "WARN: $chart_dir - Missing values.yaml"
    ((TOTAL_WARNINGS++))
  fi

  # Check for templates directory
  if [[ ! -d "$chart_dir/templates" ]]; then
    echo "ERROR: $chart_dir - Missing templates/ directory"
    ((GATE4_FAIL++))
    ((TOTAL_ERRORS++))
  fi
done
```

#### Step 5.4: Validate Template Syntax

Check template files for common issues:

```bash
# For each template file
template_files=$(find "$chart_dir/templates" -name "*.yaml" -o -name "*.yml")

for template in $template_files; do
  # Check for unclosed template tags
  if grep -q "{{[^}]*$" "$template"; then
    echo "ERROR: $template - Unclosed template tag detected"
    ((GATE4_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  # Check for common template functions
  if grep -q "{{ .Values" "$template"; then
    # Validate values exist
    echo "INFO: $template uses .Values, ensure values.yaml is complete"
  fi
done
```

#### Step 5.5: Check Version Constraints

Validate dependencies and version requirements:

```bash
# Check Chart.yaml for dependencies
if grep -q "^dependencies:" "$chart_file"; then
  echo "INFO: Chart has dependencies, checking..."

  # Check for Chart.lock
  if [[ ! -f "$chart_dir/Chart.lock" ]]; then
    echo "WARN: $chart_dir - Missing Chart.lock (run helm dependency update)"
    ((TOTAL_WARNINGS++))
  fi
fi

# Check kubeVersion constraint
if ! grep -q "^kubeVersion:" "$chart_file"; then
  echo "INFO: $chart_file - No kubeVersion constraint specified"
fi
```

### Phase 6: Gate 5 - Labels and Annotations

#### Step 6.1: Check Recommended Labels

Verify app.kubernetes.io/\* labels present:

```bash
REQUIRED_LABELS=(
  "app.kubernetes.io/name"
  "app.kubernetes.io/instance"
)

RECOMMENDED_LABELS=(
  "app.kubernetes.io/version"
  "app.kubernetes.io/component"
  "app.kubernetes.io/part-of"
  "app.kubernetes.io/managed-by"
)

for file in "${manifest_files[@]}"; do
  if grep -q "kind: Deployment\|kind: StatefulSet\|kind: Service" "$file"; then
    # Check required labels
    for label in "${REQUIRED_LABELS[@]}"; do
      if ! grep -q "$label:" "$file"; then
        echo "ERROR: $file - Missing required label: $label"
        ((GATE5_FAIL++))
        ((TOTAL_ERRORS++))
      fi
    done

    # Check recommended labels
    for label in "${RECOMMENDED_LABELS[@]}"; do
      if ! grep -q "$label:" "$file"; then
        echo "WARN: $file - Missing recommended label: $label"
        ((TOTAL_WARNINGS++))
      fi
    done
  fi
done
```

#### Step 6.2: Validate Label Consistency

Check labels match across related resources:

```bash
# Extract app label from Deployment
if grep -q "kind: Deployment" "$file"; then
  app_label=$(grep "app:" "$file" | head -1 | awk '{print $2}')
  deployment_file="$file"

  # Find corresponding Service
  service_files=$(grep -l "kind: Service" **/*.yaml)
  for svc_file in $service_files; do
    svc_app_label=$(grep "app:" "$svc_file" | head -1 | awk '{print $2}')

    if [[ "$app_label" == "$svc_app_label" ]]; then
      # Check selector matches
      if ! grep -q "selector:" "$svc_file"; then
        echo "ERROR: $svc_file - Service missing selector"
        ((GATE5_FAIL++))
        ((TOTAL_ERRORS++))
      fi
    fi
  done
fi
```

#### Step 6.3: Validate Label Format

Check label values conform to DNS subdomain rules:

```bash
# Labels must be <=63 chars, alphanumeric + dash/underscore/dot
grep -n "^\s*[a-z][a-z0-9\.\-/]*:" "$file" | while read -r line; do
  label_name=$(echo "$line" | sed 's/.*:\s*\([^:]*\):.*/\1/')
  label_value=$(echo "$line" | sed 's/.*:\s*[^:]*:\s*\(.*\)/\1/' | tr -d '"' | tr -d "'")

  # Check length
  if [[ ${#label_value} -gt 63 ]]; then
    echo "ERROR: $file:${line%%:*} - Label value exceeds 63 characters"
    ((GATE5_FAIL++))
    ((TOTAL_ERRORS++))
  fi

  # Check format (alphanumeric, dash, underscore, dot)
  if [[ ! "$label_value" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "ERROR: $file:${line%%:*} - Invalid label value format: $label_value"
    ((GATE5_FAIL++))
    ((TOTAL_ERRORS++))
  fi
done
```

#### Step 6.4: Check Annotation Usage

Verify proper annotation usage:

```bash
# Check for common annotations
if grep -q "kind: Ingress" "$file"; then
  # Check for ingress annotations
  if ! grep -q "annotations:" "$file"; then
    echo "WARN: $file - Ingress missing annotations (may need cert-manager, nginx config)"
    ((TOTAL_WARNINGS++))
  fi
fi

# Check for prometheus annotations
if grep -q "kind: Service" "$file"; then
  if ! grep -q "prometheus.io/scrape" "$file"; then
    echo "INFO: $file - Consider adding Prometheus scrape annotations"
  fi
fi
```

### Phase 7: Gate 6 - Policy-as-Code

#### Step 7.1: Check kube-linter

Run kube-linter if available:

```bash
if [[ "$KUBELINTER_AVAILABLE" == "true" ]]; then
  echo "Running kube-linter..."

  if kube-linter lint . --format json > /tmp/kube-linter-output.json 2>&1; then
    echo "PASS: kube-linter (no issues found)"
    ((GATE6_PASS++))
  else
    echo "FAIL: kube-linter found issues"
    cat /tmp/kube-linter-output.json

    # Parse JSON and count errors/warnings
    errors=$(jq '[.Reports[] | select(.Level == "error")] | length' /tmp/kube-linter-output.json)
    warnings=$(jq '[.Reports[] | select(.Level == "warning")] | length' /tmp/kube-linter-output.json)

    ((GATE6_FAIL++))
    ((TOTAL_ERRORS += errors))
    ((TOTAL_WARNINGS += warnings))
  fi
else
  echo "INFO: kube-linter not available, skipping"
  GATE6_KUBELINTER_SKIPPED=true
fi
```

#### Step 7.2: Check Polaris

Run Polaris if available:

```bash
if [[ "$POLARIS_AVAILABLE" == "true" ]]; then
  echo "Running polaris..."

  if polaris audit --audit-path . --format json > /tmp/polaris-output.json 2>&1; then
    score=$(jq '.score' /tmp/polaris-output.json)

    echo "Polaris score: $score/100"

    if (( $(echo "$score >= 80" | bc -l) )); then
      echo "PASS: Polaris score >= 80"
      ((GATE6_PASS++))
    else
      echo "FAIL: Polaris score < 80"
      cat /tmp/polaris-output.json
      ((GATE6_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  fi
else
  echo "INFO: polaris not available, skipping"
  GATE6_POLARIS_SKIPPED=true
fi
```

#### Step 7.3: Check Conftest

Run Conftest/OPA policies if available:

```bash
if [[ "$CONFTEST_AVAILABLE" == "true" ]]; then
  # Check for policy directory
  if [[ -d "policy" ]] || [[ -d ".opa" ]]; then
    echo "Running conftest..."

    if conftest test . --all-namespaces > /tmp/conftest-output.txt 2>&1; then
      echo "PASS: conftest (all policies passed)"
      ((GATE6_PASS++))
    else
      echo "FAIL: conftest policy violations"
      cat /tmp/conftest-output.txt
      ((GATE6_FAIL++))
      ((TOTAL_ERRORS++))
    fi
  else
    echo "INFO: conftest available but no policies found (policy/ or .opa/)"
    GATE6_CONFTEST_SKIPPED=true
  fi
else
  echo "INFO: conftest not available, skipping"
  GATE6_CONFTEST_SKIPPED=true
fi
```

#### Step 7.4: Report Policy Status

Summarize policy-as-code gate:

```bash
echo ""
echo "Gate 6: Policy-as-Code Summary"
echo "=============================="
echo "kube-linter: ${GATE6_KUBELINTER_SKIPPED:+SKIPPED}${GATE6_KUBELINTER_SKIPPED:-RAN}"
echo "polaris: ${GATE6_POLARIS_SKIPPED:+SKIPPED}${GATE6_POLARIS_SKIPPED:-RAN}"
echo "conftest: ${GATE6_CONFTEST_SKIPPED:+SKIPPED}${GATE6_CONFTEST_SKIPPED:-RAN}"
```

### Phase 8: Reporting and Exit

#### Step 8.1: Generate Gate Summary

Create summary for each gate:

```bash
echo ""
echo "Validation Summary"
echo "=================="
echo ""
echo "Gate 1: Manifest Syntax"
echo "  Pass: $GATE1_PASS"
echo "  Fail: $GATE1_FAIL"
echo ""
echo "Gate 2: Resource Management"
echo "  Pass: $GATE2_PASS"
echo "  Fail: $GATE2_FAIL"
echo ""
echo "Gate 3: Security Context"
echo "  Pass: $GATE3_PASS"
echo "  Fail: $GATE3_FAIL"
echo ""
echo "Gate 4: Helm Lint"
echo "  Pass: $GATE4_PASS"
echo "  Fail: $GATE4_FAIL"
echo "  Skip: ${GATE4_SKIP:-false}"
echo ""
echo "Gate 5: Labels and Annotations"
echo "  Pass: $GATE5_PASS"
echo "  Fail: $GATE5_FAIL"
echo ""
echo "Gate 6: Policy-as-Code"
echo "  Pass: $GATE6_PASS"
echo "  Fail: $GATE6_FAIL"
echo ""
```

#### Step 8.2: Overall Statistics

Report overall validation results:

```bash
echo "Overall Statistics"
echo "=================="
echo "Total files validated: $TOTAL_FILES"
echo "Total errors: $TOTAL_ERRORS"
echo "Total warnings: $TOTAL_WARNINGS"
echo ""

if [[ $TOTAL_ERRORS -eq 0 ]]; then
  echo "Status: PASS (all gates passed)"
else
  echo "Status: FAIL ($TOTAL_ERRORS errors must be fixed)"
fi
```

#### Step 8.3: Tool Availability Report

Show which tools were used:

```bash
echo ""
echo "Tools Used"
echo "=========="
echo "kubeconform: ${KUBECONFORM_AVAILABLE:-false} ${KUBECONFORM_VERSION:-}"
echo "kubeval: ${KUBEVAL_AVAILABLE:-false} ${KUBEVAL_VERSION:-}"
echo "helm: ${HELM_AVAILABLE:-false} ${HELM_VERSION:-}"
echo "kube-linter: ${KUBELINTER_AVAILABLE:-false} ${KUBELINTER_VERSION:-}"
echo "polaris: ${POLARIS_AVAILABLE:-false}"
echo "conftest: ${CONFTEST_AVAILABLE:-false}"
```

#### Step 8.4: Conventions Reference

Include conventions document info:

```bash
if [[ "$CONVENTIONS_FOUND" == "true" ]]; then
  echo ""
  echo "Project conventions: docs/infra/kubernetes-conventions.md"
  echo "Validation aligned with documented standards."
else
  echo ""
  echo "INFO: No conventions document found."
  echo "Consider creating docs/infra/kubernetes-conventions.md to document project standards."
fi
```

#### Step 8.5: Exit Code

Set appropriate exit code:

```bash
if [[ $TOTAL_ERRORS -eq 0 ]]; then
  exit 0
else
  exit 1
fi
```

## Final Report Format

### Success Example

```text
Kubernetes Validation Report
=============================
Date: 2026-02-09 14:32:15
Mode: full
Files validated: 24

Gate 1: Manifest Syntax ✓ PASS
  - Validated with kubeconform v0.6.4
  - All 24 manifests valid
  - No deprecated API versions found
  - All required fields present
  - Selector consistency verified

Gate 2: Resource Management ✓ PASS
  - All 18 containers have resource requests
  - All 18 containers have resource limits
  - ResourceQuota found for 3/3 namespaces
  - LimitRange found for 3/3 namespaces
  - Probes configured on 6/6 deployments
  - PDB configured for 4/4 HA deployments

Gate 3: Security Context ✓ PASS
  - runAsNonRoot: true on all workloads
  - readOnlyRootFilesystem: true on all containers
  - allowPrivilegeEscalation: false on all containers
  - Capabilities dropped (ALL) on all containers
  - No privileged containers detected
  - ServiceAccount configured properly

Gate 4: Helm Lint ✓ PASS
  - 2 Helm charts validated
  - helm lint passed with --strict
  - All required metadata present
  - Dependencies locked (Chart.lock present)

Gate 5: Labels and Annotations ✓ PASS
  - Required labels present on all resources
  - app.kubernetes.io/* labels consistent
  - Label format valid (DNS subdomain)
  - Prometheus annotations configured

Gate 6: Policy-as-Code ✓ PASS
  - kube-linter: 0 issues found
  - polaris: score 94/100
  - conftest: all policies passed

Overall Statistics
==================
Total files validated: 24
Total errors: 0
Total warnings: 3
Status: PASS ✓

Warnings:
  - k8s/monitoring/prometheus.yaml:45 - Image using :latest tag
  - k8s/staging/api.yaml:78 - Consider adding startupProbe
  - k8s/prod/worker.yaml:112 - Polaris suggests adding CPU limits

Tools Used
==========
kubeconform: v0.6.4
helm: v3.14.0
kube-linter: v0.6.5
polaris: v8.5.1
conftest: v0.48.0

Project conventions: docs/infra/kubernetes-conventions.md
Validation aligned with documented standards.

All validation gates passed. Manifests ready for deployment.
```

### Failure Example

```text
Kubernetes Validation Report
=============================
Date: 2026-02-09 14:35:42
Mode: full
Files validated: 18

Gate 1: Manifest Syntax ✗ FAIL
  - Validated with kubeconform v0.6.4
  - 3 manifest errors found

  ERRORS:
  - k8s/app/frontend.yaml:12 - Deprecated API version apps/v1beta2, use apps/v1
  - k8s/app/backend.yaml:8 - Missing metadata.labels
  - k8s/networking/ingress.yaml:15 - Invalid selector, does not match Deployment

Gate 2: Resource Management ✗ FAIL
  - 5/12 containers missing resource requests
  - 6/12 containers missing resource limits

  ERRORS:
  - k8s/app/frontend.yaml:45 - Container 'nginx' missing resources.requests
  - k8s/app/frontend.yaml:45 - Container 'nginx' missing resources.limits
  - k8s/app/backend.yaml:52 - Container 'api' missing resources.requests
  - k8s/app/backend.yaml:52 - Container 'api' missing resources.limits
  - k8s/app/backend.yaml:67 - Container 'sidecar' missing resources.requests
  - k8s/app/backend.yaml:67 - Container 'sidecar' missing resources.limits
  - k8s/jobs/migration.yaml:23 - CPU value set to 0

  WARNINGS:
  - Namespace 'staging' missing ResourceQuota
  - Deployment 'frontend' (replicas=3) missing PodDisruptionBudget

Gate 3: Security Context ✗ FAIL
  - 4/12 containers missing security context

  ERRORS:
  - k8s/app/frontend.yaml:45 - Missing runAsNonRoot: true
  - k8s/app/backend.yaml:52 - Missing readOnlyRootFilesystem: true
  - k8s/app/backend.yaml:52 - Missing allowPrivilegeEscalation: false
  - k8s/jobs/debug.yaml:18 - privileged: true detected (major security risk)
  - k8s/app/cache.yaml:34 - Missing capabilities drop

Gate 4: Helm Lint - SKIPPED
  - No Helm charts detected

Gate 5: Labels and Annotations ✗ FAIL
  - 6/18 resources missing required labels

  ERRORS:
  - k8s/app/frontend.yaml - Missing app.kubernetes.io/name
  - k8s/app/frontend.yaml - Missing app.kubernetes.io/instance
  - k8s/app/backend.yaml - Missing app.kubernetes.io/name
  - k8s/networking/service.yaml - Missing app.kubernetes.io/instance

  WARNINGS:
  - k8s/app/cache.yaml - Missing app.kubernetes.io/version
  - k8s/app/cache.yaml - Missing app.kubernetes.io/component

Gate 6: Policy-as-Code ✗ FAIL
  - kube-linter: 12 issues found
  - polaris: score 62/100 (threshold 80)

  kube-linter issues:
  - no-read-only-root-fs: 4 occurrences
  - no-liveness-probe: 3 occurrences
  - privilege-escalation-container: 2 occurrences
  - unset-cpu-requirements: 5 occurrences

  Polaris findings:
  - Security: 45/100
  - Efficiency: 72/100
  - Reliability: 68/100

Overall Statistics
==================
Total files validated: 18
Total errors: 28
Total warnings: 8
Status: FAIL ✗

Critical Issues (must fix):
  1. Deprecated API versions must be updated to current versions
  2. All containers must have resource requests and limits
  3. Security contexts must be configured on all containers
  4. Privileged container must be removed or justified
  5. Required Kubernetes labels must be added

Tools Used
==========
kubeconform: v0.6.4
kube-linter: v0.6.5
polaris: v8.5.1

INFO: No conventions document found.
Consider creating docs/infra/kubernetes-conventions.md to document project standards.

VALIDATION FAILED - 28 errors must be fixed before deployment.
```

### Quick Mode Example

```text
Kubernetes Validation Report (Quick Mode)
==========================================
Date: 2026-02-09 14:38:10
Mode: quick
Files validated: 24

Gate 1: Manifest Syntax ✓ PASS
  - All YAML files valid
  - API versions current
  - Required fields present

Gate 2: Resource Limits Check ✓ PASS
  - All containers have resources.requests
  - All containers have resources.limits

Overall Statistics
==================
Total files validated: 24
Total errors: 0
Status: PASS ✓

Quick validation passed. Run full validation before production deployment:
  /ccfg-kubernetes validate
```

## Edge Cases and Special Handling

### CRD Handling

Custom Resource Definitions require special treatment:

```bash
# Detect CRDs
if grep -q "kind: CustomResourceDefinition" "$file"; then
  echo "INFO: CRD detected, skipping some standard validations"
  # CRDs don't need containers, security contexts, etc.
  SKIP_CONTAINER_CHECKS=true
fi
```

### Kustomize Support

Handle kustomize overlays properly:

```bash
# Detect kustomization
if [[ -f "kustomization.yaml" ]] || [[ -f "kustomization.yml" ]]; then
  echo "INFO: Kustomize detected, building before validation"

  if command -v kustomize >/dev/null 2>&1; then
    kustomize build . > /tmp/kustomize-built.yaml
    # Validate the built output
    validate_manifest "/tmp/kustomize-built.yaml"
  else
    echo "WARN: kustomize not available, validating raw files"
  fi
fi
```

### Exclusion Comments

Support validation skip comments:

```bash
# Check for validation skip comment
if grep -q "# kubernetes-validate: skip" "$file"; then
  echo "INFO: $file - Validation skipped per inline comment"
  continue
fi

# Gate-specific skip
if grep -q "# kubernetes-validate: skip-security" "$file"; then
  echo "INFO: $file - Security validation skipped per inline comment"
  SKIP_SECURITY_CHECKS=true
fi
```

### Multi-Namespace Deployments

Handle resources across namespaces:

```bash
# Track namespaces seen
declare -A NAMESPACES_SEEN

# Record namespace from each resource
namespace=$(grep "namespace:" "$file" | head -1 | awk '{print $2}')
if [[ -n "$namespace" ]]; then
  NAMESPACES_SEEN["$namespace"]=1
fi

# Later, validate namespace-level resources
for ns in "${!NAMESPACES_SEEN[@]}"; do
  # Check for ResourceQuota, LimitRange, NetworkPolicy per namespace
  validate_namespace_resources "$ns"
done
```

### Init Container Handling

Validate init containers separately:

```bash
# Check for initContainers section
if grep -q "initContainers:" "$file"; then
  # Apply same validations as regular containers
  # But allow different resource profiles
  echo "INFO: $file - Init containers detected"
fi
```

### Job and CronJob Considerations

Handle batch workloads differently:

```bash
if grep -q "kind: Job\|kind: CronJob" "$file"; then
  # Jobs don't need readiness probes
  SKIP_READINESS_CHECK=true

  # But still need resource limits
  # And still need security contexts
fi
```

## Installation Recommendations

If validation tools not found, suggest installation:

```bash
echo ""
echo "Recommended Tools"
echo "================="
echo "Install these tools for enhanced validation:"
echo ""
echo "kubeconform:"
echo "  brew install kubeconform"
echo "  # or download from https://github.com/yannh/kubeconform"
echo ""
echo "helm:"
echo "  brew install helm"
echo "  # or https://helm.sh/docs/intro/install/"
echo ""
echo "kube-linter:"
echo "  brew install kube-linter"
echo "  # or https://github.com/stackrox/kube-linter"
echo ""
echo "polaris:"
echo "  brew install fairwinds/tap/polaris"
echo "  # or https://github.com/FairwindsOps/polaris"
echo ""
```
