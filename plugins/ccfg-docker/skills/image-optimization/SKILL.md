---
name: image-optimization
description:
  This skill should be used when optimizing Docker image size, improving build performance,
  implementing caching strategies, or hardening container security.
version: 0.1.0
---

# Docker Image Optimization and Security

This skill defines strategies for optimizing Docker image size, improving build performance,
implementing effective caching, and hardening container security. Following these practices ensures
efficient, fast, and secure container deployments.

## Existing Repository Compatibility

When working in established repositories, always respect existing optimization strategies and
security practices. If the repository has established build patterns, base image choices, or
security configurations, maintain consistency with those practices. Only introduce new optimizations
when explicitly requested or when modernizing legacy configurations. This principle applies to layer
optimization, caching strategies, security hardening, and image scanning procedures.

## Layer Minimization

Reduce the number of layers and their size for faster pulls and smaller images.

### Combining RUN Commands

```dockerfile
# CORRECT: Combined RUN commands with cleanup
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

```dockerfile
# WRONG: Separate RUN commands leave artifacts
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y curl gnupg
RUN curl -fsSL https://example.com/setup.sh | bash
RUN apt-get clean
# Each RUN creates a layer; clean doesn't remove previous layers' artifacts
```

### Multi-Stage Build Optimization

```dockerfile
# CORRECT: Multi-stage eliminates build dependencies
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Install build-only dependencies
RUN apk add --no-cache git make

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o app .

# Final stage: minimal runtime
FROM scratch

COPY --from=builder /build/app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["/app"]

# Result: ~10MB vs 500MB+ with builder stage included
```

### Chain Cleanup in Same Layer

```dockerfile
# CORRECT: Cleanup in same layer
FROM node:20-alpine

WORKDIR /app

# Download, extract, cleanup in one layer
RUN wget https://example.com/package.tar.gz && \
    tar -xzf package.tar.gz -C /usr/local && \
    rm package.tar.gz

