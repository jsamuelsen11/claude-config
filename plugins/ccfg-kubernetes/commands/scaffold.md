---
description: >
  Scaffold Kubernetes manifests, Helm charts, or kustomize configurations for projects
argument-hint: '[--type=manifest|helm-chart|kustomize]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Generate production-ready Kubernetes configurations with security best practices, resource
management, and proper labeling built-in. Supports plain manifests, Helm charts, and kustomize
overlays with intelligent application type detection.

## Usage

```bash
# Scaffold plain Kubernetes manifests (auto-detect app type)
/ccfg-kubernetes scaffold

# Scaffold with specific type
/ccfg-kubernetes scaffold --type=manifest
/ccfg-kubernetes scaffold --type=helm-chart
/ccfg-kubernetes scaffold --type=kustomize

# Typical workflow
/ccfg-kubernetes scaffold --type=helm-chart
cd helm-charts/myapp
helm lint .
```

## Overview

### Scaffold Types

#### manifest (default)

- Single-file or multi-file Kubernetes manifests
- Application type detection (web app, worker, job, database)
- Generates: Deployment, Service, ConfigMap, Secret stubs, Ingress
- Includes: resource limits, security context, probes, PDB, namespace
- Standard labels: app.kubernetes.io/\* label set
- Production-ready defaults

#### helm-chart

- Complete Helm chart structure
- Chart.yaml with metadata
- values.yaml with fully documented sections
- templates/: deployment, service, ingress, configmap, serviceaccount, hpa
- \_helpers.tpl with standard template functions
- .helmignore for clean packaging
- NOTES.txt with usage instructions

#### kustomize

- Base + overlays structure
- k8s/base/: kustomization.yaml + core resources
- k8s/overlays/dev/: development overrides
- k8s/overlays/prod/: production overrides
- Patches for replicas, resources, images
- ConfigMap/Secret generators
- Namespace per environment

## Key Rules

### Application Type Detection

- Best-effort detection from project structure
- Check package.json, requirements.txt, go.mod, pom.xml, Dockerfile
- Infer web app vs worker vs job vs database
- Use sensible defaults if detection uncertain
- Allow manual override

### Security First

- Security context always included
- runAsNonRoot: true by default
- readOnlyRootFilesystem: true by default
- Drop all capabilities
- Resource requests/limits mandatory
- No privileged containers

### No Real Secrets

- Placeholder values only
- Comments explaining secret management
- Reference to external secret managers (Sealed Secrets, External Secrets Operator)
- Never commit actual credentials

### Standard Naming Conventions

- Follow Kubernetes naming best practices
- DNS-compliant names (alphanumeric + dash)
- Consistent label selectors
- app.kubernetes.io/\* labels throughout

### Conventions Document

- Check for docs/infra/kubernetes-conventions.md
- Reference if exists
- Recommend creating if missing
- Align scaffolding with documented standards

## Step-by-Step Process

### Phase 1: Project Analysis

#### Step 1.1: Detect Project Type

Analyze project structure to determine application type:

```bash
# Check for web application indicators
if [[ -f "package.json" ]]; then
  if grep -q "express\|koa\|fastify\|nest" package.json; then
    APP_TYPE="web-nodejs"
  fi
fi

if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
  if grep -q "flask\|django\|fastapi" requirements.txt pyproject.toml 2>/dev/null; then
    APP_TYPE="web-python"
  fi
fi

if [[ -f "go.mod" ]]; then
  if grep -q "gin-gonic\|echo\|fiber" go.mod; then
    APP_TYPE="web-go"
  fi
fi

if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
  if grep -q "spring-boot\|quarkus\|micronaut" pom.xml build.gradle 2>/dev/null; then
    APP_TYPE="web-java"
  fi
fi

# Check for worker/background job indicators
if grep -q "celery\|rq\|bull\|sidekiq" requirements.txt package.json 2>/dev/null; then
  APP_TYPE="worker"
fi

# Check for database
if [[ -f "Dockerfile" ]]; then
  if grep -q "FROM postgres\|FROM mysql\|FROM mongo" Dockerfile; then
    APP_TYPE="database"
  fi
fi

# Default to generic web app
APP_TYPE="${APP_TYPE:-web-generic}"
```

#### Step 1.2: Detect Existing Kubernetes Config

Check for existing Kubernetes configurations:

