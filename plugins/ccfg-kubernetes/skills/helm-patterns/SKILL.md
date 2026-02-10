---
name: helm-patterns
description:
  This skill should be used when designing Helm charts, writing values.yaml, creating templates,
  managing chart dependencies, or testing Helm releases.
version: 0.1.0
---

# Helm Chart Design Patterns

This skill provides comprehensive patterns for designing production-grade Helm charts that are
maintainable, reusable, and follow Helm best practices. Apply these patterns when creating new
charts, refactoring existing ones, or reviewing chart pull requests.

## Existing Repository Compatibility

Before applying Helm patterns, understand the existing chart ecosystem:

1. **Chart Structure** - Review existing chart organization and template patterns
2. **Values Schema** - Identify established values.yaml patterns and naming conventions
3. **Template Helpers** - Check \_helpers.tpl for reusable functions and naming patterns
4. **Environment Strategy** - Understand how environments are handled (values-\*.yaml files,
   separate charts)
5. **Testing Approach** - Review existing test infrastructure (helm-unittest, ct, integration tests)
6. **Documentation Style** - Check README.md patterns and values.yaml comments
7. **Versioning Strategy** - Understand chart versioning and appVersion management
8. **Dependency Management** - Review how subchart dependencies are declared and versioned

When refactoring existing charts, preserve established patterns unless they conflict with critical
reliability or security requirements. Propose pattern changes through team discussion, not
unilateral refactoring.

## Chart Structure

Every Helm chart must follow the standard directory structure with complete metadata.

### Standard Chart Layout

```text
chart-name/
├── Chart.yaml           # Chart metadata (required)
├── values.yaml          # Default configuration values (required)
├── values.schema.json   # JSON schema for values validation (recommended)
├── templates/           # Template files (required)
│   ├── NOTES.txt       # Post-install usage notes (recommended)
│   ├── _helpers.tpl    # Template helpers (required)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── tests/
│       └── test-connection.yaml
├── charts/              # Chart dependencies (auto-generated)
├── crds/               # Custom Resource Definitions (if needed)
├── .helmignore         # Files to ignore when packaging
└── README.md           # Chart documentation (required)
```

### Chart.yaml Structure

Use Helm 3 format with complete metadata.

```yaml
# CORRECT: Complete Chart.yaml
apiVersion: v2
name: web-api
description: A production-ready web API Helm chart for Kubernetes
type: application
version: 1.5.2
appVersion: '2.3.1'

keywords:
  - web
  - api
  - microservice

home: https://github.com/example/web-api
sources:
  - https://github.com/example/web-api

maintainers:
  - name: Platform Team
    email: platform@example.com
    url: https://github.com/platform-team

icon: https://example.com/icon.svg

dependencies:
  - name: postgresql
    version: 12.1.9
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
    tags:
      - database

  - name: redis
    version: 17.3.7
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
    tags:
      - cache

annotations:
  category: Application
  licenses: Apache-2.0
```

```yaml
# WRONG: Minimal Chart.yaml
apiVersion: v2
name: web-api
version: 1.0.0
# Missing description, appVersion, maintainers, etc.
```

### Chart Types

| Type        | Purpose                   | Use Case         | Contains Dependencies |
| ----------- | ------------------------- | ---------------- | --------------------- |
| application | Deployable application    | Most charts      | Optional              |
| library     | Reusable template library | Shared templates | No                    |

```yaml
# CORRECT: Library chart for shared templates
apiVersion: v2
name: common-library
description: Shared template library for microservices
type: library
version: 1.0.0
```

## Values Design

The values.yaml file is the public API of your chart. Design it carefully.

### Values.yaml Principles

1. **Document Every Value** - Include inline comments explaining purpose and valid options
2. **Sensible Defaults** - Chart should work with zero configuration
3. **Prefer Flat Over Nested** - Avoid deep nesting (max 3 levels)
4. **Consistent Naming** - Use camelCase for consistency with Kubernetes
5. **Type Safety** - Use values.schema.json for validation

