---
name: performance-tuning
description:
  This skill should be used when analyzing PostgreSQL query performance, running EXPLAIN ANALYZE,
  tuning indexes, configuring shared_buffers, or optimizing database performance.
version: 0.1.0
---

# PostgreSQL Performance Tuning

This skill covers systematic PostgreSQL performance analysis and optimization, from reading query
execution plans to tuning VACUUM and shared memory configuration. Proper performance tuning follows
a data-driven approach: measure first with EXPLAIN ANALYZE and pg_stat views, identify bottlenecks
with concrete metrics, then apply targeted optimizations. Avoid cargo-cult tuning -- every change
should be justified by measurements and validated with before/after comparisons.

## Existing Repository Compatibility

When working with existing PostgreSQL deployments, always respect the current configuration and
query patterns before applying these optimization recommendations.

- **Profile before changing**: Use `EXPLAIN ANALYZE`, `pg_stat_statements`, and `pg_stat_activity`
  to understand the current performance baseline before proposing changes.
- **Existing index strategy**: Review current indexes with `\di+` or `pg_stat_user_indexes` before
  suggesting new indexes. Adding indexes speeds reads but slows writes -- confirm the trade-off.
- **shared_buffers sizing**: If the server already has tuned memory parameters, do not blindly
  override them. Verify the current cache hit ratio with `pg_stat_database` first.
- **Configuration changes**: Production PostgreSQL configuration changes require careful testing on
  staging, gradual rollout, and monitoring. Never recommend `ALTER SYSTEM SET` without documenting
  rollback steps.
- **Query rewrites**: Before rewriting existing queries, understand why they were written that way.
  ORMs, legacy compatibility, and replication topology can all impose constraints.

**These recommendations apply primarily to new queries, new indexes, and fresh deployments. For
existing production systems, validate all changes with representative workloads on staging.**

## EXPLAIN ANALYZE

The `EXPLAIN ANALYZE` statement is the primary tool for understanding how PostgreSQL executes a
query. Always start with EXPLAIN ANALYZE before optimizing any query.

### EXPLAIN Formats

```sql
-- CORRECT: EXPLAIN with ANALYZE and BUFFERS (preferred for optimization)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.email, count(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01'
GROUP BY u.email
HAVING count(o.id) > 5
ORDER BY order_count DESC;

-- CORRECT: EXPLAIN with additional options for deep analysis
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, WAL, FORMAT TEXT)
SELECT * FROM orders WHERE status = 'pending';

-- CORRECT: EXPLAIN without ANALYZE (shows plan without executing)
-- Use this for destructive queries (UPDATE, DELETE)
EXPLAIN (BUFFERS, FORMAT TEXT)
DELETE FROM sessions WHERE expires_at < now();

-- CORRECT: JSON format for programmatic analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM orders WHERE customer_id = 42;

-- WRONG: Plain EXPLAIN without ANALYZE (estimated costs only, no actual timing)
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- Shows estimated costs but not actual row counts or timing
```

### Reading EXPLAIN ANALYZE Output

```text
Sort  (cost=1523.45..1525.67 rows=891 width=48)
      (actual time=12.456..12.502 rows=847 loops=1)
  Sort Key: order_count DESC
  Sort Method: quicksort  Memory: 89kB
  Buffers: shared hit=1234 read=56
  ->  HashAggregate  (cost=1480.12..1492.34 rows=891 width=48)
                     (actual time=11.234..11.789 rows=847 loops=1)
        Group Key: u.email
        Filter: (count(o.id) > 5)
        Batches: 1  Memory Usage: 209kB
        Rows Removed by Filter: 3421
        Buffers: shared hit=1234 read=56
        ->  Hash Join  (cost=234.56..1356.78 rows=12345 width=40)
                       (actual time=2.345..8.901 rows=11234 loops=1)
              Hash Cond: (o.user_id = u.id)
              Buffers: shared hit=1200 read=56
              ->  Seq Scan on orders o  (cost=0.00..889.12 rows=50000 width=16)
                                        (actual time=0.012..3.456 rows=48756 loops=1)
                    Buffers: shared hit=800
              ->  Hash  (cost=200.34..200.34 rows=2738 width=32)
                        (actual time=1.234..1.234 rows=2456 loops=1)
                    Buckets: 4096  Batches: 1  Memory Usage: 189kB
                    Buffers: shared hit=400 read=56
                    ->  Seq Scan on users u  (cost=0.00..200.34 rows=2738 width=32)
                          (actual time=0.023..0.789 rows=2456 loops=1)
                          Filter: (created_at > '2025-01-01')
                          Rows Removed by Filter: 7544
                          Buffers: shared hit=400 read=56
```