```bash
# Look for existing manifests
if [[ -d "k8s" ]] || [[ -d "kubernetes" ]] || [[ -d ".kube" ]]; then
  echo "WARN: Existing Kubernetes directory found"
  echo "Choose action: [merge/replace/cancel]"
  # Handle user choice
fi

# Look for existing Helm charts
if find . -name "Chart.yaml" -type f | grep -q .; then
  echo "WARN: Existing Helm chart found"
  # Handle appropriately
fi

# Look for kustomization
if find . -name "kustomization.yaml" -type f | grep -q .; then
  echo "WARN: Existing kustomize config found"
  # Handle appropriately
fi
```

#### Step 1.3: Extract Project Metadata

Gather project information for manifest generation:

```bash
# Project name from directory or git
PROJECT_NAME=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Or from git remote
if git remote -v >/dev/null 2>&1; then
  GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$GIT_REMOTE" ]]; then
    PROJECT_NAME=$(basename "$GIT_REMOTE" .git | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  fi
fi

# Version from git tag or package file
if git describe --tags --abbrev=0 >/dev/null 2>&1; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
else
  VERSION="0.1.0"
fi

# Namespace (default to project name)
NAMESPACE="${PROJECT_NAME}"
```

#### Step 1.4: Determine Port Configuration

Detect application ports:

```bash
# Check Dockerfile EXPOSE
if [[ -f "Dockerfile" ]]; then
  EXPOSED_PORT=$(grep "^EXPOSE" Dockerfile | awk '{print $2}' | head -1)
fi

# Check common application ports
case "$APP_TYPE" in
  web-nodejs)
    DEFAULT_PORT=3000
    ;;
  web-python)
    DEFAULT_PORT=8000
    ;;
  web-go)
    DEFAULT_PORT=8080
    ;;
  web-java)
    DEFAULT_PORT=8080
    ;;
  *)
    DEFAULT_PORT=8080
    ;;
esac

PORT="${EXPOSED_PORT:-$DEFAULT_PORT}"
```

#### Step 1.5: Check Conventions Document

Look for project-specific standards:

```bash
if [[ -f "docs/infra/kubernetes-conventions.md" ]]; then
  echo "INFO: Found conventions document, aligning with standards"
  CONVENTIONS_FOUND=true

  # Parse for custom requirements (optional)
  # e.g., required annotations, label prefixes, resource defaults
fi
```

### Phase 2: Manifest Scaffolding

#### Step 2.1: Create Directory Structure

Set up directory for manifests:

```bash
# Create k8s directory if not exists
mkdir -p k8s

# Create subdirectories for organization
mkdir -p k8s/base
mkdir -p k8s/overlays/dev
mkdir -p k8s/overlays/staging
mkdir -p k8s/overlays/prod
```

#### Step 2.2: Generate Namespace

Create namespace manifest:

```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubernetes
    environment: base
```

#### Step 2.3: Generate Deployment

Create deployment with security context and resource limits:

```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: application
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: ${PROJECT_NAME}
      app.kubernetes.io/instance: ${PROJECT_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${PROJECT_NAME}
        app.kubernetes.io/instance: ${PROJECT_NAME}
        app.kubernetes.io/version: '${VERSION}'
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '${PORT}'
        prometheus.io/path: '/metrics'
    spec:
      serviceAccountName: ${PROJECT_NAME}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${PROJECT_NAME}
          image: ${IMAGE_REGISTRY}/${PROJECT_NAME}:${VERSION}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: ${PORT}
              protocol: TCP
          env:
            - name: PORT
              value: '${PORT}'
            - name: ENVIRONMENT
              value: 'production'
          envFrom:
            - configMapRef:
                name: ${PROJECT_NAME}-config
            - secretRef:
                name: ${PROJECT_NAME}-secrets
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 30
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
      automountServiceAccountToken: false
```

#### Step 2.4: Generate Service

Create service for the deployment:

```yaml
# k8s/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: application
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '${PORT}'
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
  sessionAffinity: None
```

#### Step 2.5: Generate ConfigMap

Create ConfigMap with example configuration:

```yaml
# k8s/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${PROJECT_NAME}-config
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: configuration
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
data:
  # Application configuration
  LOG_LEVEL: 'info'
  LOG_FORMAT: 'json'

  # Feature flags
  FEATURE_NEW_UI: 'false'

  # Integration endpoints (non-sensitive)
  API_ENDPOINT: 'https://api.example.com'

  # Performance tuning
  MAX_CONNECTIONS: '100'
  TIMEOUT_SECONDS: '30'
```

