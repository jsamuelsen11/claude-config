---
name: compose-patterns
description:
  This skill should be used when designing Docker Compose services, configuring networking, managing
  volumes, or setting up multi-container applications.
version: 0.1.0
---

# Docker Compose Patterns and Best Practices

This skill defines patterns and conventions for Docker Compose configurations, including service
design, networking, volume management, health checks, and environment configuration. Following these
patterns ensures maintainable, scalable, and production-ready multi-container applications.

## Existing Repository Compatibility

When working in established repositories, always respect existing Docker Compose patterns and
conventions. If the repository has established service naming, network topology, volume strategies,
or profile organization, maintain consistency with those practices. Only introduce new patterns when
explicitly requested or when modernizing legacy configurations. This principle applies to service
structure, dependency management, networking architecture, and environment handling.

## Compose File Structure

Use Compose file version 3.8+ or the specification format for modern features.

### Standard Compose File Layout

```yaml
# CORRECT: Well-organized compose file
version: '3.9'

# Define named networks first
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge

# Define named volumes
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

# Service definitions
services:
  # Frontend services
  web:
    # Service configuration

  # Backend services
  api:
    # Service configuration

  # Data services
  database:
    # Service configuration
```

### Using Specification Format

```yaml
# CORRECT: Modern specification format (no version field)
name: myapp

services:
  web:
    image: nginx:alpine
    ports:
      - '80:80'

networks:
  default:
    name: myapp_network
```

## Service Design Principles

### One Process Per Container

```yaml
# CORRECT: Separate services for different processes
services:
  web:
    image: nginx:alpine
    ports:
      - '80:80'
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped

  app:
    build: ./app
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  worker:
    build: ./app
    command: ['node', 'worker.js']
    environment:
      - NODE_ENV=production
    restart: unless-stopped
```

```yaml
# WRONG: Multiple processes in one container
services:
  monolith:
    build: .
    # Runs nginx, app server, and worker in one container
    command: ['/bin/sh', '-c', 'nginx && node app.js && node worker.js']
```

### Restart Policies

```yaml
# CORRECT: Appropriate restart policies
services:
  # Always restart production services
  api:
    image: myapp:latest
    restart: unless-stopped

  # Never restart one-off tasks
  migration:
    image: myapp:latest
    command: ['npm', 'run', 'migrate']
    restart: 'no'

  # Restart on failure for jobs
  worker:
    image: myapp:latest
    restart: on-failure:3
```

| Policy           | Use Case                                    |
| ---------------- | ------------------------------------------- |
| `no`             | One-off tasks, migrations, data imports     |
| `on-failure`     | Jobs that should retry on error             |
| `always`         | Services that must always run (legacy)      |
| `unless-stopped` | Production services (preferred over always) |

### Sidecar Pattern

```yaml
# CORRECT: Sidecar containers for auxiliary functionality
services:
  app:
    build: ./app
    ports:
      - '8080:8080'
    networks:
      - backend

  # Sidecar: Log shipping
  log-shipper:
    image: fluent/fluentd:latest
    volumes:
      - ./fluentd/fluent.conf:/fluentd/etc/fluent.conf
      - app-logs:/var/log/app
    depends_on:
      - app
    networks:
      - backend

  # Sidecar: Metrics exporter
  metrics:
    image: prom/node-exporter:latest
    command:
      - '--path.rootfs=/host'
    volumes:
      - /:/host:ro,rslave
    depends_on:
      - app
    networks:
      - backend

volumes:
  app-logs:
```

### Init Containers Pattern

```yaml
# CORRECT: Init containers for setup tasks
services:
  # Init: Database migration
  db-migrate:
    image: myapp:latest
    command: ['npm', 'run', 'db:migrate']
    environment:
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      postgres:
        condition: service_healthy
    restart: 'no'
    profiles:
      - init

  # Main application
  app:
    image: myapp:latest
    depends_on:
      db-migrate:
        condition: service_completed_successfully
      postgres:
        condition: service_healthy
    ports:
      - '3000:3000'

  postgres:
    image: postgres:16-alpine
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5
```

## Networking Configuration

### Named Networks

```yaml
# CORRECT: Explicit named networks with clear purpose
networks:
  frontend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-frontend

  backend:
    driver: bridge
    internal: true # No external access
    driver_opts:
      com.docker.network.bridge.name: br-backend

services:
  nginx:
    image: nginx:alpine
    networks:
      - frontend

  api:
    image: myapp:latest
    networks:
      - frontend
      - backend

  database:
    image: postgres:16-alpine
    networks:
      - backend # Only accessible from backend network
```

