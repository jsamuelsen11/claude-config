---
description: >
  Scaffold Dockerfiles, Docker Compose configuration, or .dockerignore for projects
argument-hint: '[--type=dockerfile|compose|dockerignore]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize Docker configuration for your project by scaffolding production-ready Dockerfiles, Docker
Compose configurations, or .dockerignore files. This command detects project language and framework,
then generates appropriate Docker configuration with security best practices, multi-stage builds,
health checks, and proper resource management.

## Usage

```bash
ccfg docker scaffold                           # Default: dockerfile
ccfg docker scaffold --type=dockerfile         # Scaffold Dockerfile for detected language
ccfg docker scaffold --type=compose            # Scaffold docker-compose.yml
ccfg docker scaffold --type=dockerignore       # Scaffold .dockerignore
```

## Overview

The scaffold command provides three essential scaffolding operations for Docker-based projects:

- **Dockerfile** (default): Detects project language and generates production-ready multi-stage
  Dockerfile with HEALTHCHECK, non-root USER, LABEL metadata, BuildKit syntax, and cache mount
  optimizations
- **Compose**: Generates docker-compose.yml with healthchecks, named networks/volumes, .env pattern,
  override file support, service profiles, and depends_on with service_healthy conditions
- **Dockerignore**: Generates .dockerignore tailored to project language and framework, excluding
  unnecessary files from build context

All scaffolded files follow security best practices, use pinned image tags (never :latest), include
placeholder values for sensitive data, and recommend conventions documentation.

## Key Rules

### Language Detection Best-Effort

Detect project language using package manifests, source file extensions, and project structure.
Never prescribe a specific stack if detection is ambiguous.

```text
Detection priority:
1. Check for language-specific manifest files (package.json, go.mod, requirements.txt, pom.xml, Cargo.toml, etc.)
2. Check for framework-specific files (next.config.js, django settings, spring application.yml, etc.)
3. Count source file extensions if manifests are ambiguous
4. If detection fails, scaffold generic Dockerfile template and ask user to specify language
```

### Pinned Image Tags Always

All scaffolded Dockerfiles use specific version tags. Never use `:latest`.

```text
Pinning strategy:
  - Node.js: node:20.11-alpine3.19 (LTS version, alpine variant)
  - Python: python:3.11.7-slim (latest stable, slim variant)
  - Go: golang:1.21.5-bullseye AS builder, alpine:3.19 AS runtime
  - Java: eclipse-temurin:21.0.1-jre-alpine (LTS, JRE-only runtime)
  - Rust: rust:1.75-alpine AS builder, alpine:3.19 AS runtime
  - .NET: mcr.microsoft.com/dotnet/sdk:8.0 AS builder, mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

When versions become outdated, provide current pinned versions in scaffolded output.
```

### No Real Secrets

All scaffolded configuration uses placeholder values for sensitive data. Real credentials must come
from environment variables or secret management systems.

```text
Placeholder values:
  - DATABASE_URL=postgresql://user:password@db:5432/dbname
  - REDIS_PASSWORD=<your-redis-password>
  - API_KEY=${API_KEY}
  - SECRET_KEY=${SECRET_KEY}

Always include .env.example with placeholders.
Never scaffold real credentials.
```

### Recommend Conventions Document

Suggest creating Docker conventions documentation if it doesn't exist:

```text
Conventions document locations to check:
  - docs/infra/docker-conventions.md
  - docs/docker-conventions.md
  - docs/docker.md

If not found, suggest:
  "Consider creating docs/infra/docker-conventions.md to document:
   - Base image standards
   - Multi-stage build patterns
   - Security policies
   - Resource limits
   - Health check requirements"
```

## Scaffold Types

### dockerfile (Default)

Generates production-ready Dockerfile for detected language with multi-stage builds, health checks,
and security best practices.

#### Step 1: Detect Project Language

Scan repository for language-specific indicators.

**Node.js Detection**:

```bash
# Check for Node.js manifest files
git ls-files --cached --others --exclude-standard -- 'package.json' '**/package.json' | head -10
```

