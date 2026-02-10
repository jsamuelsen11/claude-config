---
description: >
  Scaffold Redis connection configuration or key namespace conventions for a new or existing project
argument-hint: '[--type=connection-config|namespace-setup]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize Redis connection configuration or key namespace conventions for your project. This
command detects existing Redis client libraries and scaffolds appropriate connection configuration,
or creates a comprehensive key naming conventions document.

## Usage

```bash
ccfg redis scaffold                              # Default: connection-config
ccfg redis scaffold --type=connection-config     # Connection configuration
ccfg redis scaffold --type=namespace-setup       # Key namespace conventions document
```

## Overview

The scaffold command provides two essential scaffolding operations for Redis-based projects:

- **Connection Config** (default): Detects the Redis client library in use and scaffolds connection
  configuration with pooling, retry logic, sentinel support, and cluster templates
- **Namespace Setup**: Creates a comprehensive key naming conventions document with namespace
  prefix, key hierarchy patterns, TTL policies, and naming rules

All scaffolded files follow security best practices, including proper .gitignore configuration to
prevent credential leaks and placeholder values for sensitive data.

## Key Rules

### Never Real Credentials

All scaffolded configuration uses placeholder values for sensitive data. Real credentials must come
from environment variables or secret management systems.

```text
Placeholder values used in scaffolded files:
  REDIS_URL=redis://localhost:6379          (local development default)
  REDIS_PASSWORD=<your-redis-password>      (placeholder, never real)
  REDIS_TLS_CERT=<path-to-cert>            (placeholder path)
  REDIS_SENTINEL_PASSWORD=<sentinel-pass>  (placeholder, never real)
```

### Respect Existing Libraries

If the project already uses a Redis client library, scaffold configuration for that specific
library. Never introduce a competing library.

```text
Detection priority:
1. Check dependency files for known Redis clients
2. Check import statements in source files
3. If multiple clients found, scaffold for the primary client (most imports)
4. If no client found, scaffold for the recommended client per language
```

### Respect Existing Configuration

If Redis configuration already exists, do not overwrite it. Instead, suggest additions or
improvements.

```text
If existing configuration detected:
1. Read existing configuration
2. Compare with recommended settings
3. Suggest missing settings as additions
4. Never overwrite or replace existing files without confirmation
```

## Scaffold Types

### connection-config (Default)

Creates environment-based Redis connection configuration with secure defaults, connection pooling,
retry logic, and high availability templates.

#### Step 1: Detect Client Library

Scan dependency files to identify the Redis client library in use.

**Node.js Detection**:

```bash
# Check package.json for Redis clients
git ls-files --cached --others --exclude-standard -- 'package.json' '**/package.json' | head -10
```

```text
Node.js Redis clients (detection order):
  ioredis       -> "ioredis" in dependencies
  redis         -> "redis" in dependencies (node-redis v4+)
  bullmq        -> "bullmq" in dependencies (uses ioredis internally)
```

**Python Detection**:

```bash
# Check Python dependency files
git ls-files --cached --others --exclude-standard -- \
  'requirements*.txt' 'Pipfile' 'pyproject.toml' 'setup.py' 'setup.cfg' | head -10
```

```text
Python Redis clients (detection order):
  redis         -> "redis" in requirements (redis-py)
  aioredis      -> "aioredis" in requirements (async client, merged into redis-py 4.2+)
  celery        -> "celery" with redis broker URL in configuration
```

**Go Detection**:

```bash
# Check go.mod for Redis clients
git ls-files --cached --others --exclude-standard -- 'go.mod' | head -5
```

```text
Go Redis clients (detection order):
  go-redis      -> "github.com/redis/go-redis" in go.mod
  redigo        -> "github.com/gomodule/redigo" in go.mod
```

**C#/.NET Detection**:

```bash
# Check .csproj files for Redis packages
git ls-files --cached --others --exclude-standard -- '*.csproj' '*.fsproj' | head -10
```