```yaml
# CORRECT: Well-documented values.yaml
# Default values for web-api chart.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

# -- Number of replicas for the deployment
replicaCount: 3

image:
  # -- Container image repository
  repository: example/web-api
  # -- Image pull policy
  pullPolicy: IfNotPresent
  # -- Overrides the image tag whose default is the chart appVersion
  tag: ''

# -- Image pull secrets for private registries
imagePullSecrets: []

# -- Override the chart name
nameOverride: ''

# -- Override the full release name
fullnameOverride: ''

serviceAccount:
  # -- Specifies whether a service account should be created
  create: true
  # -- Annotations to add to the service account
  annotations: {}
  # -- The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ''

# -- Annotations to add to the pod
podAnnotations: {}

# -- Pod security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  seccompProfile:
    type: RuntimeDefault

# -- Container security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 1000

service:
  # -- Service type (ClusterIP, NodePort, LoadBalancer)
  type: ClusterIP
  # -- Service port
  port: 80
  # -- Target container port
  targetPort: 8080
  # -- Annotations for the service
  annotations: {}

ingress:
  # -- Enable ingress
  enabled: false
  # -- Ingress class name
  className: nginx
  # -- Ingress annotations
  annotations: {}
    # cert-manager.io/cluster-issuer: letsencrypt-prod
    # nginx.ingress.kubernetes.io/rate-limit: "100"
  # -- Ingress hosts configuration
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  # -- Ingress TLS configuration
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

# -- Container resources
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  # -- Enable horizontal pod autoscaling
  enabled: false
  # -- Minimum number of replicas
  minReplicas: 2
  # -- Maximum number of replicas
  maxReplicas: 10
  # -- Target CPU utilization percentage
  targetCPUUtilizationPercentage: 80
  # -- Target memory utilization percentage
  targetMemoryUtilizationPercentage: 80

# -- Node selector for pod assignment
nodeSelector: {}

# -- Tolerations for pod assignment
tolerations: []

# -- Affinity rules for pod assignment
affinity: {}

# Application-specific configuration
config:
  # -- Application log level (DEBUG, INFO, WARN, ERROR)
  logLevel: INFO
  # -- Enable debug mode
  debug: false
  # -- Database connection settings
  database:
    # -- Database host
    host: postgres
    # -- Database port
    port: 5432
    # -- Database name
    name: appdb
    # -- Database user
    user: appuser
  # -- Redis cache settings
  cache:
    # -- Enable caching
    enabled: true
    # -- Redis host
    host: redis
    # -- Redis port
    port: 6379

# Secret values (use external secret management in production)
secrets:
  # -- Database password (should be overridden)
  databasePassword: ''
  # -- API key (should be overridden)
  apiKey: ''

# Dependency chart configurations
postgresql:
  # -- Enable PostgreSQL subchart
  enabled: true
  auth:
    database: appdb
    username: appuser
    password: changeme

redis:
  # -- Enable Redis subchart
  enabled: true
  auth:
    enabled: false
```

```yaml
# WRONG: Poorly documented, deeply nested values
replicas: 3
img:
  repo: example/api
  tag: latest
svc:
  t: ClusterIP
  p: 80
db:
  settings:
    connection:
      primary:
        host: postgres # Too deeply nested
```

### Environment-Specific Values

Use separate values files for different environments.

```yaml
# values-dev.yaml
replicaCount: 1

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

config:
  logLevel: DEBUG
  debug: true

postgresql:
  enabled: true
  primary:
    persistence:
      enabled: false # Faster for dev

ingress:
  enabled: true
  hosts:
    - host: api.dev.example.com
      paths:
        - path: /
          pathType: Prefix
```

```yaml
# values-prod.yaml
replicaCount: 5

resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi

config:
  logLevel: INFO
  debug: false

postgresql:
  enabled: false # Use external managed database

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: '1000'
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com
```

### Values Schema Validation

Add values.schema.json for type safety and validation.

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["replicaCount", "image", "service"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "description": "Number of replicas"
    },
    "image": {
      "type": "object",
      "required": ["repository", "pullPolicy"],
      "properties": {
        "repository": {
          "type": "string",
          "description": "Container image repository"
        },
        "tag": {
          "type": "string",
          "description": "Image tag"
        },
        "pullPolicy": {
          "type": "string",
          "enum": ["Always", "IfNotPresent", "Never"],
          "description": "Image pull policy"
        }
      }
    },
    "service": {
      "type": "object",
      "required": ["type", "port"],
      "properties": {
        "type": {
          "type": "string",
          "enum": ["ClusterIP", "NodePort", "LoadBalancer"],
          "description": "Service type"
        },
        "port": {
          "type": "integer",
          "minimum": 1,
          "maximum": 65535,
          "description": "Service port"
        }
      }
    },
    "resources": {
      "type": "object",
      "properties": {
        "limits": {
          "type": "object",
          "properties": {
            "cpu": { "type": "string" },
            "memory": { "type": "string" }
          }
        },
        "requests": {
          "type": "object",
          "properties": {
            "cpu": { "type": "string" },
            "memory": { "type": "string" }
          }
        }
      }
    }
  }
}
```

## Template Patterns

Write maintainable, reusable templates using Helm best practices.

### Template Helpers (\_helpers.tpl)

Define reusable template functions in \_helpers.tpl.

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "web-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "web-api.fullname" -}}
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
{{- define "web-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "web-api.labels" -}}
helm.sh/chart: {{ include "web-api.chart" . }}
{{ include "web-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "web-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "web-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "web-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "web-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "web-api.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Return the database host
*/}}
{{- define "web-api.databaseHost" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" .Release.Name }}
{{- else }}
{{- .Values.config.database.host }}
{{- end }}
{{- end }}
```