Key fields to examine:

| Field                    | What It Tells You                                                      |
| ------------------------ | ---------------------------------------------------------------------- |
| `actual time`            | Wall-clock time in milliseconds (startup..total)                       |
| `rows`                   | Actual row count vs estimated (large differences indicate stale stats) |
| `loops`                  | How many times this node executed (multiply actual time by loops)      |
| `Buffers: shared hit`    | Pages found in shared_buffers cache (good)                             |
| `Buffers: shared read`   | Pages read from OS cache or disk (potentially slow)                    |
| `Rows Removed by Filter` | Rows fetched but discarded (sign of missing index)                     |
| `Sort Method`            | quicksort (in memory) vs external sort (spills to disk)                |
| `Hash Batches`           | 1 = all in memory; >1 = spilled to disk (increase work_mem)            |

### Red Flags in EXPLAIN Output

```sql
-- RED FLAG 1: Seq Scan on large table with filter
-- "Seq Scan on orders" with "Rows Removed by Filter: 999000"
-- Means: Scanning entire table but keeping only 1000 of 1M rows
-- Fix: Create index on the filter column

-- RED FLAG 2: Large difference between estimated and actual rows
-- "rows=100" estimated but "rows=500000" actual
-- Means: Statistics are stale
-- Fix: ANALYZE orders;

-- RED FLAG 3: Sort with external merge (disk-based sort)
-- "Sort Method: external merge  Disk: 52MB"
-- Means: work_mem is too small for this sort
-- Fix: SET work_mem = '256MB'; (session-level) or add covering index

-- RED FLAG 4: Nested loop with inner Seq Scan
-- "Nested Loop" -> "Seq Scan on products" (loops=10000)
-- Means: 10000 sequential scans of products table
-- Fix: Create index on the join column of products

-- RED FLAG 5: Hash Join batch > 1
-- "Batches: 4  Memory Usage: 32MB"
-- Means: Hash table spilled to disk
-- Fix: Increase work_mem for this query
```

### Comparing Plans Before and After Optimization

```sql
-- Before optimization: Seq Scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'pending';
-- Seq Scan on orders  (actual time=0.012..45.678 rows=15 loops=1)
--   Filter: ((customer_id = 42) AND (status = 'pending'))
--   Rows Removed by Filter: 999985
--   Buffers: shared hit=5000 read=2000

-- Create index
CREATE INDEX CONCURRENTLY idx_orders_customer_status
    ON orders (customer_id, status);

-- After optimization: Index Scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'pending';
-- Index Scan using idx_orders_customer_status on orders
--   (actual time=0.023..0.045 rows=15 loops=1)
--   Index Cond: ((customer_id = 42) AND (status = 'pending'))
--   Buffers: shared hit=4

-- Improvement: 45ms -> 0.045ms (1000x faster), 7000 -> 4 buffer reads
```

## Index Types and Selection

### B-tree (Default)

Best for: equality and range queries on scalar columns.

