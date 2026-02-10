---
name: performance-tuning
description:
  This skill should be used when analyzing MySQL query performance, running EXPLAIN, tuning indexes,
  configuring the buffer pool, or optimizing database performance.
version: 0.1.0
---

# MySQL Performance Tuning

This skill covers systematic MySQL performance analysis and optimization, from reading query
execution plans to tuning InnoDB internals. Proper performance tuning follows a data-driven
approach: measure first with EXPLAIN and the slow query log, identify bottlenecks with concrete
metrics, then apply targeted optimizations. Avoid cargo-cult tuning -- every change should be
justified by measurements and validated with before/after comparisons.

## Existing Repository Compatibility

When working with existing MySQL deployments, always respect the current configuration and query
patterns before applying these optimization recommendations.

- **Profile before changing**: Use `EXPLAIN`, slow query log, and `performance_schema` to understand
  the current performance baseline before proposing changes.
- **Existing index strategy**: Review current indexes with `SHOW INDEX FROM table_name` before
  suggesting new indexes. Adding indexes speeds reads but slows writes -- confirm the trade-off.
- **Buffer pool sizing**: If the server already has a tuned `innodb_buffer_pool_size`, do not
  blindly override it. Verify the current hit rate with `SHOW ENGINE INNODB STATUS` first.
- **Configuration changes**: Production MySQL configuration changes require careful testing on
  staging, gradual rollout, and monitoring. Never recommend a `SET GLOBAL` without documenting
  rollback steps.
- **Query rewrites**: Before rewriting existing queries, understand why they were written that way.
  ORMs, legacy compatibility, and replication topology can all impose constraints.

**These recommendations apply primarily to new queries, new indexes, and fresh deployments. For
existing production systems, validate all changes with representative workloads on staging.**

## EXPLAIN Analysis

The `EXPLAIN` statement is the primary tool for understanding how MySQL executes a query. Always
start with EXPLAIN before optimizing any query.

### EXPLAIN Formats

```sql
-- CORRECT: EXPLAIN FORMAT=TREE (MySQL 8.0.18+, best for understanding execution flow)
EXPLAIN FORMAT=TREE
SELECT u.email, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01'
GROUP BY u.id
HAVING order_count > 5;

-- CORRECT: EXPLAIN FORMAT=JSON (detailed cost estimates and optimizer decisions)
EXPLAIN FORMAT=JSON
SELECT u.email, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01'
GROUP BY u.id;

-- CORRECT: EXPLAIN ANALYZE (MySQL 8.0.18+, actually executes and shows real timing)
EXPLAIN ANALYZE
SELECT u.email, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01'
GROUP BY u.id;

-- WRONG: Guessing at performance without running EXPLAIN
-- "This query is probably slow because of the JOIN" -- measure, don't guess
```

### Reading the EXPLAIN Output

The traditional EXPLAIN output contains these critical columns:

- **type** (access type): How MySQL accesses the table, from best to worst:
  - `system` / `const`: Single-row lookup by primary key or unique index
  - `eq_ref`: One row per row from previous table (unique index join)
  - `ref`: Multiple rows from index lookup (non-unique index)
  - `range`: Index range scan (BETWEEN, <, >, IN)
  - `index`: Full index scan (reads entire index, better than ALL)
  - `ALL`: Full table scan (worst, reads every row)
- **key**: Which index MySQL chose (NULL means no index used)
- **rows**: Estimated number of rows MySQL must examine
- **filtered**: Percentage of rows that match the WHERE condition after access
- **Extra**: Additional operation info (Using filesort, Using temporary, Using index)

### Key EXPLAIN Warning Signs

Watch for these patterns in EXPLAIN output that indicate performance problems:

```sql
-- WARNING: type=ALL (full table scan)
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com'\G
-- type: ALL, rows: 1000000 (bad!)
-- Fix: CREATE UNIQUE INDEX uniq_users_email ON users(email);
-- After: type: const, rows: 1 (good!)

-- WARNING: Extra contains "Using filesort"
EXPLAIN SELECT * FROM orders WHERE user_id = 123 ORDER BY created_at DESC\G
-- Extra: Using filesort (sorting in memory or on disk)
-- Fix: CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);
-- After: Extra: Using index condition (index provides sort order)

-- WARNING: Extra contains "Using temporary"
EXPLAIN SELECT status, COUNT(*) FROM orders GROUP BY status\G
-- Extra: Using temporary; Using filesort (temp table + sort)
-- Fix: CREATE INDEX idx_orders_status ON orders(status);
-- After: Extra: Using index (index-only scan with implicit ordering)

-- WARNING: rows examined >> rows returned
EXPLAIN SELECT * FROM logs WHERE created_at > '2026-01-01' AND level = 'ERROR'\G
-- rows: 2000000, filtered: 0.50 (examining 2M rows, returning ~10K)
-- Fix: CREATE INDEX idx_logs_level_created ON logs(level, created_at);
-- After: rows: 10000, filtered: 100.00 (examining only matching rows)
```