### Using Template Functions

```yaml
# CORRECT: Using include with nindent for proper indentation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "web-api.fullname" . }}
  labels:
    {{- include "web-api.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "web-api.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "web-api.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "web-api.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        image: {{ include "web-api.image" . }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        env:
        - name: DATABASE_HOST
          value: {{ include "web-api.databaseHost" . }}
        - name: LOG_LEVEL
          value: {{ .Values.config.logLevel }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

```yaml
# WRONG: Using template instead of include
apiVersion: apps/v1
kind: Deployment
metadata:
  name: { { template "web-api.fullname" . } }
  labels:
    # Can't use nindent with template, indentation breaks
    { { template "web-api.labels" . } }
```

### Conditional Resources

Use if/else blocks to make resources optional.

```yaml
# CORRECT: Conditional ingress resource
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "web-api.fullname" . }}
  labels:
    {{- include "web-api.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "web-api.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
```

### Structured Value Injection

Use toYaml for complex nested structures.

```yaml
# CORRECT: Clean injection of complex values
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "web-api.fullname" . }}
spec:
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
```

```yaml
# WRONG: Manual iteration of unknown structure
spec:
  nodeSelector:
    {{- range $key, $value := .Values.nodeSelector }}
    {{ $key }}: {{ $value }}
    {{- end }}
  # Breaks with complex values
```

## Chart Dependencies

Manage dependencies declaratively in Chart.yaml.

### Declaring Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: 12.1.9
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
    tags:
      - database

  - name: redis
    version: 17.3.7
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
    tags:
      - cache

  - name: common
    version: 1.0.0
    repository: https://charts.example.com
    # No condition - always included (library chart)

  - name: monitoring
    version: 2.0.0
    repository: https://charts.example.com
    condition: monitoring.enabled
    alias: metrics # Rename to avoid conflicts
```

### Conditional Dependencies

Control dependencies through values.yaml.

```yaml
# values.yaml
postgresql:
  enabled: true
  auth:
    database: appdb
    username: appuser
    password: changeme
  primary:
    persistence:
      enabled: true
      size: 10Gi

redis:
  enabled: true
  auth:
    enabled: false
  master:
    persistence:
      enabled: false

monitoring:
  enabled: false
```

### Multiple Instances with Alias

```yaml
# Chart.yaml - Multiple databases
dependencies:
  - name: postgresql
    version: 12.1.9
    repository: https://charts.bitnami.com/bitnami
    condition: primaryDb.enabled
    alias: primaryDb

  - name: postgresql
    version: 12.1.9
    repository: https://charts.bitnami.com/bitnami
    condition: analyticsDb.enabled
    alias: analyticsDb
```

```yaml
# values.yaml
primaryDb:
  enabled: true
  auth:
    database: primary
    username: app

analyticsDb:
  enabled: true
  auth:
    database: analytics
    username: readonly
```

### Dependency Management Commands

```bash
# Update dependencies (download charts to charts/ directory)
helm dependency update

# List dependencies and their status
helm dependency list

# Build dependencies (package charts/ into .tgz)
helm dependency build
```

## Chart Testing

Implement comprehensive testing for chart reliability.

### Helm Template Testing

```bash
# Render templates locally
helm template my-release ./web-api

# Render with specific values
helm template my-release ./web-api -f values-prod.yaml

# Debug rendering issues
helm template my-release ./web-api --debug

# Validate against Kubernetes API
helm template my-release ./web-api | kubectl apply --dry-run=server -f -
```

### Helm Lint

```bash
# Lint chart for issues
helm lint ./web-api

# Lint with specific values
helm lint ./web-api -f values-prod.yaml

# Strict linting
helm lint ./web-api --strict
```

### Chart Testing (ct)

Use chart-testing for comprehensive validation in CI/CD.

```yaml
# ct.yaml configuration
chart-dirs:
  - charts
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
helm-extra-args: --timeout 600s
validate-maintainers: true
check-version-increment: true
debug: true
```

```bash
# Install ct
pip install yamale yamllint
curl -Lo ct.tar.gz https://github.com/helm/chart-testing/releases/download/v3.8.0/chart-testing_3.8.0_linux_amd64.tar.gz
tar -xzf ct.tar.gz

# Lint charts
ct lint --config ct.yaml

# Install and test charts
ct install --config ct.yaml

# Test changed charts only (in CI)
ct lint --config ct.yaml --target-branch main
ct install --config ct.yaml --target-branch main
```

### Helm Unittest

Write unit tests for templates.