```sql
-- CORRECT: B-tree for equality lookups
CREATE INDEX idx_users_email ON users (email);
-- WHERE email = 'user@example.com'  -> Index Scan

-- CORRECT: B-tree for range queries
CREATE INDEX idx_orders_created ON orders (created_at);
-- WHERE created_at > '2025-01-01'  -> Index Scan

-- CORRECT: Composite B-tree (column order matters)
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
-- WHERE status = 'pending' ORDER BY created_at DESC -> Index Scan
-- WHERE status = 'pending' -> Index Scan (uses leftmost prefix)
-- WHERE created_at > '2025-01-01' -> Seq Scan (cannot use, not leftmost)

-- CORRECT: Covering index (avoid heap access)
CREATE INDEX idx_orders_covering ON orders (customer_id)
    INCLUDE (status, total_amount);
-- SELECT status, total_amount FROM orders WHERE customer_id = 42
-- -> Index Only Scan (no heap access needed)
```

### Partial Indexes

Create indexes on a subset of rows. Dramatically smaller and faster for targeted queries.

```sql
-- CORRECT: Index only pending orders (small fraction of all orders)
CREATE INDEX idx_orders_pending ON orders (created_at)
    WHERE status = 'pending';
-- Size: 1MB vs 500MB for full index (if 0.2% of orders are pending)

-- CORRECT: Index only non-null values
CREATE INDEX idx_users_phone ON users (phone)
    WHERE phone IS NOT NULL;

-- CORRECT: Partial unique constraint
CREATE UNIQUE INDEX uq_users_active_email ON users (email)
    WHERE deleted_at IS NULL;
-- Allows duplicate emails for deleted users, unique for active users
```

### GIN Indexes

Best for: multi-valued types (jsonb, arrays, full-text search, trigrams).

```sql
-- CORRECT: GIN for jsonb containment
CREATE INDEX idx_products_attrs ON products USING gin (attributes);
-- WHERE attributes @> '{"color": "red"}'  -> Bitmap Index Scan

-- CORRECT: GIN with jsonb_path_ops (smaller, faster for @>)
CREATE INDEX idx_products_attrs_path ON products
    USING gin (attributes jsonb_path_ops);

-- CORRECT: GIN for array operations
CREATE INDEX idx_articles_tags ON articles USING gin (tags);
-- WHERE tags @> ARRAY['postgresql']  -> Bitmap Index Scan

-- CORRECT: GIN for full-text search
CREATE INDEX idx_articles_fts ON articles USING gin (search_vector);
-- WHERE search_vector @@ to_tsquery('postgresql')  -> Bitmap Index Scan

-- GIN tuning for write-heavy workloads
ALTER INDEX idx_products_attrs SET (gin_pending_list_limit = 256);
-- Increases pending list before forced merge (reduces write overhead)
```

### GiST Indexes

Best for: spatial data (PostGIS), range types, nearest-neighbor queries.

```sql
-- CORRECT: GiST for range types
CREATE INDEX idx_reservations_during ON reservations USING gist (during);
-- WHERE during && '[2025-03-01, 2025-03-05)'  -> Index Scan

-- CORRECT: GiST for PostGIS spatial queries
CREATE INDEX idx_locations_coords ON locations USING gist (coords);
-- WHERE ST_DWithin(coords, point, 5000)  -> Index Scan

-- CORRECT: GiST for exclusion constraints
ALTER TABLE reservations ADD CONSTRAINT excl_room_overlap
    EXCLUDE USING gist (room_id WITH =, during WITH &&);
```

### BRIN Indexes

Best for: naturally ordered data (time-series, append-only). Extremely small index size.

```sql
-- CORRECT: BRIN for time-series data
CREATE INDEX idx_events_time_brin ON events
    USING brin (created_at) WITH (pages_per_range = 32);
-- Size: ~100KB vs ~500MB B-tree for 100M rows
-- Only effective if physical row order correlates with column values

-- Check correlation (1.0 = perfect, 0.0 = random)
SELECT tablename, attname, correlation
FROM pg_stats
WHERE tablename = 'events' AND attname = 'created_at';
-- If correlation > 0.9, BRIN is effective
-- If correlation < 0.5, use B-tree instead
```

