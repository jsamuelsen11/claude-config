---
name: docker-conventions
description:
  This skill should be used when working with Docker, writing Dockerfiles, configuring Docker
  Compose, building container images, or reviewing Docker configuration.
version: 0.1.0
---

# Docker Conventions and Best Practices

This skill defines conventions for writing Dockerfiles, organizing container images, and managing
Docker configurations. Following these conventions ensures consistent, maintainable, and efficient
container images across all projects.

## Existing Repository Compatibility

When working in established repositories, always respect existing Docker conventions and patterns.
If the repository has established Dockerfile patterns, base image choices, or build workflows,
maintain consistency with those practices. Only introduce new conventions when explicitly requested
or when modernizing legacy configurations. This principle applies to instruction ordering, BuildKit
feature usage, base image selection, and layer optimization strategies.

## Dockerfile Instruction Ordering

Proper instruction ordering maximizes layer caching and build performance.

### Standard Ordering Pattern

```dockerfile
# CORRECT: Optimal instruction ordering
FROM node:20.11-alpine AS base

# Arguments that affect build
ARG NODE_ENV=production
ARG BUILD_DATE
ARG VERSION

# Install system dependencies (changes rarely)
RUN apk add --no-cache \
    dumb-init \
    curl \
    ca-certificates

# Set working directory
WORKDIR /app

# Copy dependency manifests (changes moderately)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application source (changes frequently)
COPY . .

# Build application if needed
RUN npm run build

# Runtime configuration
ENV NODE_ENV=production
EXPOSE 3000

# User and entrypoint
USER node
CMD ["dumb-init", "node", "dist/index.js"]
```

```dockerfile
# WRONG: Poor instruction ordering hurts caching
FROM node:20.11-alpine

# Source copied too early - invalidates cache on every code change
COPY . .

# Dependencies installed after source - rebuilds deps unnecessarily
RUN npm install

# System packages last - rebuilds everything above
RUN apk add --no-cache curl

CMD ["node", "index.js"]
```

### Layer Caching Strategy

Order instructions from least frequently changing to most frequently changing:

1. **Base image and build arguments**: FROM, ARG
2. **System dependencies**: RUN apt-get, RUN apk add
3. **Working directory**: WORKDIR
4. **Dependency manifests**: COPY package.json, COPY requirements.txt
5. **Dependency installation**: RUN npm install, RUN pip install
6. **Application source**: COPY . .
7. **Build steps**: RUN npm run build
8. **Runtime configuration**: ENV, EXPOSE
9. **Execution setup**: USER, ENTRYPOINT, CMD

## Multi-Stage Build Patterns

Multi-stage builds separate build-time dependencies from runtime dependencies, dramatically reducing
image size.

### Node.js Multi-Stage Build

```dockerfile
# CORRECT: Comprehensive multi-stage build
# Stage 1: Dependencies
FROM node:20.11-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Build
FROM node:20.11-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && \
    npm run test

# Stage 3: Runtime
FROM node:20.11-alpine AS runtime
WORKDIR /app

# Install only runtime dependencies
RUN apk add --no-cache dumb-init

# Copy production dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy built artifacts from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Security: run as non-root
USER node

# Runtime configuration
ENV NODE_ENV=production
EXPOSE 3000

# Use exec form with init system
CMD ["dumb-init", "node", "dist/index.js"]
```

### Go Multi-Stage Build

```dockerfile
# CORRECT: Minimal Go runtime image
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags '-extldflags "-static" -s -w' \
    -o app ./cmd/server

# Stage 2: Minimal runtime with scratch or distroless
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /build/app /app

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app"]
```

### Python Multi-Stage Build

```dockerfile
# CORRECT: Python with compiled dependencies
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /build/wheels -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime

WORKDIR /app

# Install only runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built wheels and install
COPY --from=builder /build/wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && \
    rm -rf /wheels

# Copy application code
COPY . .

# Security: create and use non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Named Stages for Clarity

```dockerfile
# CORRECT: Named stages improve readability and debugging
FROM node:20-alpine AS dependencies
# ... dependency installation