```yaml
# tests/deployment_test.yaml
suite: test deployment
templates:
  - deployment.yaml
tests:
  - it: should create deployment with correct name
    set:
      replicaCount: 3
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: metadata.name
          value: RELEASE-NAME-web-api

  - it: should set correct replica count
    set:
      replicaCount: 5
    asserts:
      - equal:
          path: spec.replicas
          value: 5

  - it: should include security context
    asserts:
      - isNotEmpty:
          path: spec.template.spec.securityContext
      - equal:
          path: spec.template.spec.securityContext.runAsNonRoot
          value: true

  - it: should set resource limits
    asserts:
      - isNotEmpty:
          path: spec.template.spec.containers[0].resources.limits
      - equal:
          path: spec.template.spec.containers[0].resources.limits.cpu
          value: 1000m

  - it: should not create ingress by default
    template: ingress.yaml
    asserts:
      - hasDocuments:
          count: 0

  - it: should create ingress when enabled
    template: ingress.yaml
    set:
      ingress.enabled: true
      ingress.hosts[0].host: example.com
      ingress.hosts[0].paths[0].path: /
      ingress.hosts[0].paths[0].pathType: Prefix
    asserts:
      - hasDocuments:
          count: 1
      - isKind:
          of: Ingress
```

```bash
# Install helm-unittest plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run tests
helm unittest ./web-api

# Run with coverage
helm unittest -f 'tests/**/*_test.yaml' ./web-api
```

### Helm Test Resources

Create test resources for post-install validation.

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "web-api.fullname" . }}-test-connection"
  labels:
    {{- include "web-api.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: wget
    image: busybox:1.36
    command: ['wget']
    args: ['{{ include "web-api.fullname" . }}:{{ .Values.service.port }}']
```

```bash
# Install chart
helm install my-release ./web-api

# Run tests
helm test my-release

# View test logs
kubectl logs -l helm.sh/hook=test
```

## Documentation

Every chart must have comprehensive documentation.

### README.md Structure

````markdown
# Web API Helm Chart

A production-ready Helm chart for deploying the Web API microservice.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure (when using persistence)

## Installing the Chart

```bash
helm repo add example https://charts.example.com
helm repo update
helm install my-release example/web-api
```

## Uninstalling the Chart

```bash
helm uninstall my-release
```

## Parameters

### Global Parameters

| Name               | Description                              | Value             |
| ------------------ | ---------------------------------------- | ----------------- |
| `replicaCount`     | Number of replicas                       | `3`               |
| `image.repository` | Container image repository               | `example/web-api` |
| `image.pullPolicy` | Image pull policy                        | `IfNotPresent`    |
| `image.tag`        | Image tag (defaults to chart appVersion) | `""`              |

### Service Parameters

| Name                 | Description    | Value       |
| -------------------- | -------------- | ----------- |
| `service.type`       | Service type   | `ClusterIP` |
| `service.port`       | Service port   | `80`        |
| `service.targetPort` | Container port | `8080`      |

### Configuration Examples

#### Production Deployment

```yaml
replicaCount: 5

resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 1000m
    memory: 2Gi

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20

postgresql:
  enabled: false

config:
  database:
    host: postgres.production.svc.cluster.local
```

#### Development Deployment

```yaml
replicaCount: 1

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

postgresql:
  enabled: true
```

## Upgrading

### From 1.x to 2.x

Version 2.0 introduces breaking changes:

- Values structure reorganized
- Security context now required
- PostgreSQL dependency updated

See [CHANGELOG.md](CHANGELOG.md) for details.

## License

Apache 2.0
````

## Chart Versioning

Follow semantic versioning for charts.

### Version Strategy

| Change Type     | Version Increment      | Example            |
| --------------- | ---------------------- | ------------------ |
| Breaking change | Major (1.0.0 -> 2.0.0) | Values restructure |
| New feature     | Minor (1.0.0 -> 1.1.0) | Add autoscaling    |
| Bug fix         | Patch (1.0.0 -> 1.0.1) | Fix template error |

### Chart vs App Version

- **Chart version** - Version of the Helm chart itself
- **App version** - Version of the application being deployed

```yaml
# Chart.yaml
version: 1.5.2 # Chart version
appVersion: '2.3.1' # Application version
```

## Best Practices Summary

- [ ] Chart.yaml includes all required metadata
- [ ] values.yaml has comments for every value
- [ ] values.schema.json validates input
- [ ] \_helpers.tpl defines reusable functions
- [ ] Templates use `include` not `template`
- [ ] Complex values use `toYaml | nindent`
- [ ] Dependencies declared in Chart.yaml
- [ ] Tests exist in templates/tests/
- [ ] README.md documents all parameters
- [ ] Chart passes `helm lint --strict`
- [ ] Templates validated with kubeconform
- [ ] Unit tests cover critical templates
- [ ] Versioning follows semver

Apply these patterns consistently to create maintainable, production-ready Helm charts.