### Hash Indexes

Best for: equality-only lookups on large values. PostgreSQL 10+ makes them WAL-logged.

```sql
-- CORRECT: Hash index for equality-only lookups on large tokens
CREATE INDEX idx_sessions_token ON sessions USING hash (session_token);
-- WHERE session_token = 'abc123...'  -> Index Scan

-- Note: B-tree is almost always better unless:
-- 1. Values are very large (hash is fixed size)
-- 2. You never need range queries
-- 3. You never need ORDER BY on this column
```

## Partitioning for Performance

### Range Partitioning (Time-Series)

```sql
-- CORRECT: Partition by time range for time-series data
CREATE TABLE events (
    id bigint GENERATED ALWAYS AS IDENTITY,
    event_type text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
-- ... more partitions

-- Default partition catches everything else
CREATE TABLE events_default PARTITION OF events DEFAULT;

-- Benefits:
-- 1. Partition pruning: Queries with WHERE created_at filter scan only relevant partitions
-- 2. Easy data lifecycle: DROP TABLE events_2024_01 (instant, vs DELETE which is slow)
-- 3. Parallel partition scans for analytics queries
-- 4. Smaller indexes per partition (faster to create, maintain, and scan)
```

### List Partitioning (Multi-Tenant)

```sql
-- CORRECT: Partition by tenant for multi-tenant workloads
CREATE TABLE tenant_data (
    id bigint GENERATED ALWAYS AS IDENTITY,
    tenant_id integer NOT NULL,
    data jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
) PARTITION BY LIST (tenant_id);

CREATE TABLE tenant_data_1 PARTITION OF tenant_data FOR VALUES IN (1);
CREATE TABLE tenant_data_2 PARTITION OF tenant_data FOR VALUES IN (2);
CREATE TABLE tenant_data_default PARTITION OF tenant_data DEFAULT;

-- Benefits:
-- 1. Tenant isolation: Queries filter to single partition
-- 2. Per-tenant VACUUM and maintenance
-- 3. Easy tenant data removal: DROP TABLE tenant_data_42
```

### Partition Pruning Verification

```sql
-- CORRECT: Verify partition pruning is working
EXPLAIN (ANALYZE)
SELECT * FROM events WHERE created_at >= '2025-06-01' AND created_at < '2025-07-01';
-- Should show: "Append" with only events_2025_06 scanned
-- Other partitions should show: "never executed" or not appear at all

-- Enable/verify partition pruning
SHOW enable_partition_pruning;  -- Should be 'on' (default)
SET enable_partition_pruning = on;
```

## Connection Pooling with pgBouncer

### Configuration Essentials

```ini
# pgbouncer.ini
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pool settings
pool_mode = transaction           # Best for most workloads
default_pool_size = 20            # Connections per user/database pair
min_pool_size = 5                 # Minimum connections to keep open
reserve_pool_size = 5             # Emergency connections
reserve_pool_timeout = 3          # Seconds before using reserve pool
max_client_conn = 1000            # Total client connections allowed
max_db_connections = 50           # Max connections to PostgreSQL per database

# Timeouts
server_idle_timeout = 600         # Close idle server connections after 10 min
client_idle_timeout = 0           # No client idle timeout (app handles this)
query_timeout = 300               # Kill queries running longer than 5 min
client_login_timeout = 60         # Max seconds for client to authenticate
server_connect_timeout = 15       # Max seconds to connect to PostgreSQL

# Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
stats_period = 60
```

### Pool Mode Comparison

| Mode          | Description                                | Use Case                  |
| ------------- | ------------------------------------------ | ------------------------- |
| `session`     | Connection held for entire session         | PREPARE/SET/LISTEN/NOTIFY |
| `transaction` | Connection returned after each transaction | Most web applications     |
| `statement`   | Connection returned after each statement   | Simple read-only queries  |