```text
C#/.NET Redis clients (detection order):
  StackExchange.Redis  -> PackageReference in .csproj
  Microsoft.Extensions.Caching.StackExchangeRedis -> PackageReference in .csproj
  ServiceStack.Redis   -> PackageReference in .csproj
```

**Java Detection**:

```bash
# Check Maven/Gradle for Redis dependencies
git ls-files --cached --others --exclude-standard -- 'pom.xml' 'build.gradle' \
  'build.gradle.kts' | head -10
```

```text
Java Redis clients (detection order):
  lettuce       -> "lettuce-core" in pom.xml/build.gradle
  jedis         -> "jedis" in pom.xml/build.gradle
  spring-data-redis -> "spring-boot-starter-data-redis" in dependencies
  redisson      -> "redisson" in pom.xml/build.gradle
```

#### Step 2: Scaffold Environment File

Create or update `.env.example` with Redis configuration variables.

```bash
# Check if .env.example exists
ls .env.example 2>/dev/null
```

Scaffolded `.env.example` content:

```env
# =============================================================================
# Redis Configuration
# =============================================================================

# Connection
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=<your-redis-password>
REDIS_TLS_ENABLED=false
REDIS_DB=0

# Connection Pool
REDIS_POOL_SIZE=10
REDIS_POOL_MIN_IDLE=5
REDIS_CONNECT_TIMEOUT_MS=5000
REDIS_COMMAND_TIMEOUT_MS=2000

# Retry
REDIS_RETRY_COUNT=3
REDIS_RETRY_DELAY_MS=100
REDIS_RETRY_MAX_DELAY_MS=2000

# Sentinel (uncomment for HA setup)
# REDIS_SENTINEL_HOSTS=sentinel1:26379,sentinel2:26379,sentinel3:26379
# REDIS_SENTINEL_MASTER_NAME=mymaster
# REDIS_SENTINEL_PASSWORD=<sentinel-password>

# Cluster (uncomment for cluster setup)
# REDIS_CLUSTER_NODES=node1:6379,node2:6379,node3:6379
# REDIS_CLUSTER_MAX_REDIRECTIONS=16

# TLS (uncomment for encrypted connections)
# REDIS_TLS_CERT_PATH=/path/to/redis.crt
# REDIS_TLS_KEY_PATH=/path/to/redis.key
# REDIS_TLS_CA_PATH=/path/to/ca.crt
```

Ensure `.gitignore` excludes actual `.env` file:

```bash
# Check .gitignore for .env exclusion
grep -q '^\.env$' .gitignore 2>/dev/null || echo '.env' >> .gitignore
```

#### Step 3: Scaffold Connection Configuration

Generate client-specific connection configuration.

**Node.js with ioredis**:

```typescript
// config/redis.ts
import Redis from 'ioredis';

const redisConfig = {
  host: process.env.REDIS_URL ? undefined : 'localhost',
  port: process.env.REDIS_URL ? undefined : 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: parseInt(process.env.REDIS_DB || '0', 10),
  tls: process.env.REDIS_TLS_ENABLED === 'true' ? {} : undefined,

  // Connection pool
  maxRetriesPerRequest: parseInt(process.env.REDIS_RETRY_COUNT || '3', 10),
  connectTimeout: parseInt(process.env.REDIS_CONNECT_TIMEOUT_MS || '5000', 10),
  commandTimeout: parseInt(process.env.REDIS_COMMAND_TIMEOUT_MS || '2000', 10),

  // Retry strategy with exponential backoff
  retryStrategy(times: number): number | null {
    const maxRetries = parseInt(process.env.REDIS_RETRY_COUNT || '3', 10);
    if (times > maxRetries) return null;
    const delay = Math.min(
      parseInt(process.env.REDIS_RETRY_DELAY_MS || '100', 10) * Math.pow(2, times - 1),
      parseInt(process.env.REDIS_RETRY_MAX_DELAY_MS || '2000', 10)
    );
    return delay;
  },

  // Reconnect on error
  reconnectOnError(err: Error): boolean {
    const targetErrors = ['READONLY', 'ECONNRESET', 'ETIMEDOUT'];
    return targetErrors.some((e) => err.message.includes(e));
  },

  // Enable offline queue (buffer commands while reconnecting)
  enableOfflineQueue: true,
  lazyConnect: false,
};

// Standard connection
export const redis = process.env.REDIS_URL
  ? new Redis(process.env.REDIS_URL, redisConfig)
  : new Redis(redisConfig);

// Event handlers
redis.on('connect', () => console.log('Redis connected'));
redis.on('error', (err) => console.error('Redis error:', err.message));
redis.on('close', () => console.log('Redis connection closed'));

// Sentinel connection template (uncomment for HA)
// export const redisSentinel = new Redis({
//   sentinels: (process.env.REDIS_SENTINEL_HOSTS || '').split(',').map((h) => {
//     const [host, port] = h.split(':');
//     return { host, port: parseInt(port, 10) };
//   }),
//   name: process.env.REDIS_SENTINEL_MASTER_NAME || 'mymaster',
//   sentinelPassword: process.env.REDIS_SENTINEL_PASSWORD,
//   ...redisConfig,
// });

// Cluster connection template (uncomment for cluster)
// export const redisCluster = new Redis.Cluster(
//   (process.env.REDIS_CLUSTER_NODES || '').split(',').map((n) => {
//     const [host, port] = n.split(':');
//     return { host, port: parseInt(port, 10) };
//   }),
//   {
//     redisOptions: redisConfig,
//     clusterRetryStrategy(times: number) {
//       return Math.min(100 * Math.pow(2, times), 2000);
//     },
//     maxRedirections: parseInt(process.env.REDIS_CLUSTER_MAX_REDIRECTIONS || '16', 10),
//   }
// );

export default redis;
```

**Python with redis-py**:

```python
# config/redis_client.py
import os
import redis

# Connection configuration from environment
REDIS_CONFIG = {
    'host': os.getenv('REDIS_HOST', 'localhost'),
    'port': int(os.getenv('REDIS_PORT', '6379')),
    'password': os.getenv('REDIS_PASSWORD'),
    'db': int(os.getenv('REDIS_DB', '0')),
    'decode_responses': True,

    # Connection pool
    'max_connections': int(os.getenv('REDIS_POOL_SIZE', '10')),
    'socket_connect_timeout': int(os.getenv('REDIS_CONNECT_TIMEOUT_MS', '5000')) / 1000,
    'socket_timeout': int(os.getenv('REDIS_COMMAND_TIMEOUT_MS', '2000')) / 1000,

    # Retry
    'retry_on_timeout': True,
    'retry_on_error': [redis.ConnectionError, redis.TimeoutError],
}

# TLS configuration
if os.getenv('REDIS_TLS_ENABLED', 'false').lower() == 'true':
    REDIS_CONFIG['ssl'] = True
    REDIS_CONFIG['ssl_certfile'] = os.getenv('REDIS_TLS_CERT_PATH')
    REDIS_CONFIG['ssl_keyfile'] = os.getenv('REDIS_TLS_KEY_PATH')
    REDIS_CONFIG['ssl_ca_certs'] = os.getenv('REDIS_TLS_CA_PATH')

# Standard connection pool
pool = redis.ConnectionPool(**REDIS_CONFIG)
redis_client = redis.Redis(connection_pool=pool)

# Sentinel connection template (uncomment for HA)
# from redis.sentinel import Sentinel
# sentinel_hosts = [
#     tuple(h.split(':')) for h in
#     os.getenv('REDIS_SENTINEL_HOSTS', '').split(',')
# ]
# sentinel = Sentinel(
#     [(h, int(p)) for h, p in sentinel_hosts],
#     sentinel_kwargs={'password': os.getenv('REDIS_SENTINEL_PASSWORD')},
# )
# redis_client = sentinel.master_for(
#     os.getenv('REDIS_SENTINEL_MASTER_NAME', 'mymaster'),
#     **REDIS_CONFIG,
# )

# Cluster connection template (uncomment for cluster)
# from redis.cluster import RedisCluster
# cluster_nodes = [
#     redis.cluster.ClusterNode(h, int(p)) for h, p in
#     [n.split(':') for n in os.getenv('REDIS_CLUSTER_NODES', '').split(',')]
# ]
# redis_client = RedisCluster(
#     startup_nodes=cluster_nodes,
#     password=os.getenv('REDIS_PASSWORD'),
#     decode_responses=True,
#     max_connections=int(os.getenv('REDIS_POOL_SIZE', '10')),
# )

def get_redis():
    """Get Redis client instance."""
    return redis_client

def health_check() -> bool:
    """Check Redis connectivity."""
    try:
        return redis_client.ping()
    except redis.ConnectionError:
        return False
```

