---
name: migration-patterns
description:
  This skill should be used when writing database migrations, altering tables, adding columns,
  creating indexes, or planning schema changes for PostgreSQL.
version: 0.1.0
---

# Migration Patterns

Safe, reversible PostgreSQL schema migrations are fundamental to maintaining database integrity and
enabling continuous deployment. This skill covers production-grade migration patterns that minimize
downtime, prevent data loss, and ensure rollback capability. Every migration should be tested on a
replica, have a documented rollback path, and consider the impact on running applications.

## Existing Repository Compatibility

When working with existing PostgreSQL deployments, always respect the current migration framework
and patterns before applying these recommendations.

- **Follow existing conventions**: If the project uses a specific migration tool (Alembic, Flyway,
  golang-migrate, etc.), follow that tool's conventions for file naming, directory structure, and
  migration format.
- **Numbering schemes**: Respect the existing numbering or timestamping convention. Do not mix
  sequential numbers with timestamps.
- **Transaction handling**: Some tools wrap migrations in transactions automatically. Understand
  your tool's behavior before adding explicit BEGIN/COMMIT.
- **Down migrations**: If the project maintains down migrations, always include them. If the project
  does not use down migrations, follow the established pattern.
- **Testing requirements**: Follow existing testing requirements for migrations (staging deployment,
  replica testing, backup verification, etc.).

**These patterns apply primarily to new migrations. For modifying existing migrations, coordinate
with the team and understand the deployment state across all environments.**

## Up/Down Migration Pairs

Every migration must have a corresponding down migration that reverses the changes. This enables
safe rollbacks during deployment failures or when bugs are discovered in production.

### Reversible Migration Example

```sql
-- Up Migration: 20260209_01_add_user_status.sql
ALTER TABLE users ADD COLUMN status text NOT NULL DEFAULT 'active';

CREATE INDEX CONCURRENTLY idx_users_status ON users (status);
```

```sql
-- Down Migration: 20260209_01_add_user_status_down.sql
DROP INDEX CONCURRENTLY IF EXISTS idx_users_status;

ALTER TABLE users DROP COLUMN status;
```

### Irreversible Migrations

Some migrations cannot be fully reversed without data loss. These must be clearly documented.

```sql
-- Up Migration: 20260209_02_remove_legacy_column.sql
-- WARNING: This migration is IRREVERSIBLE
-- The 'legacy_notes' column data will be permanently deleted
-- Backup taken: prod_backup_20260209_083000.sql.gz
-- Rollback plan: Restore column from backup if needed within 24h window

ALTER TABLE users DROP COLUMN legacy_notes;
```

```sql
-- Down Migration: 20260209_02_remove_legacy_column_down.sql
-- PARTIAL ROLLBACK: Re-creates column structure but data is lost
-- To restore data, use backup: prod_backup_20260209_083000.sql.gz

ALTER TABLE users ADD COLUMN legacy_notes text;
-- Data must be restored from backup separately
```

### Documenting Irreversible Operations

Every irreversible migration must include:

1. **WARNING comment** at the top of the file
2. **Backup reference**: When and where the backup was taken
3. **Rollback plan**: Steps to recover if the migration causes issues
4. **Data retention window**: How long backup data is available

```sql
-- Migration: 20260209_03_truncate_old_logs.sql
-- ============================================================
-- WARNING: IRREVERSIBLE MIGRATION
-- ============================================================
-- Action: Truncate event_log entries older than 2 years
-- Affected rows (estimated): ~50M
-- Backup: s3://backups/event_log_pre_truncate_20260209.dump.gz
-- Rollback: Restore from backup within 30-day retention window
-- Approved by: DBA Team (ticket INFRA-1234)
-- ============================================================

DELETE FROM event_log
WHERE created_at < now() - interval '2 years';

-- Run VACUUM after large deletes to reclaim space
-- VACUUM (VERBOSE) event_log;  -- Run separately, not in migration transaction
```