```sql
-- Session-mode features that DON'T work in transaction mode:
PREPARE my_stmt(int) AS SELECT * FROM users WHERE id = $1;  -- Fails
SET search_path TO myschema;  -- Lost between transactions
LISTEN new_order;  -- Lost between transactions
DECLARE my_cursor CURSOR FOR SELECT * FROM orders;  -- Lost between transactions
LOCK TABLE orders;  -- Lost after transaction ends (normal behavior)

-- CORRECT: Use session-local settings differently in transaction mode
-- Instead of SET, use function parameters or per-query settings
SELECT * FROM orders WHERE status = $1
    ORDER BY created_at;  -- Let query optimizer decide, don't SET

-- Instead of PREPARE, use the driver's built-in prepared statement caching
-- Most PostgreSQL drivers (pgx, node-postgres, psycopg) handle this
```

### Monitoring pgBouncer

```sql
-- Connect to pgBouncer admin console
-- psql -p 6432 -U pgbouncer pgbouncer

SHOW POOLS;
-- database | user | cl_active | cl_waiting | sv_active | sv_idle | sv_used

SHOW STATS;
-- database | total_xact_count | total_query_count | total_received | total_sent

SHOW CLIENTS;
-- Shows all connected clients with their state

SHOW SERVERS;
-- Shows all PostgreSQL backend connections

-- Key metrics to monitor:
-- cl_waiting > 0: Clients waiting for connections (pool too small)
-- sv_active close to max_db_connections: Pool nearly exhausted
-- avg_query_time increasing: Query performance degrading
```

## VACUUM and Autovacuum Tuning

### Understanding MVCC and Dead Tuples

PostgreSQL uses MVCC (Multi-Version Concurrency Control), which means UPDATE and DELETE create dead
tuples (old row versions) that must be cleaned up by VACUUM.

```sql
-- Check dead tuple counts
SELECT schemaname, relname,
       n_live_tup, n_dead_tup,
       round(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1)
           AS dead_pct,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;

-- Check if autovacuum is running
SELECT datname, usename, pid, state, query, backend_start
FROM pg_stat_activity
WHERE backend_type = 'autovacuum worker';
```

### Autovacuum Configuration

```ini
# postgresql.conf - Autovacuum settings

# Global autovacuum settings
autovacuum = on                              # Never turn this off
autovacuum_max_workers = 5                   # Default: 3, increase for many tables
autovacuum_naptime = 30s                     # Default: 1min, decrease for write-heavy

# Threshold: vacuum when dead tuples > threshold + scale_factor * live_tuples
autovacuum_vacuum_threshold = 50             # Default: 50
autovacuum_vacuum_scale_factor = 0.1         # Default: 0.2 (20% -> 10%)
autovacuum_analyze_threshold = 50            # Default: 50
autovacuum_analyze_scale_factor = 0.05       # Default: 0.1 (10% -> 5%)

# Cost-based vacuum delay (prevents I/O spikes)
autovacuum_vacuum_cost_delay = 2ms           # Default: 2ms (PG 12+)
autovacuum_vacuum_cost_limit = 1000          # Default: -1 (uses vacuum_cost_limit = 200)
# Increase cost_limit for faster vacuuming on modern SSDs
```

### Per-Table Autovacuum Tuning

```sql
-- CORRECT: Aggressive autovacuum for write-heavy tables
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.01,     -- Vacuum at 1% dead tuples
    autovacuum_vacuum_threshold = 1000,         -- Or at 1000 dead tuples
    autovacuum_analyze_scale_factor = 0.005,    -- Analyze at 0.5% change
    autovacuum_vacuum_cost_delay = 0            -- No throttling for this table
);

-- For very large tables (100M+ rows), scale_factor of 0.2 means
-- 20M dead tuples before vacuum runs -- too many
ALTER TABLE huge_events SET (
    autovacuum_vacuum_scale_factor = 0.005,    -- 0.5% = 500K dead tuples
    autovacuum_vacuum_threshold = 10000
);

-- For small lookup tables that rarely change
ALTER TABLE countries SET (
    autovacuum_vacuum_scale_factor = 0.5,      -- Less aggressive
    autovacuum_enabled = true                   -- But keep it on
);
```

