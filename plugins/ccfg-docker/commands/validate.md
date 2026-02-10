---
description: >
  Run Docker configuration quality gate suite (Dockerfile lint, compose validation, security checks,
  .dockerignore verification)
argument-hint: '[--quick]'
allowed-tools: Bash(hadolint *), Bash(docker compose config *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive Docker configuration quality gate suite to ensure Dockerfiles, Docker Compose
files, and container configurations meet production standards. This command analyzes repository
artifacts to verify build best practices, security configurations, and operational readiness.

## Usage

```bash
ccfg docker validate                    # Full validation (all gates)
ccfg docker validate --quick            # Quick mode (syntax and .dockerignore only)
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Dockerfile Lint**: Base image tag pinning, COPY over ADD preference, apt-get cleanup,
   multi-stage builds, HEALTHCHECK presence, instruction ordering, hadolint integration
2. **Compose Validation**: Service definitions completeness, network configuration, volume
   declarations, depends_on with healthcheck conditions, environment variable handling, named
   networks/volumes
3. **Security Checks**: Non-root USER directive, no privileged mode, no secrets in build args or
   environment, minimal base images, COPY --chown usage
4. **.dockerignore Verification**: Presence check, .git/, node_modules/, .env, \*.log, build
   artifacts exclusion
5. **Image Provenance** (detect-and-skip): trivy/grype scanning if available, SBOM recommendations

All gates must pass for validation to succeed. In quick mode, only Dockerfile syntax (base image
pinning) and .dockerignore presence checks run. The validation operates on repository artifacts
(Dockerfiles, compose files, .dockerignore) without Docker daemon interaction by default.

## Key Rules

### Repository-Only by Default

Validation operates exclusively on repository artifacts. Never interact with the Docker daemon or
running containers unless explicitly required for future features.

```text
DEFAULT behavior:
  - Scan Dockerfile and docker-compose.yml files
  - Check .dockerignore presence and contents
  - Verify configuration syntax and conventions
  - NEVER connect to Docker daemon
  - NEVER inspect running containers
  - NEVER pull or build images
```

### Detect and Skip

If no Docker usage is detected in the repository, skip validation gracefully with an informational
message. Never fail validation on a non-Docker project.

```text
No Docker usage detected in repository.

Checked for:
  - Dockerfile, Dockerfile.*, *.dockerfile
  - docker-compose.yml, docker-compose.yaml
  - .dockerignore
  - Docker configuration in package.json or other manifests

Skipping Docker validation.
```

### Never Suggest Disabling Checks

When a check fails, suggest how to fix the issue. Never suggest disabling or skipping the check. If
a check is a false positive, suggest adding a targeted exclusion comment.

### Conventions Document

Check for Docker conventions documentation at standard locations:

```bash
docs/infra/docker-conventions.md
docs/docker-conventions.md
docs/docker.md
.docker/conventions.md
```

If found, verify it documents base image standards, multi-stage patterns, security policies, and
resource limits.

## Step-by-Step Process

### 0. Docker Usage Discovery

Before running any gates, detect whether the project uses Docker.

#### Strategy A: Dockerfile Detection

Check for Dockerfiles in the repository:

```bash
# Standard Dockerfile locations
git ls-files --cached --others --exclude-standard -- 'Dockerfile' '**/Dockerfile' \
  'Dockerfile.*' '*.dockerfile' | head -30
```

Common Dockerfile naming patterns:

```text
Dockerfile                      (standard root Dockerfile)
Dockerfile.dev                  (development variant)
Dockerfile.prod                 (production variant)
services/api/Dockerfile         (service-specific)
docker/app.dockerfile           (organized in docker/ directory)
build/Dockerfile                (build directory organization)
```

#### Strategy B: Docker Compose Detection

Search for Docker Compose files:

```bash
# Docker Compose files
git ls-files --cached --others --exclude-standard -- 'docker-compose.yml' \
  'docker-compose.yaml' 'docker-compose.*.yml' 'docker-compose.*.yaml' \
  'compose.yml' 'compose.yaml' | head -20
```

Common Docker Compose naming patterns:

```text
docker-compose.yml              (standard compose file)
docker-compose.yaml             (YAML variant)
docker-compose.dev.yml          (development override)
docker-compose.prod.yml         (production configuration)
docker-compose.test.yml         (test environment)
compose.yml                     (modern compose v2 naming)
```

#### Strategy C: .dockerignore Detection

Check for Docker ignore files:

```bash
# .dockerignore files
git ls-files --cached --others --exclude-standard -- '.dockerignore' \
  '**/.dockerignore' | head -10
```

#### Strategy D: Docker Configuration in Manifests

Search for Docker configuration in project manifests:

```bash
# package.json scripts
grep -l 'docker\|compose' package.json 2>/dev/null

# Makefile targets
grep -l '^docker\|^compose' Makefile makefile GNUmakefile 2>/dev/null

# CI/CD configuration
git ls-files --cached --others --exclude-standard -- '.github/workflows/*.yml' \
  '.gitlab-ci.yml' 'Jenkinsfile' '.circleci/config.yml' | head -10
```

**Combining results**:

```bash
# Collect all Docker usage indicators
{ strategy_a; strategy_b; strategy_c; strategy_d; } | sort -u > /tmp/docker-usage-files.txt
```

**Empty discovery**: If no Docker usage artifacts are found, report and skip:

```text
No Docker usage detected in repository.

Checked locations:
  - Dockerfile, Dockerfile.*, *.dockerfile
  - docker-compose.yml, docker-compose.yaml
  - .dockerignore
  - package.json, Makefile, CI/CD configurations

Skipping Docker validation.
```

### 1. Dockerfile Lint Gate

Verify that all Dockerfiles in the codebase follow best practices.

**Skip in quick mode**: Quick mode runs reduced checks (base image pinning only).

#### Dockerfile Discovery

Find all Dockerfiles in the repository:

```bash
# Find all Dockerfiles (excluding test fixtures and examples)
git ls-files --cached --others --exclude-standard -- 'Dockerfile' '**/Dockerfile' \
  'Dockerfile.*' '*.dockerfile' | \
  grep -v 'test\|example\|fixture\|\.bak' | head -30
```

For each discovered Dockerfile, run the following checks.

#### Check 1: Pinned Base Image Tags

Base images must use specific version tags, never `:latest`.

```bash
# Extract FROM statements
grep -n '^FROM' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

Validate base image tags:

```text
PASS: FROM node:20.11-alpine3.19
PASS: FROM golang:1.21.5-bullseye
PASS: FROM python:3.11.7-slim
PASS: FROM nginx:1.25-alpine
FAIL: FROM node:latest                 (unpinned :latest tag)
FAIL: FROM python                      (no tag specified, defaults to :latest)
FAIL: FROM ubuntu                      (no tag specified)
WARN: FROM node:20                     (partial pin, missing patch version)
```

For multi-stage builds, verify all stages use pinned tags:

```dockerfile
# Good: All stages pinned
FROM golang:1.21.5-bullseye AS builder
FROM alpine:3.19 AS runtime

# Bad: Final stage unpinned
FROM golang:1.21.5-bullseye AS builder
FROM alpine AS runtime
```

#### Check 2: COPY over ADD Preference

Prefer COPY over ADD unless ADD-specific functionality (tar extraction, URL fetch) is required.

```bash
# Find ADD instructions
grep -n '^ADD' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

```text
PASS: COPY package*.json ./
PASS: COPY . .
WARN: ADD package.json ./              (use COPY unless ADD features needed)
OK:   ADD https://example.com/file.tar.gz /tmp/  (URL fetch, ADD required)
OK:   ADD archive.tar.gz /app/         (tar extraction, ADD required)
```

#### Check 3: apt-get Best Practices

For Debian/Ubuntu base images, verify apt-get follows best practices.

```bash
# Find apt-get usage
grep -n 'apt-get\|apt ' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

Best practices for apt-get:

```dockerfile
# Good: Single RUN layer with cleanup
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Bad: Separate layers, no cleanup
RUN apt-get update
RUN apt-get install -y curl git
```

Validation checks:

```text
PASS: apt-get with --no-install-recommends flag
PASS: rm -rf /var/lib/apt/lists/* in same RUN command
FAIL: apt-get update && apt-get upgrade (breaks reproducibility)
FAIL: apt-get without cleanup (increases image size)
FAIL: Multiple RUN apt-get (inefficient layering)
```

#### Check 4: Multi-Stage Build Detection

Encourage multi-stage builds for compiled languages and build-time dependencies.

```bash
# Count FROM statements
grep -c '^FROM' Dockerfile
```

For projects with build-time dependencies, verify multi-stage usage:

```text
Node.js project:
  - If package.json includes devDependencies -> RECOMMEND multi-stage
  - If Dockerfile installs build-tools -> RECOMMEND multi-stage

Go project:
  - Single-stage with go binary -> FAIL: Use multi-stage
  - Multi-stage (builder + runtime) -> PASS

Python project:
  - If requirements.txt includes build deps -> RECOMMEND multi-stage
  - If installing gcc/build-essential -> RECOMMEND multi-stage

Java project:
  - Single-stage with Maven/Gradle -> FAIL: Use multi-stage
  - Multi-stage (build + runtime) -> PASS
```

Example multi-stage pattern:

```dockerfile
# Good: Multi-stage for Go
FROM golang:1.21.5-bullseye AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o app

FROM alpine:3.19
COPY --from=builder /build/app /usr/local/bin/app
CMD ["app"]

# Bad: Single-stage includes build tools in final image
FROM golang:1.21.5-bullseye
WORKDIR /app
COPY . .
RUN go build -o app
CMD ["./app"]
```

#### Check 5: HEALTHCHECK Presence

Production images should include HEALTHCHECK instructions.

```bash
# Check for HEALTHCHECK
grep -n '^HEALTHCHECK' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

```text
PASS: HEALTHCHECK CMD curl --fail http://localhost:8080/health || exit 1
PASS: HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
      CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
WARN: No HEALTHCHECK directive found (recommended for production images)
EXCEPTION: Base images (FROM scratch, alpine base) may skip HEALTHCHECK
```

#### Check 6: Instruction Ordering

Verify instructions are ordered for optimal layer caching.

Optimal ordering principle:

```text
1. FROM (base image)
2. ARG (build arguments that affect subsequent layers)
3. ENV (environment variables)
4. WORKDIR (working directory)
5. COPY dependency files (package.json, go.mod, requirements.txt)
6. RUN dependency installation (npm install, go mod download, pip install)
7. COPY application code
8. RUN build/compile (npm run build, go build)
9. EXPOSE (ports)
10. HEALTHCHECK
11. USER (switch to non-root user)
12. CMD/ENTRYPOINT
```

```text
WARN: COPY . . before COPY package.json (breaks cache on code changes)
WARN: RUN npm install after COPY . . (rebuilds deps on any file change)
PASS: Dependency files copied and installed before application code
```

#### Check 7: Hadolint Integration (Detect-and-Skip)

If `hadolint` is available, run it for comprehensive linting.

```bash
# Check if hadolint is available
command -v hadolint >/dev/null 2>&1
```

If available, run hadolint:

```bash
# Run hadolint on each Dockerfile
hadolint Dockerfile --no-fail --format json
```

```text
Hadolint detected: Running automated Dockerfile linting

Dockerfile:
  DL3006: Always tag the version of an image explicitly
  DL3008: Pin versions in apt-get install
  DL3009: Delete the apt-get lists after installing
  DL3015: Avoid additional packages by specifying --no-install-recommends
  DL3025: Use arguments JSON notation for CMD and ENTRYPOINT
```

If hadolint is not available, run heuristic checks only:

```text
Hadolint not found. Running heuristic checks only.
Install hadolint for comprehensive linting: https://github.com/hadolint/hadolint
```

#### Dockerfile Lint Gate Output

**Success output**:

```text
[1/5] Dockerfile Lint
  -> Scanning: 3 Dockerfiles (Dockerfile, services/api/Dockerfile, services/worker/Dockerfile)
  OK: All base images use pinned tags
  OK: COPY preferred over ADD (0 ADD instructions, 12 COPY instructions)
  OK: apt-get follows best practices (--no-install-recommends, cleanup)
  OK: Multi-stage builds detected (3/3 Dockerfiles)
  OK: HEALTHCHECK present in all production Dockerfiles
  OK: Instruction ordering optimized for layer caching
  OK: Hadolint passed (0 errors, 0 warnings)
  PASS
```

**Failure output**:

```text
[1/5] Dockerfile Lint
  -> Scanning: 3 Dockerfiles (Dockerfile, services/api/Dockerfile, services/worker/Dockerfile)
  FAIL: 2 Dockerfiles use unpinned base images
    - Dockerfile:1 FROM node:latest (use node:20.11-alpine3.19)
    - services/worker/Dockerfile:1 FROM python (use python:3.11.7-slim)
  WARN: 1 ADD instruction could be COPY
    - services/api/Dockerfile:15 ADD package.json ./ (use COPY)
  OK: apt-get follows best practices
  WARN: 1 Dockerfile missing multi-stage build
    - services/worker/Dockerfile (includes gcc, should use multi-stage)
  WARN: 2 Dockerfiles missing HEALTHCHECK
    - services/api/Dockerfile
    - services/worker/Dockerfile
  OK: Instruction ordering optimal
  Hadolint: 4 errors, 2 warnings
  FAIL (3 errors, 4 warnings)
```

### 2. Compose Validation Gate

Verify Docker Compose files follow best practices.

**Skip in quick mode**: This gate only runs in full mode.

#### Compose File Discovery

Find all Docker Compose files:

```bash
# Find all compose files
git ls-files --cached --others --exclude-standard -- 'docker-compose.yml' \
  'docker-compose.yaml' 'docker-compose.*.yml' 'docker-compose.*.yaml' \
  'compose.yml' 'compose.yaml' | head -20
```

#### Check 1: Service Definitions Complete

Verify each service has required fields:

```bash
# Validate compose file syntax
docker compose -f docker-compose.yml config --quiet 2>&1
```

If `docker compose` is not available, use heuristic checks:

```bash
# Heuristic: Check for required service fields
grep -A 20 '^  [a-z]' docker-compose.yml | grep -E 'image:|build:|container_name:'
```

```text
Required service fields:
  - image OR build (at least one required)
  - container_name (recommended for production)
  - restart (recommended: always, unless-stopped, on-failure)
  - networks (recommended: use named networks, not default)

PASS: Service "api" has image and restart policy
FAIL: Service "worker" missing restart policy
WARN: Service "db" using default network (use named networks)
```

#### Check 2: Network Configuration

Verify network definitions and service network assignments:

```yaml
# Good: Named networks with explicit definitions
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

services:
  api:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend

# Bad: Using default network
services:
  api:
    image: app:latest
  db:
    image: postgres:latest
```

```text
PASS: Named networks defined (frontend, backend)
PASS: Services explicitly assign networks
FAIL: Service "cache" not assigned to any network (uses default)
WARN: Network "backend" not marked as internal (exposed to host)
```

#### Check 3: Volume Declarations

Verify volumes are properly declared and named:

```yaml
# Good: Named volumes with declarations
volumes:
  postgres-data:
  redis-data:

services:
  db:
    volumes:
      - postgres-data:/var/lib/postgresql/data

# Bad: Anonymous volumes
services:
  db:
    volumes:
      - /var/lib/postgresql/data

# OK: Bind mounts for development
services:
  api:
    volumes:
      - ./src:/app/src  # ccfg-docker-ignore: bind-mount (development only)
```

```text
PASS: Named volumes declared (postgres-data, redis-data)
FAIL: Service "db" uses anonymous volume (use named volumes)
WARN: Service "api" uses bind mount ./src:/app/src (acceptable for dev, remove in prod)
```

#### Check 4: depends_on with Healthcheck Conditions

Verify service dependencies use healthcheck conditions:

```yaml
# Good: depends_on with service_healthy
services:
  api:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 10s
      timeout: 5s
      retries: 3

# Bad: depends_on without conditions
services:
  api:
    depends_on:
      - db
      - redis
```

```text
PASS: Service "api" uses depends_on with conditions
FAIL: Service "worker" uses depends_on without healthcheck conditions
WARN: Service "db" in depends_on but no healthcheck defined
```

#### Check 5: Environment Variable Handling

Verify no hardcoded secrets in environment variables:

```bash
# Check for hardcoded secrets
grep -n 'PASSWORD\|SECRET\|TOKEN\|KEY' docker-compose.yml docker-compose.yaml 2>/dev/null | \
  grep -v '\${.*}' | grep -v 'env_file'
```

```yaml
# Good: Environment variables from .env file or ${VAR} syntax
services:
  api:
    env_file:
      - .env
    environment:
      - DB_PASSWORD=${DB_PASSWORD}
      - API_KEY=${API_KEY}

# Bad: Hardcoded secrets
services:
  api:
    environment:
      - DB_PASSWORD=mysecretpassword
      - API_KEY=abc123xyz
```

```text
PASS: Environment variables use ${VAR} syntax or env_file
FAIL: Hardcoded secret in docker-compose.yml:23 (DB_PASSWORD=mysecretpassword)
FAIL: Hardcoded token in docker-compose.yml:24 (API_KEY=abc123xyz)
WARN: .env file in repository (ensure .env is in .gitignore)
```

Verify .env.example exists but .env is gitignored:

```bash
# Check for .env.example
ls .env.example 2>/dev/null

# Verify .env is gitignored
git check-ignore .env 2>/dev/null
```

#### Check 6: Named Networks and Volumes

Verify all networks and volumes are explicitly named:

```text
PASS: All volumes are named (postgres-data, redis-data, uploads)
PASS: All networks are named (frontend, backend, monitoring)
FAIL: Service "cache" uses default network (add to named network)
FAIL: Volume on service "logs" is anonymous (declare named volume)
```

#### Compose Validation Gate Output

**Success output**:

```text
[2/5] Compose Validation
  -> Scanning: docker-compose.yml, docker-compose.prod.yml
  OK: All services have required fields (image/build, restart, networks)
  OK: Named networks defined and used consistently
  OK: Named volumes declared for all persistent data
  OK: depends_on uses healthcheck conditions (service_healthy)
  OK: No hardcoded secrets detected (uses env_file and ${VAR})
  OK: .env.example present, .env in .gitignore
  PASS
```

**Failure output**:

```text
[2/5] Compose Validation
  -> Scanning: docker-compose.yml
  WARN: 1 service missing restart policy (worker)
  FAIL: 1 service using default network (cache)
  FAIL: 1 anonymous volume detected (db service)
  FAIL: 2 services with depends_on missing healthcheck conditions
  FAIL: 2 hardcoded secrets in environment variables
    - Line 23: DB_PASSWORD=mysecretpassword
    - Line 24: API_KEY=abc123xyz
  WARN: .env file exists but not in .gitignore
  FAIL (5 errors, 2 warnings)
```

### 3. Security Checks Gate

Verify Docker configurations follow security best practices.

**Skip in quick mode**: This gate only runs in full mode.

#### Check 1: Non-Root USER Directive

Production images must run as non-root user:

```bash
# Check for USER directive in Dockerfiles
grep -n '^USER' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

```dockerfile
# Good: Explicit non-root user
FROM node:20.11-alpine3.19
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs
CMD ["node", "server.js"]

# Bad: No USER directive (runs as root)
FROM node:20.11-alpine3.19
CMD ["node", "server.js"]

# Bad: USER root
FROM node:20.11-alpine3.19
USER root
CMD ["node", "server.js"]
```

```text
PASS: Dockerfile uses USER directive (USER nodejs)
FAIL: services/api/Dockerfile missing USER directive (runs as root)
FAIL: services/worker/Dockerfile uses USER root (line 25)
```

#### Check 2: No Privileged Mode in Compose

Services must not run in privileged mode:

```bash
# Check for privileged mode in compose files
grep -n 'privileged.*true' docker-compose.yml docker-compose.yaml 2>/dev/null
```

```yaml
# Bad: Privileged mode enabled
services:
  api:
    privileged: true

# OK: Specific capabilities instead
services:
  api:
    cap_add:
      - NET_ADMIN
```

```text
FAIL: Service "api" uses privileged mode (docker-compose.yml:15)
WARN: Service "worker" adds CAP_SYS_ADMIN (reduce capabilities if possible)
PASS: Service "db" uses no elevated privileges
```

#### Check 3: No Secrets in Build Args or Environment

Verify no secrets passed as build arguments:

```bash
# Check for secrets in build args
grep -n 'args:' docker-compose.yml docker-compose.yaml 2>/dev/null | \
  grep -A5 'PASSWORD\|SECRET\|TOKEN\|KEY'

# Check for secrets in ENV instructions
grep -n '^ENV' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null | \
  grep 'PASSWORD\|SECRET\|TOKEN\|KEY'
```

```dockerfile
# Bad: Secret in build arg
ARG GITHUB_TOKEN=ghp_abc123
RUN git clone https://${GITHUB_TOKEN}@github.com/private/repo.git

# Good: Secret from external source
# Build: docker build --secret id=github_token,src=$HOME/.github_token .
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/private/repo.git
```

```text
FAIL: Dockerfile:5 ARG GITHUB_TOKEN with hardcoded value
FAIL: docker-compose.yml:30 build arg API_KEY (use Docker secrets)
PASS: No secrets in ENV instructions
```

#### Check 4: Minimal Base Images

Encourage minimal base images (alpine, slim, distroless):

```bash
# Check base images for size optimization
grep '^FROM' Dockerfile Dockerfile.* **/Dockerfile 2>/dev/null
```

```text
Base image preferences:
  - alpine variants (node:20-alpine, python:3.11-alpine)
  - slim variants (python:3.11-slim, node:20-slim)
  - distroless (gcr.io/distroless/static-debian11)
  - scratch (for static binaries)

PASS: node:20.11-alpine3.19 (minimal alpine variant)
PASS: python:3.11.7-slim (slim variant)
WARN: golang:1.21.5-bullseye (consider alpine or distroless for final stage)
FAIL: ubuntu:latest (use minimal base image, also unpinned)
```

#### Check 5: COPY --chown Usage

When copying files as non-root user, use COPY --chown to avoid permission issues:

```dockerfile
# Good: COPY with --chown
FROM node:20.11-alpine3.19
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY --chown=nodejs:nodejs package*.json ./
USER nodejs

# Bad: COPY without --chown (requires additional RUN chown)
FROM node:20.11-alpine3.19
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY package*.json ./
RUN chown -R nodejs:nodejs /app
USER nodejs
```

```text
PASS: COPY uses --chown flag (Dockerfile:12)
WARN: COPY without --chown before USER directive (services/api/Dockerfile:18)
  Fix: COPY --chown=nodejs:nodejs package*.json ./
```

#### Security Checks Gate Output

**Success output**:

```text
[3/5] Security Checks
  -> Scanning: 3 Dockerfiles, 2 compose files
  OK: All Dockerfiles use non-root USER directive
  OK: No privileged mode in compose services
  OK: No secrets in build args or ENV instructions
  OK: Minimal base images (alpine, slim variants)
  OK: COPY --chown used consistently
  PASS
```

**Failure output**:

```text
[3/5] Security Checks
  -> Scanning: 3 Dockerfiles, 2 compose files
  FAIL: 2 Dockerfiles missing USER directive (run as root)
    - services/api/Dockerfile
    - services/worker/Dockerfile
  FAIL: 1 service uses privileged mode
    - docker-compose.yml:15 (service "api")
  FAIL: 2 secrets in build args
    - Dockerfile:5 ARG GITHUB_TOKEN
    - docker-compose.yml:30 build arg API_KEY
  WARN: 1 Dockerfile uses non-minimal base image
    - services/worker/Dockerfile:1 FROM ubuntu:latest
  WARN: 2 COPY instructions without --chown
  FAIL (5 errors, 3 warnings)
```

### 4. .dockerignore Verification Gate

Verify .dockerignore file exists and contains essential exclusions.

**Included in quick mode**: Quick mode checks .dockerignore presence.

#### Check 1: .dockerignore Presence

```bash
# Check for .dockerignore
git ls-files --cached --others --exclude-standard -- '.dockerignore' \
  '**/.dockerignore' | head -10
```

```text
PASS: .dockerignore found at repository root
FAIL: No .dockerignore file found
  Recommendation: Create .dockerignore to exclude unnecessary files from build context
  Run: ccfg docker scaffold --type=dockerignore
```

#### Check 2: Essential Exclusions

If .dockerignore exists, verify it excludes common unnecessary files:

```bash
# Read .dockerignore contents
cat .dockerignore
```

Essential exclusions:

```text
Required exclusions:
  .git/            (version control, never needed in image)
  .gitignore       (development file)
  .env             (secrets and local config)
  .env.*           (environment files)
  *.log            (log files)
  *.md             (documentation, usually not needed)
  node_modules/    (Node.js dependencies, reinstalled in image)
  __pycache__/     (Python bytecode)
  *.pyc            (Python compiled files)
  .pytest_cache/   (Python test cache)
  target/          (Rust/Java build artifacts)
  dist/            (build output)
  build/           (build output)
  .vscode/         (editor configuration)
  .idea/           (IDE configuration)

Recommended exclusions (project-specific):
  test/            (if tests not run in container)
  tests/           (if tests not run in container)
  coverage/        (test coverage reports)
  .DS_Store        (macOS metadata)
  Thumbs.db        (Windows metadata)
```

Validation:

```text
PASS: .dockerignore excludes .git/
PASS: .dockerignore excludes .env
PASS: .dockerignore excludes node_modules/
FAIL: .dockerignore missing *.log exclusion
WARN: .dockerignore missing __pycache__/ exclusion (Python project detected)
```

#### .dockerignore Verification Gate Output

**Success output**:

```text
[4/5] .dockerignore Verification
  -> Checking: .dockerignore at repository root
  OK: .dockerignore file present
  OK: Essential exclusions present (.git/, .env, node_modules/, *.log)
  OK: Python exclusions present (__pycache__/, *.pyc)
  PASS
```

**Failure output**:

```text
[4/5] .dockerignore Verification
  -> Checking: .dockerignore at repository root
  FAIL: No .dockerignore file found
    Create .dockerignore to reduce build context size and avoid leaking secrets
    Run: ccfg docker scaffold --type=dockerignore

  Recommended content:
    .git/
    .env
    .env.*
    node_modules/
    *.log
    *.md

  FAIL (1 error)
```

### 5. Image Provenance Gate (Detect-and-Skip)

Verify image security scanning and SBOM if tools are available.

**Skip in quick mode**: This gate only runs in full mode.

#### Check 1: Trivy/Grype Availability

```bash
# Check if trivy or grype is available
command -v trivy >/dev/null 2>&1
command -v grype >/dev/null 2>&1
```

If neither tool is available:

```text
[5/5] Image Provenance
  -> Security scanning tools not available (trivy, grype)
  SKIP: Install trivy or grype for automated vulnerability scanning
    - Trivy: https://github.com/aquasecurity/trivy
    - Grype: https://github.com/anchore/grype

  Recommendation: Add vulnerability scanning to CI/CD pipeline
  SKIP
```

#### Check 2: SBOM Recommendation

If provenance tools are available but images are not built, recommend SBOM generation:

```text
[5/5] Image Provenance
  -> Trivy detected but no images to scan (repository-only validation)
  Recommendation: Generate SBOM in CI/CD pipeline:
    - docker buildx build --sbom=true --output type=local,dest=./sbom .
    - trivy image --format sarif --output trivy-results.sarif image:tag

  SBOM benefits:
    - Supply chain security visibility
    - License compliance tracking
    - Vulnerability database correlation

  SKIP (no images to scan in repository-only mode)
```

#### Image Provenance Gate Output

```text
[5/5] Image Provenance
  -> Security scanning tools not detected
  SKIP: Install trivy or grype for vulnerability scanning
  Recommendation: Add SBOM generation to build pipeline
  SKIP
```

## Final Report Format

### Full Mode Report

```text
Docker Validation Report
========================

Project: my-application
Mode: Full
Date: 2024-12-15T14:30:00Z
Files scanned: 3 Dockerfiles, 2 compose files, 1 .dockerignore

[1/5] Dockerfile Lint .................. FAIL (3 errors, 4 warnings)
[2/5] Compose Validation ............... FAIL (5 errors, 2 warnings)
[3/5] Security Checks .................. FAIL (5 errors, 3 warnings)
[4/5] .dockerignore Verification ....... PASS
[5/5] Image Provenance ................. SKIP (tools not available)

Summary:
  Errors:   13
  Warnings: 9
  Status:   FAIL

Critical Errors:
  1. Dockerfile:1 - Unpinned base image (FROM node:latest)
  2. services/api/Dockerfile - Missing USER directive (runs as root)
  3. docker-compose.yml:23 - Hardcoded secret (DB_PASSWORD=mysecretpassword)
  4. docker-compose.yml:15 - Privileged mode enabled (service "api")
  5. Dockerfile:5 - Secret in build arg (ARG GITHUB_TOKEN)

Warnings:
  1. services/worker/Dockerfile - Missing HEALTHCHECK directive
  2. docker-compose.yml - Service "worker" missing restart policy
  3. services/worker/Dockerfile:1 - Non-minimal base image (ubuntu:latest)

Recommendations:
  - Pin all base image tags to specific versions
  - Add USER directive to all Dockerfiles
  - Use environment variables or Docker secrets for sensitive data
  - Remove privileged mode unless absolutely necessary
  - Add HEALTHCHECK to production Dockerfiles
  - Use minimal base images (alpine, slim, distroless)

Next Steps:
  1. Fix critical errors (unpinned images, root user, hardcoded secrets)
  2. Review Docker conventions: docs/infra/docker-conventions.md
  3. Run: ccfg docker scaffold --type=dockerfile to see best practice examples
```

### Quick Mode Report

```text
Docker Validation Report
========================

Project: my-application
Mode: Quick
Date: 2024-12-15T14:30:00Z
Files scanned: 3 Dockerfiles, 1 .dockerignore

[1/2] Dockerfile Syntax (Base Images) ... FAIL (2 errors)
[2/2] .dockerignore Presence ............. PASS

Summary:
  Errors:   2
  Warnings: 0
  Status:   FAIL

Errors:
  1. Dockerfile:1 - FROM node:latest (use node:20.11-alpine3.19)
  2. services/worker/Dockerfile:1 - FROM python (use python:3.11.7-slim)

Quick mode validates essential syntax only.
Run 'ccfg docker validate' (full mode) for comprehensive checks.
```

### Success Report (All Gates Pass)

```text
Docker Validation Report
========================

Project: my-application
Mode: Full
Date: 2024-12-15T14:30:00Z
Files scanned: 3 Dockerfiles, 2 compose files, 1 .dockerignore

[1/5] Dockerfile Lint .................. PASS
[2/5] Compose Validation ............... PASS
[3/5] Security Checks .................. PASS
[4/5] .dockerignore Verification ....... PASS
[5/5] Image Provenance ................. SKIP (tools not available)

Summary:
  Errors:   0
  Warnings: 0
  Status:   PASS

All Docker configuration checks passed!

Highlights:
  - All base images use pinned tags
  - Multi-stage builds detected for compiled languages
  - All services run as non-root users
  - Named networks and volumes configured
  - No hardcoded secrets detected
  - .dockerignore properly configured

Recommendations:
  - Install trivy or grype for vulnerability scanning
  - Document Docker conventions: docs/infra/docker-conventions.md
  - Consider adding SBOM generation to CI/CD pipeline
```

## Edge Cases and Special Handling

### Multi-Stage Dockerfile Validation

Multi-stage Dockerfiles require special handling to validate each stage:

```dockerfile
# services/api/Dockerfile
FROM node:20.11-alpine3.19 AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20.11-alpine3.19 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20.11-alpine3.19 AS runtime
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./
USER nodejs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD wget --spider http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

Validation per stage:

```text
Stage "dependencies":
  - Base image pinned: PASS
  - Minimal image: PASS
  - No USER needed (intermediate stage): OK

Stage "builder":
  - Base image pinned: PASS
  - Minimal image: PASS
  - No USER needed (intermediate stage): OK

Stage "runtime":
  - Base image pinned: PASS
  - USER directive present: PASS
  - HEALTHCHECK present: PASS
  - COPY --chown not needed (files from previous stages): OK

Overall Dockerfile: PASS
```

### Monorepo with Multiple Dockerfiles

Monorepo projects may have Dockerfiles in multiple service directories:

```text
repo/
├── services/
│   ├── api/
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   ├── worker/
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   └── frontend/
│       ├── Dockerfile
│       └── .dockerignore
├── docker-compose.yml
└── docker-compose.prod.yml
```

Validate each Dockerfile independently:

```text
Docker Validation Report (Monorepo)
====================================

Services validated: 3 (api, worker, frontend)

api (services/api/Dockerfile):
  - Dockerfile Lint: PASS
  - Security Checks: PASS
  - .dockerignore: PASS

worker (services/worker/Dockerfile):
  - Dockerfile Lint: FAIL (missing HEALTHCHECK)
  - Security Checks: PASS
  - .dockerignore: PASS

frontend (services/frontend/Dockerfile):
  - Dockerfile Lint: PASS
  - Security Checks: FAIL (no USER directive)
  - .dockerignore: PASS

Compose files:
  - docker-compose.yml: PASS
  - docker-compose.prod.yml: PASS

Overall Status: FAIL (2 services have errors)
```

### Docker Compose Override Files

Handle override files correctly:

```bash
# Validate base compose file
docker compose -f docker-compose.yml config --quiet

# Validate with override
docker compose -f docker-compose.yml -f docker-compose.override.yml config --quiet

# Validate production
docker compose -f docker-compose.yml -f docker-compose.prod.yml config --quiet
```

Report validation for each combination:

```text
Compose Validation:
  - docker-compose.yml (base): PASS
  - docker-compose.yml + docker-compose.override.yml: PASS
  - docker-compose.yml + docker-compose.prod.yml: FAIL
    Error: Service "api" in prod missing healthcheck condition

Recommendation: Ensure production overrides maintain all validation rules
```

### Development vs Production Dockerfiles

Treat development and production Dockerfiles differently:

```text
Dockerfile naming patterns:
  - Dockerfile.dev, Dockerfile.development: Relaxed validation
  - Dockerfile.prod, Dockerfile.production: Strict validation
  - Dockerfile (no suffix): Strict validation (assume production)

Relaxed rules for development Dockerfiles:
  - HEALTHCHECK: WARN instead of FAIL
  - USER directive: WARN instead of FAIL
  - Multi-stage: Not required
  - Hot-reload volumes in compose: Allowed

Example:
  Dockerfile.dev:
    - Missing HEALTHCHECK: WARN (OK for development)
    - Runs as root: WARN (OK for development convenience)
    - Bind mount ./src:/app/src: OK (development hot-reload)

  Dockerfile:
    - Missing HEALTHCHECK: FAIL
    - Runs as root: FAIL
    - Bind mount: FAIL
```

### Exclusion Comments

Allow targeted exclusion with inline comments:

```dockerfile
# ccfg-docker-ignore: unpinned-tag (base image updated frequently, latest acceptable)
FROM alpine:latest

# ccfg-docker-ignore: root-user (requires root for network configuration)
USER root

# ccfg-docker-ignore: add-command (URL fetch required, ADD appropriate)
ADD https://example.com/binary /usr/local/bin/tool
```

In docker-compose.yml:

```yaml
services:
  dev-proxy:
    # ccfg-docker-ignore: privileged (development proxy needs host network access)
    privileged: true

  api:
    # ccfg-docker-ignore: bind-mount (development hot-reload)
    volumes:
      - ./src:/app/src
```

Validation of exclusion comments:

```text
WARN: Exclusion comment without reason
  File: Dockerfile:5
  Code: # ccfg-docker-ignore: root-user
  Fix: Add reason - # ccfg-docker-ignore: root-user (requires root for network config)

WARN: Exclusion comment with weak reason
  File: Dockerfile:10
  Code: # ccfg-docker-ignore: unpinned-tag (easier to maintain)
  Issue: "easier to maintain" is not a valid reason for unpinned tags
  Fix: Use pinned tags or document specific technical requirement
```

### CI/CD Configuration Detection

If CI/CD files are detected, recommend integrating Docker validation:

```bash
# Detect CI/CD configurations
git ls-files --cached --others --exclude-standard -- \
  '.github/workflows/*.yml' '.gitlab-ci.yml' 'Jenkinsfile' \
  '.circleci/config.yml' 'azure-pipelines.yml' | head -10
```

```text
CI/CD detected: .github/workflows/docker-build.yml

Recommendation: Add Docker validation to CI/CD pipeline

GitHub Actions example:
  - name: Validate Docker configuration
    run: ccfg docker validate

  - name: Build Docker image
    run: docker build -t app:${{ github.sha }} .

  - name: Scan image with Trivy
    run: trivy image --severity HIGH,CRITICAL app:${{ github.sha }}

Fail the build if validation fails to enforce Docker best practices.
```

### Conventions Document Verification

If conventions document exists, verify it covers required topics:

```bash
# Check for Docker conventions documentation
ls docs/infra/docker-conventions.md docs/docker-conventions.md 2>/dev/null | head -1
```

If found, verify contents:

```bash
# Check conventions doc for required sections
grep -i 'base.*image\|from' docs/infra/docker-conventions.md
grep -i 'multi-stage\|multi stage' docs/infra/docker-conventions.md
grep -i 'security\|user\|root' docs/infra/docker-conventions.md
grep -i 'resource\|memory\|cpu' docs/infra/docker-conventions.md
```

```text
Conventions document found: docs/infra/docker-conventions.md

Sections present:
  OK: Base image standards
  OK: Multi-stage build patterns
  OK: Security policies (USER directive, secrets)
  WARN: Resource limits not documented

Recommendation: Add resource limits section to conventions document
```

## Exit Behavior

```text
All gates pass:              Exit with success message, no errors
Any gate has warnings only:  Exit with success message, list warnings
Any gate has errors:         Exit with failure message, list all errors and warnings
No Docker usage detected:    Exit with informational message, no errors
```