**Go with go-redis**:

```go
// config/redis.go
package config

import (
	"context"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

func NewRedisClient() *redis.Client {
	poolSize, _ := strconv.Atoi(getEnv("REDIS_POOL_SIZE", "10"))
	minIdleConns, _ := strconv.Atoi(getEnv("REDIS_POOL_MIN_IDLE", "5"))
	connectTimeout, _ := strconv.Atoi(getEnv("REDIS_CONNECT_TIMEOUT_MS", "5000"))
	commandTimeout, _ := strconv.Atoi(getEnv("REDIS_COMMAND_TIMEOUT_MS", "2000"))
	db, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))

	opts := &redis.Options{
		Addr:         getEnv("REDIS_HOST", "localhost") + ":" + getEnv("REDIS_PORT", "6379"),
		Password:     os.Getenv("REDIS_PASSWORD"),
		DB:           db,
		PoolSize:     poolSize,
		MinIdleConns: minIdleConns,
		DialTimeout:  time.Duration(connectTimeout) * time.Millisecond,
		ReadTimeout:  time.Duration(commandTimeout) * time.Millisecond,
		WriteTimeout: time.Duration(commandTimeout) * time.Millisecond,
		MaxRetries:   3,
		MinRetryBackoff: 100 * time.Millisecond,
		MaxRetryBackoff: 2 * time.Second,
	}

	client := redis.NewClient(opts)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("Redis connection failed: %v", err)
	}

	return client
}

// Sentinel connection template
// func NewRedisSentinelClient() *redis.Client {
//     sentinelHosts := strings.Split(os.Getenv("REDIS_SENTINEL_HOSTS"), ",")
//     return redis.NewFailoverClient(&redis.FailoverOptions{
//         MasterName:    os.Getenv("REDIS_SENTINEL_MASTER_NAME"),
//         SentinelAddrs: sentinelHosts,
//         Password:      os.Getenv("REDIS_PASSWORD"),
//         PoolSize:      10,
//     })
// }

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
```

**C# with StackExchange.Redis**:

```csharp
// Config/RedisConfiguration.cs
using StackExchange.Redis;
using System;

public static class RedisConfiguration
{
    private static readonly Lazy<ConnectionMultiplexer> _connection =
        new Lazy<ConnectionMultiplexer>(() =>
        {
            var config = ConfigurationOptions.Parse(
                Environment.GetEnvironmentVariable("REDIS_URL") ?? "localhost:6379"
            );

            config.Password = Environment.GetEnvironmentVariable("REDIS_PASSWORD");
            config.AbortOnConnectFail = false;
            config.ConnectRetry = 3;
            config.ConnectTimeout = 5000;
            config.SyncTimeout = 2000;
            config.AsyncTimeout = 2000;

            if (Environment.GetEnvironmentVariable("REDIS_TLS_ENABLED") == "true")
            {
                config.Ssl = true;
                config.SslProtocols = System.Security.Authentication.SslProtocols.Tls12;
            }

            return ConnectionMultiplexer.Connect(config);
        });

    public static ConnectionMultiplexer Connection => _connection.Value;
    public static IDatabase Database => Connection.GetDatabase();
}
```

**Java with Lettuce (Spring Boot)**:

```java
// config/RedisConfig.java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettucePoolingClientConfiguration;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.TimeoutOptions;
import org.apache.commons.pool2.impl.GenericObjectPoolConfig;

import java.time.Duration;

@Configuration
public class RedisConfig {

    @Value("${spring.redis.host:localhost}")
    private String host;

    @Value("${spring.redis.port:6379}")
    private int port;

    @Value("${spring.redis.password:}")
    private String password;

    @Bean
    public RedisConnectionFactory redisConnectionFactory() {
        RedisStandaloneConfiguration serverConfig = new RedisStandaloneConfiguration();
        serverConfig.setHostName(host);
        serverConfig.setPort(port);
        if (!password.isEmpty()) {
            serverConfig.setPassword(password);
        }

        GenericObjectPoolConfig<?> poolConfig = new GenericObjectPoolConfig<>();
        poolConfig.setMaxTotal(10);
        poolConfig.setMinIdle(5);
        poolConfig.setMaxIdle(10);

        LettucePoolingClientConfiguration clientConfig =
            LettucePoolingClientConfiguration.builder()
                .poolConfig(poolConfig)
                .commandTimeout(Duration.ofMillis(2000))
                .build();

        return new LettuceConnectionFactory(serverConfig, clientConfig);
    }

    @Bean
    public RedisTemplate<String, String> redisTemplate(
            RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, String> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new StringRedisSerializer());
        return template;
    }
}
```

#### Step 4: Verify .gitignore

Ensure sensitive files are excluded from version control:

```bash
# Check and update .gitignore
for pattern in '.env' '.env.local' '.env.production' '*.pem' '*.key'; do
  grep -qxF "$pattern" .gitignore 2>/dev/null || echo "$pattern" >> .gitignore
done
```

### namespace-setup

Creates a comprehensive key naming conventions document at `docs/db/redis-conventions.md`.

#### Step 1: Detect Existing Conventions

```bash
# Check for existing conventions document
ls docs/db/redis-conventions.md 2>/dev/null
ls docs/redis-conventions.md 2>/dev/null
ls docs/database/redis.md 2>/dev/null
```

If a conventions document already exists, read it and suggest additions rather than overwriting.

#### Step 2: Detect Namespace Prefix

Scan existing Redis usage to determine the current namespace prefix:

```bash
# Extract key patterns from source code to detect existing prefix
grep -roh '[a-z][a-z0-9_]*:[a-z][a-z0-9_]*:' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' . | sort | uniq -c | sort -rn | head -5
```

If no existing prefix is detected, derive from the project name:

```bash
# Use project directory name or package name as namespace prefix
basename "$(git rev-parse --show-toplevel)" | tr '[:upper:]-' '[:lower:]_'
```

#### Step 3: Scaffold Conventions Document

Create the directory structure:

```bash
mkdir -p docs/db
```

Scaffolded `docs/db/redis-conventions.md`:

```markdown
# Redis Key Conventions

## Namespace

All Redis keys in this project use the prefix `{namespace}:` to prevent collisions with other
services sharing the same Redis instance.

## Key Naming Rules

1. **Colon separator**: Use `:` as hierarchy separator (`{namespace}:entity:id:attribute`)
2. **Lowercase only**: All key components must be lowercase
3. **No single-character keys**: Keys must be descriptive
4. **Hierarchical**: General to specific (namespace > entity > id > attribute)
5. **Documented**: All key patterns must be listed in this document

## Key Patterns

| Pattern                                 | Type        | TTL    | Purpose            |
| --------------------------------------- | ----------- | ------ | ------------------ |
| {namespace}:user:{id}:profile           | Hash        | None   | User profile data  |
| {namespace}:session:{token}             | Hash        | 30m    | Session data       |
| {namespace}:cache:product:{id}          | String      | 1h     | Product cache      |
| {namespace}:cache:api:{endpoint}:{hash} | String      | 5m     | API response cache |
| {namespace}:rate:api:{ip}:{window}      | String      | 60s    | Rate limit counter |
| {namespace}:lock:{resource}:{id}        | String      | 30s    | Distributed lock   |
| {namespace}:queue:{name}                | List/Stream | None   | Job queue          |
| {namespace}:stream:events:{domain}      | Stream      | None   | Event stream       |
| {namespace}:leaderboard:{name}          | Sorted Set  | None   | Score ranking      |
| {namespace}:counter:{name}              | String      | Varies | Atomic counter     |

## TTL Policy

| Category   | TTL Range  | Renewal     | Notes                                      |
| ---------- | ---------- | ----------- | ------------------------------------------ |
| Hot cache  | 1-5 min    | No          | API responses, rate counters               |
| Warm cache | 5-60 min   | No          | Product data, search results               |
| Cold cache | 1-24 hours | No          | Reports, aggregations                      |
| Sessions   | 30 min     | Sliding     | Renewed on activity                        |
| Locks      | 10-60 sec  | Extend only | Owner must extend before expiry            |
| Persistent | None       | N/A         | Leaderboards, config (document explicitly) |

**Rule**: Every cache key MUST have a TTL. Keys without TTL must be explicitly documented as
persistent in this table with justification.

## Data Structure Selection

| Use Case           | Structure      | Why                                            |
| ------------------ | -------------- | ---------------------------------------------- |
| Simple cache       | String         | Fast GET/SET, supports EX                      |
| Object with fields | Hash           | Partial field access without deserialization   |
| Queue (FIFO)       | List or Stream | RPUSH/BLPOP or XADD/XREADGROUP                 |
| Unique collection  | Set            | Membership testing, intersections              |
| Ranked data        | Sorted Set     | Score-based ordering, range queries            |
| Event log          | Stream         | Append-only, consumer groups, replay           |
| Unique counting    | HyperLogLog    | Constant 12KB memory regardless of cardinality |
| Boolean per ID     | Bitmap         | Space-efficient for dense ID ranges            |

## Adding New Key Patterns

When adding a new Redis key pattern to the codebase:

1. Add the pattern to the Key Patterns table above
2. Specify the data structure and TTL
3. Document the purpose
4. Ensure the key follows naming rules (colon separator, lowercase, namespace prefix)
5. Run `ccfg redis validate` to verify compliance
```

#### Step 4: Update .gitignore

Ensure the conventions document is tracked (not in .gitignore):

```bash
# Conventions doc should be committed - verify it is not gitignored
git check-ignore docs/db/redis-conventions.md
# Should return nothing (not ignored)
```

## Scaffold Output Format

### connection-config Output

```text
Redis Connection Scaffold
=========================

Detected: ioredis (Node.js) in package.json

Created files:
  + .env.example               (Redis environment variables)
  + config/redis.ts            (Connection configuration with pooling + retry)
  ~ .gitignore                 (Added .env exclusion)

Configuration includes:
  - Connection pooling (10 connections, 5 min idle)
  - Retry with exponential backoff (3 retries, 100ms-2s delay)
  - Connect timeout: 5s, command timeout: 2s
  - Sentinel template (commented, uncomment for HA)
  - Cluster template (commented, uncomment for cluster)
  - TLS template (commented, uncomment for encrypted connections)

Next steps:
  1. Copy .env.example to .env and fill in real values
  2. Import redis from config/redis.ts in your application
  3. For Sentinel/Cluster: uncomment the appropriate template
  4. Run 'ccfg redis scaffold --type=namespace-setup' to create conventions doc
```

### namespace-setup Output

```text
Redis Namespace Scaffold
========================

Detected namespace prefix: myapp (from existing key patterns)

Created files:
  + docs/db/redis-conventions.md  (Key naming conventions document)

Document includes:
  - Namespace prefix: myapp
  - Key naming rules (colon separator, lowercase, hierarchical)
  - Key pattern registry (10 common patterns)
  - TTL policy by category
  - Data structure selection guide
  - Instructions for adding new patterns

Next steps:
  1. Review docs/db/redis-conventions.md
  2. Update the namespace prefix if needed
  3. Add your application-specific key patterns to the registry
  4. Run 'ccfg redis validate' to verify existing code compliance
```

## Edge Cases and Special Handling

### Docker Compose Projects

If a `docker-compose.yml` is detected with a Redis service, scaffold configuration that connects to
the Docker service name.