### Transaction ID Wraparound Prevention

PostgreSQL uses 32-bit transaction IDs. After ~2 billion transactions, wraparound occurs. Autovacuum
performs aggressive "anti-wraparound" vacuuming to prevent this.

```sql
-- Check how close to wraparound
SELECT datname,
       age(datfrozenxid) AS xid_age,
       round(100.0 * age(datfrozenxid) / 2147483647, 1) AS pct_to_wraparound
FROM pg_database
ORDER BY age(datfrozenxid) DESC;

-- Check per-table oldest transaction ID
SELECT schemaname, relname,
       age(relfrozenxid) AS xid_age,
       pg_size_pretty(pg_relation_size(oid)) AS table_size
FROM pg_class
JOIN pg_stat_user_tables USING (relname)
WHERE relkind = 'r'
ORDER BY age(relfrozenxid) DESC
LIMIT 20;

-- WARNING: If xid_age approaches 2 billion, the database will shut down
-- to prevent data corruption. Monitor this metric continuously.

-- Emergency: Force aggressive vacuum if nearing limit
VACUUM (FREEZE, VERBOSE) problem_table;
```

## Memory Configuration

### shared_buffers

The PostgreSQL shared memory cache for table and index pages.

```ini
# postgresql.conf
# General rule: 25% of total RAM (but not more than ~8GB on some workloads)
shared_buffers = 4GB        # 25% of 16GB RAM

# Check cache hit ratio (should be > 99% for OLTP)
```

```sql
-- Monitor cache hit ratio
SELECT
    sum(heap_blks_hit) AS cache_hits,
    sum(heap_blks_read) AS disk_reads,
    round(
        sum(heap_blks_hit)::numeric /
        NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2
    ) AS cache_hit_pct
FROM pg_statio_user_tables;
-- Target: > 99% for OLTP workloads

-- Per-table cache hit ratio (find tables with poor caching)
SELECT schemaname, relname,
       heap_blks_hit, heap_blks_read,
       round(heap_blks_hit::numeric /
             NULLIF(heap_blks_hit + heap_blks_read, 0) * 100, 2)
           AS hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 0
ORDER BY hit_pct ASC
LIMIT 20;
```

### work_mem

Memory available for each sort, hash join, and similar operation. Each query can use multiple
work_mem allocations simultaneously.

```ini
# postgresql.conf
# Conservative default for shared server
work_mem = 16MB          # Default: 4MB (too low for complex queries)
# Formula: Total RAM / (max_connections * 2 or 3)

# For analytics workloads, increase per-session
# SET work_mem = '256MB';  -- Session-level override
```

```sql
-- CORRECT: Increase work_mem for specific complex query
SET LOCAL work_mem = '256MB';  -- Only for current transaction
SELECT ... complex aggregation query ...;
RESET work_mem;

-- Check if sorts are spilling to disk
EXPLAIN (ANALYZE, BUFFERS)
SELECT ... ORDER BY complex_expression ...;
-- Look for: "Sort Method: external merge  Disk: 52MB"
-- If you see disk spill, increase work_mem for that query/session
```

### effective_cache_size

Tells the planner how much memory is available for caching (shared_buffers + OS page cache). Does
not allocate memory, only affects query planning.

```ini
# postgresql.conf
# General rule: 50-75% of total RAM
effective_cache_size = 12GB   # 75% of 16GB RAM
# Higher value encourages index scans over sequential scans
```

### maintenance_work_mem