FROM node:20-alpine AS builder
# ... build process

FROM node:20-alpine AS test
# ... test execution

FROM node:20-alpine AS production
# ... final runtime image
```

Build specific stages:

```bash
# Build and stop at test stage
docker build --target test -t myapp:test .

# Build production stage
docker build --target production -t myapp:prod .
```

## BuildKit Features

BuildKit provides advanced caching and secret management capabilities.

### Cache Mounts

```dockerfile
# CORRECT: Using BuildKit cache mounts
# syntax=docker/dockerfile:1.4

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# Cache npm packages across builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

COPY . .
RUN npm run build
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
```

```dockerfile
# CORRECT: Go module cache mount
# syntax=docker/dockerfile:1.4

FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.* ./

# Cache Go modules
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app .
```

### Secret Mounts

```dockerfile
# CORRECT: Using secret mounts for credentials
# syntax=docker/dockerfile:1.4

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# Access NPM token without embedding in image
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

COPY . .
```

Build with secret:

```bash
docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myapp .
```

### SSH Mounts

```dockerfile
# CORRECT: SSH mount for private repositories
# syntax=docker/dockerfile:1.4

FROM golang:1.22-alpine AS builder

# Install git and SSH client
RUN apk add --no-cache git openssh-client

# Create .ssh directory with correct permissions
RUN mkdir -p -m 0700 /root/.ssh && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts

WORKDIR /build

COPY go.* ./

# Use SSH mount to access private repos
RUN --mount=type=ssh \
    go mod download

COPY . .
RUN go build -o app .
```

Build with SSH:

```bash
docker buildx build --ssh default -t myapp .
```

### Bind Mounts for Build Context

```dockerfile
# CORRECT: Bind mount for external build artifacts
# syntax=docker/dockerfile:1.4

FROM node:20-alpine AS builder

WORKDIR /app

# Mount local node_modules for faster development builds
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .
RUN npm run build
```

## Layer Optimization

Combine related operations to minimize layers and clean up in the same layer.

### Combining RUN Commands

```dockerfile
# CORRECT: Combined and cleaned up in same layer
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

```dockerfile
# WRONG: Multiple layers with lingering cache
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y curl gnupg
RUN curl -fsSL https://example.com/setup.sh | bash
# Cache and temp files remain in image
```

### Alpine APK Best Practices

```dockerfile
# CORRECT: Alpine package installation
FROM alpine:3.19

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl && \
    rm -rf /tmp/*
```

### Debian/Ubuntu APT Best Practices

```dockerfile
# CORRECT: Debian/Ubuntu package installation
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

## Base Image Selection

Choose appropriate base images for security, size, and functionality.

### Official Images

```dockerfile
# CORRECT: Official images from trusted sources
FROM node:20.11-alpine
FROM python:3.12-slim
FROM golang:1.22-alpine
FROM nginx:1.25-alpine
FROM postgres:16-alpine
FROM redis:7.2-alpine
```

```dockerfile
# WRONG: Unverified or unclear provenance
FROM someuser/node
FROM random-org/python
```

### Version Pinning

```dockerfile
# CORRECT: Pin to specific versions
FROM node:20.11.1-alpine3.19
FROM python:3.12.2-slim-bookworm
FROM golang:1.22.1-alpine3.19
```

```dockerfile
# WRONG: Using latest or major-only tags in production
FROM node:latest
FROM python:3
FROM golang:alpine
```

### Image Variant Selection

| Variant              | Size     | Use Case                           | Security                               |
| -------------------- | -------- | ---------------------------------- | -------------------------------------- |
| `alpine`             | Smallest | Production, microservices          | High (minimal attack surface)          |
| `slim`               | Small    | Production with more compatibility | Medium                                 |
| `bookworm` / `jammy` | Large    | Development, complex dependencies  | Low (more packages)                    |
| `distroless`         | Minimal  | Production, maximum security       | Highest (no shell, no package manager) |
| `scratch`            | Tiny     | Static binaries only               | Highest (nothing but app)              |

```dockerfile
# CORRECT: Distroless for maximum security
FROM golang:1.22-alpine AS builder
WORKDIR /build
COPY . .
RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

