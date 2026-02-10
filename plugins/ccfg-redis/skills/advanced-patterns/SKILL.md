---
name: advanced-patterns
description:
  This skill should be used when implementing caching strategies, rate limiting, distributed locks,
  session management, job queues, or other Redis-based patterns.
version: 0.1.0
---

# Advanced Redis Patterns

These are comprehensive patterns for Redis-based architectural components, covering caching
strategies, rate limiting algorithms, distributed lock implementations, session management, job
queues, leaderboards, and other common Redis patterns. Following these patterns ensures correctness,
fault tolerance, and production-grade reliability.

## Existing Repository Compatibility

When implementing Redis patterns in existing projects, always respect established patterns and
library choices before applying these preferences.

- **Audit existing patterns**: Review how the project currently uses Redis before suggesting new
  patterns. An existing cache-aside implementation may have specific invalidation logic that must be
  preserved.
- **Library compatibility**: If the project uses BullMQ for job queues, do not suggest replacing it
  with a custom stream-based queue. Work within the existing library's conventions.
- **Migration path**: When improving an existing pattern (e.g., adding stampede protection to
  cache-aside), provide a migration path that does not break existing consumers.
- **Testing**: All pattern changes must be testable. Provide test scenarios for success cases,
  failure cases, and race conditions.

**These patterns apply primarily to new implementations and significant refactors. For existing
systems, propose changes through proper change management processes.**

## Cache-Aside Pattern (Lazy Loading)

The most common caching pattern. Application code manages the cache explicitly: read from cache
first, fetch from database on miss, write result to cache.

### Implementation

```python
# CORRECT: Cache-aside with TTL and error handling
import redis
import json

r = redis.Redis(host='localhost', port=6379, decode_responses=True)

def get_product(product_id: int) -> dict:
    cache_key = f"myapp:cache:product:{product_id}"

    # Step 1: Check cache
    cached = r.get(cache_key)
    if cached is not None:
        return json.loads(cached)

    # Step 2: Cache miss - query database
    product = db.query("SELECT * FROM products WHERE id = %s", product_id)
    if product is None:
        # Cache negative result with short TTL to prevent cache penetration
        r.set(cache_key, json.dumps(None), ex=60)
        return None

    # Step 3: Store in cache with TTL
    r.set(cache_key, json.dumps(product), ex=3600)
    return product

def invalidate_product(product_id: int) -> None:
    """Invalidate cache on write (do not update cache directly)."""
    r.unlink(f"myapp:cache:product:{product_id}")
```

```python
# WRONG: Cache-aside without TTL
def get_product_bad(product_id: int) -> dict:
    cached = r.get(f"myapp:cache:product:{product_id}")
    if cached:
        return json.loads(cached)
    product = db.query("SELECT * FROM products WHERE id = %s", product_id)
    r.set(f"myapp:cache:product:{product_id}", json.dumps(product))  # No TTL
    return product
    # Problem: Stale data lives forever, memory grows unbounded

# WRONG: Updating cache instead of invalidating on write
def update_product_bad(product_id: int, data: dict) -> None:
    db.execute("UPDATE products SET ... WHERE id = %s", product_id)
    product = db.query("SELECT * FROM products WHERE id = %s", product_id)
    r.set(f"myapp:cache:product:{product_id}", json.dumps(product), ex=3600)
    # Problem: Race condition between UPDATE and SELECT
    # Another process may UPDATE between our two queries, caching stale data
```

### Cache Stampede Prevention

When a popular cache key expires, many concurrent requests may hit the database simultaneously.

```python
# CORRECT: Lock-based stampede prevention
def get_with_lock(key: str, ttl: int, lock_ttl: int = 10) -> dict:
    """Cache-aside with lock-based stampede prevention."""
    cached = r.get(key)
    if cached is not None:
        return json.loads(cached)

    lock_key = f"myapp:lock:cache:{key}"
    acquired = r.set(lock_key, "1", nx=True, ex=lock_ttl)

    if acquired:
        try:
            value = expensive_database_query()
            r.set(key, json.dumps(value), ex=ttl)
            return value
        finally:
            r.unlink(lock_key)
    else:
        # Wait briefly and retry from cache
        time.sleep(0.1)
        cached = r.get(key)
        if cached is not None:
            return json.loads(cached)
        # Fallback: query database (lock holder may have failed)
        return expensive_database_query()
```