Detect Node.js framework:

```bash
# Next.js
grep -l 'next' package.json 2>/dev/null | xargs grep '"next"'

# Express
grep -l 'express' package.json 2>/dev/null | xargs grep '"express"'

# NestJS
grep -l '@nestjs' package.json 2>/dev/null | xargs grep '"@nestjs/core"'

# Nuxt
grep -l 'nuxt' package.json 2>/dev/null | xargs grep '"nuxt"'
```

**Python Detection**:

```bash
# Check for Python dependency files
git ls-files --cached --others --exclude-standard -- \
  'requirements.txt' 'requirements*.txt' 'Pipfile' 'pyproject.toml' \
  'setup.py' 'poetry.lock' | head -10
```

Detect Python framework:

```bash
# Django
grep -l 'Django\|django' requirements.txt pyproject.toml 2>/dev/null

# Flask
grep -l 'Flask\|flask' requirements.txt pyproject.toml 2>/dev/null

# FastAPI
grep -l 'fastapi\|FastAPI' requirements.txt pyproject.toml 2>/dev/null
```

**Go Detection**:

```bash
# Check for Go modules
git ls-files --cached --others --exclude-standard -- 'go.mod' 'go.sum' | head -5
```

**Rust Detection**:

```bash
# Check for Cargo manifest
git ls-files --cached --others --exclude-standard -- 'Cargo.toml' 'Cargo.lock' | head -5
```

**Java Detection**:

```bash
# Check for Java build files
git ls-files --cached --others --exclude-standard -- \
  'pom.xml' 'build.gradle' 'build.gradle.kts' 'settings.gradle' | head -10
```

Detect Java framework:

```bash
# Spring Boot
grep -l 'spring-boot' pom.xml build.gradle 2>/dev/null

# Quarkus
grep -l 'quarkus' pom.xml build.gradle 2>/dev/null
```

**.NET Detection**:

```bash
# Check for .NET project files
git ls-files --cached --others --exclude-standard -- \
  '*.csproj' '*.fsproj' '*.vbproj' | head -10
```

**Language Priority**: If multiple languages are detected (e.g., monorepo), scaffold for the primary
language or ask user to specify.

#### Step 2: Check for Existing Dockerfile

```bash
# Check if Dockerfile already exists
ls Dockerfile Dockerfile.prod Dockerfile.production 2>/dev/null | head -1
```

If Dockerfile exists:

```text
Dockerfile already exists at repository root.

Existing Dockerfile: Dockerfile
Created: 2024-11-15
Size: 1.2KB

Options:
  1. Scaffold alternative: Dockerfile.new (review and rename manually)
  2. Scaffold service-specific: services/<service>/Dockerfile
  3. Cancel

Choose option (1-3):
```

#### Step 3: Generate Language-Specific Dockerfile

Generate production-ready multi-stage Dockerfile based on detected language.

**Node.js Dockerfile Template**:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# Build stage: Install dependencies
# ============================================================================
FROM node:20.11-alpine3.19 AS dependencies

WORKDIR /app

# Copy dependency manifests
COPY package.json package-lock.json ./

# Install production dependencies only
RUN npm ci --only=production && \
    npm cache clean --force

# ============================================================================
# Build stage: Build application
# ============================================================================
FROM node:20.11-alpine3.19 AS builder

WORKDIR /app

# Copy dependency manifests
COPY package.json package-lock.json ./

# Install all dependencies (including devDependencies)
RUN npm ci && \
    npm cache clean --force

# Copy application source
COPY . .

# Build application
RUN npm run build

# ============================================================================
# Runtime stage: Production image
# ============================================================================
FROM node:20.11-alpine3.19 AS runtime

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy production dependencies from dependencies stage
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application with dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

**Python Dockerfile Template**:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# Build stage: Install dependencies
# ============================================================================
FROM python:3.11.7-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency manifests
COPY requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# ============================================================================
# Runtime stage: Production image
# ============================================================================
FROM python:3.11.7-slim AS runtime

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy Python packages from builder
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy application source
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Add local Python packages to PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Expose port
EXPOSE 8000

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail http://localhost:8000/health || exit 1