## Expand-Contract Pattern

The expand-contract pattern enables zero-downtime schema changes by splitting migrations into
multiple steps with application code changes between them.

### Phase 1: Expand (Add New Structure)

Add the new column, table, or constraint without removing the old one. Both old and new application
code must work.

```sql
-- Migration: 20260209_10_expand_add_email_verified.sql
-- Phase 1 of 3: Add new column alongside old one
-- Old column: email_confirmed (integer 0/1)
-- New column: email_verified (boolean)

ALTER TABLE users ADD COLUMN email_verified boolean;

-- Backfill new column from old column (in batches for large tables)
-- Do this in application code or a separate migration for large tables
UPDATE users SET email_verified = (email_confirmed = 1)
WHERE email_verified IS NULL;
```

### Phase 2: Migrate (Update Application Code)

Deploy application code that writes to both old and new columns and reads from the new column. This
is not a SQL migration but an application deployment step.

### Phase 3: Contract (Remove Old Structure)

After all application instances use the new column and sufficient time has passed, remove the old
column.

```sql
-- Migration: 20260209_11_contract_remove_email_confirmed.sql
-- Phase 3 of 3: Remove old column
-- Prerequisite: All application code uses email_verified (deployed 2026-02-05)
-- Verification: No queries reference email_confirmed in pg_stat_statements

-- Add NOT NULL constraint now that all rows have values
ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;
ALTER TABLE users ALTER COLUMN email_verified SET DEFAULT false;

-- Drop old column
ALTER TABLE users DROP COLUMN email_confirmed;
```

### Expand-Contract for Table Renames

```sql
-- Phase 1: Create new table, set up sync
-- Migration: 20260209_20_expand_rename_orders.sql
CREATE TABLE customer_orders (LIKE orders INCLUDING ALL);

-- Create trigger to sync inserts/updates from old to new table
CREATE OR REPLACE FUNCTION sync_orders_to_customer_orders()
RETURNS trigger AS $$
BEGIN
    INSERT INTO customer_orders
    SELECT NEW.*
    ON CONFLICT (id) DO UPDATE SET
        customer_id = EXCLUDED.customer_id,
        total = EXCLUDED.total,
        status = EXCLUDED.status,
        updated_at = EXCLUDED.updated_at;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_orders
    AFTER INSERT OR UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION sync_orders_to_customer_orders();

-- Backfill existing data
INSERT INTO customer_orders SELECT * FROM orders
ON CONFLICT (id) DO NOTHING;
```

```sql
-- Phase 3: Drop old table after application migration
-- Migration: 20260209_21_contract_drop_orders.sql
-- Prerequisite: All code reads/writes customer_orders (deployed 2026-02-07)

DROP TRIGGER trg_sync_orders ON orders;
DROP FUNCTION sync_orders_to_customer_orders();
DROP TABLE orders;
```

## CREATE INDEX CONCURRENTLY

Standard `CREATE INDEX` acquires a lock that blocks writes on the table for the duration of index
creation. For any table with traffic, always use `CREATE INDEX CONCURRENTLY`.

### Standard vs Concurrent Index Creation

```sql
-- WRONG: Blocks writes for the entire duration of index build
CREATE INDEX idx_orders_customer ON orders (customer_id);
-- On a 50M row table, this could block writes for minutes

-- CORRECT: Non-blocking index creation
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
-- Takes longer but does not block writes

-- CORRECT: With IF NOT EXISTS (idempotent)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer
    ON orders (customer_id);
```

### CONCURRENTLY Constraints

`CREATE INDEX CONCURRENTLY` has specific constraints you must understand:

```sql
-- CONSTRAINT 1: Cannot run inside a transaction block
-- WRONG:
BEGIN;
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
COMMIT;
-- ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block

-- Many migration tools wrap each migration in a transaction.
-- You must disable this for concurrent index migrations:
-- Flyway: Use non-transactional migration (V<ver>__<desc>.sql in non-transactional mode)
-- Alembic: Use op.execute() with connection.execution_options(isolation_level="AUTOCOMMIT")
-- golang-migrate: Disable transaction wrapping for this migration
-- dbmate: Add -- disable-transaction comment
```

```sql
-- CONSTRAINT 2: May leave INVALID indexes on failure
-- If CREATE INDEX CONCURRENTLY fails (e.g., deadlock, unique violation), it leaves
-- an INVALID index that must be cleaned up manually.

-- Check for invalid indexes
SELECT indexname, indexdef
FROM pg_indexes
JOIN pg_index ON pg_indexes.indexname::regclass = pg_index.indexrelid::regclass
WHERE NOT pg_index.indisvalid;

-- Clean up invalid index
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_customer;

-- Retry
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
```

```sql
-- CONSTRAINT 3: Takes longer than regular CREATE INDEX
-- Two passes: first builds index, then validates. During the second pass,
-- it must wait for all existing transactions to complete.

-- Monitor progress (PostgreSQL 12+)
SELECT phase, blocks_total, blocks_done,
       round(100.0 * blocks_done / NULLIF(blocks_total, 0), 1) AS pct
FROM pg_stat_progress_create_index;
```

### DROP INDEX CONCURRENTLY

Use `DROP INDEX CONCURRENTLY` to avoid blocking writes during index removal.

```sql
-- CORRECT: Non-blocking index drop
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_old_status;

-- Note: Cannot run inside a transaction, same as CREATE INDEX CONCURRENTLY
```

### Replacing an Index

When replacing one index with another (e.g., changing column order):

```sql
-- Step 1: Create new index concurrently
CREATE INDEX CONCURRENTLY idx_orders_status_date_new
    ON orders (status, created_at DESC);

-- Step 2: Verify new index is valid and being used
-- Wait for traffic to confirm index is used:
SELECT indexname, idx_scan
FROM pg_stat_user_indexes
WHERE tablename = 'orders' AND indexname LIKE '%status%';

-- Step 3: Drop old index concurrently
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_status_old;

-- Step 4: Rename new index to standard name
ALTER INDEX idx_orders_status_date_new RENAME TO idx_orders_status_date;
```

## Guard Clauses

Guard clauses make migrations idempotent and safe to re-run. Every migration should be safe to
execute multiple times without error.

### IF NOT EXISTS / IF EXISTS

```sql
-- CORRECT: Idempotent table creation
CREATE TABLE IF NOT EXISTS audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id bigint NOT NULL,
    changes jsonb NOT NULL DEFAULT '{}',
    performed_by bigint,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- CORRECT: Idempotent column addition (PostgreSQL doesn't have IF NOT EXISTS for columns)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'middle_name'
    ) THEN
        ALTER TABLE users ADD COLUMN middle_name text;
    END IF;
END $$;

-- CORRECT: Idempotent index creation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_entity
    ON audit_log (entity_type, entity_id);

-- CORRECT: Idempotent extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CORRECT: Idempotent drop
DROP TABLE IF EXISTS temp_migration_data;
DROP INDEX CONCURRENTLY IF EXISTS idx_old_unused;
```

### Pre-Condition Checks

```sql
-- CORRECT: Check preconditions before migration
DO $$
BEGIN
    -- Verify table exists before altering
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'orders'
    ) THEN
        RAISE EXCEPTION 'Table "orders" does not exist; run migration V001 first';
    END IF;

    -- Verify column doesn't already exist
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'shipping_method'
    ) THEN
        RAISE NOTICE 'Column "shipping_method" already exists; skipping';
        RETURN;
    END IF;

    -- Add the column
    ALTER TABLE orders ADD COLUMN shipping_method text DEFAULT 'standard';
END $$;
```

### Version Guards