```python
# CORRECT: Probabilistic early recomputation (PER)
def get_with_per(key: str, ttl: int, beta: float = 1.0) -> dict:
    """Cache with early recomputation before expiry."""
    cached = r.get(key)
    remaining = r.ttl(key)

    if cached is not None and remaining > 0:
        # As TTL approaches 0, probability of recomputation increases
        delta = ttl - remaining
        if delta > 0 and delta < beta * ttl * (-math.log(random.random())):
            return json.loads(cached)  # Not yet time to recompute

    value = expensive_database_query()
    r.set(key, json.dumps(value), ex=ttl)
    return value
```

```python
# WRONG: No stampede protection
def get_stampede_vulnerable(key: str) -> dict:
    cached = r.get(key)
    if cached:
        return json.loads(cached)
    # 1000 concurrent requests all arrive here at once
    result = expensive_database_query()  # DB hit 1000 times
    r.set(key, json.dumps(result), ex=3600)
    return result
```

## Write-Through Pattern

Every write goes to both cache and database synchronously.

```python
# CORRECT: Write-through with database-first ordering
def create_user(user_data: dict) -> dict:
    # Step 1: Write to database first (source of truth)
    user = db.execute(
        "INSERT INTO users (name, email) VALUES (%s, %s) RETURNING *",
        user_data['name'], user_data['email']
    )

    # Step 2: Write to cache after successful DB write
    cache_key = f"myapp:user:{user['id']}:profile"
    r.hset(cache_key, mapping={
        'id': str(user['id']),
        'name': user['name'],
        'email': user['email'],
    })
    r.expire(cache_key, 3600)
    return user
```

```python
# WRONG: Write to cache before database
def create_user_bad(user_data: dict) -> dict:
    r.hset(f"myapp:user:new:profile", mapping=user_data)
    user = db.execute("INSERT INTO users ...", user_data)  # May fail!
    # Problem: Cache has phantom data if DB write fails
    return user
```

## Write-Behind (Write-Back) Pattern

Writes go to cache immediately and are asynchronously persisted to the database.

```python
# CORRECT: Write-behind with stream-based persistence queue
def update_inventory(product_id: int, quantity: int) -> None:
    # Step 1: Update cache immediately (fast path)
    r.hset(f"myapp:inventory:{product_id}", 'quantity', quantity)
    r.expire(f"myapp:inventory:{product_id}", 86400)

    # Step 2: Queue async write to database
    r.xadd('myapp:stream:db_writes', {
        'table': 'inventory',
        'product_id': str(product_id),
        'quantity': str(quantity),
        'timestamp': str(int(time.time())),
    }, maxlen=100000)

# Background worker persists writes
def process_db_writes():
    while True:
        entries = r.xreadgroup(
            'db_writers', 'worker-1',
            {'myapp:stream:db_writes': '>'},
            count=100, block=5000
        )
        for stream, messages in entries:
            for msg_id, data in messages:
                try:
                    db.execute("UPDATE inventory SET quantity = %s WHERE product_id = %s",
                               data['quantity'], data['product_id'])
                    r.xack('myapp:stream:db_writes', 'db_writers', msg_id)
                except Exception as e:
                    log.error(f"Write-behind persistence failed: {e}")
```

```python
# WRONG: Write-behind without persistence queue
def update_inventory_bad(product_id: int, quantity: int) -> None:
    r.hset(f"myapp:inventory:{product_id}", 'quantity', quantity)
    # Problem: No persistence mechanism, data lost on Redis restart
```

## Fixed Window Rate Limiter

Counts requests in fixed time windows. Simple but allows burst at window boundaries.

