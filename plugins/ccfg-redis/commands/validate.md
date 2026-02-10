---
description: >
  Run Redis usage quality gate suite (key naming, memory policy, antipattern detection)
argument-hint: '[--quick]'
allowed-tools: Bash(redis-cli *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive Redis usage quality gate suite to ensure Redis implementations meet production
standards. This command analyzes code artifacts in the repository to verify key naming conventions,
TTL compliance, memory policy awareness, and antipattern detection.

## Usage

```bash
ccfg redis validate                    # Full validation (all gates)
ccfg redis validate --quick            # Quick mode (key naming only)
ccfg redis validate --live             # Validate against live instance (requires confirmation)
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Key Naming**: Verify hierarchical colon-separated keys, namespace prefix, lowercase, documented
   patterns
2. **Memory Policy**: TTL on cache keys, unbounded key growth detection, maxmemory-policy awareness,
   cache stampede risk
3. **Antipattern Detection**: KEYS \* in app code, values >1MB, hot keys, FLUSHALL/FLUSHDB in
   non-test code, blocking commands without timeout, SELECT for db switching

All gates must pass for validation to succeed. In quick mode, only the Key Naming gate runs. The
validation operates on repository artifacts (source files, configuration files, scripts) by default.
Live instance validation requires explicit `--live` flag and user confirmation.

## Key Rules

### Repository-Only by Default

Validation operates exclusively on repository artifacts unless the `--live` flag is explicitly
provided. Never connect to a Redis instance without the `--live` flag and user confirmation.

```text
DEFAULT behavior (no --live flag):
  - Scan source files for Redis key patterns
  - Scan configuration files for Redis settings
  - Scan test files for antipatterns
  - NEVER connect to any Redis instance

WITH --live flag:
  1. Ask user to confirm the target instance
  2. Ask user to confirm it is safe to run read-only commands
  3. Only execute read-only commands (INFO, SCAN, OBJECT, MEMORY USAGE)
  4. NEVER execute write commands during validation
```

### Detect and Skip

If no Redis usage is detected in the repository, skip validation gracefully with an informational
message. Never fail validation on a non-Redis project.

```text
No Redis usage detected in repository.

Checked for:
  - Redis client libraries in dependency files
  - Redis connection strings in configuration
  - Redis commands in source files
  - Redis key patterns in code

Skipping Redis validation.
```

### Never Suggest Disabling Checks

When a check fails, suggest how to fix the issue. Never suggest disabling or skipping the check. If
a check is a false positive, suggest adding a targeted exclusion comment.

## Step-by-Step Process

### 0. Redis Usage Discovery

Before running any gates, detect whether the project uses Redis.

#### Strategy A: Dependency File Detection

Check package manifests for Redis client libraries:

```bash
# Node.js
git ls-files --cached --others --exclude-standard -- 'package.json' '**/package.json' | head -20

# Python
git ls-files --cached --others --exclude-standard -- 'requirements*.txt' 'Pipfile' 'pyproject.toml' \
  'setup.py' 'setup.cfg' | head -20

# Go
git ls-files --cached --others --exclude-standard -- 'go.mod' 'go.sum' | head -10

# C#/.NET
git ls-files --cached --others --exclude-standard -- '*.csproj' '*.fsproj' | head -20

# Java
git ls-files --cached --others --exclude-standard -- 'pom.xml' 'build.gradle' \
  'build.gradle.kts' | head -20
```

Known Redis client libraries by language:

```text
Node.js:   ioredis, redis, bullmq, bull, bee-queue, connect-redis
Python:    redis, aioredis, redis-py, celery (with redis broker), django-redis, flask-caching
Go:        github.com/redis/go-redis, github.com/gomodule/redigo
C#/.NET:   StackExchange.Redis, Microsoft.Extensions.Caching.StackExchangeRedis, ServiceStack.Redis
Java:      lettuce-core, jedis, spring-data-redis, redisson, spring-boot-starter-data-redis
```

#### Strategy B: Configuration File Detection

Search for Redis connection configuration:

```bash
# Environment files
git ls-files --cached --others --exclude-standard -- '.env.example' '.env.sample' \
  '.env.template' '.env.development' | head -10

# Docker compose files
git ls-files --cached --others --exclude-standard -- 'docker-compose*.yml' \
  'docker-compose*.yaml' | head -10

# Application config files
git ls-files --cached --others --exclude-standard -- '*.conf' '*.cfg' '*.ini' \
  '*.properties' '*.yaml' '*.yml' | head -30
```

Search for Redis connection patterns in discovered files:

```bash
# Redis URL patterns
grep -rl 'redis://' --include='*.env*' --include='*.yml' --include='*.yaml' \
  --include='*.json' --include='*.conf' .

# Redis environment variables
grep -rl 'REDIS_URL\|REDIS_HOST\|REDIS_PORT\|REDIS_PASSWORD' \
  --include='*.env*' --include='*.yml' --include='*.yaml' .
```

#### Strategy C: Source Code Detection

Search source files for Redis commands and client usage:

```bash
# Redis client instantiation patterns
grep -rl 'Redis\|redis\|ioredis\|RedisClient\|ConnectionMultiplexer' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' .

# Redis command patterns in code
grep -rl '\.set\b.*EX\|\.get\b\|\.hset\b\|\.zadd\b\|\.lpush\b\|\.xadd\b' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' .
```

**Combining and deduplicating results**:

```bash
# Collect all Redis usage indicators
{ strategy_a; strategy_b; strategy_c; } | sort -u > /tmp/redis-usage-files.txt
```

**Empty discovery**: If no Redis usage artifacts are found, report and skip:

```text
No Redis usage detected in repository.

Checked locations:
  - package.json, requirements.txt, go.mod, *.csproj, pom.xml
  - .env.example, docker-compose.yml
  - Source files for Redis client instantiation
  - Configuration files for redis:// URLs

Skipping Redis validation.
```

### 1. Key Naming Gate

Verify that all Redis key patterns in the codebase follow naming conventions.

#### Key Pattern Extraction

Parse source files to extract Redis key patterns. Look for string literals that are used as Redis
key arguments.

```bash
# Extract key patterns from source code
# Look for common Redis command patterns with string key arguments
grep -rn "\.set\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .
grep -rn "\.get\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .
grep -rn "\.hset\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .
grep -rn "\.zadd\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .
grep -rn "\.lpush\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .
grep -rn "\.xadd\s*(\s*['\"]" --include='*.ts' --include='*.js' --include='*.py' .

# Also check for key construction with template literals or f-strings
grep -rn 'f"[^"]*:[^"]*"' --include='*.py' .
grep -rn '`[^`]*:[^`]*`' --include='*.ts' --include='*.js' .
```

#### Naming Convention Checks

For each extracted key pattern, verify:

**Hierarchical colon separator**: Keys must use colons (`:`) as hierarchy separators.

```text
PASS: myapp:user:1001:profile
PASS: myapp:cache:product:5001
FAIL: myapp.user.1001.profile       (dot separator)
FAIL: myapp/user/1001/profile        (slash separator)
FAIL: myapp_user_1001_profile        (underscore separator for hierarchy)
```

**No single-character keys**: Application keys must be descriptive, not single characters.

```text
PASS: myapp:user:1001:profile
PASS: myapp:rate:api:192.168.1.1
FAIL: a                               (single character key)
FAIL: x                               (single character key)
EXCEPTION: Single-char keys in Lua script local variables are acceptable
```

**Namespace prefix**: All keys must begin with a consistent namespace prefix.

```text
PASS: myapp:user:1001:profile         (has namespace prefix "myapp")
PASS: myapp:cache:product:5001        (same namespace prefix)
FAIL: user:1001:profile               (no namespace prefix)
FAIL: cache:product:5001              (no namespace prefix)
WARN: myapp:user:... and webapp:cache:...  (inconsistent namespace prefixes)
```

**Lowercase enforcement**: All key components must be lowercase.

```text
PASS: myapp:user:1001:profile
PASS: myapp:cache:api:v2:products
FAIL: myapp:User:1001:Profile         (mixed case)
FAIL: MYAPP:USER:1001:PROFILE         (uppercase)
FAIL: myapp:cache:ProductCategory     (camelCase component)
```

**Documented patterns**: Check for a conventions document.

```bash
# Check for Redis conventions documentation
ls docs/db/redis-conventions.md 2>/dev/null
ls docs/redis-conventions.md 2>/dev/null
ls docs/database/redis.md 2>/dev/null
ls .redis/conventions.md 2>/dev/null
```

If no conventions document exists, emit a WARN suggesting creation:

```text
WARN: No Redis key conventions document found.
  Expected: docs/db/redis-conventions.md
  Run 'ccfg redis scaffold --type=namespace-setup' to generate one.
```

**Namespace and TTL in conventions doc**: If conventions doc exists, verify it documents namespace
prefix and TTL policy per key category.

```bash
# Check conventions doc for required sections
grep -c 'namespace\|prefix' docs/db/redis-conventions.md
grep -c 'TTL\|ttl\|expir' docs/db/redis-conventions.md
grep -c 'pattern\|Pattern' docs/db/redis-conventions.md
```

#### Key Naming Gate Output

**Success output**:

```text
[1/3] Key Naming
  -> Scanning: 45 source files (127 key patterns extracted)
  OK: All keys use colon separator
  OK: No single-character keys detected
  OK: Namespace prefix "myapp" consistent across 127 patterns
  OK: All key components are lowercase
  OK: Conventions document found at docs/db/redis-conventions.md
  OK: Conventions document includes namespace and TTL policy
  PASS
```

**Failure output**:

```text
[1/3] Key Naming
  -> Scanning: 45 source files (127 key patterns extracted)
  OK: All keys use colon separator
  OK: No single-character keys detected
  FAIL: Inconsistent namespace prefixes detected:
    - "myapp:" (89 keys) in src/services/*.ts
    - "webapp:" (38 keys) in src/cache/*.ts
    Recommendation: Standardize on a single namespace prefix. Update src/cache/*.ts
    to use "myapp:" prefix.
  OK: All key components are lowercase
  WARN: No Redis conventions document found
  FAIL (1 error, 1 warning)
```

### 2. Memory Policy Gate

Verify that Redis usage follows memory-safe practices.

**Skip in quick mode**: This gate only runs in full mode.

#### TTL on Cache Keys

Scan for cache key operations that lack TTL assignment. Cache keys are identified by patterns
containing "cache" in the key name, or by being used with SET/HSET without subsequent EXPIRE.

```bash
# Find SET commands without EX/PX/EXAT/PXAT
grep -rn '\.set\s*(' --include='*.ts' --include='*.js' --include='*.py' \
  --include='*.go' --include='*.cs' --include='*.java' . | \
  grep -iv 'EX\|PX\|EXAT\|PXAT\|expire\|ttl'

# Find HSET without corresponding EXPIRE
grep -rn '\.hset\s*(' --include='*.ts' --include='*.js' --include='*.py' .
```

For each cache key SET without TTL, emit a FAIL:

```text
FAIL: Cache key set without TTL
  File: src/services/product-cache.ts:42
  Key: myapp:cache:product:{id}
  Command: redis.set(key, JSON.stringify(product))
  Fix: Add TTL - redis.set(key, JSON.stringify(product), 'EX', 3600)
```

#### Unbounded Key Growth

Detect patterns that create keys without bounds or TTL:

```bash
# LPUSH/RPUSH without LTRIM
grep -rn 'lpush\|rpush' --include='*.ts' --include='*.js' --include='*.py' . | \
  grep -iv 'ltrim\|MAXLEN\|trim'

# SADD without expiry (check surrounding lines for EXPIRE)
grep -rn 'sadd\b' --include='*.ts' --include='*.js' --include='*.py' .

# ZADD without expiry or cleanup
grep -rn 'zadd\b' --include='*.ts' --include='*.js' --include='*.py' .
```

For each unbounded growth pattern, emit a WARN:

```text
WARN: Potential unbounded key growth
  File: src/services/activity-feed.ts:67
  Pattern: LPUSH without LTRIM
  Key: myapp:feed:user:{id}
  Fix: Add LTRIM after LPUSH to bound the list:
    redis.lpush(key, event)
    redis.ltrim(key, 0, 999)
```

#### Maxmemory-Policy Awareness

Check for maxmemory-policy configuration in Redis config files or documentation:

```bash
# Check for Redis configuration files
git ls-files --cached --others --exclude-standard -- 'redis.conf' '**/redis.conf' \
  'redis/*.conf' | head -10

# Check for maxmemory-policy in config
grep -rn 'maxmemory-policy\|maxmemory_policy' --include='*.conf' --include='*.yaml' \
  --include='*.yml' --include='*.properties' .

# Check Docker Compose for Redis config
grep -A5 'redis' docker-compose*.yml 2>/dev/null | grep -i 'maxmemory'
```

If no maxmemory-policy is configured and the project uses Redis for caching, emit a WARN:

```text
WARN: No maxmemory-policy configuration detected
  Redis defaults to 'noeviction' which returns errors when memory is full.
  For cache workloads, configure: maxmemory-policy allkeys-lfu
  For mixed workloads: maxmemory-policy volatile-lru
```

#### Cache Stampede / Dogpile Detection

Scan for cache-aside patterns that lack stampede protection:

```bash
# Look for cache miss -> DB query -> cache set patterns without locking
grep -rn -A10 '\.get\s*(' --include='*.ts' --include='*.js' --include='*.py' . | \
  grep -B5 'query\|SELECT\|find\|fetch' | grep -B10 '\.set\s*('
```

If cache-aside patterns are detected without lock-based or PER-based stampede protection:

```text
WARN: Cache stampede risk detected
  File: src/services/product-service.ts:23-35
  Pattern: cache miss -> database query -> cache set
  No stampede protection (lock or probabilistic early recomputation) detected.
  Risk: High-traffic keys may cause database thundering herd on cache expiry.
  See: ccfg redis patterns-expert for stampede prevention patterns.
```

#### Memory Policy Gate Output

**Success output**:

```text
[2/3] Memory Policy
  -> Scanning: 45 source files, 3 configuration files
  OK: All cache keys have TTL (89 SET operations verified)
  OK: No unbounded key growth detected
  OK: maxmemory-policy configured as allkeys-lfu in redis.conf
  OK: Cache stampede protection detected (lock pattern in cache-service.ts)
  PASS
```

**Failure output**:

```text
[2/3] Memory Policy
  -> Scanning: 45 source files, 3 configuration files
  FAIL: 3 cache keys missing TTL
    - src/services/product-cache.ts:42 (myapp:cache:product:{id})
    - src/services/user-cache.ts:18 (myapp:cache:user:{id}:profile)
    - src/cache/search-results.ts:55 (myapp:cache:search:{query})
  WARN: 2 potential unbounded key growth patterns
  WARN: No maxmemory-policy configuration detected
  WARN: Cache stampede risk in 1 location
  FAIL (1 error, 3 warnings)
```

### 3. Antipattern Detection Gate

Detect dangerous or suboptimal Redis usage patterns in the codebase.

**Skip in quick mode**: This gate only runs in full mode.

#### KEYS \* in Application Code

The KEYS command is O(N) and blocks the Redis server. It must never appear in application code.

```bash
# Search for KEYS command usage (exclude test files)
grep -rn 'KEYS \*\|\.keys\s*(\|redis\.keys\b' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' . | \
  grep -v '__test__\|\.test\.\|\.spec\.\|_test\.go\|Test\.java\|Tests\.cs'
```

```text
FAIL: KEYS command used in application code
  File: src/services/cache-manager.ts:78
  Code: const keys = await redis.keys('myapp:cache:*')
  Problem: KEYS is O(N), blocks the server for the entire keyspace scan
  Fix: Use SCAN with cursor-based iteration:
    let cursor = '0'
    do {
      const [next, keys] = await redis.scan(cursor, 'MATCH', 'myapp:cache:*', 'COUNT', 100)
      cursor = next
      // process keys
    } while (cursor !== '0')
```

#### Values > 1MB Detection

Search for patterns that may store large values:

```bash
# Look for JSON.stringify of large objects or arrays
grep -rn 'JSON\.stringify\|json\.dumps\|JsonConvert\.Serialize' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.cs' . | \
  grep -i 'redis\|cache\|set'

# Look for file contents being stored in Redis
grep -rn 'readFile.*redis\|redis.*readFile\|readFileSync.*set' \
  --include='*.ts' --include='*.js' .
```

For detected patterns, check surrounding context for size limits or compression:

```text
WARN: Potential large value storage
  File: src/services/report-cache.ts:34
  Pattern: JSON.stringify(reportData) stored in Redis
  Risk: Report data may exceed 1MB, causing latency spikes and network blocking
  Fix: Compress with gzip before storage, or store in object storage with Redis pointer
```

#### Hot Key Detection

Search for patterns that concentrate traffic on a single key:

```bash
# Global counters without sharding
grep -rn 'INCR\|incr\b' --include='*.ts' --include='*.js' --include='*.py' . | \
  grep -i 'global\|total\|all_\|overall'

# Single key used in high-frequency code paths
grep -rn '\.incr\s*(\s*["\x27]' --include='*.ts' --include='*.js' --include='*.py' .
```

```text
WARN: Potential hot key detected
  File: src/middleware/analytics.ts:12
  Key: myapp:counter:total_requests
  Pattern: Global INCR on every request
  Risk: Single key on single node cannot scale horizontally in cluster mode
  Fix: Shard the counter: myapp:counter:requests:{shard_N}
    Use random or hash-based shard selection, sum shards for total
```

#### FLUSHALL/FLUSHDB in Non-Test Code

```bash
# Search for FLUSHALL/FLUSHDB outside test directories
grep -rn 'FLUSHALL\|FLUSHDB\|flushall\|flushdb\|flush_all\|flush_db' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' . | \
  grep -v '__test__\|\.test\.\|\.spec\.\|_test\.go\|Test\.java\|Tests\.cs\|test_\|/test/'
```

```text
FAIL: FLUSHALL/FLUSHDB in non-test code
  File: src/scripts/cleanup.ts:15
  Code: await redis.flushdb()
  Problem: Destroys all data in the database, no recovery without backup
  Fix: Use targeted SCAN + UNLINK for selective cleanup:
    const stream = redis.scanStream({ match: 'myapp:temp:*', count: 100 })
    stream.on('data', (keys) => { if (keys.length) redis.unlink(...keys) })
```

#### Blocking Commands Without Timeout

```bash
# Search for BLPOP/BRPOP/BLMOVE/BZPOPMIN/BZPOPMAX/XREADGROUP with 0 timeout
grep -rn 'blpop\|brpop\|blmove\|bzpopmin\|bzpopmax' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' . | \
  grep -E ',\s*0\s*\)|\btimeout.*=.*0\b'

# XREADGROUP with BLOCK 0
grep -rn 'xreadgroup\|XREADGROUP' \
  --include='*.ts' --include='*.js' --include='*.py' . | \
  grep -i 'block.*0\b'
```

```text
FAIL: Blocking command with infinite timeout
  File: src/workers/queue-worker.ts:45
  Code: await redis.blpop('myapp:queue:jobs', 0)
  Problem: Connection blocked indefinitely, cannot detect dead consumers,
    prevents graceful shutdown
  Fix: Use a reasonable timeout (e.g., 30 seconds) with retry loop:
    while (running) {
      const result = await redis.blpop('myapp:queue:jobs', 30)
      if (result) processJob(result)
    }
```

#### SELECT for Database Switching

```bash
# Search for SELECT command usage
grep -rn '\.select\s*(\s*[0-9]\|SELECT [0-9]\|select_db\|database.*[1-9]' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
  --include='*.cs' --include='*.java' . | \
  grep -iv 'sql\|mysql\|postgres\|sqlite\|SELECT \*\|SELECT.*FROM'
```

```text
WARN: SELECT command used for database switching
  File: src/config/redis.ts:23
  Code: redis.select(1)
  Problem: Multiple databases are fragile (connection state), not supported in cluster mode,
    most clients default to DB 0, and ops tools assume DB 0
  Fix: Use key namespaces instead of database numbers:
    Instead of DB 0 for cache and DB 1 for sessions:
    - myapp:cache:* (namespace for cache keys)
    - myapp:session:* (namespace for session keys)
```

#### Antipattern Detection Gate Output

**Success output**:

```text
[3/3] Antipattern Detection
  -> Scanning: 45 source files (excluding test files)
  OK: No KEYS command in application code
  OK: No large value patterns detected
  OK: No global hot key patterns detected
  OK: No FLUSHALL/FLUSHDB in non-test code
  OK: All blocking commands have reasonable timeout
  OK: No SELECT database switching detected
  PASS
```

**Failure output**:

```text
[3/3] Antipattern Detection
  -> Scanning: 45 source files (excluding test files)
  FAIL: KEYS command in application code (1 occurrence)
  WARN: Potential large value storage (2 locations)
  WARN: Potential hot key (1 location)
  OK: No FLUSHALL/FLUSHDB in non-test code
  FAIL: Blocking command with infinite timeout (1 occurrence)
  WARN: SELECT database switching (1 location)
  FAIL (2 errors, 3 warnings)
```

## Final Report Format

### Full Mode Report

```text
Redis Validation Report
=======================

Project: my-application
Mode: Full
Date: 2024-01-31T12:00:00Z
Files scanned: 45 source files, 3 configuration files

[1/3] Key Naming .............. PASS
[2/3] Memory Policy ........... PASS (1 warning)
[3/3] Antipattern Detection ... FAIL (2 errors, 1 warning)

Summary:
  Errors:   2
  Warnings: 2
  Status:   FAIL

Errors:
  1. KEYS command in application code (src/services/cache-manager.ts:78)
  2. Blocking command with infinite timeout (src/workers/queue-worker.ts:45)

Warnings:
  1. Cache stampede risk (src/services/product-service.ts:23)
  2. Potential hot key (src/middleware/analytics.ts:12)
```

### Quick Mode Report

```text
Redis Validation Report
=======================

Project: my-application
Mode: Quick
Date: 2024-01-31T12:00:00Z
Files scanned: 45 source files

[1/1] Key Naming .............. PASS

Summary:
  Errors:   0
  Warnings: 0
  Status:   PASS
```

### Live Mode Additions

When `--live` flag is provided and user confirms:

```text
BEFORE any live commands:
  1. Display: "This will connect to: redis://10.0.0.5:6379"
  2. Ask: "Is this a production instance? (yes/no)"
  3. If yes: "Running read-only validation on production. Continue? (yes/no)"
  4. If confirmed: Proceed with read-only commands only
```

Live mode additional checks:

```bash
# Memory usage overview
redis-cli INFO memory

# Check maxmemory configuration
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy

# Scan for large keys (non-blocking)
redis-cli --bigkeys --memkeys-samples 100

# Check for keys without TTL (sample-based)
redis-cli SCAN 0 COUNT 100
# For each sampled key: redis-cli TTL <key>

# Check slow log
redis-cli SLOWLOG GET 10

# Check connected clients
redis-cli INFO clients
```

```text
Live Instance Report Additions:

Memory:
  used_memory: 1.2 GB / 4 GB maxmemory (30%)
  mem_fragmentation_ratio: 1.12 (OK)
  eviction_policy: allkeys-lfu (OK)
  evicted_keys_total: 0

Large Keys:
  Biggest string: myapp:cache:report:2024 (2.3 MB) -> WARN: >1MB
  Biggest hash: myapp:user:stats (45 KB) -> OK
  Biggest sorted set: myapp:leaderboard:global (120 KB) -> OK

TTL Compliance (sampled 100 keys):
  With TTL: 78/100 (78%)
  Without TTL: 22/100 (22%)
  Keys without TTL:
    - myapp:config:features (persistent - OK if intentional)
    - myapp:cache:old_report (FAIL - cache key without TTL)

Slow Log (last 10 entries):
  2024-01-31 11:45:00 KEYS myapp:* (450ms) -> FAIL: KEYS in production
  2024-01-31 11:30:00 HGETALL myapp:user:stats (12ms) -> WARN: slow HGETALL
```

## Edge Cases and Special Handling

### Multi-Language Projects

Some projects use Redis from multiple languages (e.g., Node.js API + Python workers). The validation
must scan all relevant language files and verify consistency across languages.

```text
Multi-language key naming consistency:
  - Extract key patterns from all detected languages
  - Verify namespace prefix is identical across languages
  - Verify key hierarchy follows the same conventions
  - Flag inconsistencies between languages

Example inconsistency:
  Node.js (src/api/cache.ts):    myapp:cache:product:{id}
  Python (workers/processor.py): app:cache:product:{id}
  FAIL: Namespace prefix mismatch ("myapp" vs "app")
```

### Monorepo Projects

For monorepo structures, each service may have its own Redis namespace. Validate that services use
distinct namespace prefixes to prevent key collisions.

```text
Monorepo key namespace validation:
  - Detect monorepo structure (packages/, services/, apps/ directories)
  - Extract namespace prefix per service
  - Verify no two services share the same prefix
  - Allow shared prefix only if services share the same Redis instance intentionally

Example collision:
  services/auth/src/cache.ts:     myapp:user:{id}:session
  services/profile/src/cache.ts:  myapp:user:{id}:profile
  OK: Same prefix "myapp" is acceptable if sharing same Redis instance

Example conflict:
  services/auth/src/cache.ts:     myapp:cache:user:{id}
  services/billing/src/cache.ts:  myapp:cache:user:{id}
  FAIL: Identical key pattern in different services risks data corruption
```

### Test File Handling

Test files receive different treatment than application code:

```text
Test file detection patterns:
  - **/*.test.ts, **/*.spec.ts
  - **/*.test.js, **/*.spec.js
  - **/test_*.py, **/*_test.py
  - **/*_test.go
  - **/Test*.java, **/*Test.java
  - **/Tests*.cs, **/*Tests.cs
  - Directories: test/, tests/, __tests__/, spec/

Rules for test files:
  - FLUSHALL/FLUSHDB: ALLOWED (needed for test isolation)
  - KEYS *: WARN (prefer SCAN even in tests for consistency)
  - Missing TTL: SKIP (test cleanup handles key removal)
  - Namespace prefix: WARN if missing (test keys should still be namespaced)
```

### Configuration-as-Code Files

Redis configuration in infrastructure-as-code files requires specific validation:

```bash
# Terraform Redis resources
grep -rn 'aws_elasticache\|google_redis_instance\|azurerm_redis_cache' \
  --include='*.tf' .

# Kubernetes Redis configuration
grep -rn 'redis\|Redis' --include='*.yaml' --include='*.yml' . | \
  grep -i 'configmap\|deployment\|statefulset'

# Ansible Redis playbooks
grep -rn 'redis' --include='*.yml' --include='*.yaml' . | \
  grep -i 'ansible\|playbook\|role'
```

Validate infrastructure configuration:

```text
Infrastructure validation checks:
  - maxmemory is set (not left at default 0 / unlimited)
  - maxmemory-policy is explicitly configured
  - TLS is enabled for non-local connections
  - AUTH / ACL is configured
  - Persistence settings match workload type
```

### Exclusion Comments

When a check is a known false positive, allow targeted exclusion with inline comments:

```typescript
// ccfg-redis-ignore: keys-command (legacy migration script, runs once)
const keys = await redis.keys('myapp:migration:*');

// ccfg-redis-ignore: no-ttl (intentional persistent configuration)
await redis.set('myapp:config:features', JSON.stringify(features));

// ccfg-redis-ignore: large-value (compressed, verified < 500KB)
await redis.set(key, compressedData, 'EX', 3600);
```

```bash
# Detect exclusion comments and skip those lines
grep -rn 'ccfg-redis-ignore' --include='*.ts' --include='*.js' --include='*.py' .
```

Each exclusion comment must include a reason. Bare exclusion comments without reason are flagged:

```text
WARN: Exclusion comment without reason
  File: src/cache/legacy.ts:12
  Code: // ccfg-redis-ignore
  Fix: Add reason - // ccfg-redis-ignore: keys-command (reason here)
```

## Exit Behavior

```text
All gates pass:              Exit with success message, no errors
Any gate has warnings only:  Exit with success message, list warnings
Any gate has errors:         Exit with failure message, list all errors and warnings
No Redis usage detected:     Exit with informational message, no errors
```
