# Plugin: ccfg-redis

The Redis data plugin. Provides data structure and pattern agents, key naming validation, connection
scaffolding, and opinionated conventions for consistent Redis development. Focuses on data structure
selection, key naming conventions, caching patterns, and distributed locking. Intentionally leaner
than relational data plugins — Redis lacks schemas, migrations, and traditional DBA concerns, but
has unique data structure and pattern considerations. Safety is paramount — never connects to
production instances without explicit user confirmation.

## Directory Structure

```text
plugins/ccfg-redis/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── redis-specialist.md
│   └── patterns-expert.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── redis-conventions/
    │   └── SKILL.md
    └── advanced-patterns/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-redis",
  "description": "Redis data plugin: data structure and pattern agents, key naming validation, connection scaffolding, and conventions for consistent Redis development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["redis", "cache", "pub-sub", "streams", "data-structures", "distributed-lock"]
}
```

## Agents (2)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent              | Role                                                                      | Model  |
| ------------------ | ------------------------------------------------------------------------- | ------ |
| `redis-specialist` | Redis 7+, data structures, modules, Lua scripting, pub/sub, streams       | sonnet |
| `patterns-expert`  | Caching, rate limiting, distributed locks, sessions, queues, leaderboards | sonnet |

No coverage command — coverage is a code concept, not a database concept. This is intentional and
differs from language plugins.

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-redis:validate

**Purpose**: Run the full Redis usage quality gate suite in one command.

**Trigger**: User invokes before deploying code that uses Redis.

**Allowed tools**: `Bash(redis-cli *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Key naming**: Verify hierarchical key naming with `:` separator (e.g.,
   `service:entity:id:field`). Flag single-character keys, keys without namespace prefix,
   inconsistent separator usage. Check that key patterns are documented. Verify that namespace
   prefix and TTL policy are documented in the conventions doc (not just implied from code
   patterns). If conventions doc exists but lacks namespace/TTL sections, report WARN
2. **Memory policy**: Check for TTL coverage on cache keys (keys intended as cache should have TTL
   set). Flag potentially unbounded key growth (patterns that create keys without expiry). Verify
   `maxmemory-policy` awareness in application code (handling eviction gracefully). WARN-level: when
   cache-aside patterns are detected without locking, probabilistic early expiration, or backoff
   strategy, flag cache stampede/dogpile risk (advisory — not all cache keys need this)
3. **Antipattern detection**: `KEYS *` usage in application code (use `SCAN` instead — `KEYS` blocks
   the server), single values over 1MB (fragment or use streams), hot key patterns (all traffic
   hitting one key), `FLUSHALL`/`FLUSHDB` in non-test code, blocking commands (`BLPOP`, `BRPOP`)
   without timeout, `SELECT` for database switching in production (use key namespaces instead)
4. Report pass/fail for each gate with output
5. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Key naming**: Same as full mode
2. Report pass/fail — skips memory policy and antipattern detection for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — application source code, Redis client calls, key patterns,
  and configuration files. Does not connect to a live Redis instance by default. Live instance
  validation requires the `--live` flag and explicit user confirmation before any connection is
  established
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available, skip that gate and report it as
  SKIPPED
- Checks for presence of conventions document (`docs/db/redis-conventions.md` or similar). Reports
  SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-redis:scaffold

**Purpose**: Initialize connection configuration and key namespace documentation for Redis projects.

**Trigger**: User invokes when setting up Redis in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=connection-config|namespace-setup]`

**Behavior**:

**connection-config** (default):

1. Detect project's Redis client library from project files:
   - Node.js: check package.json for `ioredis`, `redis`, or `bullmq`
   - Python: check requirements/pyproject.toml for `redis`, `aioredis`, or `celery`
   - Go: check go.mod for `github.com/redis/go-redis`
   - C#/.NET: check `.csproj` for `StackExchange.Redis`
   - Java: check pom.xml/build.gradle for `lettuce-core`, `jedis`, or `spring-data-redis`
2. Create `.env.example` with:

   ```text
   REDIS_URL=redis://localhost:6379/0
   REDIS_PASSWORD=
   REDIS_TLS=false
   REDIS_POOL_SIZE=10
   ```

3. Generate connection configuration snippet for the detected client library, including:
   - Connection pooling configuration
   - Retry/reconnection settings
   - Sentinel configuration template (commented out)
   - Cluster configuration template (commented out)
4. Ensure `.env` is in `.gitignore` (add entry if missing)

**namespace-setup**:

1. Create a key naming convention document (prefer `docs/db/redis-conventions.md`; fall back to
   existing `docs/redis-key-conventions.md` if one already exists) with:
   - Project namespace prefix (e.g., `myapp:`)
   - Key hierarchy pattern: `{service}:{entity}:{id}:{field}`
   - Examples for common patterns (cache, session, rate limit, queue)
   - TTL policy by key category
   - Naming rules (lowercase, `:` separator, no spaces, descriptive)
2. Include key pattern examples matching the project's domain

**Key rules**:

- Client library detection is best-effort — never prescribe a library, respect what the project
  already uses