```lua
-- CORRECT: Atomic fixed window rate limiter (Lua script)
-- KEYS[1] = rate limit key
-- ARGV[1] = limit, ARGV[2] = window in seconds
local current = redis.call('INCR', KEYS[1])
if current == 1 then
    redis.call('EXPIRE', KEYS[1], ARGV[2])
end
if current > tonumber(ARGV[1]) then
    return 0  -- Rate limited
end
return 1  -- Allowed
```

```python
# CORRECT: Python wrapper
def check_rate_limit_fixed(client_id: str, limit: int, window: int) -> bool:
    window_num = int(time.time() // window)
    key = f"myapp:rate:{client_id}:{window_num}"
    pipe = r.pipeline()
    pipe.incr(key)
    pipe.expire(key, window + 1)
    results = pipe.execute()
    return results[0] <= limit
```

```python
# WRONG: Non-atomic rate limiter
def check_rate_bad(client_id: str, limit: int) -> bool:
    key = f"myapp:rate:{client_id}"
    current = r.get(key)           # Read
    if current and int(current) >= limit:
        return False
    r.incr(key)                     # Write
    return True
    # Problem: Race condition between read and write
```

## Sliding Window Rate Limiter

Uses a sorted set to track individual request timestamps. Accurate without boundary burst.

```python
# CORRECT: Sliding window with sorted set
def check_rate_limit_sliding(client_id: str, limit: int, window: int) -> bool:
    key = f"myapp:rate:sliding:{client_id}"
    now = time.time()
    window_start = now - window

    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, window_start)  # Remove expired
    pipe.zcard(key)                               # Count remaining
    pipe.zadd(key, {f"{now}:{uuid.uuid4().hex[:8]}": now})  # Add current
    pipe.expire(key, window + 1)                  # Set TTL
    results = pipe.execute()

    current_count = results[1]
    if current_count >= limit:
        r.zrem(key, f"{now}:{uuid.uuid4().hex[:8]}")  # Remove the one we just added
        return False
    return True
```

```python
# WRONG: Sliding window without cleanup
def check_rate_bad_sliding(client_id: str, limit: int) -> bool:
    key = f"myapp:rate:sliding:{client_id}"
    r.zadd(key, {str(time.time()): time.time()})
    count = r.zcard(key)  # Counts ALL entries including expired
    return count <= limit
    # Problem: Never removes old entries, sorted set grows forever
```

## Token Bucket Rate Limiter

Allows controlled burst traffic up to bucket capacity while maintaining a steady average rate.

```lua
-- CORRECT: Token bucket (Lua script for atomicity)
-- KEYS[1] = bucket key
-- ARGV[1] = capacity, ARGV[2] = refill rate, ARGV[3] = now, ARGV[4] = tokens requested
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
local tokens = tonumber(bucket[1]) or capacity
local last_refill = tonumber(bucket[2]) or now

local elapsed = now - last_refill
tokens = math.min(capacity, tokens + elapsed * refill_rate)

if tokens >= requested then
    tokens = tokens - requested
    redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
    redis.call('EXPIRE', key, math.ceil(capacity / refill_rate) + 1)
    return 1  -- Allowed
else
    redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
    redis.call('EXPIRE', key, math.ceil(capacity / refill_rate) + 1)
    return 0  -- Rate limited
end
```

```text
Rate limiter comparison:
  Fixed window:    Simple, low memory, boundary burst possible
  Sliding window:  Accurate, higher memory (sorted set per client), no burst
  Token bucket:    Controlled burst, low memory, most flexible
  Recommendation:  Token bucket for API gateways, fixed window for per-user limits
```

## Distributed Lock with SET NX EX

### Single-Instance Lock