# Start application
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Go Dockerfile Template**:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# Build stage: Compile Go binary
# ============================================================================
FROM golang:1.21.5-bullseye AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies (cached layer)
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o /build/app \
    ./cmd/server

# ============================================================================
# Runtime stage: Minimal Alpine image
# ============================================================================
FROM alpine:3.19 AS runtime

# Install CA certificates for HTTPS
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/app /app/app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/app/app", "healthcheck"]

# Start application
ENTRYPOINT ["/app/app"]
CMD ["serve"]
```

**Rust Dockerfile Template**:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# Build stage: Compile Rust binary
# ============================================================================
FROM rust:1.75-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache musl-dev

# Copy manifest files
COPY Cargo.toml Cargo.lock ./

# Create dummy main to cache dependencies
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy actual source code
COPY src ./src

# Build release binary (dependencies already cached)
RUN touch src/main.rs && \
    cargo build --release

# ============================================================================
# Runtime stage: Minimal Alpine image
# ============================================================================
FROM alpine:3.19 AS runtime

# Install CA certificates and timezone data
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/target/release/app /app/app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/app/app", "health"]

# Start application
ENTRYPOINT ["/app/app"]
```

**Java Dockerfile Template (Spring Boot)**:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# Build stage: Maven build
# ============================================================================
FROM eclipse-temurin:21.0.1-jdk-alpine AS builder

WORKDIR /build

# Copy Maven wrapper and pom.xml
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build application
RUN ./mvnw package -DskipTests -B && \
    mkdir -p target/extracted && \
    java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# ============================================================================
# Runtime stage: JRE-only Alpine image
# ============================================================================
FROM eclipse-temurin:21.0.1-jre-alpine AS runtime

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S spring && \
    adduser -S spring -u 1001

# Copy extracted layers for better caching
COPY --from=builder --chown=spring:spring /build/target/extracted/dependencies/ ./
COPY --from=builder --chown=spring:spring /build/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /build/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /build/target/extracted/application/ ./

# Switch to non-root user
USER spring

# Expose port
EXPOSE 8080

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

**Generic Dockerfile Template**:

If language detection fails:

```dockerfile
# syntax=docker/dockerfile:1.6

# ============================================================================
# TODO: Replace with appropriate base image for your language/framework
# ============================================================================
FROM alpine:3.19 AS runtime

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache <runtime-dependencies>

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001

# Copy application files
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Add metadata labels
LABEL org.opencontainers.image.source="https://github.com/<org>/<repo>" \
      org.opencontainers.image.description="<Application Description>" \
      org.opencontainers.image.licenses="MIT"

# Health check (update endpoint for your application)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider http://localhost:8080/health || exit 1

# Start application
CMD ["<your-start-command>"]
```

#### Step 4: Generate .dockerignore

Also generate corresponding .dockerignore file:

```bash
# Check if .dockerignore exists
ls .dockerignore 2>/dev/null
```

If .dockerignore doesn't exist, create it with language-specific exclusions (see dockerignore
section below).

#### Dockerfile Scaffold Output

```text
Dockerfile Scaffold
===================

Detected: Node.js (package.json found)
Framework: Express (express dependency detected)

Created files:
  + Dockerfile                 (Production multi-stage Dockerfile)
  + .dockerignore              (Build context exclusions)

Dockerfile features:
  - Multi-stage build (dependencies, builder, runtime)
  - Base image: node:20.11-alpine3.19 (pinned version, alpine variant)
  - Non-root user: nodejs (UID 1001)
  - Health check: HTTP GET /health endpoint
  - BuildKit syntax: docker/dockerfile:1.6
  - Proper signal handling: dumb-init
  - Cache optimization: Separate dependency and source copy
  - Metadata labels: OCI image spec
  - Security: No root user, minimal attack surface

Build command:
  docker build -t app:latest .

Build with cache mounts (BuildKit):
  DOCKER_BUILDKIT=1 docker build -t app:latest .

Next steps:
  1. Update health check endpoint if different from /health
  2. Update port if different from 3000
  3. Update start command in CMD if needed
  4. Add custom environment variables
  5. Run: ccfg docker validate to verify configuration
  6. Consider: ccfg docker scaffold --type=compose for orchestration
```