### EXPLAIN ANALYZE for Real Execution Metrics

`EXPLAIN ANALYZE` (MySQL 8.0.18+) actually executes the query and reports real timing alongside
estimates. Use it to validate that optimizer estimates match reality.

```sql
EXPLAIN ANALYZE
SELECT p.name, c.name AS category
FROM products p
JOIN categories c ON p.category_id = c.id
WHERE p.price > 100.00
ORDER BY p.name\G

-- Example output:
-- -> Sort: p.name (cost=450 rows=1200) (actual time=12.5..15.2 rows=1150 loops=1)
--     -> Nested loop inner join (cost=350 rows=1200)
--                               (actual time=0.15..10.8 rows=1150 loops=1)
--         -> Filter: (p.price > 100.00) (cost=250 rows=1200)
--                    (actual time=0.12..8.5 rows=1150 loops=1)
--             -> Table scan on p (cost=250 rows=5000)
--                (actual time=0.10..6.2 rows=5000 loops=1)
--         -> Single-row index lookup on c using PRIMARY (id=p.category_id)
--             (cost=0.08 rows=1) (actual time=0.002..0.002 rows=1 loops=1150)

-- Key observations:
-- 1. Table scan on products examines all 5000 rows to find 1150 matching
-- 2. An index on products(price) would reduce the scan to ~1150 rows
-- 3. The join uses PRIMARY key lookup (efficient, 0.002ms per lookup)
-- 4. The sort adds ~4.4ms overhead (15.2 - 10.8)
-- 5. Compare estimated rows (1200) vs actual rows (1150) -- optimizer is close here
```

## Index Strategy

Indexes are the most impactful performance optimization. A well-designed index strategy eliminates
full table scans, reduces I/O, and enables index-only queries.

### B-tree Index Fundamentals

B-tree indexes (the default in InnoDB) support equality lookups, range scans, and prefix matching.

```sql
-- CORRECT: Composite index for equality + range query
CREATE INDEX idx_orders_user_status_created
  ON orders(user_id, status, created_at);

-- This index efficiently serves:
SELECT * FROM orders
WHERE user_id = 123 AND status = 'shipped' AND created_at > '2025-06-01';

-- Also serves leftmost-prefix queries:
SELECT * FROM orders WHERE user_id = 123;
SELECT * FROM orders WHERE user_id = 123 AND status = 'shipped';

-- WRONG: Query cannot use the index (missing leftmost prefix)
SELECT * FROM orders WHERE status = 'shipped';
-- type: ALL (full table scan, user_id prefix missing)

-- WRONG: Range on middle column stops index usage for subsequent columns
SELECT * FROM orders
WHERE user_id = 123 AND status > 'a' AND created_at > '2025-06-01';
-- Only user_id and status use the index; created_at requires a filter
```

### Covering Indexes

A covering index contains all columns needed by a query, eliminating table data reads ("Using index"
in EXPLAIN Extra).

```sql
-- CORRECT: Covering index for a frequent query
CREATE INDEX idx_users_active_created_covering
  ON users(is_active, created_at, user_id, email);

EXPLAIN SELECT user_id, email, created_at FROM users
WHERE is_active = 1 ORDER BY created_at\G
-- Extra: Using index  <-- covering index, no table access!

-- WRONG: Index only on WHERE column -- requires table lookup for SELECT columns
CREATE INDEX idx_users_active ON users(is_active);
-- Extra: Using filesort  <-- must read table and sort results

-- Covering index column order:
-- 1. WHERE/JOIN columns first (filter)
-- 2. ORDER BY columns next (sort elimination)
-- 3. SELECT columns last (avoid table lookup)
-- 4. Only worthwhile for frequent, performance-critical queries
```

### InnoDB Clustered Index and Secondary Index Lookups

InnoDB stores table data organized by the primary key (clustered index). Every secondary index
stores the primary key value at each leaf node, requiring a double lookup: secondary index to find
the PK, then clustered index to find the row.

```sql
-- Secondary index lookup path:
-- Table: orders (id BIGINT PK, user_id BIGINT, status VARCHAR, total DECIMAL)
-- Index: idx_orders_user_id (user_id)
-- Query: SELECT * FROM orders WHERE user_id = 123;
-- Step 1: Scan idx_orders_user_id -> finds entries with user_id=123, each has id=<PK>
-- Step 2: For each PK, look up full row in clustered index (random I/O!)

-- A covering index eliminates Step 2:
CREATE INDEX idx_orders_user_covering ON orders(user_id, status, total);
-- SELECT status, total FROM orders WHERE user_id = 123;
-- Only Step 1 needed, no clustered index lookup
```