```python
# CORRECT: Lock with owner verification and atomic release
class RedisLock:
    def __init__(self, redis_client, name: str, ttl: int = 30):
        self.redis = redis_client
        self.name = f"myapp:lock:{name}"
        self.ttl = ttl
        self.owner = str(uuid.uuid4())

    def acquire(self, timeout: int = 10) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.redis.set(self.name, self.owner, nx=True, ex=self.ttl):
                return True
            time.sleep(0.1)
        return False

    def release(self) -> bool:
        # Atomic: verify owner then delete
        script = """
        if redis.call('GET', KEYS[1]) == ARGV[1] then
            return redis.call('DEL', KEYS[1])
        end
        return 0
        """
        return self.redis.eval(script, 1, self.name, self.owner) == 1

    def extend(self, additional_ttl: int = None) -> bool:
        ttl = additional_ttl or self.ttl
        script = """
        if redis.call('GET', KEYS[1]) == ARGV[1] then
            return redis.call('EXPIRE', KEYS[1], ARGV[2])
        end
        return 0
        """
        return self.redis.eval(script, 1, self.name, self.owner, ttl) == 1

# Usage
lock = RedisLock(r, "order:5001:process")
if lock.acquire():
    try:
        process_order(5001)
    finally:
        lock.release()
```

```python
# WRONG: Lock without owner verification on release
def release_bad(name: str):
    r.delete(f"lock:{name}")
    # Problem: Any process can release any lock
    # Process A acquires, times out, Process B acquires, Process A releases B's lock

# WRONG: Lock without TTL
def acquire_bad(name: str) -> bool:
    return r.setnx(f"lock:{name}", "1")
    # Problem: If process crashes, lock held forever (deadlock)

# WRONG: Non-atomic check-and-delete
def release_race(name: str, owner: str):
    if r.get(f"lock:{name}") == owner:
        r.delete(f"lock:{name}")
    # Problem: Race between GET and DELETE
```

### Redlock Algorithm

Distributed lock across multiple independent Redis instances for higher fault tolerance.

```text
Redlock steps:
1. Record current time
2. Try to acquire lock on N instances (minimum 3, recommended 5)
3. Lock is acquired if majority (N/2 + 1) succeed AND elapsed time < TTL
4. Effective TTL = original TTL - elapsed time - clock drift
5. If failed: release lock on all instances

Requirements:
- N independent Redis instances (not replicas)
- Clock drift factor: 1% of TTL
- Retry with random delay to prevent split-brain
```

### Fencing Tokens

Prevent stale lock holders from performing writes after expiry.

```python
# CORRECT: Fencing token with monotonic counter
class FencedLock:
    def __init__(self, redis_client, name: str, ttl: int = 30):
        self.redis = redis_client
        self.name = f"myapp:lock:{name}"
        self.fence_key = f"myapp:fence:{name}"
        self.ttl = ttl
        self.owner = str(uuid.uuid4())

    def acquire(self) -> int | None:
        if self.redis.set(self.name, self.owner, nx=True, ex=self.ttl):
            return self.redis.incr(self.fence_key)
        return None

# Storage validates: reject writes with fence_token <= last_seen_token
```

```text
Fencing flow:
1. Client A acquires lock, gets fence_token=33
2. Client A starts processing (slow), lock expires
3. Client B acquires lock, gets fence_token=34
4. Client B writes with token=34 -> Accepted
5. Client A writes with token=33 -> Rejected (33 < 34)
```

## Pub/Sub vs Streams

```text
Use Pub/Sub when:
  - Fire-and-forget messaging is acceptable
  - All subscribers must receive all messages (fan-out)
  - No message persistence needed
  - Cache invalidation, config updates, real-time notifications

Use Streams when:
  - Messages must be delivered reliably (at-least-once)
  - Consumer groups for load-balanced processing
  - Message acknowledgment and retry needed
  - Consumers may disconnect and resume later
  - Event sourcing, job queues, audit logs
```

```python
# CORRECT: Pub/Sub for cache invalidation (fire-and-forget)
def invalidate_cache(entity_type: str, entity_id: int):
    r.publish(f"myapp:invalidate:{entity_type}", json.dumps({'id': entity_id}))

# WRONG: Pub/Sub for critical message delivery
r.publish("myapp:critical:payment", json.dumps({'order_id': 5001}))
# Problem: If no subscriber connected, message is lost forever
```