### Multi-Platform Images

```dockerfile
# CORRECT: Platform-specific base image selection
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /build
COPY . .

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -o app .

FROM alpine:3.19
COPY --from=builder /build/app /app
CMD ["/app"]
```

Build multi-platform:

```bash
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t myapp:latest .
```

### Digest Pinning for Production

```dockerfile
# CORRECT: Pin by digest for reproducibility
FROM node:20.11-alpine@sha256:c0a3badbd8a0a760de903e00cedbca94588e609299820557e72cba2a53dbaa2c

# Document the tag for humans
# node:20.11.1-alpine3.19 as of 2024-03-15
```

## COPY vs ADD

Use COPY for most scenarios; ADD only when extracting archives.

```dockerfile
# CORRECT: Use COPY for regular files
COPY package.json package-lock.json ./
COPY src/ ./src/
COPY --chown=node:node . /app
```

```dockerfile
# CORRECT: Use ADD only for automatic extraction
ADD https://example.com/archive.tar.gz /tmp/
# Automatically extracts tar.gz

ADD rootfs.tar.xz /
# Extracts archive to root
```

```dockerfile
# WRONG: Using ADD for regular files
ADD package.json ./
ADD src/ ./src/
# Adds unnecessary magic behavior
```

## CMD vs ENTRYPOINT

Use exec form and understand the difference between CMD and ENTRYPOINT.

### Exec Form vs Shell Form

```dockerfile
# CORRECT: Exec form - no shell, clean signal handling
CMD ["node", "server.js"]
ENTRYPOINT ["python", "-m", "app"]
```

```dockerfile
# WRONG: Shell form - spawns shell, breaks signals
CMD node server.js
ENTRYPOINT python -m app
```

### ENTRYPOINT + CMD Pattern

```dockerfile
# CORRECT: ENTRYPOINT as main command, CMD as default args
FROM node:20-alpine

COPY . /app
WORKDIR /app

ENTRYPOINT ["node"]
CMD ["server.js"]

# Run default: docker run myapp
# Runs: node server.js

# Override CMD: docker run myapp worker.js
# Runs: node worker.js
```

### Using Init Systems

```dockerfile
# CORRECT: Using dumb-init for proper signal handling
FROM node:20-alpine

RUN apk add --no-cache dumb-init

COPY . /app
WORKDIR /app

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

```dockerfile
# CORRECT: Using tini
FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

ENTRYPOINT ["tini", "--"]
CMD ["python", "app.py"]
```

## .dockerignore Files

Every Dockerfile must have a corresponding .dockerignore file to exclude unnecessary files from the
build context.

### Standard .dockerignore Template

```text
# CORRECT: Comprehensive .dockerignore

# Version control
.git/
.gitignore
.gitattributes

# Dependencies
node_modules/
bower_components/
vendor/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.egg-info/
dist/
build/

# Environment files
.env
.env.*
!.env.example
*.local

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# Logs
*.log
logs/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Test and coverage
coverage/
.coverage
htmlcov/
.pytest_cache/
.tox/
test-results/
*.test
*.spec

# Documentation
*.md
!README.md
docs/

# CI/CD
.github/
.gitlab-ci.yml
.circleci/
.travis.yml
Jenkinsfile

# Docker
Dockerfile*
docker-compose*.yml
.dockerignore

# Build artifacts
*.tar.gz
*.zip
*.tgz
dist-*/
target/

# Temporary files
tmp/
temp/
*.tmp
*.bak
*.swp
```

### Language-Specific Patterns

```text
# Node.js specific
node_modules/
npm-debug.log
.npm/
.eslintcache
.node_repl_history

# Python specific
__pycache__/
*.py[cod]
*$py.class
.Python
.venv/
venv/
ENV/
pip-log.txt