### Index Merge Optimization

```sql
-- WRONG: Relying on index merge (two single-column indexes intersected)
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
-- EXPLAIN: type: index_merge, Using intersect(...) -- slower than composite

-- CORRECT: Single composite index
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
-- EXPLAIN: type: ref -- single index lookup, no merge step
```

### FULLTEXT Index for Text Search

```sql
-- CORRECT: FULLTEXT for natural language search
CREATE FULLTEXT INDEX ft_articles_content ON articles(title, body);

SELECT id, title,
  MATCH(title, body) AGAINST ('mysql performance' IN NATURAL LANGUAGE MODE) AS relevance
FROM articles
WHERE MATCH(title, body) AGAINST ('mysql performance' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC LIMIT 20;

-- Boolean mode for complex queries:
SELECT id, title FROM articles
WHERE MATCH(title, body) AGAINST ('+mysql +performance -oracle' IN BOOLEAN MODE);

-- WRONG: LIKE with leading wildcard (always full table scan)
SELECT id, title FROM articles WHERE title LIKE '%mysql%';
```

### Spatial Indexes (GIS Data)

Spatial indexes use R-tree structures for geographic queries. Require POINT/GEOMETRY columns with
SRID specification on MySQL 8.0+.

```sql
-- Spatial index for location-based queries
CREATE TABLE stores (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  location POINT NOT NULL SRID 4326,
  SPATIAL INDEX idx_stores_location (location)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Find stores within a bounding box
SELECT id, name, ST_AsText(location) FROM stores
WHERE MBRContains(
  ST_GeomFromText('POLYGON((
    -73.99 40.75, -73.95 40.75, -73.95 40.78, -73.99 40.78, -73.99 40.75
  ))', 4326),
  location
);
```

### Hash Indexes (MEMORY Engine Only)

Hash indexes provide O(1) equality lookups but do not support range queries, ordering, or partial
key matching. Available only on the MEMORY (HEAP) engine.

```sql
-- Hash index on MEMORY table for session cache
CREATE TABLE session_cache (
  session_id CHAR(64) NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  data JSON NOT NULL,
  PRIMARY KEY USING HASH (session_id)
) ENGINE=MEMORY;
-- Fast O(1) equality: SELECT data FROM session_cache WHERE session_id = 'abc123';
-- WRONG: Range queries cannot use hash index -- use BTREE instead
```

## Buffer Pool Tuning

The InnoDB buffer pool is the most critical memory structure for MySQL performance, caching data and
index pages to reduce disk I/O.

### Sizing the Buffer Pool

```ini
# CORRECT: Dedicated database server (70-80% of available RAM)
# Server with 64GB RAM:
[mysqld]
innodb_buffer_pool_size = 48G

# CORRECT: Shared server (50-60% of RAM, leaving room for OS + other services)
[mysqld]
innodb_buffer_pool_size = 16G

# WRONG: Default 128MB on a server with 64GB RAM
# innodb_buffer_pool_size = 128M  -- forces almost every read to hit disk
```

### Buffer Pool Instances

```ini
# CORRECT: Multiple instances for large buffer pools (>1GB, reduces mutex contention)
[mysqld]
innodb_buffer_pool_size = 48G
innodb_buffer_pool_instances = 8
# Each instance = 48G / 8 = 6GB

# WRONG: Too many instances for the pool size
# innodb_buffer_pool_size = 2G
# innodb_buffer_pool_instances = 16  -- each instance only 128MB, wasted overhead
```

### Monitoring Buffer Pool Hit Rate

```sql
-- Check hit rate from SHOW ENGINE INNODB STATUS
SHOW ENGINE INNODB STATUS\G
-- Look for: "Buffer pool hit rate 999 / 1000" (99.9%, excellent)

-- Programmatic check:
SELECT
  (1 - (
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_reads') /
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_read_requests')
  )) * 100 AS buffer_pool_hit_rate_pct;
-- If hit rate < 99%, the buffer pool is too small or working set is too large
```

### Buffer Pool Warmup

```ini
# Enable buffer pool dump/load on restart to reduce cold-start penalty
[mysqld]
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup = ON
innodb_buffer_pool_dump_pct = 75
```

## Slow Query Log

The slow query log captures queries exceeding a configurable execution time threshold.

### Enabling and Configuring

```ini
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
log_queries_not_using_indexes = ON
min_examined_row_limit = 1000
```

### Analyzing with pt-query-digest and mysqldumpslow

```bash
# Top slow queries by total time
mysqldumpslow -s t -t 10 /var/log/mysql/slow.log

# Detailed analysis with Percona pt-query-digest
pt-query-digest /var/log/mysql/slow.log

# Filter by time range
pt-query-digest --since '2026-02-08' --until '2026-02-09' /var/log/mysql/slow.log
```