```python
# CORRECT: Streams for reliable processing
processor = OrderEventProcessor(r, "processors", "worker-1")
processor.publish({'type': 'order_created', 'order_id': '5001'})

# Consumer loop with acknowledgment
for stream, messages in processor.consume():
    for msg_id, data in messages:
        try:
            handle_event(data)
            processor.ack(msg_id)
        except Exception:
            pass  # Stays in pending list for retry/claim
```

## Job Queue Patterns

### Stream-Based Queue

```python
# CORRECT: Job queue with streams, consumer groups, and dead letter
class StreamQueue:
    def __init__(self, redis_client, name: str, group: str, consumer: str):
        self.redis = redis_client
        self.stream = f"myapp:queue:stream:{name}"
        self.group = group
        self.consumer = consumer
        try:
            self.redis.xgroup_create(self.stream, self.group, id='0', mkstream=True)
        except redis.ResponseError as e:
            if 'BUSYGROUP' not in str(e):
                raise

    def enqueue(self, job_type: str, data: dict) -> str:
        return self.redis.xadd(self.stream, {
            'type': job_type,
            'data': json.dumps(data),
        }, maxlen=500000)

    def dequeue(self, count: int = 1, block_ms: int = 5000) -> list:
        return self.redis.xreadgroup(
            self.group, self.consumer,
            {self.stream: '>'}, count=count, block=block_ms
        ) or []

    def ack(self, msg_id: str):
        self.redis.xack(self.stream, self.group, msg_id)

    def claim_stale(self, min_idle_ms: int = 60000):
        return self.redis.xautoclaim(
            self.stream, self.group, self.consumer,
            min_idle_time=min_idle_ms, start_id='0-0', count=10
        )
```

### Priority Queue with Sorted Set

```python
# CORRECT: Priority queue using sorted set
class PriorityQueue:
    def __init__(self, redis_client, name: str):
        self.redis = redis_client
        self.key = f"myapp:queue:priority:{name}"

    def enqueue(self, job_id: str, priority: int = 0):
        self.redis.zadd(self.key, {job_id: priority})

    def dequeue(self) -> str | None:
        result = self.redis.zpopmin(self.key)
        return result[0][0] if result else None
```

## Session Storage Pattern

```python
# CORRECT: Hash-based session with sliding expiry
class SessionStore:
    def __init__(self, redis_client, ttl: int = 1800):
        self.redis = redis_client
        self.prefix = "myapp:session"
        self.ttl = ttl

    def create(self, user_id: int, metadata: dict = None) -> str:
        import secrets
        token = secrets.token_urlsafe(32)
        key = f"{self.prefix}:{token}"
        pipe = self.redis.pipeline()
        pipe.hset(key, mapping={
            'user_id': str(user_id),
            'created_at': str(int(time.time())),
            'ip': metadata.get('ip', '') if metadata else '',
        })
        pipe.expire(key, self.ttl)
        pipe.sadd(f"{self.prefix}:user:{user_id}:active", token)
        pipe.execute()
        return token

    def get(self, token: str) -> dict | None:
        key = f"{self.prefix}:{token}"
        session = self.redis.hgetall(key)
        if not session:
            return None
        # Sliding expiry: renew TTL on access
        self.redis.expire(key, self.ttl)
        return session

    def destroy(self, token: str):
        key = f"{self.prefix}:{token}"
        session = self.redis.hgetall(key)
        if session:
            pipe = self.redis.pipeline()
            pipe.unlink(key)
            if 'user_id' in session:
                pipe.srem(f"{self.prefix}:user:{session['user_id']}:active", token)
            pipe.execute()
```

```python
# WRONG: Session as JSON string without sliding expiry
def create_session_bad(user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    r.set(f"session:{token}", json.dumps({'user_id': user_id}))
    # Problem: No TTL, no sliding expiry, full deserialize for any read
    return token
```

## Leaderboard Pattern