```sql
-- CORRECT: Check PostgreSQL version before using version-specific features
DO $$
BEGIN
    IF current_setting('server_version_num')::integer < 150000 THEN
        RAISE EXCEPTION 'This migration requires PostgreSQL 15+. Current: %',
                        current_setting('server_version');
    END IF;
END $$;

-- CORRECT: Check extension version before using version-specific features
DO $$
DECLARE
    v_version text;
BEGIN
    SELECT extversion INTO v_version
    FROM pg_extension WHERE extname = 'postgis';

    IF v_version IS NULL THEN
        RAISE EXCEPTION 'PostGIS extension is not installed';
    END IF;

    IF v_version < '3.4' THEN
        RAISE EXCEPTION 'This migration requires PostGIS 3.4+. Current: %', v_version;
    END IF;
END $$;
```

## Column Operations

### Adding Columns

```sql
-- CORRECT: Add nullable column (instant, no table rewrite in PG 11+)
ALTER TABLE users ADD COLUMN middle_name text;

-- CORRECT: Add column with constant default (instant in PG 11+)
ALTER TABLE users ADD COLUMN is_premium boolean NOT NULL DEFAULT false;

-- CORRECT: Add column with volatile default (requires table rewrite)
-- Only do this on small tables; for large tables, add nullable then backfill
ALTER TABLE users ADD COLUMN api_key text DEFAULT gen_random_uuid()::text;

-- WRONG: Add NOT NULL column without default on populated table
ALTER TABLE users ADD COLUMN required_field text NOT NULL;
-- ERROR: Column "required_field" contains null values

-- CORRECT: Three-step pattern for adding NOT NULL column to large tables
-- Step 1: Add nullable column
ALTER TABLE users ADD COLUMN required_field text;

-- Step 2: Backfill in batches (separate migration or script)
UPDATE users SET required_field = 'default_value'
WHERE required_field IS NULL AND id BETWEEN $start AND $end;

-- Step 3: Add NOT NULL constraint (after all rows have values)
ALTER TABLE users ALTER COLUMN required_field SET NOT NULL;
```

### Changing Column Types

```sql
-- CORRECT: Safe type changes that don't rewrite the table
ALTER TABLE users ALTER COLUMN name TYPE text;      -- varchar(n) to text: no rewrite
ALTER TABLE users ALTER COLUMN id TYPE bigint;       -- int to bigint: REWRITES TABLE

-- CORRECT: Type change with explicit USING clause
ALTER TABLE events ALTER COLUMN event_time TYPE timestamptz
    USING event_time AT TIME ZONE 'UTC';

-- CORRECT: For large tables, use expand-contract pattern instead of ALTER TYPE
-- Step 1: Add new column
ALTER TABLE events ADD COLUMN event_time_tz timestamptz;
-- Step 2: Backfill (batched)
UPDATE events SET event_time_tz = event_time AT TIME ZONE 'UTC'
WHERE event_time_tz IS NULL AND id BETWEEN $start AND $end;
-- Step 3: Swap columns (after app code is updated)
ALTER TABLE events DROP COLUMN event_time;
ALTER TABLE events RENAME COLUMN event_time_tz TO event_time;
ALTER TABLE events ALTER COLUMN event_time SET NOT NULL;

-- WRONG: Type change that rewrites table on large table without planning
ALTER TABLE huge_table ALTER COLUMN description TYPE varchar(500);
-- Rewrites entire table, acquires AccessExclusiveLock
```

### Dropping Columns