### Key Slow Query Metrics

When analyzing slow queries, focus on these indicators:

```text
# High Lock_time indicates lock contention:
# Query_time: 5.2s, Lock_time: 4.8s  -- 92% of time waiting for locks!
# Fix: reduce transaction scope, add indexes, check for long-running transactions

# Rows_examined >> Rows_sent indicates missing or poor indexes:
# Rows_examined: 5000000, Rows_sent: 12
# Fix: Add a targeted index to reduce examined rows to match sent rows

# Example slow query log entry:
# # Time: 2026-02-09T10:15:30.123456Z
# # User@Host: app_user[app_user] @ 10.0.1.50
# # Query_time: 8.543210  Lock_time: 0.000123  Rows_sent: 15  Rows_examined: 3500000
# SET timestamp=1739095530;
# SELECT o.id, o.total, u.email
# FROM orders o JOIN users u ON o.user_id = u.id
# WHERE o.created_at > '2025-01-01' AND o.status = 'pending';
#
# Diagnosis:
# 1. Query_time = 8.5s (far too slow for an OLTP query)
# 2. Lock_time = 0.0001s (no lock contention)
# 3. Rows_examined = 3.5M vs Rows_sent = 15 (terrible selectivity)
# 4. Fix: CREATE INDEX idx_orders_status_created ON orders(status, created_at);
```

## Optimizer Hints

MySQL 8.0+ supports optimizer hints via `/*+ ... */` syntax. Use hints sparingly and prefer query
restructuring over hints.

```sql
-- CORRECT: Hint for specific join strategy when optimizer chooses poorly
SELECT /*+ BKA(o) */
  u.email, o.total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01';

-- CORRECT: Disable hash join when it causes excessive memory usage
SELECT /*+ NO_HASH_JOIN(o, oi) */
  o.id, SUM(oi.price * oi.quantity) AS total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id;

-- CORRECT: Force or exclude specific indexes
SELECT /*+ INDEX(orders idx_orders_status_created) */ id, total FROM orders
WHERE status = 'pending' AND created_at > '2025-06-01';

SELECT /*+ NO_INDEX(orders idx_orders_created_at) */ id, total FROM orders
WHERE status = 'pending' AND created_at > '2025-06-01';

-- WRONG: Overloading hints to fix what better indexes would solve
SELECT /*+ HASH_JOIN(t1, t2) NO_BKA(t1) SET_VAR(join_buffer_size=512M) */
  t1.*, t2.*
FROM huge_table t1 JOIN huge_table_2 t2 ON t1.key = t2.key;
-- Fix the indexes and query structure instead of piling on hints
```

### Hint Reference

```sql
-- Join hints: BKA(), NO_BKA(), HASH_JOIN(), NO_HASH_JOIN(), JOIN_ORDER()
-- Index hints: INDEX(), NO_INDEX(), INDEX_MERGE(), NO_INDEX_MERGE()
-- Subquery hints: SEMIJOIN(), SUBQUERY()
-- Resource hints: MAX_EXECUTION_TIME(ms), SET_VAR(var=value)
```

## InnoDB Internals for Performance

### Redo Log Sizing

The InnoDB redo log records all changes before they are written to data files. If the redo log is
too small, InnoDB must flush dirty pages more aggressively, causing checkpoint stalls.

```ini
# CORRECT: Size redo log to handle ~1 hour of writes during peak
[mysqld]
innodb_redo_log_capacity = 4G   # MySQL 8.0.30+
# MySQL 8.0.29 and earlier: innodb_log_file_size = 2G, innodb_log_files_in_group = 2

# WRONG: Default 48MB on write-heavy system -- causes frequent checkpoint stalls
```

```sql
-- Monitor redo log usage to determine correct size
-- Check bytes written per hour during peak:
SELECT variable_value AS bytes_written
FROM performance_schema.global_status
WHERE variable_name = 'Innodb_os_log_written';
-- Record this value, wait 1 hour, check again
-- Difference = bytes per hour; set innodb_redo_log_capacity to at least that value
```

### Flush Configuration

```ini
[mysqld]
# Full ACID (default, safest):
innodb_flush_log_at_trx_commit = 1

# Non-critical workloads (2-10x better writes, slight durability trade-off):
# innodb_flush_log_at_trx_commit = 2
# Writes to OS buffer on commit, flushes to disk once per second
# At most 1 second of transactions lost on OS crash (safe from MySQL crash)
```

### I/O Capacity Settings