- Never generates actual credentials in config files — always placeholder values
- Connection config includes Sentinel/Cluster templates as comments for easy activation
- If inside a git repo, verify `.gitignore` includes `.env`
- Scaffold recommends creating a conventions document at `docs/db/redis-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (2)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### redis-conventions

**Trigger description**: "This skill should be used when working with Redis, designing key schemas,
selecting data structures, configuring Redis clients, or managing Redis memory."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses a different key separator or naming convention, follow it. If the project uses Lua
scripts instead of Redis 7 functions, follow the established pattern. These preferences apply to new
Redis usage and scaffold output only.

**Data structure selection guide**:

- **String**: Simple key-value, counters (`INCR`/`DECR`), cached serialized objects. Use for:
  session tokens, cached API responses, configuration values, atomic counters
- **Hash**: Object with multiple fields. Use for: user profiles, product details, configuration
  groups. More memory-efficient than separate string keys for related fields
- **List**: Ordered collection, push/pop from both ends. Use for: message queues (simple), activity
  feeds, recent items. Use `LTRIM` to cap list length
- **Set**: Unordered unique collection. Use for: tags, unique visitors, set operations
  (intersection, union), tracking unique items, membership testing
- **Sorted Set**: Scored unique members. Use for: leaderboards, priority queues, time-series
  indexes, rate limiting windows. `ZADD` + `ZRANGEBYSCORE` for time-windowed queries
- **Stream**: Append-only log with consumer groups. Use for: event sourcing, message queues
  (robust), activity logs. Prefer streams over lists for queue patterns (consumer groups,
  acknowledgment, persistence)
- **HyperLogLog**: Probabilistic cardinality counting. Use for: unique visitor counts, unique event
  counts where exact precision isn't needed (0.81% standard error)

**Key naming rules**:

- Use `:` as separator: `service:entity:id:field` (e.g., `myapp:user:12345:profile`)
- Use lowercase keys — Redis keys are case-sensitive, lowercase prevents confusion
- Use descriptive, hierarchical names — `cache:api:users:list` not `c:a:u:l`
- No spaces in keys — use `:` or `-` as delimiters within segments
- Prefix all keys with application/service namespace to prevent collisions in shared Redis instances
- Document all key patterns in a conventions file

**TTL strategy**:

- All cache keys MUST have TTL — unbounded cache growth is the #1 Redis memory issue
- Set TTL at write time, not as an afterthought
- Use different TTL tiers: short (5m for volatile data), medium (1h for API cache), long (24h for
  computed aggregations)
- Consider `EXPIREAT` for time-aligned expiry (e.g., expire at end of day)
- Use `maxmemory-policy` as a safety net, not a primary eviction strategy. Recommended:
  `allkeys-lru` for cache workloads, `noeviction` for data store workloads

**Memory management**:

- Monitor memory with `INFO memory` and `MEMORY USAGE <key>`
- Use `OBJECT ENCODING <key>` to check internal encoding (ziplist vs hashtable, etc.)
- Keep individual values under 1MB — large values cause latency spikes
- Use `UNLINK` instead of `DEL` for large keys (non-blocking deletion)
- Consider Redis modules for specialized needs (RedisJSON, RediSearch, RedisTimeSeries)

**Persistence rules**:

- Cache-only: no persistence needed, use `save ""` to disable
- Data store: use AOF with `appendfsync everysec` for durability with acceptable performance
- Hybrid: RDB snapshots for backups + AOF for durability
- Redis 7 functions over Lua scripts — functions are first-class, stored in Redis, replicated, and
  support `FUNCTION LOAD`/`FUNCTION CALL`

### advanced-patterns

**Trigger description**: "This skill should be used when implementing caching strategies, rate
limiting, distributed locks, session management, job queues, or other Redis-based patterns."

**Contents**:

- **Cache-aside (lazy loading)**: Application checks cache first, fetches from source on miss,
  writes to cache. Most common pattern. Handles cache failures gracefully (falls back to source).
  Risk: thundering herd on cold cache — use locking or probabilistic early expiration
- **Write-through**: Application writes to cache and source simultaneously. Guarantees cache
  consistency. Higher write latency. Use when: read-heavy workloads, consistency is critical
- **Write-behind (write-back)**: Application writes to cache, cache asynchronously writes to source.
  Lowest write latency. Risk: data loss if Redis fails before flush. Use when: high write throughput
  needed, eventual consistency acceptable
- **Rate limiting patterns**:
  - **Fixed window**: `INCR key` + `EXPIRE key <window>`. Simple but allows burst at window
    boundaries
  - **Sliding window**: Use sorted set with timestamps. `ZADD key <now> <request-id>`,
    `ZREMRANGEBYSCORE key 0 <now - window>`, `ZCARD key`. More accurate, slightly more expensive
  - **Token bucket**: `INCR`/`DECR` with periodic refill via Lua script or Redis function. Allows
    controlled bursting
- **Distributed locks (Redlock)**: Use `SET key value NX EX <ttl>` for single-instance locks. For
  multi-instance, implement Redlock algorithm (acquire lock on N/2+1 nodes). Always set TTL to
  prevent deadlocks. Use fencing tokens for correctness. Consider Redisson (Java) or redlock-py for
  battle-tested implementations
- **Pub/sub vs streams**: Pub/sub: fire-and-forget, no persistence, subscribers must be connected.
  Streams: persistent, consumer groups, acknowledgment, replay. Use streams for reliable messaging,
  pub/sub for real-time notifications where message loss is acceptable
- **Job queues (BullMQ pattern)**: Use Redis lists or streams for job queues. BullMQ pattern:
  `BRPOPLPUSH` from waiting list to processing list, `LREM` on completion. Streams pattern: `XADD`
  to stream, `XREADGROUP` for consumers, `XACK` on completion. Prefer streams for new
  implementations
- **Session storage**: Use hash per session: `session:{id}` with fields for user data. Set TTL equal
  to session timeout. Use `HSET`/`HGET` for individual fields, `HGETALL` for full session load.
  Sliding expiry: `EXPIRE session:{id} <timeout>` on each access
- **Leaderboards**: Use sorted sets: `ZADD leaderboard <score> <member>`. `ZREVRANGE` for top N.
  `ZRANK` for position. `ZINCRBY` for score updates. Sorted sets handle millions of members
  efficiently. Use `ZRANGEBYSCORE` for score-range queries