#### Step 2.6: Generate Secret Stub

Create Secret template with placeholders:

```yaml
# k8s/base/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${PROJECT_NAME}-secrets
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: secrets
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
type: Opaque
stringData:
  # WARNING: Do not commit real secrets to git
  # Use Sealed Secrets, External Secrets Operator, or vault

  # Database credentials (replace with actual secret management)
  DATABASE_URL: 'postgresql://user:REPLACE_ME@postgres:5432/dbname'

  # API keys (replace with actual secret management)
  API_KEY: 'REPLACE_ME'
  API_SECRET: 'REPLACE_ME'

  # Session secrets (replace with actual secret management)
  SESSION_SECRET: 'REPLACE_ME'

  # See docs/secrets-management.md for proper secret handling
```

#### Step 2.7: Generate Ingress

Create Ingress for external access:

```yaml
# k8s/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: ingress
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
  annotations:
    # Configure for your ingress controller
    kubernetes.io/ingress.class: 'nginx'
    cert-manager.io/cluster-issuer: 'letsencrypt-prod'
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/force-ssl-redirect: 'true'

    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";

    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: '100'

    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: '30'
    nginx.ingress.kubernetes.io/proxy-send-timeout: '30'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '30'
spec:
  tls:
    - hosts:
        - ${PROJECT_NAME}.example.com
      secretName: ${PROJECT_NAME}-tls
  rules:
    - host: ${PROJECT_NAME}.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${PROJECT_NAME}
                port:
                  name: http
```

#### Step 2.8: Generate ServiceAccount

Create ServiceAccount for pod identity:

```yaml
# k8s/base/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: serviceaccount
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
automountServiceAccountToken: false
```

#### Step 2.9: Generate PodDisruptionBudget

Create PDB for high availability:

```yaml
# k8s/base/poddisruptionbudget.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: pdb
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${PROJECT_NAME}
      app.kubernetes.io/instance: ${PROJECT_NAME}
```

#### Step 2.10: Generate HorizontalPodAutoscaler

Create HPA for auto-scaling:

```yaml
# k8s/base/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: autoscaling
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${PROJECT_NAME}
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
        - type: Pods
          value: 1
          periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
      selectPolicy: Max
```

#### Step 2.11: Generate NetworkPolicy

Create NetworkPolicy for network segmentation:

```yaml
# k8s/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${PROJECT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${PROJECT_NAME}
    app.kubernetes.io/instance: ${PROJECT_NAME}
    app.kubernetes.io/version: '${VERSION}'
    app.kubernetes.io/component: network-policy
    app.kubernetes.io/part-of: ${PROJECT_NAME}
    app.kubernetes.io/managed-by: kubectl
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: ${PROJECT_NAME}
      app.kubernetes.io/instance: ${PROJECT_NAME}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: ${PORT}
    # Allow same namespace
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: ${PORT}
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow external HTTPS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
    # Allow database (adjust as needed)
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
```

### Phase 3: Helm Chart Scaffolding

#### Step 3.1: Create Chart Directory

Set up Helm chart structure:

```bash
# Create chart directory
CHART_NAME="${PROJECT_NAME}"
mkdir -p "helm-charts/${CHART_NAME}"
cd "helm-charts/${CHART_NAME}"

# Create subdirectories
mkdir -p templates
mkdir -p charts
```

#### Step 3.2: Generate Chart.yaml

Create Helm chart metadata:

```yaml
# Chart.yaml
apiVersion: v2
name: ${CHART_NAME}
description: A Helm chart for ${PROJECT_NAME}
type: application
version: ${VERSION}
appVersion: '${VERSION}'
keywords:
  - ${PROJECT_NAME}
  - kubernetes
home: https://github.com/example/${PROJECT_NAME}
sources:
  - https://github.com/example/${PROJECT_NAME}
maintainers:
  - name: Platform Team
    email: platform@example.com
icon: https://example.com/icon.png
kubeVersion: '>=1.24.0'
```

#### Step 3.3: Generate values.yaml

Create comprehensive values file:

```yaml
# values.yaml
# Default values for ${CHART_NAME}
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

## Global settings
global:
  ## Image registry to use
  imageRegistry: ''

## Number of replicas
replicaCount: 3

## Container image settings
image:
  ## Image registry
  registry: docker.io
  ## Image repository
  repository: ${PROJECT_NAME}
  ## Image pull policy
  pullPolicy: IfNotPresent
  ## Image tag (defaults to chart appVersion)
  tag: ''

## Image pull secrets
imagePullSecrets: []

## Override chart name
nameOverride: ''
fullnameOverride: ''

## ServiceAccount configuration
serviceAccount:
  ## Create service account
  create: true
  ## Annotations for service account
  annotations: {}
  ## Service account name
  name: ''
  ## Automount service account token
  automountServiceAccountToken: false

## Pod annotations
podAnnotations:
  prometheus.io/scrape: 'true'
  prometheus.io/port: '8080'
  prometheus.io/path: '/metrics'

## Pod security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

## Container security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL

## Service configuration
service:
  ## Service type
  type: ClusterIP
  ## Service port
  port: 80
  ## Target port
  targetPort: http
  ## Annotations
  annotations: {}
  ## Session affinity
  sessionAffinity: None

## Ingress configuration
ingress:
  ## Enable ingress
  enabled: true
  ## Ingress class name
  className: 'nginx'
  ## Ingress annotations
  annotations:
    cert-manager.io/cluster-issuer: 'letsencrypt-prod'
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/force-ssl-redirect: 'true'
  ## Ingress hosts
  hosts:
    - host: ${PROJECT_NAME}.example.com
      paths:
        - path: /
          pathType: Prefix
  ## TLS configuration
  tls:
    - secretName: ${PROJECT_NAME}-tls
      hosts:
        - ${PROJECT_NAME}.example.com

## Resource limits and requests
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

## Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

## Pod disruption budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

## Node selector
nodeSelector: {}

## Tolerations
tolerations: []

## Affinity rules
affinity: {}

## Liveness probe
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

## Readiness probe
readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

## Startup probe
startupProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30

## Environment variables
env:
  - name: PORT
    value: '8080'
  - name: ENVIRONMENT
    value: 'production'

## ConfigMap data
configMap:
  data:
    LOG_LEVEL: 'info'
    LOG_FORMAT: 'json'

## Secret data (use external secret management in production)
secrets:
  # WARNING: Do not commit real secrets
  # Use Sealed Secrets or External Secrets Operator
  data: {}

## Network policy
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443

## Volume mounts
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /app/cache

## Volumes
volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

#### Step 3.4: Generate \_helpers.tpl

Create template helper functions:

```yaml
# templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "${CHART_NAME}.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "${CHART_NAME}.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "${CHART_NAME}.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "${CHART_NAME}.labels" -}}
helm.sh/chart: {{ include "${CHART_NAME}.chart" . }}
{{ include "${CHART_NAME}.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "${CHART_NAME}.selectorLabels" -}}
app.kubernetes.io/name: {{ include "${CHART_NAME}.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "${CHART_NAME}.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "${CHART_NAME}.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "${CHART_NAME}.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- if .Values.global }}
  {{- if .Values.global.imageRegistry }}
    {{- $registryName = .Values.global.imageRegistry -}}
  {{- end -}}
{{- end -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end }}
```

#### Step 3.5: Generate Template Files

Create deployment template:

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      {{- include "${CHART_NAME}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "${CHART_NAME}.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "${CHART_NAME}.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: {{ include "${CHART_NAME}.image" . }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        {{- with .Values.env }}
        env:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        envFrom:
        - configMapRef:
            name: {{ include "${CHART_NAME}.fullname" . }}
        {{- if .Values.secrets.data }}
        - secretRef:
            name: {{ include "${CHART_NAME}.fullname" . }}
        {{- end }}
        livenessProbe:
          {{- toYaml .Values.livenessProbe | nindent 12 }}
        readinessProbe:
          {{- toYaml .Values.readinessProbe | nindent 12 }}
        startupProbe:
          {{- toYaml .Values.startupProbe | nindent 12 }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        {{- with .Values.volumeMounts }}
        volumeMounts:
          {{- toYaml . | nindent 12 }}
        {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

Create remaining templates (service, ingress, serviceaccount, hpa, pdb, networkpolicy, configmap)
following similar pattern.

#### Step 3.6: Generate .helmignore

Create Helm ignore file:

```text
# .helmignore
# Patterns to ignore when building packages.
.git/
.gitignore
.bzr/
.bzrignore
.hg/
.hgignore
.svn/
*.swp
*.bak
*.tmp
*.orig
*~
.DS_Store
.project
.idea/
*.tmproj
.vscode/
```

#### Step 3.7: Generate NOTES.txt

Create post-install notes:

```text
# templates/NOTES.txt
1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
{{- range $host := .Values.ingress.hosts }}
  {{- range .paths }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ $host.host }}{{ .path }}
  {{- end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "${CHART_NAME}.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status of by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "${CHART_NAME}.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "${CHART_NAME}.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "${CHART_NAME}.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT
{{- end }}
```

### Phase 4: Kustomize Scaffolding

#### Step 4.1: Create Base Structure

Set up kustomize base directory:

```bash
mkdir -p k8s/base
cd k8s/base
```

#### Step 4.2: Generate Base Kustomization

Create base kustomization.yaml:

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

commonLabels:
  app.kubernetes.io/name: ${PROJECT_NAME}
  app.kubernetes.io/managed-by: kustomize

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml
  - configmap.yaml
  - secret.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
  - networkpolicy.yaml

images:
  - name: ${PROJECT_NAME}
    newName: ${IMAGE_REGISTRY}/${PROJECT_NAME}
    newTag: ${VERSION}

configMapGenerator:
  - name: ${PROJECT_NAME}-config
    literals:
      - LOG_LEVEL=info
      - LOG_FORMAT=json

secretGenerator:
  - name: ${PROJECT_NAME}-secrets
    literals:
      - DATABASE_URL=REPLACE_ME
      - API_KEY=REPLACE_ME
```

#### Step 4.3: Create Overlay Structures

Set up environment overlays:

```bash
mkdir -p k8s/overlays/dev
mkdir -p k8s/overlays/staging
mkdir -p k8s/overlays/prod
```

#### Step 4.4: Generate Dev Overlay

Create development kustomization:

```yaml
# k8s/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}-dev

bases:
  - ../../base

nameSuffix: -dev

commonLabels:
  environment: development

patches:
  - path: deployment-patch.yaml

replicas:
  - name: ${PROJECT_NAME}
    count: 1

images:
  - name: ${PROJECT_NAME}
    newTag: dev-latest

configMapGenerator:
  - name: ${PROJECT_NAME}-config
    behavior: merge
    literals:
      - LOG_LEVEL=debug
      - ENVIRONMENT=development
```

Development deployment patch:

```yaml
# k8s/overlays/dev/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${PROJECT_NAME}
spec:
  template:
    spec:
      containers:
        - name: ${PROJECT_NAME}
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
```

#### Step 4.5: Generate Prod Overlay

Create production kustomization:

```yaml
# k8s/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}-prod

bases:
  - ../../base

nameSuffix: -prod

commonLabels:
  environment: production

patches:
  - path: deployment-patch.yaml

replicas:
  - name: ${PROJECT_NAME}
    count: 5

images:
  - name: ${PROJECT_NAME}
    newTag: ${VERSION}

configMapGenerator:
  - name: ${PROJECT_NAME}-config
    behavior: merge
    literals:
      - LOG_LEVEL=warn
      - ENVIRONMENT=production
```

Production deployment patch:

```yaml
# k8s/overlays/prod/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${PROJECT_NAME}
spec:
  template:
    spec:
      containers:
        - name: ${PROJECT_NAME}
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 1Gi
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app.kubernetes.io/name
                      operator: In
                      values:
                        - ${PROJECT_NAME}
                topologyKey: kubernetes.io/hostname
```

### Phase 5: Documentation and Finalization

#### Step 5.1: Generate README

Create deployment documentation:

````markdown
# ${PROJECT_NAME} Kubernetes Deployment

This directory contains Kubernetes manifests for deploying ${PROJECT_NAME}.

## Structure

- `k8s/base/` - Base manifests
- `k8s/overlays/dev/` - Development environment
- `k8s/overlays/staging/` - Staging environment
- `k8s/overlays/prod/` - Production environment

## Deployment

### Using kubectl

```bash
# Deploy to dev
kubectl apply -f k8s/base/

# Deploy with kustomize
kubectl apply -k k8s/overlays/dev/
kubectl apply -k k8s/overlays/prod/
```

### Using Helm

```bash
# Install chart
helm install ${PROJECT_NAME} ./helm-charts/${PROJECT_NAME}

# Upgrade
helm upgrade ${PROJECT_NAME} ./helm-charts/${PROJECT_NAME}

# Custom values
helm install ${PROJECT_NAME} ./helm-charts/${PROJECT_NAME} -f values-prod.yaml
```

## Configuration

See `docs/infra/kubernetes-conventions.md` for project standards.

## Secrets Management

Do not commit real secrets to git. Use one of:

- Sealed Secrets
- External Secrets Operator
- HashiCorp Vault
- Cloud provider secret managers

## Monitoring

Prometheus metrics available at `/metrics` endpoint.

## Security

All manifests follow security best practices:

- Non-root containers
- Read-only root filesystem
- Dropped capabilities
- Resource limits
- Network policies
````

#### Step 5.2: Verify Generated Files

Run validation on generated manifests:

```bash
# Validate YAML syntax
find k8s -name "*.yaml" -exec yamllint {} \;

# Validate with kubeval/kubeconform if available
if command -v kubeconform >/dev/null 2>&1; then
  kubeconform k8s/base/*.yaml
fi

# Validate Helm chart
if [[ -d "helm-charts/${PROJECT_NAME}" ]]; then
  helm lint helm-charts/${PROJECT_NAME}
fi

# Validate kustomize
if command -v kustomize >/dev/null 2>&1; then
  kustomize build k8s/overlays/dev/ | kubeconform -
  kustomize build k8s/overlays/prod/ | kubeconform -
fi
```

#### Step 5.3: Report Summary

Generate scaffolding report:

```bash
echo ""
echo "Kubernetes Scaffolding Complete"
echo "==============================="
echo ""
echo "Generated files:"
find k8s helm-charts -name "*.yaml" -o -name "*.yml" | wc -l
echo ""
echo "Next steps:"
echo "1. Review generated manifests"
echo "2. Update placeholder values (image, ingress host, secrets)"
echo "3. Customize resource limits for your workload"
echo "4. Validate: /ccfg-kubernetes validate"
echo "5. Deploy to dev environment for testing"
echo ""

if [[ "$CONVENTIONS_FOUND" == "true" ]]; then
  echo "Generated manifests aligned with docs/infra/kubernetes-conventions.md"
else
  echo "Consider creating docs/infra/kubernetes-conventions.md to document standards"
fi
```

## Final Report Format

### Success Example

```text
Kubernetes Scaffolding Complete
================================
Type: helm-chart
Project: myapp
Version: 0.1.0
Location: /home/user/myapp/helm-charts/myapp

Generated Files:
├── Chart.yaml
├── values.yaml
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── networkpolicy.yaml
│   └── NOTES.txt

Total files: 13

Configuration:
- Replicas: 3
- Port: 8080
- Image: docker.io/myapp:0.1.0
- Security: runAsNonRoot, readOnlyRootFilesystem, dropped capabilities
- Resources: CPU 100m-500m, Memory 128Mi-512Mi
- Probes: liveness, readiness, startup
- Autoscaling: 3-10 replicas (CPU 70%, Memory 80%)
- Network Policy: enabled with DNS + HTTPS egress

Next Steps:
1. Review and customize values.yaml
2. Update image repository and tag
3. Configure ingress hostname
4. Setup secret management (Sealed Secrets/External Secrets)
5. Validate: helm lint helm-charts/myapp
6. Test install: helm install myapp helm-charts/myapp --dry-run --debug
7. Deploy to dev: helm install myapp helm-charts/myapp -n myapp-dev --create-namespace

Production Readiness:
✓ Security context configured
✓ Resource limits set
✓ Health probes configured
✓ Pod disruption budget included
✓ Horizontal autoscaling enabled
✓ Network policy defined
✓ ServiceAccount created

Project conventions: docs/infra/kubernetes-conventions.md
All manifests aligned with documented standards.

Helm chart ready for deployment!
```

### Manifest Type Example

```text
Kubernetes Scaffolding Complete
================================
Type: manifest
Project: api-service
Version: 1.2.3
Location: /home/user/api-service/k8s

Generated Files:
k8s/base/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
├── serviceaccount.yaml
├── configmap.yaml
├── secret.yaml
├── ingress.yaml
├── hpa.yaml
├── pdb.yaml
└── networkpolicy.yaml

Total files: 10

Application Type: web-nodejs
Detected from: package.json (express framework)

Configuration:
- Namespace: api-service
- Replicas: 3
- Port: 3000
- Image: docker.io/api-service:1.2.3
- Probes: /health, /ready endpoints

Security Hardening:
✓ runAsNonRoot: true
✓ runAsUser: 1000
✓ readOnlyRootFilesystem: true
✓ allowPrivilegeEscalation: false
✓ Capabilities: drop [ALL]
✓ seccompProfile: RuntimeDefault
✓ automountServiceAccountToken: false

Resource Management:
✓ CPU requests: 100m
✓ CPU limits: 500m
✓ Memory requests: 128Mi
✓ Memory limits: 512Mi
✓ HPA configured: 3-10 replicas
✓ PDB configured: minAvailable 1

Next Steps:
1. Update image in k8s/base/deployment.yaml
2. Configure ingress hostname in k8s/base/ingress.yaml
3. Replace secret placeholders in k8s/base/secret.yaml
4. Review ConfigMap values in k8s/base/configmap.yaml
5. Validate manifests: /ccfg-kubernetes validate
6. Deploy to dev: kubectl apply -f k8s/base/ -n api-service-dev

Deployment Commands:
# Create namespace
kubectl create namespace api-service

# Apply manifests
kubectl apply -f k8s/base/

# Check status
kubectl get pods -n api-service
kubectl get svc -n api-service
kubectl get ingress -n api-service

INFO: Consider creating docs/infra/kubernetes-conventions.md
to document project-specific standards.

Manifests ready for deployment!
```

### Kustomize Type Example

```text
Kubernetes Scaffolding Complete
================================
Type: kustomize
Project: backend-api
Version: 2.0.0
Location: /home/user/backend-api/k8s

Generated Structure:
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── networkpolicy.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── deployment-patch.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── deployment-patch.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── deployment-patch.yaml

Total files: 17

Environment Configuration:
Development:
- Replicas: 1
- Resources: CPU 50m-200m, Memory 64Mi-256Mi
- Log level: debug
- Image tag: dev-latest

Production:
- Replicas: 5
- Resources: CPU 200m-1000m, Memory 256Mi-1Gi
- Log level: warn
- Image tag: 2.0.0
- Pod anti-affinity: enabled

Next Steps:
1. Update image registry in k8s/base/kustomization.yaml
2. Configure environment-specific values in overlays
3. Setup secret management
4. Validate: kustomize build k8s/overlays/dev | kubeconform -
5. Deploy dev: kubectl apply -k k8s/overlays/dev
6. Deploy prod: kubectl apply -k k8s/overlays/prod

Deployment Commands:
# Build and preview
kustomize build k8s/overlays/dev
kustomize build k8s/overlays/prod

# Deploy
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/prod

# Diff before apply
kubectl diff -k k8s/overlays/prod

Security & Best Practices:
✓ Non-root containers
✓ Read-only filesystem
✓ Resource limits per environment
✓ Network policies included
✓ PodDisruptionBudget configured
✓ Anti-affinity in production

Project conventions: docs/infra/kubernetes-conventions.md
Kustomize structure aligned with documented standards.

Kustomize configuration ready!
```

## Edge Cases and Special Handling

### Existing Configuration Detection

```bash
# Check for existing config
if [[ -d "k8s" ]] || [[ -d "kubernetes" ]]; then
  echo "WARNING: Existing Kubernetes configuration detected"
  echo "Options:"
  echo "  1. Merge with existing (preserve custom changes)"
  echo "  2. Backup and replace"
  echo "  3. Cancel"
  # Handle user choice
fi
```

### Database Workloads

For StatefulSet workloads:

```yaml
# Use StatefulSet instead of Deployment
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${PROJECT_NAME}
spec:
  serviceName: ${PROJECT_NAME}-headless
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ['ReadWriteOnce']
        resources:
          requests:
            storage: 10Gi
```

### CronJob Workloads

For scheduled jobs:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${PROJECT_NAME}
spec:
  schedule: '0 2 * * *'
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          # ... container spec
```

### Multi-Container Pods

For sidecar patterns:

```yaml
containers:
  - name: ${PROJECT_NAME}
    # ... main container
  - name: sidecar
    image: sidecar:latest
    # ... sidecar config
```