```yaml
# WRONG: Using default network only
services:
  nginx:
    image: nginx:alpine

  api:
    image: myapp:latest

  database:
    image: postgres:16-alpine
    # All services can access database
```

### Network Aliases

```yaml
# CORRECT: Network aliases for service discovery
services:
  api-1:
    image: myapp:latest
    networks:
      backend:
        aliases:
          - api
          - api.internal

  api-2:
    image: myapp:latest
    networks:
      backend:
        aliases:
          - api
          - api.internal

  nginx:
    image: nginx:alpine
    networks:
      - backend
    # Can reach both api-1 and api-2 via 'api' alias
```

### Port Mapping

```yaml
# CORRECT: Explicit port mapping with comments
services:
  web:
    image: nginx:alpine
    ports:
      # host:container
      - '80:80' # HTTP
      - '443:443' # HTTPS
      - '127.0.0.1:8080:8080' # Admin interface (localhost only)

  api:
    image: myapp:latest
    ports:
      - '3000:3000'
    expose:
      - '3001' # Internal metrics port (not published to host)
```

```yaml
# WRONG: Mapping all ports or using imprecise ranges
services:
  web:
    image: nginx:alpine
    ports:
      - '80-90:80-90' # Too broad
    network_mode: host # Exposes all ports (security risk)
```

### Network Isolation

```yaml
# CORRECT: Frontend/backend network isolation
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

services:
  # Public-facing service
  nginx:
    image: nginx:alpine
    ports:
      - '80:80'
    networks:
      - frontend

  # API bridges both networks
  api:
    image: myapp:latest
    networks:
      - frontend
      - backend

  # Private services (backend only)
  database:
    image: postgres:16-alpine
    networks:
      - backend

  redis:
    image: redis:7-alpine
    networks:
      - backend
```

## Volume Management

### Named Volumes for Persistent Data

```yaml
# CORRECT: Named volumes for production data
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  uploads:
    driver: local

services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  api:
    image: myapp:latest
    volumes:
      - uploads:/app/uploads
```

### Bind Mounts for Development

```yaml
# CORRECT: Bind mounts in development override
# docker-compose.override.yml
services:
  api:
    volumes:
      # Source code for hot reload
      - ./src:/app/src:ro
      # Node modules from container (not host)
      - /app/node_modules

  postgres:
    volumes:
      # Local SQL scripts for development
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

```yaml
# WRONG: Bind mounts in production compose file
# docker-compose.yml
services:
  api:
    volumes:
      - ./src:/app/src # Source code should be in image
      - ./config:/app/config # Config should be in image or env vars
```

### Tmpfs for Ephemeral Data

```yaml
# CORRECT: Tmpfs for temporary data
services:
  api:
    image: myapp:latest
    tmpfs:
      - /tmp
      - /app/cache:size=100M,mode=1777

  worker:
    image: myapp:latest
    volumes:
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 512M
```

### Volume Configuration Options

```yaml
# CORRECT: Advanced volume configuration
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/postgres

  backups:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nas.example.com,rw
      device: ':/exports/backups'

services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - backups:/backups:ro
```

### Read-Only Mounts

```yaml
# CORRECT: Read-only mounts for security
services:
  web:
    image: nginx:alpine
    volumes:
      # Static content is read-only
      - ./html:/usr/share/nginx/html:ro
      # Config is read-only
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      # Cache is writable
      - nginx_cache:/var/cache/nginx

volumes:
  nginx_cache:
```

## Health Checks

Define health checks for all services with dependencies.

### HTTP Health Checks

```yaml
# CORRECT: HTTP health check with proper configuration
services:
  api:
    image: myapp:latest
    healthcheck:
      test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost:3000/health']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Command-Based Health Checks

```yaml
# CORRECT: Various health check methods
services:
  postgres:
    image: postgres:16-alpine
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 3s
      retries: 3

  mongodb:
    image: mongo:7
    healthcheck:
      test: ['CMD', 'mongosh', '--eval', "db.adminCommand('ping')"]
      interval: 15s
      timeout: 10s
      retries: 3
      start_period: 30s
```

### Health Check Dependencies

```yaml
# CORRECT: Wait for healthy dependencies
services:
  database:
    image: postgres:16-alpine
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 3s
      retries: 3

  api:
    image: myapp:latest
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'curl', '-f', 'http://localhost:3000/health']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

```yaml
# WRONG: No health checks on dependencies
services:
  api:
    image: myapp:latest
    depends_on:
      - database
      - redis
    # API may start before database is ready