### compose

Generates docker-compose.yml with production-ready service definitions, health checks, named
networks and volumes.

#### Step 1: Detect Existing Services

Check if Dockerfile exists to infer service configuration:

```bash
# Check for existing Dockerfiles
git ls-files --cached --others --exclude-standard -- 'Dockerfile' '**/Dockerfile' | head -10

# Check for existing compose file
ls docker-compose.yml docker-compose.yaml 2>/dev/null | head -1
```

If compose file exists:

```text
docker-compose.yml already exists.

Options:
  1. Generate docker-compose.new.yml (review and merge manually)
  2. Update existing compose file with missing best practices
  3. Cancel

Choose option (1-3):
```

#### Step 2: Detect Services and Dependencies

Scan for common service patterns:

```bash
# Check for database usage
grep -rl 'postgresql\|postgres' --include='*.js' --include='*.py' --include='*.go' . | head -5
grep -rl 'mongodb\|mongoose' --include='*.js' --include='*.py' . | head -5
grep -rl 'mysql\|mariadb' --include='*.py' --include='*.go' . | head -5

# Check for cache usage
grep -rl 'redis\|ioredis' --include='*.js' --include='*.py' --include='*.go' . | head -5

# Check for message queue usage
grep -rl 'rabbitmq\|amqp' --include='*.js' --include='*.py' . | head -5
```

#### Step 3: Generate docker-compose.yml

Generate compose file with detected services:

```yaml
# Generated by ccfg docker scaffold --type=compose
# Docker Compose file with production-ready defaults

version: '3.9'

services:
  # =========================================================================
  # Application service
  # =========================================================================
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
    container_name: app
    restart: unless-stopped
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL:-postgresql://postgres:password@db:5432/appdb}
      - REDIS_URL=${REDIS_URL:-redis://redis:6379}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend
      - backend
    healthcheck:
      test: ['CMD', 'wget', '--spider', '-q', 'http://localhost:3000/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

  # =========================================================================
  # PostgreSQL database
  # =========================================================================
  db:
    image: postgres:16.1-alpine
    container_name: db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-postgres}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-password}
      - POSTGRES_DB=${POSTGRES_DB:-appdb}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # =========================================================================
  # Redis cache
  # =========================================================================
  redis:
    image: redis:7.2-alpine
    container_name: redis
    restart: unless-stopped
    command: >
      redis-server
        --maxmemory 256mb
        --maxmemory-policy allkeys-lfu
        --appendonly yes
        --appendfsync everysec
    volumes:
      - redis-data:/data
    networks:
      - backend
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

# ===========================================================================
# Networks
# ===========================================================================
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true # Backend network not exposed to host

# ===========================================================================
# Volumes
# ===========================================================================
volumes:
  postgres-data:
    driver: local
  redis-data:
    driver: local
```

#### Step 4: Generate docker-compose.override.yml

Create development override file:

```yaml
# docker-compose.override.yml
# Development overrides (automatically applied with docker compose up)

version: '3.9'

services:
  app:
    build:
      target: development
      args:
        - NODE_ENV=development
    environment:
      - NODE_ENV=development
      - LOG_LEVEL=debug
    volumes:
      # Hot reload: mount source code
      - ./src:/app/src:ro
      - ./package.json:/app/package.json:ro
    ports:
      # Expose debugging port
      - '9229:9229'
    command: npm run dev

  db:
    ports:
      # Expose DB port for local development tools
      - '5432:5432'

  redis:
    ports:
      # Expose Redis port for local development
      - '6379:6379'
```

#### Step 5: Generate .env.example

Create environment variables template:

```env
# =============================================================================
# Docker Compose Environment Variables
# =============================================================================

# Application
NODE_ENV=production
LOG_LEVEL=info
PORT=3000

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<your-secure-password>
POSTGRES_DB=appdb
DATABASE_URL=postgresql://postgres:<your-secure-password>@db:5432/appdb

# Redis
REDIS_URL=redis://redis:6379

# Authentication (replace with actual values)
JWT_SECRET=<your-jwt-secret>
API_KEY=<your-api-key>

# External Services
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=<your-smtp-user>
SMTP_PASSWORD=<your-smtp-password>
```

Ensure .env is in .gitignore:

```bash
# Add .env to .gitignore if not present
grep -qxF '.env' .gitignore 2>/dev/null || echo '.env' >> .gitignore
```

#### Step 6: Generate docker-compose.prod.yml

Create production override:

```yaml
# docker-compose.prod.yml
# Production overrides (use: docker compose -f docker-compose.yml -f docker-compose.prod.yml up)

version: '3.9'

services:
  app:
    image: registry.example.com/app:${VERSION:-latest}
    build:
      cache_from:
        - registry.example.com/app:latest
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=warn
    # Remove volume mounts (no hot reload in production)
    volumes: []
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  db:
    # Do not expose database port in production
    ports: []
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD} # Must be set via secrets

  redis:
    # Do not expose Redis port in production
    ports: []
```

#### Compose Scaffold Output

```text
Docker Compose Scaffold
=======================

Detected services: app (Node.js), db (PostgreSQL), redis (Redis)

Created files:
  + docker-compose.yml          (Base compose configuration)
  + docker-compose.override.yml (Development overrides, hot reload)
  + docker-compose.prod.yml     (Production overrides, no exposed ports)
  + .env.example                (Environment variables template)
  ~ .gitignore                  (Added .env exclusion)

Configuration features:
  - Named networks: frontend (public), backend (internal)
  - Named volumes: postgres-data, redis-data
  - Health checks: All services with proper healthcheck
  - depends_on: service_healthy conditions
  - Resource limits: CPU and memory limits for all services
  - Security: Backend network internal, no root users
  - Development: Hot reload volumes in override file

Usage:

  Development:
    docker compose up                    # Applies base + override automatically
    docker compose logs -f app           # View application logs

  Production:
    docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    docker compose -f docker-compose.yml -f docker-compose.prod.yml ps

  Management:
    docker compose ps                    # List running services
    docker compose exec app sh           # Shell into app container
    docker compose down                  # Stop and remove containers
    docker compose down -v               # Stop and remove containers + volumes

Next steps:
  1. Copy .env.example to .env and fill in real values
  2. Update service names and ports as needed
  3. Update health check commands for your endpoints
  4. Add additional services (nginx, workers, etc.) as needed
  5. Run: ccfg docker validate to verify configuration
  6. Consider: Adding monitoring (Prometheus, Grafana)
```

### dockerignore

Generates .dockerignore file tailored to project language and framework.

#### Step 1: Detect Project Language for .dockerignore

Use same language detection as Dockerfile scaffold:

```bash
# Detect language-specific files
ls package.json requirements.txt go.mod Cargo.toml pom.xml *.csproj 2>/dev/null
```

#### Step 2: Check for Existing .dockerignore

```bash
# Check if .dockerignore exists
ls .dockerignore 2>/dev/null
```

If .dockerignore exists:

```text
.dockerignore already exists.

Existing .dockerignore: 15 lines, 8 patterns
Created: 2024-10-05

Options:
  1. Generate .dockerignore.new (review and merge manually)
  2. Append missing patterns to existing .dockerignore
  3. Cancel

Choose option (1-3):
```

#### Step 3: Generate Language-Specific .dockerignore

**Node.js .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Dependencies (will be installed in container)
node_modules
npm-debug.log
yarn-error.log

# Environment files
.env
.env.*
!.env.example

# Build artifacts
dist
build
.next
out
.nuxt
.cache