Memory for maintenance operations (VACUUM, CREATE INDEX, ALTER TABLE ADD FOREIGN KEY).

```ini
# postgresql.conf
maintenance_work_mem = 1GB    # Default: 64MB (too low for large indexes)
# Can safely be 5-10% of total RAM
# Speeds up VACUUM and index creation significantly
```

## pg_stat Views for Performance Monitoring

### pg_stat_user_tables

```sql
-- Find tables needing attention
SELECT schemaname, relname,
       seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch,
       n_tup_ins, n_tup_upd, n_tup_del,
       n_dead_tup, n_live_tup,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY seq_scan DESC
LIMIT 20;

-- Tables with high sequential scan to index scan ratio (missing indexes?)
SELECT schemaname, relname,
       seq_scan, idx_scan,
       CASE WHEN idx_scan > 0
            THEN round(seq_scan::numeric / idx_scan, 2)
            ELSE seq_scan END AS seq_to_idx_ratio,
       pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) AS size
FROM pg_stat_user_tables
WHERE seq_scan > 100  -- Filter out rarely-accessed tables
ORDER BY seq_to_idx_ratio DESC
LIMIT 20;
```

### pg_stat_user_indexes

```sql
-- Find unused indexes (candidates for removal)
SELECT schemaname, tablename, indexname,
       idx_scan AS times_used,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (
      SELECT indexrelid FROM pg_index WHERE indisunique
  )
ORDER BY pg_relation_size(indexrelid) DESC;

-- Duplicate/redundant indexes
SELECT a.indexrelid::regclass AS index_a,
       b.indexrelid::regclass AS index_b,
       pg_size_pretty(pg_relation_size(a.indexrelid)) AS size_a,
       pg_size_pretty(pg_relation_size(b.indexrelid)) AS size_b
FROM pg_index a
JOIN pg_index b ON a.indrelid = b.indrelid
    AND a.indexrelid != b.indexrelid
    AND a.indkey::text LIKE b.indkey::text || '%'
WHERE a.indrelid::regclass::text NOT LIKE 'pg_%';
```

### pg_stat_statements

```sql
-- Top queries by total execution time
SELECT queryid,
       calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       round(stddev_exec_time::numeric, 2) AS stddev_ms,
       rows,
       round((shared_blks_hit::numeric /
              NULLIF(shared_blks_hit + shared_blks_read, 0)) * 100, 2)
           AS cache_hit_pct,
       left(query, 100) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Queries with highest I/O impact
SELECT queryid, calls,
       shared_blks_read + shared_blks_written AS total_io_blocks,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       left(query, 100) AS query_preview
FROM pg_stat_statements
WHERE calls > 10
ORDER BY (shared_blks_read + shared_blks_written) DESC
LIMIT 20;

-- Most variable query performance (high stddev)
SELECT queryid, calls,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       round(stddev_exec_time::numeric, 2) AS stddev_ms,
       round(stddev_exec_time / NULLIF(mean_exec_time, 0), 2) AS cv,
       left(query, 100) AS query_preview
FROM pg_stat_statements
WHERE calls > 100
ORDER BY stddev_exec_time DESC
LIMIT 20;
```

### pg_stat_activity (Live Monitoring)

```sql
-- Current active queries
SELECT pid, usename, datname, state,
       now() - query_start AS duration,
       wait_event_type, wait_event,
       left(query, 100) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND pid != pg_backend_pid()
ORDER BY query_start;

-- Long-running queries (> 5 minutes)
SELECT pid, usename, datname,
       now() - query_start AS duration,
       state, left(query, 200) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - interval '5 minutes'
ORDER BY query_start;

-- Blocked queries (waiting on locks)
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query,
       now() - blocked.query_start AS wait_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.locktype = bl.locktype
    AND gl.database IS NOT DISTINCT FROM bl.database
    AND gl.relation IS NOT DISTINCT FROM bl.relation
    AND gl.page IS NOT DISTINCT FROM bl.page
    AND gl.tuple IS NOT DISTINCT FROM bl.tuple
    AND gl.pid != bl.pid
    AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid;
```