```

## Service Profiles

Use profiles to organize optional services.

### Development Services

```yaml
# CORRECT: Profile-based service organization
services:
  # Core services (always run)
  api:
    image: myapp:latest
    ports:
      - '3000:3000'

  database:
    image: postgres:16-alpine
    ports:
      - '5432:5432'

  # Development tools (dev profile)
  pgadmin:
    image: dpage/pgadmin4
    ports:
      - '5050:80'
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
    profiles:
      - dev

  mailhog:
    image: mailhog/mailhog
    ports:
      - '1025:1025' # SMTP
      - '8025:8025' # Web UI
    profiles:
      - dev

  # Testing services (test profile)
  test-runner:
    image: myapp:latest
    command: ['npm', 'test']
    profiles:
      - test

  # Debugging services (debug profile)
  debugger:
    image: myapp:latest
    command: ['node', '--inspect=0.0.0.0:9229', 'server.js']
    ports:
      - '9229:9229'
    profiles:
      - debug
```

Run with profiles:

```bash
# Run core services only
docker compose up

# Run with development tools
docker compose --profile dev up

# Run with multiple profiles
docker compose --profile dev --profile test up
```

### Profile-Based Environment Separation

```yaml
# CORRECT: Environment-specific services
services:
  api:
    image: myapp:latest
    environment:
      - NODE_ENV=production

  # Local development database
  postgres-dev:
    image: postgres:16-alpine
    ports:
      - '5432:5432'
    profiles:
      - dev

  # Production-like database (no exposed ports)
  postgres-prod:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    profiles:
      - prod

volumes:
  postgres_data:
```

## Environment Management

### .env Files

```bash
# CORRECT: .env file for local development
# .env

# Application
NODE_ENV=development
API_PORT=3000
LOG_LEVEL=debug

# Database
POSTGRES_USER=myapp
POSTGRES_PASSWORD=dev_password
POSTGRES_DB=myapp_dev
DATABASE_URL=postgresql://myapp:dev_password@postgres:5432/myapp_dev

# Redis
REDIS_URL=redis://redis:6379/0

# External services
AWS_REGION=us-east-1
S3_BUCKET=myapp-dev-uploads
```

### docker-compose.override.yml

```yaml
# CORRECT: docker-compose.override.yml for local development
version: '3.9'

services:
  api:
    # Build locally instead of using image
    build:
      context: .
      target: development

    # Mount source code for hot reload
    volumes:
      - ./src:/app/src:ro
      - /app/node_modules

    # Override environment
    environment:
      - DEBUG=app:*
      - LOG_LEVEL=debug

    # Expose debugger port
    ports:
      - '9229:9229'

  postgres:
    # Expose database port for local tools
    ports:
      - '5432:5432'
```

### Environment Files Directive

```yaml
# CORRECT: Multiple env files with precedence
services:
  api:
    image: myapp:latest
    env_file:
      - .env # Common variables
      - .env.local # Local overrides (in .gitignore)
    environment:
      # Inline overrides (highest precedence)
      - NODE_ENV=production
```

### Environment Variable Interpolation

```yaml
# CORRECT: Interpolate from host environment and .env
services:
  api:
    image: myapp:${VERSION:-latest}
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - API_KEY=${API_KEY:?API_KEY is required}
      - AWS_REGION=${AWS_REGION:-us-east-1}
    ports:
      - '${API_PORT:-3000}:3000'
```

### Secret Management

```yaml
# CORRECT: Using Docker secrets (Swarm mode)
secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true

services:
  api:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key
```

```yaml
# CORRECT: Using external secret management
services:
  api:
    image: myapp:latest
    environment:
      # Fetch from AWS Secrets Manager on startup
      - SECRET_ARN=${SECRET_ARN}
    command: ['/bin/sh', '-c', 'fetch-secrets.sh && node server.js']
```

```yaml
# WRONG: Hardcoded secrets
services:
  api:
    image: myapp:latest
    environment:
      - DATABASE_PASSWORD=super_secret_123
      - API_KEY=sk-abc123xyz789
```

## Resource Limits

Define resource constraints for predictable behavior.

```yaml
# CORRECT: Resource limits and reservations
services:
  api:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  database:
    image: postgres:16-alpine
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### Memory and OOM Handling