```sql
-- CORRECT: Drop column (marks as dropped, doesn't reclaim space immediately)
ALTER TABLE users DROP COLUMN IF EXISTS legacy_field;

-- Note: PostgreSQL doesn't physically remove the column data immediately.
-- Space is reclaimed when rows are updated or VACUUM FULL runs.
-- This means DROP COLUMN is relatively fast even on large tables.

-- CORRECT: Drop column with CASCADE (also drops dependent objects)
ALTER TABLE users DROP COLUMN IF EXISTS status CASCADE;
-- WARNING: CASCADE may drop dependent views, indexes, or constraints
-- Always check dependencies first:
SELECT dependent_ns.nspname, dependent_view.relname
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class AS dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_namespace AS dependent_ns ON dependent_view.relnamespace = dependent_ns.oid
WHERE pg_depend.refobjid = 'users'::regclass;
```

## Constraint Operations

### Adding Foreign Keys

```sql
-- WRONG: Add foreign key (validates all existing rows, holds AccessExclusiveLock)
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);
-- On large tables, this blocks all operations while validating

-- CORRECT: Two-step foreign key addition (minimal locking)
-- Step 1: Add constraint NOT VALID (instant, no validation)
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id) NOT VALID;

-- Step 2: Validate constraint separately (holds ShareUpdateExclusiveLock, not blocking)
ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_customer;
-- This scan doesn't block reads or writes
```

### Adding Check Constraints

```sql
-- CORRECT: Two-step check constraint (same pattern as foreign keys)
-- Step 1: Add NOT VALID
ALTER TABLE orders ADD CONSTRAINT chk_orders_amount_positive
    CHECK (amount > 0) NOT VALID;

-- Step 2: Validate separately
ALTER TABLE orders VALIDATE CONSTRAINT chk_orders_amount_positive;

-- WRONG: Single-step (scans table while holding heavy lock)
ALTER TABLE orders ADD CONSTRAINT chk_orders_amount_positive
    CHECK (amount > 0);
```

### Adding NOT NULL Constraints

```sql
-- PostgreSQL 12+: Adding NOT NULL uses a CHECK constraint internally and is fast
-- IF there is an existing validated CHECK (column IS NOT NULL) constraint.

-- CORRECT: Fast NOT NULL addition pattern (PostgreSQL 12+)
-- Step 1: Add check constraint NOT VALID
ALTER TABLE users ADD CONSTRAINT chk_users_email_not_null
    CHECK (email IS NOT NULL) NOT VALID;

-- Step 2: Validate the constraint (does not block writes)
ALTER TABLE users VALIDATE CONSTRAINT chk_users_email_not_null;

-- Step 3: Add NOT NULL (instant because PostgreSQL sees the validated CHECK)
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Step 4: Drop the now-redundant CHECK constraint
ALTER TABLE users DROP CONSTRAINT chk_users_email_not_null;
```

## Table Operations

### Creating Tables

```sql
-- CORRECT: Table with all conventions applied
CREATE TABLE IF NOT EXISTS order_items (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(15, 2) NOT NULL,
    discount_pct numeric(5, 2) NOT NULL DEFAULT 0.00,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_order_items_order_id
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product_id
        FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT chk_order_items_quantity_positive
        CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price_nonneg
        CHECK (unit_price >= 0),
    CONSTRAINT chk_order_items_discount_range
        CHECK (discount_pct >= 0 AND discount_pct <= 100)
);

-- Indexes (create concurrently for existing tables, inline OK for new tables)
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- Updated_at trigger
CREATE TRIGGER trg_order_items_updated_at
    BEFORE UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE order_items IS 'Individual items within a customer order';
COMMENT ON COLUMN order_items.discount_pct IS 'Discount percentage (0-100)';
```

### Partitioning Existing Tables

```sql
-- Convert an existing table to partitioned (requires data migration)
-- Step 1: Create new partitioned table
CREATE TABLE orders_partitioned (
    LIKE orders INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Step 2: Create partitions
CREATE TABLE orders_2025 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE orders_2026 PARTITION OF orders_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE orders_default PARTITION OF orders_partitioned DEFAULT;

-- Step 3: Copy data (during maintenance window or with dual-write)
INSERT INTO orders_partitioned SELECT * FROM orders;

-- Step 4: Swap tables (brief lock)
BEGIN;
ALTER TABLE orders RENAME TO orders_old;
ALTER TABLE orders_partitioned RENAME TO orders;
COMMIT;

-- Step 5: Drop old table after verification
-- DROP TABLE orders_old;  -- After confirming all is well
```