```ini
# Match I/O capacity to storage hardware
[mysqld]
# SSD: innodb_io_capacity = 2000, innodb_io_capacity_max = 4000
# NVMe array: innodb_io_capacity = 10000, innodb_io_capacity_max = 20000
# HDD: innodb_io_capacity = 200, innodb_io_capacity_max = 400

# WRONG: Default 200 on fast SSD -- InnoDB won't flush pages fast enough
```

## Join Optimization

Join performance is critical for relational queries. MySQL uses nested loop joins by default, with
hash joins available in 8.0.18+.

### Nested Loop Join Optimization

```sql
-- CORRECT: Ensure join columns are indexed on the inner (right) table
SELECT u.email, o.total FROM users u
JOIN orders o ON o.user_id = u.id WHERE u.country = 'US';
-- Required: INDEX on orders(user_id) for join lookup
-- Required: INDEX on users(country) for WHERE filter

-- WRONG: Missing index on join column forces full scan of inner table
-- for EVERY row in outer table -- catastrophic for large tables
```

### Hash Join (MySQL 8.0.18+)

MySQL 8.0.18+ can use hash joins for equi-joins without indexes. The optimizer builds a hash table
from the smaller table and probes it with rows from the larger table.

```sql
-- Hash join is automatic when no suitable index exists
EXPLAIN FORMAT=TREE
SELECT d.name, COUNT(e.id) AS emp_count
FROM departments d
JOIN employees e ON e.dept_id = d.id
GROUP BY d.id;
-- If output shows "Hash join" -- optimizer chose hash join
-- For OLTP queries, prefer indexed nested loop joins (add proper indexes)
-- For analytical queries on large datasets, hash join is often acceptable
```

### Join Order Optimization

```sql
-- CORRECT: Help the optimizer with STRAIGHT_JOIN when it chooses poorly
-- Use only after EXPLAIN confirms suboptimal join order
SELECT STRAIGHT_JOIN u.email, o.total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2025-01-01' AND o.status = 'pending';
-- Forces left-to-right join order as written

-- WRONG: Using STRAIGHT_JOIN without profiling first
-- STRAIGHT_JOIN removes the optimizer's ability to choose the best order
-- Only use when you have confirmed the optimizer's choice is wrong
```

## Subquery Optimization

### Correlated Subquery to JOIN Rewrite

```sql
-- WRONG: Correlated subquery (executes once per outer row)
SELECT u.email FROM users u
WHERE u.id IN (
  SELECT o.user_id FROM orders o WHERE o.total > 1000
);

-- CORRECT: Rewrite as JOIN
SELECT DISTINCT u.email FROM users u
JOIN orders o ON o.user_id = u.id WHERE o.total > 1000;

-- CORRECT: EXISTS for existence checks (optimizer handles well)
SELECT u.email FROM users u
WHERE EXISTS (
  SELECT 1 FROM orders o WHERE o.user_id = u.id AND o.total > 1000
);
```

### Scalar Subquery in SELECT

```sql
-- WRONG: Scalar subquery executes once per result row
SELECT u.email,
  (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count,
  (SELECT MAX(o.created_at) FROM orders o WHERE o.user_id = u.id) AS last_order
FROM users u WHERE u.is_active = 1;
-- Two correlated subqueries per user row!

-- CORRECT: LEFT JOIN with aggregation
SELECT u.email, COUNT(o.id) AS order_count, MAX(o.created_at) AS last_order
FROM users u LEFT JOIN orders o ON o.user_id = u.id
WHERE u.is_active = 1 GROUP BY u.id, u.email;
```

### Derived Table Optimization

```sql
-- WRONG: Derived table that materializes all rows before filtering
SELECT * FROM (
  SELECT user_id, SUM(total) AS total_spent
  FROM orders GROUP BY user_id
) AS user_totals
WHERE user_totals.total_spent > 10000;

-- CORRECT: Direct query with HAVING (optimizer can push conditions down)
SELECT user_id, SUM(total) AS total_spent
FROM orders GROUP BY user_id
HAVING total_spent > 10000;

-- MySQL 8.0+ can merge derived tables into the outer query in many cases
-- Check EXPLAIN to verify: "Rematerialize" or "Table scan on <derived>" is suboptimal
```

## Temporary Table and Sort Avoidance

Temporary tables and filesorts are expensive operations. Restructure queries and indexes to
eliminate them whenever possible.

### Avoiding Temporary Tables

```sql
-- WRONG: GROUP BY on non-indexed column creates temp table
SELECT status, COUNT(*) AS cnt FROM orders GROUP BY status;
-- EXPLAIN Extra: Using temporary; Using filesort

-- CORRECT: Index on GROUP BY column eliminates temp table
CREATE INDEX idx_orders_status ON orders(status);
-- EXPLAIN Extra: Using index

-- WRONG: DISTINCT on non-indexed columns creates a temp table
SELECT DISTINCT category_id, brand FROM products;
-- EXPLAIN Extra: Using temporary

-- CORRECT: Composite index covers DISTINCT columns
CREATE INDEX idx_products_category_brand ON products(category_id, brand);
-- EXPLAIN Extra: Using index
```