# Install dependencies and cleanup cache in one layer
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force && \
    rm -rf /tmp/*
```

```dockerfile
# WRONG: Cleanup in separate layer doesn't reduce size
FROM node:20-alpine

WORKDIR /app

RUN wget https://example.com/package.tar.gz
RUN tar -xzf package.tar.gz -C /usr/local
RUN rm package.tar.gz
# File exists in previous layers, image size unchanged
```

## Size Reduction Strategies

### Minimal Base Images

| Base Image          | Size      | Use Case                      | Trade-offs                       |
| ------------------- | --------- | ----------------------------- | -------------------------------- |
| `scratch`           | 0 B       | Static binaries (Go, Rust)    | No shell, no debugging tools     |
| `distroless/static` | ~2 MB     | Static binaries with CA certs | No shell, no package manager     |
| `distroless/base`   | ~20 MB    | Dynamic binaries              | No shell, no package manager     |
| `alpine`            | ~7 MB     | General purpose               | musl libc (compatibility issues) |
| `-slim`             | ~40-80 MB | Good compatibility            | Debian-based                     |
| `ubuntu:22.04`      | ~80 MB    | Full compatibility            | Larger, more attack surface      |

```dockerfile
# CORRECT: Choosing appropriate base image

# Static Go binary: use scratch
FROM golang:1.22-alpine AS builder
RUN CGO_ENABLED=0 go build -o app .

FROM scratch
COPY --from=builder /build/app /app
ENTRYPOINT ["/app"]

# Dynamic binary: use distroless
FROM golang:1.22-alpine AS builder
RUN go build -o app .

FROM gcr.io/distroless/base-debian12
COPY --from=builder /build/app /app
ENTRYPOINT ["/app"]

# Complex dependencies: use alpine or slim
FROM python:3.12-slim
RUN pip install --no-cache-dir -r requirements.txt
```

### Strip Debug Symbols

```dockerfile
# CORRECT: Strip debug symbols from binaries
FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY . .

# Build with flags to strip debug info
RUN CGO_ENABLED=0 go build \
    -ldflags="-w -s" \
    -a -installsuffix cgo \
    -o app .

# -w: Omit DWARF symbol table
# -s: Omit symbol table and debug info
# Result: 30-50% smaller binary
```

```dockerfile
# CORRECT: Strip C/C++ binaries
FROM gcc:12 AS builder

WORKDIR /build

COPY . .

RUN make && \
    strip --strip-all /build/app

# Reduces size by removing debug symbols
```

### Exclude Development Dependencies

```dockerfile
# CORRECT: Install only production dependencies
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

# Install all dependencies for build
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

COPY --from=builder /app/dist ./dist

USER node
CMD ["node", "dist/index.js"]
```

```dockerfile
# CORRECT: Python production dependencies
FROM python:3.12-slim AS builder

WORKDIR /build

# Build wheels for all dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# Production stage
FROM python:3.12-slim

WORKDIR /app

# Install from pre-built wheels
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && \
    rm -rf /wheels

COPY . .

CMD ["python", "app.py"]
```

### Comprehensive .dockerignore

```text
# CORRECT: Comprehensive .dockerignore reduces context size

# Version control
.git/
.gitignore
.gitattributes

# Dependencies (installed during build)
node_modules/
vendor/
__pycache__/
*.pyc

# Build artifacts (created during build)
dist/
build/
target/
*.o
*.a

# Environment and secrets
.env
.env.*
!.env.example
*.key
*.pem

# Development files
.vscode/
.idea/
*.swp
.DS_Store

# Documentation
README.md
docs/
*.md
!API.md

# CI/CD
.github/
.gitlab-ci.yml
Jenkinsfile

# Tests
test/
tests/
spec/
*.test.js
*.spec.ts
coverage/

# Large files
*.tar
*.tar.gz
*.zip
*.log
logs/

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

Measure context size:

```bash
# Before optimization
docker build --no-cache .
# Sending build context to Docker daemon: 450MB

# After .dockerignore
docker build --no-cache .
# Sending build context to Docker daemon: 12MB
```

## Build Caching Strategies

### Instruction Ordering for Cache Hits

```dockerfile
# CORRECT: Optimal ordering for cache hits
FROM node:20-alpine

WORKDIR /app

# 1. Copy dependency files first (change rarely)
COPY package*.json ./

# 2. Install dependencies (cached unless package.json changes)
RUN npm ci --only=production && \
    npm cache clean --force

# 3. Copy source code last (changes frequently)
COPY . .

# 4. Build (only runs if source or deps change)
RUN npm run build

CMD ["node", "dist/index.js"]

# Typical development:
# - Code change: Runs steps 3-4 (fast)
# - Dependency change: Runs steps 2-4 (medium)
# - Base image change: Runs all steps (slow)
```

### BuildKit Cache Mounts

```dockerfile
# CORRECT: BuildKit cache mounts for package managers
# syntax=docker/dockerfile:1.4

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# Cache npm packages across builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

COPY . .
RUN npm run build

# Benefits:
# - npm packages cached on host
# - Faster reinstalls
# - Works across different branches
```

```dockerfile
# CORRECT: Python pip cache mount
# syntax=docker/dockerfile:1.4

FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

# Cache pip packages
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY . .

# Pip cache persists across builds
```

```dockerfile
# CORRECT: Go module cache mount
# syntax=docker/dockerfile:1.4

FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.* ./

# Cache Go modules and build cache
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app .

# Go modules and build artifacts cached
```

### CI/CD Layer Caching

```dockerfile
# CORRECT: CI-friendly caching with --cache-from
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS production

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

USER node
CMD ["node", "dist/index.js"]
```

Build with cache in CI:

```bash
# Pull previous images for cache
docker pull myapp:latest || true
docker pull myapp:deps || true
docker pull myapp:builder || true

# Build with cache
docker buildx build \
  --cache-from type=registry,ref=myapp:latest \
  --cache-from type=registry,ref=myapp:deps \
  --cache-from type=registry,ref=myapp:builder \
  --cache-to type=inline \
  --target production \
  -t myapp:${VERSION} \
  -t myapp:latest \
  --push \
  .
```

### Inline Cache Export

```bash
# CORRECT: Export cache with image
docker buildx build \
  --cache-to type=inline \
  --tag myapp:latest \
  --push \
  .

# Import cache from registry
docker buildx build \
  --cache-from type=registry,ref=myapp:latest \
  --tag myapp:new \
  .
```

### Registry Cache Backend

```bash
# CORRECT: Dedicated cache storage in registry
docker buildx build \
  --cache-from type=registry,ref=myapp:buildcache \
  --cache-to type=registry,ref=myapp:buildcache,mode=max \
  --tag myapp:latest \
  --push \
  .

# mode=max: Export all layers (larger but better cache hits)
# mode=min: Export only result layers (smaller but fewer cache hits)
```

### Local Cache Backend

```bash
# CORRECT: Local cache directory
docker buildx build \
  --cache-from type=local,src=/tmp/buildx-cache \
  --cache-to type=local,dest=/tmp/buildx-cache,mode=max \
  --tag myapp:latest \
  .

# Useful for CI systems with persistent volumes
```

## Security Hardening

### Non-Root User

```dockerfile
# CORRECT: Run as non-root user
FROM node:20-alpine

WORKDIR /app

# Install dependencies as root
COPY package*.json ./
RUN npm ci --only=production

# Copy application
COPY . .

# Switch to node user (built into official node images)
USER node

# All subsequent commands and runtime as node user
CMD ["node", "server.js"]
```

```dockerfile
# CORRECT: Create custom user
FROM alpine:3.19

# Create user and group
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Set ownership
RUN chown -R appuser:appgroup /app

# Copy with ownership
COPY --chown=appuser:appgroup . .

USER appuser

CMD ["./app"]
```

```dockerfile
# CORRECT: Distroless with non-root
FROM golang:1.22-alpine AS builder
RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /build/app /app

# nonroot user (UID 65532) built in
USER nonroot:nonroot

ENTRYPOINT ["/app"]
```

### Read-Only Root Filesystem

```dockerfile
# CORRECT: Read-only root filesystem
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Create writable temp directory
RUN mkdir -p /tmp/app && \
    chown -R node:node /tmp/app

USER node

# Application must write only to /tmp/app or mounted volumes
CMD ["node", "server.js"]
```

Run with read-only root:

```bash
docker run --read-only --tmpfs /tmp/app myapp:latest
```

In Kubernetes:

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
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
```

### Drop Capabilities

```dockerfile
# CORRECT: Document required capabilities
FROM nginx:alpine

LABEL security.capabilities="NET_BIND_SERVICE,CHOWN,SETUID,SETGID"

# Nginx needs NET_BIND_SERVICE for port 80
```

Run with minimal capabilities:

```bash
docker run \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --cap-add=CHOWN \
  --cap-add=SETUID \
  --cap-add=SETGID \
  nginx:alpine
```

In Kubernetes:

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

### No New Privileges

```dockerfile
# CORRECT: Prevent privilege escalation
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

USER node

# Prevent setuid binaries from gaining privileges
CMD ["node", "server.js"]
```

Run with no-new-privileges:

```bash
docker run --security-opt=no-new-privileges:true myapp:latest
```

In Kubernetes:

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

### CVE Scanning

```bash
# CORRECT: Scan images for vulnerabilities

# Using Docker Scout
docker scout cves myapp:latest

# Using Trivy
trivy image myapp:latest

# Using Grype
grype myapp:latest

# Using Snyk
snyk container test myapp:latest

# Fail build on high/critical vulnerabilities
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

Integrate into CI:

```yaml
# CORRECT: GitHub Actions security scanning
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:test .

      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:test
          format: sarif
          output: trivy-results.sarif
          severity: HIGH,CRITICAL
          exit-code: 1

      - name: Upload results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: trivy-results.sarif
```

### Never Embed Secrets

```dockerfile
# WRONG: Secrets in image
FROM node:20-alpine
ENV API_KEY=sk-abc123xyz789
ENV DATABASE_PASSWORD=super_secret
```

```dockerfile
# CORRECT: Secrets via environment at runtime
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

USER node

# No secrets in image
CMD ["node", "server.js"]
```

```dockerfile
# CORRECT: Secrets via BuildKit secret mount
# syntax=docker/dockerfile:1.4

FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

# Access secret during build without embedding
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY --from=builder /app/dist ./dist

USER node
CMD ["node", "dist/index.js"]
```

Build with secret:

```bash
docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myapp .
```

## Image Size Analysis

### Analyze Layer Sizes

```bash
# CORRECT: Analyze image layers
docker history myapp:latest

# Show layer sizes
docker history --human --no-trunc myapp:latest

# Use dive for detailed analysis
dive myapp:latest

# CI-friendly layer analysis
docker history --format "{{.Size}}\t{{.CreatedBy}}" myapp:latest
```

### Compare Image Sizes

```dockerfile
# Example: Optimize Python image

# BEFORE: 1.2GB
FROM python:3.12
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]

# AFTER: 150MB
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && \
    rm -rf /wheels
COPY . .
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser
CMD ["python", "app.py"]

# Savings: 87% reduction
```

### Benchmark Results

| Technique                   | Before                | After  | Savings |
| --------------------------- | --------------------- | ------ | ------- |
| Multi-stage build (Node.js) | 1.1 GB                | 180 MB | 84%     |
| Alpine base (Python)        | 950 MB                | 85 MB  | 91%     |
| Slim base (Python)          | 950 MB                | 150 MB | 84%     |
| Distroless (Go)             | 850 MB                | 12 MB  | 99%     |
| Scratch (Go static)         | 850 MB                | 8 MB   | 99%     |
| Combined RUN commands       | 500 MB                | 450 MB | 10%     |
| .dockerignore               | Build context: 450 MB | 12 MB  | 97%     |
| Strip Go binary             | 25 MB                 | 12 MB  | 52%     |

## Complete Optimization Example

```dockerfile
# CORRECT: Fully optimized Node.js application
# syntax=docker/dockerfile:1.4

# Stage 1: Dependencies
FROM node:20.11-alpine3.19 AS deps

WORKDIR /app

# Copy dependency manifests
COPY package.json package-lock.json ./

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

# Stage 2: Build
FROM node:20.11-alpine3.19 AS builder

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source
COPY . .

# Build with cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm run build && \
    npm run test

# Stage 3: Production dependencies
FROM node:20.11-alpine3.19 AS prod-deps

WORKDIR /app

COPY package.json package-lock.json ./

# Install only production dependencies
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production --prefer-offline && \
    npm cache clean --force

# Stage 4: Runtime
FROM node:20.11-alpine3.19 AS runtime

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

WORKDIR /app

# Copy production dependencies
COPY --from=prod-deps /app/node_modules ./node_modules

# Copy built artifacts
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

# Security: run as non-root
USER node

# Metadata
LABEL org.opencontainers.image.title="MyApp API" \
      org.opencontainers.image.description="Optimized production API" \
      org.opencontainers.image.version="1.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

# Runtime config
ENV NODE_ENV=production
EXPOSE 3000

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]

# Final image: ~50MB
# - Alpine base: 7MB
# - Node.js runtime: 35MB
# - Application: 8MB
```

Build optimized:

```bash
docker buildx build \
  --cache-from type=registry,ref=myapp:buildcache \
  --cache-to type=registry,ref=myapp:buildcache,mode=max \
  --target runtime \
  -t myapp:1.0.0 \
  -t myapp:latest \
  --push \
  .
```

Security scan:

```bash
trivy image --severity HIGH,CRITICAL myapp:1.0.0
```

Run hardened:

```bash
docker run \
  --read-only \
  --tmpfs /tmp \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  -p 3000:3000 \
  myapp:1.0.0
```

This comprehensive guide covers optimization strategies that ensure efficient, fast, and secure
Docker images ready for production deployment.