```python
# CORRECT: Real-time leaderboard with sorted sets
class Leaderboard:
    def __init__(self, redis_client, name: str):
        self.redis = redis_client
        self.key = f"myapp:leaderboard:{name}"

    def add_score(self, player: str, score: float):
        self.redis.zadd(self.key, {player: score})

    def increment(self, player: str, delta: float) -> float:
        return self.redis.zincrby(self.key, delta, player)

    def rank(self, player: str) -> int | None:
        return self.redis.zrevrank(self.key, player)

    def top(self, count: int = 10) -> list:
        return self.redis.zrevrange(self.key, 0, count - 1, withscores=True)

    def around(self, player: str, count: int = 5) -> list:
        rank = self.redis.zrevrank(self.key, player)
        if rank is None:
            return []
        return self.redis.zrevrange(
            self.key, max(0, rank - count), rank + count, withscores=True
        )
```

```python
# WRONG: String keys per player
def add_score_bad(player: str, score: float):
    r.set(f"score:{player}", score)
    # Problem: No sorting, ranking requires scanning all keys
```

## Circuit Breaker Pattern

```python
# CORRECT: Circuit breaker with Redis state
class CircuitBreaker:
    CLOSED, OPEN, HALF_OPEN = "closed", "open", "half_open"

    def __init__(self, redis_client, service: str,
                 failure_threshold: int = 5, recovery_timeout: int = 30):
        self.redis = redis_client
        self.prefix = f"myapp:circuit:{service}"
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout

    def can_execute(self) -> bool:
        state = self.redis.get(f"{self.prefix}:state") or self.CLOSED
        if state == self.CLOSED:
            return True
        if state == self.OPEN:
            opened_at = float(self.redis.get(f"{self.prefix}:opened_at") or 0)
            if time.time() - opened_at >= self.recovery_timeout:
                self.redis.set(f"{self.prefix}:state", self.HALF_OPEN)
                return True
            return False
        return True  # HALF_OPEN allows testing

    def record_success(self):
        state = self.redis.get(f"{self.prefix}:state") or self.CLOSED
        if state == self.HALF_OPEN:
            self.redis.set(f"{self.prefix}:state", self.CLOSED)
            self.redis.delete(f"{self.prefix}:failures")

    def record_failure(self):
        state = self.redis.get(f"{self.prefix}:state") or self.CLOSED
        if state == self.HALF_OPEN:
            self.redis.set(f"{self.prefix}:state", self.OPEN)
            self.redis.set(f"{self.prefix}:opened_at", time.time())
        elif state == self.CLOSED:
            failures = self.redis.incr(f"{self.prefix}:failures")
            self.redis.expire(f"{self.prefix}:failures", 60)
            if failures >= self.failure_threshold:
                self.redis.set(f"{self.prefix}:state", self.OPEN)
                self.redis.set(f"{self.prefix}:opened_at", time.time())
```

## Anti-Pattern Summary

```text
Pattern             | Anti-Pattern                        | Fix
--------------------|-------------------------------------|-----------------------------------
Cache-aside         | No TTL on cache keys                | Always SET ... EX
Cache-aside         | Update cache on write               | Invalidate (UNLINK), let read repop
Cache-aside         | No stampede protection              | Lock or PER-based repopulation
Write-through       | Cache before database               | Database first, then cache
Write-behind        | No persistence queue                | Use Streams for async DB writes
Rate limiting       | Non-atomic read + increment         | Lua script or pipeline
Rate limiting       | No TTL on rate keys                 | EXPIRE on every counter
Locks               | No owner verification on release    | Lua: compare owner then DEL
Locks               | No TTL on lock                      | Always SET NX EX
Locks               | Non-atomic release                  | Lua for atomic check + delete
Sessions            | No sliding expiry                   | EXPIRE on every access
Sessions            | JSON string instead of hash         | HSET for partial field updates
Queues              | No dead letter handling             | DLQ after max retries
Queues              | No acknowledgment                   | XACK with consumer groups
Leaderboards        | String keys per player              | Single sorted set
Pub/Sub             | Reliable delivery expectation       | Use Streams instead
```