### Avoiding Filesort

```sql
-- WRONG: ORDER BY on column not in index
SELECT id, title, created_at FROM articles
WHERE author_id = 42 ORDER BY created_at DESC LIMIT 20;
-- With only INDEX(author_id): Extra: Using filesort

-- CORRECT: Composite index covers WHERE + ORDER BY
CREATE INDEX idx_articles_author_created ON articles(author_id, created_at);
-- Index provides both filtering and ordering

-- WRONG: ORDER BY direction mismatch with standard index
SELECT * FROM events WHERE user_id = 123
ORDER BY event_date ASC, priority DESC;
-- Standard index (user_id, event_date, priority) cannot serve mixed sort

-- CORRECT: MySQL 8.0+ descending index support
CREATE INDEX idx_events_user_date_priority
  ON events(user_id, event_date ASC, priority DESC);
-- Now the mixed sort order matches the index
```

### Tuning Memory for Temp Tables and Sorts

```ini
[mysqld]
# Maximum size for in-memory temp tables (per connection)
tmp_table_size = 64M
max_heap_table_size = 64M
# Both must be set -- MySQL uses the smaller of the two

# Sort buffer (per connection, allocated per sort operation)
sort_buffer_size = 4M
# Don't set too high -- allocated per connection, not globally!
# 100 connections * 4MB = 400MB just for sort buffers
```

## Connection Pooling and Thread Management

MySQL creates a thread per connection. Too many connections waste memory and CPU on context
switching, while too few cause application timeouts.

### Server-Side Thread Configuration

```ini
[mysqld]
# Maximum allowed connections
max_connections = 500
# Rule: Set to actual peak concurrent connections + 20% headroom
# Do NOT set to thousands "just in case" -- each idle connection uses ~1MB

# Thread cache for connection reuse
thread_cache_size = 50
# Caches threads after disconnect, avoids thread creation overhead
```

### Monitoring Connection Usage

```sql
-- Monitor connection usage to size the pool correctly
SHOW STATUS LIKE 'Threads_connected';      -- Current active connections
SHOW STATUS LIKE 'Threads_running';        -- Currently executing queries
SHOW STATUS LIKE 'Max_used_connections';   -- Peak connections since last restart

-- If Max_used_connections is close to max_connections:
-- 1. Increase max_connections (but investigate why so many are needed)
-- 2. Implement connection pooling (ProxySQL, MySQL Router, or application-level)
-- 3. Reduce connection hold time in application code
```

### Application-Level Connection Management

```sql
-- WRONG: Holding connections open during non-database work
-- connection = pool.get_connection()
-- result = connection.query("SELECT ...")
-- send_email(result)  # Takes 2 seconds, connection held open!
-- connection.close()

-- CORRECT: Release connection before non-database work
-- connection = pool.get_connection()
-- result = connection.query("SELECT ...")
-- connection.close()  # Release immediately
-- send_email(result)  # Uses no database connection
```

## Query Rewriting Patterns

### Pagination: Keyset vs OFFSET

```sql
-- WRONG: OFFSET pagination (scans and discards rows, gets slower with page number)
SELECT id, title FROM articles ORDER BY created_at DESC LIMIT 20 OFFSET 100000;

-- CORRECT: Keyset (cursor) pagination -- constant time regardless of page
SELECT id, title, created_at FROM articles
WHERE (created_at, id) < ('2025-12-15 08:30:00', 54321)
ORDER BY created_at DESC LIMIT 20;
-- Required: INDEX on (created_at DESC, id DESC)
```

### Avoiding Functions on Indexed Columns

```sql
-- WRONG: Function on indexed column prevents index usage
SELECT * FROM orders WHERE YEAR(created_at) = 2025;

-- CORRECT: Rewrite as range condition
SELECT * FROM orders WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01';

-- WRONG: Math on indexed column
SELECT * FROM products WHERE price * 1.08 > 100;

-- CORRECT: Move math to the constant side
SELECT * FROM products WHERE price > 100 / 1.08;
```

### COUNT Optimization

```sql
-- WRONG: COUNT(*) on large table with complex WHERE (slow even with indexes)
SELECT COUNT(*) FROM orders WHERE created_at > '2025-01-01' AND status = 'shipped';
-- May still scan millions of index entries

-- CORRECT: Use covering index for count
CREATE INDEX idx_orders_status_created ON orders(status, created_at);
-- Now COUNT uses index-only scan

-- CORRECT: Approximate count for display purposes (fast, ~10-20% off for InnoDB)
SELECT table_rows FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_name = 'orders';

-- CORRECT: Cached count for frequently needed totals
CREATE TABLE counters (
  name VARCHAR(100) PRIMARY KEY,
  value BIGINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;
-- Update atomically: UPDATE counters SET value = value + 1 WHERE name = 'active_orders';
```