```yaml
# CORRECT: Configure OOM behavior
services:
  redis:
    image: redis:7-alpine
    deploy:
      resources:
        limits:
          memory: 512M
    # Don't kill container on OOM, let Redis handle it
    oom_kill_disable: false
    mem_swappiness: 0
```

## Logging Configuration

```yaml
# CORRECT: Logging configuration
services:
  api:
    image: myapp:latest
    logging:
      driver: json-file
      options:
        max-size: '10m'
        max-file: '3'
        labels: 'app,environment'
        env: 'NODE_ENV'

  nginx:
    image: nginx:alpine
    logging:
      driver: syslog
      options:
        syslog-address: 'tcp://logstash:5000'
        tag: 'nginx'
```

## Extension Fields (DRY)

Use extension fields to avoid repetition.

```yaml
# CORRECT: Using extension fields
version: '3.9'

x-common-variables: &common-variables
  NODE_ENV: production
  LOG_LEVEL: info
  TZ: UTC

x-common-healthcheck: &common-healthcheck
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

x-common-resources: &common-resources
  limits:
    cpus: '1.0'
    memory: 1G
  reservations:
    cpus: '0.5'
    memory: 512M

services:
  api-1:
    image: myapp:latest
    environment:
      <<: *common-variables
      SERVICE_NAME: api-1
    healthcheck:
      <<: *common-healthcheck
      test: ['CMD', 'curl', '-f', 'http://localhost:3000/health']
    deploy:
      resources:
        <<: *common-resources

  api-2:
    image: myapp:latest
    environment:
      <<: *common-variables
      SERVICE_NAME: api-2
    healthcheck:
      <<: *common-healthcheck
      test: ['CMD', 'curl', '-f', 'http://localhost:3000/health']
    deploy:
      resources:
        <<: *common-resources
```

## Build Configuration

```yaml
# CORRECT: Build configuration with context and args
services:
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
      target: production
      args:
        - NODE_ENV=production
        - BUILD_DATE=${BUILD_DATE}
        - VERSION=${VERSION}
      cache_from:
        - myapp:latest
        - myapp:${VERSION}
      labels:
        - 'com.example.version=${VERSION}'
        - 'com.example.build-date=${BUILD_DATE}'
    image: myapp:${VERSION:-latest}
```

## Complete Example: Production-Ready Setup

```yaml
# CORRECT: Comprehensive production-ready compose file
version: '3.9'

name: myapp

# Extension fields for DRY
x-common-logging: &common-logging
  driver: json-file
  options:
    max-size: '10m'
    max-file: '3'

x-common-healthcheck: &common-healthcheck
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

# Networks
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

# Volumes
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  nginx_cache:
    driver: local

services:
  # Reverse proxy
  nginx:
    image: nginx:1.25-alpine
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_cache:/var/cache/nginx
    networks:
      - frontend
    depends_on:
      - api
    healthcheck:
      test: ['CMD', 'wget', '--quiet', '--tries=1', '--spider', 'http://localhost/health']
      <<: *common-healthcheck
    logging:
      <<: *common-logging
    restart: unless-stopped

  # Application API
  api:
    image: myapp:${VERSION:-latest}
    build:
      context: .
      target: production
      args:
        - VERSION=${VERSION}
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://myapp:${DB_PASSWORD}@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379/0
    networks:
      - frontend
      - backend
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'node', 'healthcheck.js']
      <<: *common-healthcheck
    logging:
      <<: *common-logging
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped

  # Background worker
  worker:
    image: myapp:${VERSION:-latest}
    command: ['node', 'worker.js']
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://myapp:${DB_PASSWORD}@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379/0
    networks:
      - backend
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    logging:
      <<: *common-logging
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped

  # PostgreSQL database
  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=myapp
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U myapp']
      interval: 10s
      timeout: 5s
      retries: 5
    logging:
      <<: *common-logging
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
    restart: unless-stopped

  # Redis cache
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 3s
      retries: 3
    logging:
      <<: *common-logging
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped

  # Development tools (profiles)
  pgadmin:
    image: dpage/pgadmin4
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL:-admin@example.com}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD:-admin}
    ports:
      - '5050:80'
    networks:
      - backend
    profiles:
      - dev
    restart: unless-stopped

  redis-commander:
    image: rediscommander/redis-commander:latest
    environment:
      - REDIS_HOSTS=local:redis:6379
    ports:
      - '8081:8081'
    networks:
      - backend
    depends_on:
      - redis
    profiles:
      - dev
    restart: unless-stopped
```

This comprehensive guide covers Docker Compose patterns that ensure maintainable, scalable, and
production-ready multi-container applications.