## Bloom Filter Pattern

Use bloom filters for probabilistic membership testing where false negatives are impossible and
false positives are acceptable at a known rate.

```python
# CORRECT: Bloom filter for duplicate detection (requires Redis Bloom module)
class BloomFilter:
    def __init__(self, redis_client, name: str):
        self.redis = redis_client
        self.key = f"myapp:bloom:{name}"

    def create(self, error_rate: float = 0.01, capacity: int = 1000000):
        try:
            self.redis.execute_command('BF.RESERVE', self.key, error_rate, capacity)
        except redis.ResponseError:
            pass  # Filter already exists

    def add(self, item: str) -> bool:
        return bool(self.redis.execute_command('BF.ADD', self.key, item))

    def exists(self, item: str) -> bool:
        return bool(self.redis.execute_command('BF.EXISTS', self.key, item))

# Usage: Prevent duplicate email sends
bloom = BloomFilter(r, "sent_emails")
bloom.create(error_rate=0.001, capacity=10000000)

def should_send_email(email_id: str) -> bool:
    if bloom.exists(email_id):
        return False  # Probably already sent
    bloom.add(email_id)
    return True
```

```text
Bloom filter properties:
- False negatives: IMPOSSIBLE (if bloom says "not exists", it definitely does not)
- False positives: Possible at configured rate (e.g., 0.1% with 0.001 error rate)
- Memory: ~1.2 MB per 1M items at 1% error rate, ~1.8 MB at 0.1%
- Use cases: Email dedup, URL filtering, username availability pre-check
```

```python
# WRONG: Set for massive duplicate detection
def check_sent_bad(email_id: str) -> bool:
    return r.sismember("myapp:sent_emails", email_id)
    # Problem: Set with 10M members uses 400MB+; bloom filter uses ~12MB
```

## HyperLogLog Counting Pattern

Use HyperLogLog for approximate cardinality estimation with constant 12 KB memory per key.

```python
# CORRECT: Unique visitor counting with daily rollup
class UniqueCounter:
    def __init__(self, redis_client, prefix: str = "myapp:visitors"):
        self.redis = redis_client
        self.prefix = prefix

    def track(self, visitor_id: str, date: str = None):
        if date is None:
            date = time.strftime('%Y-%m-%d')
        self.redis.pfadd(f"{self.prefix}:daily:{date}", visitor_id)
        self.redis.expire(f"{self.prefix}:daily:{date}", 86400 * 90)

    def daily_count(self, date: str) -> int:
        return self.redis.pfcount(f"{self.prefix}:daily:{date}")

    def weekly_count(self, start_date: str) -> int:
        from datetime import datetime, timedelta
        start = datetime.strptime(start_date, '%Y-%m-%d')
        keys = [
            f"{self.prefix}:daily:{(start + timedelta(days=i)).strftime('%Y-%m-%d')}"
            for i in range(7)
        ]
        weekly_key = f"{self.prefix}:weekly:{start_date}"
        self.redis.pfmerge(weekly_key, *keys)
        self.redis.expire(weekly_key, 86400 * 7)
        return self.redis.pfcount(weekly_key)

# Usage
counter = UniqueCounter(r)
counter.track("user:1001")
counter.track("user:1002")
counter.track("user:1001")  # Duplicate, not counted
daily = counter.daily_count("2024-01-31")  # ~2 (0.81% standard error)
```

```python
# WRONG: Set for counting millions of unique items
def track_visitor_bad(visitor_id: str):
    r.sadd("myapp:all_visitors", visitor_id)
    # Problem: 10M members use 400MB+ of memory
    # HyperLogLog uses 12KB regardless of cardinality
```

## Geospatial Query Pattern