# Testing
coverage
.nyc_output
.jest

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# Temporary files
tmp
temp
*.tmp

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files (not needed in image)
Dockerfile*
docker-compose*.yml
.dockerignore
```

**Python .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Python cache
__pycache__
*.py[cod]
*$py.class
.pytest_cache
.mypy_cache
.ruff_cache

# Virtual environments
venv
env
ENV
.venv

# Environment files
.env
.env.*
!.env.example

# Build artifacts
dist
build
*.egg-info
.eggs
*.egg

# Testing
.coverage
htmlcov
.tox
.nox

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# Jupyter
.ipynb_checkpoints
*.ipynb

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

**Go .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Go build artifacts
bin
vendor
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out

# Environment files
.env
.env.*
!.env.example

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# Testing
coverage.txt
coverage.html

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

**Rust .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Rust build artifacts
target
Cargo.lock
*.pdb

# Environment files
.env
.env.*
!.env.example

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

**Java .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Java build artifacts
target
build
bin
*.class
*.jar
*.war
*.ear

# Maven
.mvn
mvnw
mvnw.cmd

# Gradle
.gradle
gradle
gradlew
gradlew.bat

# Environment files
.env
.env.*
!.env.example

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.iml
.classpath
.project
.settings
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

**Generic .dockerignore**:

```gitignore
# Version control
.git
.gitignore
.gitattributes

# Environment files
.env
.env.*
!.env.example

# Build artifacts
dist
build
target
bin
out

# Dependencies (language-specific, reinstalled in container)
node_modules
vendor
__pycache__

# Documentation
*.md
docs
README

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
logs

# Temporary files
tmp
temp
*.tmp

# Testing
coverage
.pytest_cache
.nyc_output

# CI/CD
.github
.gitlab-ci.yml
.circleci
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml
.dockerignore
```

#### .dockerignore Scaffold Output

```text
.dockerignore Scaffold
======================

Detected: Node.js (package.json found)

Created files:
  + .dockerignore              (Build context exclusions)

Exclusions included:
  - Version control: .git, .gitignore
  - Dependencies: node_modules (will be installed in container)
  - Environment files: .env, .env.* (except .env.example)
  - Build artifacts: dist, build, .next, out
  - Testing: coverage, .jest
  - Documentation: *.md, docs, README
  - IDE files: .vscode, .idea, .DS_Store
  - Logs: *.log, logs
  - CI/CD: .github, .gitlab-ci.yml
  - Docker files: Dockerfile*, docker-compose*.yml

Benefits:
  - Reduced build context size (faster docker build)
  - Prevents leaking secrets (.env files excluded)
  - Avoids cache invalidation from irrelevant file changes
  - Cleaner images (no unnecessary files)

Verify exclusions:
  docker build --progress=plain . 2>&1 | grep "COPY"

Next steps:
  1. Review .dockerignore and adjust for your project
  2. Add project-specific exclusions
  3. Verify build context size: docker build --progress=plain .
  4. Run: ccfg docker validate to verify configuration
```

## Edge Cases and Special Handling

### Monorepo Projects

Detect monorepo structure and scaffold per-service Dockerfiles:

```bash
# Detect monorepo structure
ls packages services apps 2>/dev/null
```

If monorepo detected:

```text
Monorepo detected: packages/ and services/ directories found

Services detected:
  - services/api (Node.js, Express)
  - services/worker (Python, Celery)
  - services/frontend (Node.js, Next.js)

Scaffold location options:
  1. Root Dockerfile (multi-service build with build targets)
  2. Per-service Dockerfiles (services/api/Dockerfile, etc.)
  3. Both (root + per-service)

Recommended: Per-service Dockerfiles for independent deployment

Choose option (1-3):
```

Generate per-service Dockerfiles with service-specific context:

```yaml
# docker-compose.yml for monorepo
services:
  api:
    build:
      context: ./services/api
      dockerfile: Dockerfile
    container_name: api

  worker:
    build:
      context: ./services/worker
      dockerfile: Dockerfile
    container_name: worker

  frontend:
    build:
      context: ./services/frontend
      dockerfile: Dockerfile
    container_name: frontend