## Anti-Patterns

### 1. Cargo-Cult Configuration

```ini
-- WRONG: Copying random configuration from the internet
shared_buffers = 32GB          # Without knowing total RAM
work_mem = 1GB                 # Without understanding concurrent connections
effective_cache_size = 100GB   # Without measuring available memory

-- CORRECT: Data-driven configuration
-- 1. Check total RAM: free -h
-- 2. shared_buffers = 25% of RAM (4GB for 16GB system)
-- 3. effective_cache_size = 75% of RAM (12GB for 16GB system)
-- 4. work_mem = RAM / (max_connections * 3) = 16GB / (100*3) ≈ 50MB
-- 5. maintenance_work_mem = 5-10% of RAM = 1GB
```

### 2. Adding Indexes Without Measuring

```sql
-- WRONG: Add index "just in case"
CREATE INDEX idx_users_first_name ON users (first_name);
CREATE INDEX idx_users_last_name ON users (last_name);
CREATE INDEX idx_users_city ON users (city);
CREATE INDEX idx_users_state ON users (state);
-- 4 indexes that may never be used, slowing down every INSERT/UPDATE

-- CORRECT: Measure first, add targeted indexes
-- 1. Check pg_stat_statements for slow queries
-- 2. EXPLAIN ANALYZE the specific slow query
-- 3. Add the minimal index that resolves the bottleneck
-- 4. Verify with EXPLAIN ANALYZE that the index is used
-- 5. Monitor pg_stat_user_indexes to confirm ongoing usage
```

### 3. Not Running ANALYZE After Major Changes

```sql
-- WRONG: Load millions of rows, then wonder why queries are slow
COPY large_table FROM '/data/import.csv' CSV;
-- Planner uses stale statistics, makes bad plan choices

-- CORRECT: Always ANALYZE after bulk changes
COPY large_table FROM '/data/import.csv' CSV;
ANALYZE large_table;
```

### 4. Ignoring Connection Overhead

```sql
-- WRONG: Each web request opens a new PostgreSQL connection
-- Connection cost: ~5ms setup + memory overhead per connection
-- 1000 concurrent requests = 1000 PostgreSQL backends = out of memory

-- CORRECT: Use connection pooling (pgBouncer, application-level pools)
-- pgBouncer: 1000 client connections -> 20 PostgreSQL connections
-- Each PostgreSQL connection: ~10MB RAM
-- 1000 connections = 10GB just for connections
-- 20 connections = 200MB (with pgBouncer)
```

### 5. OFFSET Pagination on Large Tables

```sql
-- WRONG: OFFSET pagination (O(n) cost, gets slower with page depth)
SELECT * FROM orders ORDER BY created_at DESC OFFSET 100000 LIMIT 20;
-- Must scan and discard 100000 rows

-- CORRECT: Keyset pagination (constant O(1) cost)
SELECT * FROM orders
WHERE (created_at, id) < ($last_created_at, $last_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

### 6. SELECT \* in Production Queries

```sql
-- WRONG: Fetching all columns when only a few are needed
SELECT * FROM orders WHERE customer_id = 42;
-- Transfers unnecessary data, prevents index-only scans

-- CORRECT: Select only needed columns
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42;
-- Can use covering index for index-only scan
```

### 7. Missing Query Timeout

```sql
-- WRONG: No statement timeout (runaway queries consume resources forever)

-- CORRECT: Set statement timeout
SET statement_timeout = '30s';  -- Per session
-- Or in postgresql.conf for global default:
-- statement_timeout = 60000  -- 60 seconds (in milliseconds)

-- CORRECT: Per-transaction timeout
SET LOCAL statement_timeout = '5s';
SELECT * FROM expensive_view;
RESET statement_timeout;
```