### IN vs OR vs UNION

```sql
-- CORRECT: IN clause (optimizer handles efficiently with index)
SELECT * FROM users WHERE country IN ('US', 'CA', 'MX');

-- WRONG: Multiple OR conditions on different columns (hard to optimize)
SELECT * FROM products
WHERE category_id = 5 OR brand = 'Acme' OR price < 10;
-- Cannot use a single index effectively

-- CORRECT: UNION ALL for OR on different columns (each branch uses its own index)
SELECT * FROM products WHERE category_id = 5
UNION ALL
SELECT * FROM products WHERE brand = 'Acme' AND category_id != 5
UNION ALL
SELECT * FROM products WHERE price < 10 AND category_id != 5 AND brand != 'Acme';
-- Each SELECT uses its own optimal index
-- Must exclude overlapping rows to avoid duplicates
```

## Performance Schema

The `performance_schema` provides detailed instrumentation of MySQL internals without the overhead
of general query logging. It is the preferred tool for production performance analysis.

### Essential Performance Schema Queries

```sql
-- Top 10 queries by total execution time
SELECT
  DIGEST_TEXT AS query_pattern,
  COUNT_STAR AS exec_count,
  ROUND(SUM_TIMER_WAIT / 1e12, 3) AS total_sec,
  ROUND(AVG_TIMER_WAIT / 1e12, 3) AS avg_sec,
  SUM_ROWS_EXAMINED AS rows_examined,
  SUM_ROWS_SENT AS rows_sent
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;

-- Queries with worst rows_examined / rows_sent ratio (missing indexes)
SELECT
  DIGEST_TEXT AS query_pattern,
  COUNT_STAR AS exec_count,
  SUM_ROWS_EXAMINED AS examined,
  SUM_ROWS_SENT AS sent,
  ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 1) AS examine_to_send_ratio
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_ROWS_SENT > 0
ORDER BY SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0) DESC LIMIT 10;

-- Tables with most I/O wait time
SELECT
  OBJECT_SCHEMA AS db,
  OBJECT_NAME AS table_name,
  COUNT_STAR AS io_count,
  ROUND(SUM_TIMER_WAIT / 1e12, 3) AS total_io_sec,
  COUNT_READ AS reads,
  COUNT_WRITE AS writes
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys')
ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;

-- Find unused indexes (candidates for removal -- save write overhead)
SELECT OBJECT_SCHEMA, OBJECT_NAME, INDEX_NAME
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys')
  AND INDEX_NAME IS NOT NULL AND COUNT_STAR = 0
ORDER BY OBJECT_SCHEMA, OBJECT_NAME;
```

### Enabling Performance Schema

```ini
# Enable performance_schema with targeted instruments
[mysqld]
performance_schema = ON
performance_schema_instrument = 'statement/%=ON'
performance_schema_instrument = 'wait/io/file/%=ON'
performance_schema_instrument = 'wait/io/table/%=ON'
# Typically 200-400MB memory overhead, acceptable on production servers
```

## Common Performance Wins

### 1. Set innodb_flush_log_at_trx_commit for Your Workload

For replicated, non-critical workloads, `innodb_flush_log_at_trx_commit=2` provides 2-10x better
write throughput with minimal durability risk.

### 2. Match innodb_io_capacity to Storage

Benchmark storage IOPS with `fio` and set `innodb_io_capacity` to 50-75% of measured value.

### 3. Size Redo Log for 1 Hour of Writes

Monitor `Innodb_os_log_written` over one hour during peak and set `innodb_redo_log_capacity`
accordingly. Prevents checkpoint stalls during write-heavy periods.

### 4. ANALYZE TABLE After Bulk Operations

```sql
-- After large INSERT/UPDATE/DELETE, refresh optimizer statistics
ANALYZE TABLE orders;
-- Without fresh statistics, the optimizer may choose poor execution plans
```

### 5. Optimize Data Types for Cache Efficiency

```sql
-- CORRECT: Right-sized types (more rows per buffer pool page)
CREATE TABLE events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_type TINYINT UNSIGNED NOT NULL,   -- 1 byte, not VARCHAR(255)
  user_id INT UNSIGNED NOT NULL,           -- 4 bytes if < 4B users
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP  -- 4 bytes
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: Oversized types waste buffer pool space
CREATE TABLE events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_type VARCHAR(255) NOT NULL,  -- 256+ bytes for a few dozen values
  user_id BIGINT UNSIGNED NOT NULL,  -- 8 bytes when 4B is enough
  created_at DATETIME(6) NOT NULL    -- 8 bytes when TIMESTAMP is 4 bytes
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 6. Use Read Replicas for Read-Heavy Workloads

Route read queries to replicas, writes to the primary. Monitor `Seconds_Behind_Source` and fall back
to primary if replica lag exceeds the acceptable threshold.

## Performance Tuning Checklist

```sql
-- 1. Full table scans in current queries
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY no_index_used_count DESC LIMIT 10;