## Data Migration Patterns

### Batch Updates

```sql
-- CORRECT: Batch update for large tables
DO $$
DECLARE
    batch_size constant integer := 10000;
    updated integer;
    total_updated integer := 0;
BEGIN
    LOOP
        WITH batch AS (
            SELECT id
            FROM users
            WHERE email_normalized IS NULL
            ORDER BY id
            LIMIT batch_size
            FOR UPDATE SKIP LOCKED
        )
        UPDATE users u
        SET email_normalized = lower(trim(u.email))
        FROM batch b
        WHERE u.id = b.id;

        GET DIAGNOSTICS updated = ROW_COUNT;
        total_updated := total_updated + updated;
        RAISE NOTICE 'Updated % rows (total: %)', updated, total_updated;

        COMMIT;

        EXIT WHEN updated < batch_size;
        PERFORM pg_sleep(0.05);  -- Brief pause
    END LOOP;

    RAISE NOTICE 'Migration complete. Total rows updated: %', total_updated;
END $$;
```

### Data Backfill with Progress

```sql
-- CORRECT: Backfill with progress tracking
DO $$
DECLARE
    total_rows bigint;
    processed bigint := 0;
    batch_size constant integer := 5000;
    rows_affected integer;
BEGIN
    SELECT count(*) INTO total_rows
    FROM orders WHERE shipping_estimate IS NULL;

    RAISE NOTICE 'Starting backfill: % rows to process', total_rows;

    LOOP
        UPDATE orders
        SET shipping_estimate = created_at + interval '5 days'
        WHERE id IN (
            SELECT id FROM orders
            WHERE shipping_estimate IS NULL
            ORDER BY id
            LIMIT batch_size
        );

        GET DIAGNOSTICS rows_affected = ROW_COUNT;
        processed := processed + rows_affected;

        RAISE NOTICE 'Progress: %/% (%%)',
            processed, total_rows,
            round(100.0 * processed / NULLIF(total_rows, 0), 1);

        COMMIT;
        EXIT WHEN rows_affected < batch_size;
        PERFORM pg_sleep(0.02);
    END LOOP;
END $$;
```

## Online Schema Changes with pg_repack

For operations that normally require a full table rewrite (like CLUSTER or VACUUM FULL), pg_repack
performs the operation online without blocking reads or writes.

```bash
# Install pg_repack
# Debian/Ubuntu: apt install postgresql-15-repack
# RHEL/CentOS: yum install pg_repack_15

# Repack a table (reclaim bloat, reorder by index)
pg_repack -d mydb -t orders

# Repack specific table by index order
pg_repack -d mydb -t orders -o created_at

# Repack only indexes of a table
pg_repack -d mydb -t orders --only-indexes

# Dry run
pg_repack -d mydb -t orders --dry-run
```

```sql
-- Create the extension (required)
CREATE EXTENSION IF NOT EXISTS pg_repack;

-- Alternative to VACUUM FULL (online, non-blocking)
-- Instead of: VACUUM FULL orders;  (blocks everything)
-- Use: pg_repack -d mydb -t orders  (online)

-- Alternative to CLUSTER (online, non-blocking)
-- Instead of: CLUSTER orders USING idx_orders_created_at;  (blocks everything)
-- Use: pg_repack -d mydb -t orders -o created_at  (online)
```

## Migration Testing Checklist

Before deploying any migration to production:

```text
[ ] 1. Migration runs successfully on fresh database (schema from scratch)
[ ] 2. Migration runs successfully on staging (existing data)
[ ] 3. Down migration reverses all changes cleanly
[ ] 4. Migration is idempotent (safe to run twice)
[ ] 5. No table-locking operations on high-traffic tables
[ ] 6. Indexes created with CONCURRENTLY where needed
[ ] 7. Foreign keys added with NOT VALID + VALIDATE
[ ] 8. Large data backfills are batched
[ ] 9. Migration has been tested with realistic data volume
[ ] 10. Rollback plan is documented for irreversible changes
[ ] 11. Application code is compatible with both pre- and post-migration schema
[ ] 12. Monitoring alerts are configured for migration duration
```

## Anti-Patterns

### 1. Running Migrations Without Backups

```sql
-- WRONG: No backup before irreversible migration
DROP TABLE old_data;

-- CORRECT: Always backup first
-- pg_dump -Fc -t old_data mydb > old_data_backup.dump
-- Then run: DROP TABLE old_data;
```

### 2. Mixing DML and DDL

```sql
-- WRONG: Data changes mixed with schema changes in one migration
ALTER TABLE users ADD COLUMN status text;
UPDATE users SET status = 'active';
ALTER TABLE users ALTER COLUMN status SET NOT NULL;
-- If the UPDATE fails, the column exists but is nullable

-- CORRECT: Separate migrations
-- Migration 1: Add column
ALTER TABLE users ADD COLUMN status text;
-- Migration 2: Backfill data
UPDATE users SET status = 'active' WHERE status IS NULL;
-- Migration 3: Add constraint
ALTER TABLE users ALTER COLUMN status SET NOT NULL;
```

### 3. No Lock Timeout

```sql
-- WRONG: Migration with no lock timeout (could wait forever)
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

-- CORRECT: Set lock timeout for safety
SET lock_timeout = '5s';
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
RESET lock_timeout;
-- If lock is not acquired in 5 seconds, migration fails safely
```

### 4. CREATE INDEX Without CONCURRENTLY

```sql
-- WRONG: Blocking index creation on production table
CREATE INDEX idx_orders_status ON orders (status);

-- CORRECT: Non-blocking
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);
```

### 5. Foreign Key Without NOT VALID

```sql
-- WRONG: Full table scan with heavy lock
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);

-- CORRECT: Two-step approach
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_customer;
```

### 6. No Transaction Safety

```sql
-- WRONG: Multiple operations outside transaction (partial failure leaves mess)
ALTER TABLE users ADD COLUMN phone text;
ALTER TABLE users ADD COLUMN phone_verified boolean;
CREATE INDEX idx_users_phone ON users (phone);
-- If second ALTER fails, first ALTER is committed, migration is in broken state

-- CORRECT: Wrap related DDL in transaction (except CONCURRENTLY operations)
BEGIN;
ALTER TABLE users ADD COLUMN phone text;
ALTER TABLE users ADD COLUMN phone_verified boolean NOT NULL DEFAULT false;
COMMIT;

-- Separate non-transactional migration for concurrent index
CREATE INDEX CONCURRENTLY idx_users_phone ON users (phone)
    WHERE phone IS NOT NULL;
```

### 7. No Monitoring During Migration

```sql
-- WRONG: Fire and forget

-- CORRECT: Monitor throughout migration
-- Terminal 1: Execute migration
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);

-- Terminal 2: Monitor replication lag
-- watch -n 5 "psql -c \"SELECT client_addr, state,
--   sent_lsn - write_lsn AS write_lag,
--   sent_lsn - replay_lsn AS replay_lag
--   FROM pg_stat_replication;\""

-- Terminal 3: Monitor locks
-- watch -n 5 "psql -c \"SELECT pid, wait_event_type, wait_event, state, query
--   FROM pg_stat_activity WHERE wait_event_type = 'Lock';\""

-- Terminal 4: Monitor index creation progress
-- watch -n 5 "psql -c \"SELECT phase, blocks_total, blocks_done,
--   tuples_total, tuples_done
--   FROM pg_stat_progress_create_index;\""
```