```

### Framework-Specific Optimizations

**Next.js Dockerfile**:

```dockerfile
# Next.js specific optimizations
FROM node:20.11-alpine3.19 AS dependencies
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20.11-alpine3.19 AS builder
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20.11-alpine3.19 AS runtime
WORKDIR /app
ENV NODE_ENV production
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT 3000
CMD ["node", "server.js"]
```

**Django Dockerfile**:

```dockerfile
# Django specific with static files and migrations
FROM python:3.11.7-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl && rm -rf /var/lib/apt/lists/*
RUN groupadd -r django && useradd -r -g django django
COPY --chown=django:django requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=django:django . .
RUN python manage.py collectstatic --noinput
USER django
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail http://localhost:8000/health/ || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "project.wsgi:application"]
```

### Docker Buildx and BuildKit Features

Include BuildKit syntax and cache mount optimizations in scaffolded Dockerfiles:

```dockerfile
# syntax=docker/dockerfile:1.6

FROM node:20.11-alpine3.19 AS dependencies

WORKDIR /app

# Use cache mounts for npm cache (BuildKit feature)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

# Use bind mount for package files (BuildKit feature)
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --only=production
```

Include build instructions:

```bash
# Build with BuildKit (recommended)
DOCKER_BUILDKIT=1 docker build -t app:latest .

# Or set BuildKit as default
export DOCKER_BUILDKIT=1
docker build -t app:latest .
```

### Platform-Specific Builds

For multi-platform images (amd64, arm64):

```dockerfile
# Platform-specific optimizations
FROM --platform=$BUILDPLATFORM node:20.11-alpine3.19 AS dependencies
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM"

# Multi-platform build command
docker buildx build --platform linux/amd64,linux/arm64 -t app:latest .
```

### Conventions Document Reference

After scaffolding, suggest conventions document:

```text
Docker configuration scaffolded successfully.

Next Steps:
  1. Review generated files and customize for your project
  2. Update placeholder values (ports, commands, health checks)
  3. Test build: docker build -t app:latest .
  4. Test compose: docker compose up
  5. Run validation: ccfg docker validate

Consider creating conventions document:
  Location: docs/infra/docker-conventions.md

  Topics to document:
    - Base image standards (which base images and versions to use)
    - Multi-stage build patterns (builder + runtime)
    - Security policies (non-root users, no privileged mode)
    - Resource limits (CPU, memory per service type)
    - Health check requirements (endpoints, intervals)
    - Naming conventions (container names, volume names)
    - Development vs production differences
```

### .env.example Generation

Always generate .env.example with compose scaffolding:

```env
# =============================================================================
# Environment Variables - Docker Compose
# =============================================================================
# Copy this file to .env and fill in real values
# NEVER commit .env to version control

# Application
NODE_ENV=production
APP_PORT=3000
LOG_LEVEL=info

# Database (PostgreSQL)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<your-secure-password-min-16-chars>
POSTGRES_DB=appdb
DATABASE_URL=postgresql://postgres:<password>@db:5432/appdb

# Redis
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=<your-redis-password-optional>

# Authentication
JWT_SECRET=<your-jwt-secret-min-32-chars>
JWT_EXPIRY=24h
API_KEY=<your-api-key>

# External Services
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=<your-smtp-username>
SMTP_PASSWORD=<your-smtp-password>
SMTP_FROM=noreply@example.com

# Monitoring (optional)
SENTRY_DSN=<your-sentry-dsn>

# Feature Flags
FEATURE_NEW_UI=false
FEATURE_BETA_API=false
```

Ensure .env is gitignored:

```bash
# Verify .env is in .gitignore
grep -qxF '.env' .gitignore 2>/dev/null || {
  echo '.env' >> .gitignore
  echo "Added .env to .gitignore"
}
```

## Exit Behavior

```text
All files generated successfully:  Exit with success message, list created files
File already exists:                Prompt for alternative or cancel
Language detection failed:          Generate generic template, ask user to customize
No write permission:                Exit with error, suggest running with appropriate permissions
```