```python
# CORRECT: Location-based search
class GeoService:
    def __init__(self, redis_client, category: str):
        self.redis = redis_client
        self.key = f"myapp:geo:{category}"

    def add(self, name: str, lon: float, lat: float):
        self.redis.geoadd(self.key, (lon, lat, name))

    def nearby(self, lon: float, lat: float, radius: float,
               unit: str = 'km', count: int = 20) -> list:
        return self.redis.geosearch(
            self.key, longitude=lon, latitude=lat,
            radius=radius, unit=unit, sort='ASC', count=count,
            withcoord=True, withdist=True)

    def distance(self, a: str, b: str, unit: str = 'km') -> float:
        return self.redis.geodist(self.key, a, b, unit=unit)

# Usage
geo = GeoService(r, "restaurants")
geo.add("joes-pizza", -73.9857, 40.7484)
nearby = geo.nearby(-73.9830, 40.7500, 1, 'km')
```

```redis
-- WRONG: Storing coordinates in separate string keys
SET myapp:store:nyc:lat "40.748817"
SET myapp:store:nyc:lon "-73.985428"
-- Problem: Cannot do radius queries, requires application-level distance math
```

## Cache Invalidation Strategies

### Event-Driven Invalidation via Pub/Sub

```python
# CORRECT: Invalidate cache across all app instances
def on_product_update(product_id: int):
    """Called after database update."""
    r.unlink(f"myapp:cache:product:{product_id}")
    r.publish("myapp:invalidate:product", json.dumps({'id': product_id}))

# Listener in each app instance
def invalidation_listener():
    pubsub = r.pubsub()
    pubsub.subscribe("myapp:invalidate:product")
    for msg in pubsub.listen():
        if msg['type'] == 'message':
            data = json.loads(msg['data'])
            local_cache.delete(f"product:{data['id']}")
```

### Tag-Based Invalidation

```python
# CORRECT: Tag-based invalidation for related cache entries
def cache_with_tags(key: str, value: str, tags: list, ttl: int = 3600):
    pipe = r.pipeline()
    pipe.set(key, value, ex=ttl)
    for tag in tags:
        pipe.sadd(f"myapp:tag:{tag}", key)
        pipe.expire(f"myapp:tag:{tag}", ttl + 60)
    pipe.execute()

def invalidate_by_tag(tag: str):
    keys = r.smembers(f"myapp:tag:{tag}")
    if keys:
        r.unlink(*keys)
    r.unlink(f"myapp:tag:{tag}")

# Usage
cache_with_tags("myapp:cache:product:5001", data,
                tags=["category:electronics", "brand:acme"])
invalidate_by_tag("category:electronics")  # Clears all electronics cache
```

## Pattern Selection Guide

```text
Need                          | Pattern                    | Key Redis Feature
------------------------------|----------------------------|----------------------
Fast reads, occasional writes | Cache-aside                | String GET/SET EX
Always-fresh cache            | Write-through              | HSET + EXPIRE
Low write latency             | Write-behind               | XADD (async queue)
API rate limiting             | Token bucket               | HMSET + Lua script
Per-user quotas               | Fixed window               | INCR + EXPIRE
Strict rate compliance        | Sliding window             | Sorted Set + ZCARD
Mutual exclusion              | SET NX EX lock             | SET NX EX + Lua release
HA mutual exclusion           | Redlock                    | Multi-instance SET NX
User sessions                 | Hash + sliding expiry      | HSET + EXPIRE on access
Real-time rankings            | Sorted Set leaderboard     | ZADD + ZREVRANGE
Reliable messaging            | Streams + consumer groups  | XREADGROUP + XACK
Fire-and-forget notifications | Pub/Sub                    | PUBLISH + SUBSCRIBE
Background jobs               | Stream queue               | XADD + XREADGROUP
Priority jobs                 | Sorted Set + List          | ZADD + ZPOPMIN
Deduplication at scale        | Bloom filter               | BF.ADD + BF.EXISTS
Unique counting               | HyperLogLog                | PFADD + PFCOUNT
Location search               | Geospatial                 | GEOADD + GEOSEARCH
Service resilience            | Circuit breaker            | Hash state machine
```