-- 2. Unused indexes (wasting write performance)
SELECT * FROM sys.schema_unused_indexes
WHERE object_schema NOT IN ('mysql', 'performance_schema', 'sys');

-- 3. Redundant indexes
SELECT * FROM sys.schema_redundant_indexes
WHERE table_schema NOT IN ('mysql', 'performance_schema', 'sys');

-- 4. Buffer pool hit rate
SELECT FORMAT(
  (1 - Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests) * 100, 2
) AS hit_rate_pct
FROM (
  SELECT
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_reads') AS Innodb_buffer_pool_reads,
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_read_requests') AS Innodb_buffer_pool_read_requests
) AS stats;

-- 5. Lock contention
SELECT * FROM sys.innodb_lock_waits;

-- 6. Table sizes and fragmentation
SELECT table_name, table_rows,
  ROUND(data_length / 1024 / 1024, 2) AS data_mb,
  ROUND(index_length / 1024 / 1024, 2) AS index_mb,
  ROUND(data_free / 1024 / 1024, 2) AS fragmented_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY data_length + index_length DESC LIMIT 20;

-- 7. Slow query log status
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- 8. Connection and thread status
SHOW STATUS LIKE 'Threads_%';
SHOW STATUS LIKE 'Max_used_connections';
```

## Anti-Patterns to Avoid

### 1. Tuning Without Measuring

```sql
-- WRONG: Blindly increasing buffer sizes
-- "My queries are slow, let me set join_buffer_size = 1G"

-- CORRECT: Measure first, tune based on evidence
-- Step 1: EXPLAIN the slow query
-- Step 2: Identify the bottleneck (full scan? filesort? temp table?)
-- Step 3: Apply targeted fix (add index, rewrite query, tune specific setting)
-- Step 4: Verify improvement with EXPLAIN ANALYZE
```

### 2. Over-Indexing

```sql
-- WRONG: Index on every column "just in case"
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  sku VARCHAR(100) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  INDEX idx_name (name),
  INDEX idx_sku (sku),
  INDEX idx_price (price),
  INDEX idx_category (category_id),
  INDEX idx_name_price (name, price),
  INDEX idx_category_price (category_id, price)
  -- 6 indexes! Every INSERT/UPDATE maintains all 6
);

-- CORRECT: Index only for known query patterns
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  sku VARCHAR(100) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  UNIQUE KEY uniq_products_sku (sku),
  INDEX idx_products_category_price (category_id, price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 3. Per-Connection Buffers Too High

```ini
# WRONG: 200 connections * (256 + 256 + 128) MB = 125 GB potential memory
# sort_buffer_size = 256M
# join_buffer_size = 256M

# CORRECT: Conservative per-connection buffers, fix queries instead
sort_buffer_size = 2M
join_buffer_size = 2M
```

### 4. Ignoring Implicit Type Conversions

```sql
-- WRONG: VARCHAR column compared to INTEGER (full table scan)
SELECT * FROM users WHERE phone = 5551234567;
-- MySQL converts every phone value to integer for comparison!

-- CORRECT: Match the type
SELECT * FROM users WHERE phone = '5551234567';
```

## Core Principles

- **Measure before tuning**: Always use EXPLAIN, EXPLAIN ANALYZE, slow query log, and
  performance_schema before making changes. Cargo-cult tuning wastes time and can make things worse.

- **Index for your queries**: Design indexes based on actual query patterns, not theoretical needs.
  Use EXPLAIN to validate that each index is used.

- **Buffer pool is king**: The InnoDB buffer pool is the single most impactful setting. Size it to
  70-80% of RAM on dedicated servers and monitor the hit rate.

- **Right-size data types**: Smaller types mean more rows per page, better cache utilization, and
  smaller indexes. Use the smallest type that safely holds your data.

- **Eliminate full table scans**: Every OLTP query should use an index. Full table scans (type=ALL)
  on large tables are performance killers.

- **Understand the trade-offs**: Every index speeds reads but slows writes. Every buffer increase
  uses memory. Make informed decisions based on workload characteristics.

- **Test on representative data**: Query plans change with data distribution. A fast query on 1000
  rows may be slow on 10 million. Test with production-scale data volumes.

- **Monitor continuously**: Performance is not a one-time task. Use performance_schema, slow query
  log, and buffer pool metrics to detect regressions early.