# Go specific
vendor/
*.exe
*.exe~
*.dll
*.so
*.dylib

# Java specific
target/
*.class
*.jar
*.war
.gradle/
build/

# Rust specific
target/
**/*.rs.bk
Cargo.lock
```

### Selective Inclusion with Negation

```text
# Exclude all markdown except README
*.md
!README.md

# Exclude all env files except example
.env*
!.env.example

# Exclude all configs except production
config/*
!config/production.json
```

## WORKDIR Best Practices

Always set WORKDIR explicitly instead of using cd in RUN commands.

```dockerfile
# CORRECT: Explicit WORKDIR
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
CMD ["node", "server.js"]
```

```dockerfile
# WRONG: Using cd in RUN commands
FROM node:20-alpine

RUN cd /app
COPY package.json /app/
RUN cd /app && npm install
# Each RUN resets to root directory
```

### Creating WORKDIR with Permissions

```dockerfile
# CORRECT: WORKDIR with proper ownership
FROM node:20-alpine

# WORKDIR creates directory if it doesn't exist
WORKDIR /app

# Set ownership
RUN chown -R node:node /app

USER node

COPY --chown=node:node . .
```

## Security Best Practices

### Non-Root User

```dockerfile
# CORRECT: Run as non-root user
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Switch to node user (exists in official node images)
USER node

CMD ["node", "server.js"]
```

```dockerfile
# CORRECT: Create custom user
FROM alpine:3.19

RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

COPY --chown=appuser:appgroup . .

USER appuser

CMD ["./app"]
```

### Drop Capabilities

```dockerfile
# CORRECT: Minimal capabilities in docker run
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp
```

Define in Dockerfile labels:

```dockerfile
LABEL security.capabilities="NET_BIND_SERVICE"
LABEL security.no-new-privileges="true"
```

## ARG and ENV Best Practices

### ARG for Build-Time Variables

```dockerfile
# CORRECT: ARG for build-time configuration
FROM node:20-alpine AS builder

ARG NODE_ENV=production
ARG API_URL=https://api.example.com
ARG BUILD_DATE
ARG VERSION

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=${NODE_ENV}

COPY . .
RUN npm run build

# ARG values don't persist in final image
```

### ENV for Runtime Variables

```dockerfile
# CORRECT: ENV for runtime configuration
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info

COPY . .

EXPOSE ${PORT}

CMD ["node", "server.js"]
```

### Combining ARG and ENV

```dockerfile
# CORRECT: ARG to set ENV with default
FROM node:20-alpine

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

ARG VERSION=unknown
ENV APP_VERSION=${VERSION}

# Now VERSION is available at runtime
```

## Health Checks

Define health checks in Dockerfile for container orchestration.

```dockerfile
# CORRECT: HTTP health check
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

CMD ["node", "server.js"]
```

```dockerfile
# CORRECT: Using wget for health check
FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY html/ /usr/share/nginx/html/

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

EXPOSE 80
```

```dockerfile
# CORRECT: Using curl for health check
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Metadata and Labels

Use labels to document images and enable automation.

```dockerfile
# CORRECT: Comprehensive image metadata
FROM node:20-alpine

LABEL org.opencontainers.image.title="MyApp API" \
      org.opencontainers.image.description="REST API for MyApp service" \
      org.opencontainers.image.version="1.2.3" \
      org.opencontainers.image.authors="DevOps Team <devops@example.com>" \
      org.opencontainers.image.url="https://example.com" \
      org.opencontainers.image.documentation="https://docs.example.com" \
      org.opencontainers.image.source="https://github.com/org/repo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Example Corp"

WORKDIR /app

COPY . .

CMD ["node", "server.js"]
```

Use ARG for dynamic labels:

```dockerfile
ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"
```

Build with labels:

```bash
docker build \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VERSION=1.2.3 \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t myapp:1.2.3 .
```

This comprehensive guide covers Docker conventions that ensure efficient, secure, and maintainable
container images across all projects.