```bash
# Detect Redis in Docker Compose
grep -l 'redis' docker-compose*.yml docker-compose*.yaml 2>/dev/null
```

If detected, adjust the default host in `.env.example`:

```env
# Docker Compose default (uses service name as hostname)
REDIS_HOST=redis
REDIS_PORT=6379
```

And add a Docker Compose Redis service template if one does not exist:

```yaml
# docker-compose.yml - Redis service template
services:
  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redis-data:/data
    command: >
      redis-server
        --maxmemory 256mb
        --maxmemory-policy allkeys-lfu
        --appendonly yes
        --appendfsync everysec
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  redis-data:
```

### Existing .env.example

If `.env.example` already exists, append Redis variables rather than overwriting:

```bash
# Check for existing Redis config in .env.example
grep -q 'REDIS' .env.example 2>/dev/null
```

If Redis variables already exist, compare with recommended settings and suggest additions:

```text
Existing .env.example already contains Redis configuration.

Current Redis variables:
  REDIS_URL=redis://localhost:6379
  REDIS_PASSWORD=

Missing recommended variables:
  + REDIS_POOL_SIZE=10
  + REDIS_CONNECT_TIMEOUT_MS=5000
  + REDIS_COMMAND_TIMEOUT_MS=2000
  + REDIS_RETRY_COUNT=3

Add missing variables? (yes/no)
```

### Multiple Redis Instances

Some projects use multiple Redis instances (e.g., cache + queue + session). Scaffold configuration
that supports named connections.

```typescript
// config/redis.ts - Multiple named connections
import Redis from 'ioredis';

const baseConfig = {
  maxRetriesPerRequest: 3,
  connectTimeout: 5000,
  commandTimeout: 2000,
};

// Primary cache connection
export const cacheRedis = new Redis({
  ...baseConfig,
  host: process.env.REDIS_CACHE_HOST || 'localhost',
  port: parseInt(process.env.REDIS_CACHE_PORT || '6379', 10),
  password: process.env.REDIS_CACHE_PASSWORD,
});

// Queue connection (separate instance for isolation)
export const queueRedis = new Redis({
  ...baseConfig,
  host: process.env.REDIS_QUEUE_HOST || 'localhost',
  port: parseInt(process.env.REDIS_QUEUE_PORT || '6380', 10),
  password: process.env.REDIS_QUEUE_PASSWORD,
});

// Session connection (separate for security isolation)
export const sessionRedis = new Redis({
  ...baseConfig,
  host: process.env.REDIS_SESSION_HOST || 'localhost',
  port: parseInt(process.env.REDIS_SESSION_PORT || '6381', 10),
  password: process.env.REDIS_SESSION_PASSWORD,
});
```

### Framework-Specific Integration

When a web framework is detected, scaffold framework-specific Redis integration.

**Express.js with connect-redis**:

```typescript
// middleware/session.ts
import session from 'express-session';
import RedisStore from 'connect-redis';
import redis from '../config/redis';

export const sessionMiddleware = session({
  store: new RedisStore({ client: redis, prefix: 'myapp:session:' }),
  secret: process.env.SESSION_SECRET || 'change-me',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 1800000, // 30 minutes
    sameSite: 'strict',
  },
});
```

**Django with django-redis**:

```python
# settings.py - Django cache backend
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'SOCKET_CONNECT_TIMEOUT': 5,
            'SOCKET_TIMEOUT': 2,
            'CONNECTION_POOL_KWARGS': {
                'max_connections': int(os.getenv('REDIS_POOL_SIZE', '10')),
            },
        },
        'KEY_PREFIX': 'myapp',
        'TIMEOUT': 3600,
    }
}

# Session backend
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
```

**Spring Boot application.yml**:

```yaml
# application.yml - Spring Redis configuration
spring:
  redis:
    host: ${REDIS_HOST:localhost}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PASSWORD:}
    timeout: 2000ms
    lettuce:
      pool:
        max-active: ${REDIS_POOL_SIZE:10}
        min-idle: ${REDIS_POOL_MIN_IDLE:5}
        max-idle: 10
        max-wait: 5000ms
```
