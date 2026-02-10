---
name: migration-patterns
description:
  This skill should be used when writing database migrations, altering tables, adding columns,
  creating indexes, or planning schema changes for MySQL.
version: 0.1.0
---

# Migration Patterns

Safe, reversible MySQL schema migrations are fundamental to maintaining database integrity and
enabling continuous deployment. This skill covers production-grade migration patterns that minimize
downtime, prevent data loss, and ensure rollback capability. Every migration should be tested on a
replica, have a documented rollback path, and consider the impact on running applications.

## Up/Down Migration Pairs

Every migration must have a corresponding down migration that reverses the changes. This enables
safe rollbacks during deployment failures or when bugs are discovered in production.

### Reversible Migration Example

```sql
-- Up Migration: 20260209_01_add_user_status.sql
ALTER TABLE users
  ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active'
  COMMENT 'User account status: active, suspended, deleted';

CREATE INDEX idx_users_status ON users(status);
```

```sql
-- Down Migration: 20260209_01_add_user_status_down.sql
DROP INDEX idx_users_status ON users;

ALTER TABLE users
  DROP COLUMN status;
```

### Irreversible Migrations

Some migrations cannot be fully reversed without data loss. These must be clearly documented.

```sql
-- Up Migration: 20260209_02_remove_legacy_column.sql
-- WARNING: This migration is IRREVERSIBLE
-- The 'legacy_notes' column data will be permanently deleted
-- Backup taken: prod_backup_20260209_083000.sql.gz
-- Rollback plan: Restore from backup if needed within 24h window

ALTER TABLE orders
  DROP COLUMN legacy_notes;
```

```sql
-- Down Migration: 20260209_02_remove_legacy_column_down.sql
-- IRREVERSIBLE: Cannot restore data
-- To rollback, restore from backup: prod_backup_20260209_083000.sql.gz
-- ALTER TABLE orders ADD COLUMN legacy_notes TEXT; -- DO NOT RUN without data restore
SELECT 'ERROR: This migration cannot be automatically reversed' AS error_message;
```

### Data Transformation Migrations

When transforming data, preserve original data temporarily to enable rollback.

```sql
-- Up Migration: 20260209_03_normalize_phone_format.sql
-- Add new column for normalized phone numbers
ALTER TABLE customers
  ADD COLUMN phone_normalized VARCHAR(20)
  COMMENT 'E.164 format phone number';

-- Transform data (run as separate script for large tables)
UPDATE customers
SET phone_normalized = CONCAT('+1', REGEXP_REPLACE(phone, '[^0-9]', ''))
WHERE phone IS NOT NULL
  AND phone_normalized IS NULL;

-- Don't drop old column yet - keep for rollback safety
-- Migration 20260209_04 will drop 'phone' after validation period
```

```sql
-- Down Migration: 20260209_03_normalize_phone_format_down.sql
-- Original data still exists in 'phone' column
ALTER TABLE customers
  DROP COLUMN phone_normalized;
```

## Online DDL

MySQL Online DDL allows many schema changes without blocking reads or writes. Understanding which
operations support which algorithms is critical for production environments.

### DDL Algorithms

MySQL supports three DDL algorithms:

- **INSTANT**: Metadata-only change (MySQL 8.0.12+), no table rebuild, microseconds
- **INPLACE**: Table rebuilt in-place, allows concurrent DML, seconds to hours
- **COPY**: Creates new table, copies data, blocks writes, hours for large tables

### INSTANT Algorithm Operations (MySQL 8.0.12+)

```sql
-- Adding column with default value (INSTANT in 8.0.12+)
ALTER TABLE products
  ADD COLUMN discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  ALGORITHM=INSTANT;

-- Adding column at end without default
ALTER TABLE products
  ADD COLUMN created_at TIMESTAMP NULL,
  ALGORITHM=INSTANT;

-- Adding virtual generated column
ALTER TABLE orders
  ADD COLUMN total_with_tax DECIMAL(10,2) AS (total * 1.08) VIRTUAL,
  ALGORITHM=INSTANT;

-- Changing column default
ALTER TABLE users
  ALTER COLUMN status SET DEFAULT 'pending',
  ALGORITHM=INSTANT;

-- Renaming column (8.0.14+)
ALTER TABLE customers
  RENAME COLUMN addr TO address,
  ALGORITHM=INSTANT;
```

### INPLACE Algorithm Operations

```sql
-- Adding index (INPLACE by default)
ALTER TABLE orders
  ADD INDEX idx_customer_created (customer_id, created_at),
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Adding unique constraint
ALTER TABLE email_subscriptions
  ADD UNIQUE KEY uk_email (email),
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Dropping index
ALTER TABLE orders
  DROP INDEX idx_old_column,
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Changing column data type (compatible types only)
ALTER TABLE products
  MODIFY COLUMN price DECIMAL(12,2),  -- was DECIMAL(10,2)
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Adding foreign key (validates existing data)
ALTER TABLE order_items
  ADD CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  ALGORITHM=INPLACE,
  LOCK=NONE;
```

### Operations Requiring COPY

```sql
-- Changing column type (incompatible types)
-- VARCHAR to INT requires table copy
ALTER TABLE logs
  MODIFY COLUMN error_code INT,  -- was VARCHAR(50)
  ALGORITHM=COPY;

-- Adding column with AFTER clause (before 8.0.29)
ALTER TABLE users
  ADD COLUMN middle_name VARCHAR(100) AFTER first_name,
  ALGORITHM=COPY;

-- Changing character set
ALTER TABLE articles
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  ALGORITHM=COPY;
```

### Specifying Lock Levels

```sql
-- LOCK=NONE: Allow concurrent reads and writes (preferred)
ALTER TABLE products
  ADD INDEX idx_category (category_id),
  LOCK=NONE;

-- LOCK=SHARED: Allow reads, block writes
ALTER TABLE inventory
  ADD COLUMN last_counted TIMESTAMP,
  LOCK=SHARED;

-- LOCK=EXCLUSIVE: Block all access (avoid in production)
ALTER TABLE audit_log
  ENGINE=InnoDB,
  LOCK=EXCLUSIVE;

-- LOCK=DEFAULT: Let MySQL choose
ALTER TABLE sessions
  ADD INDEX idx_expires (expires_at),
  LOCK=DEFAULT;
```

## Large Table Changes

For tables with millions of rows, standard ALTER TABLE can lock tables for hours. Use online schema
change tools to minimize impact.

### Percona Toolkit: pt-online-schema-change

Percona's pt-online-schema-change creates a shadow table, copies data in chunks, and swaps tables
atomically.

```bash
# Add column to large table (10M+ rows)
pt-online-schema-change \
  --alter "ADD COLUMN last_login TIMESTAMP NULL" \
  --execute \
  --chunk-size=1000 \
  --chunk-time=0.5 \
  --max-lag=1s \
  --critical-load="Threads_running=200" \
  --set-vars="lock_wait_timeout=2" \
  --progress=time,30 \
  D=production,t=users

# Add index on large table
pt-online-schema-change \
  --alter "ADD INDEX idx_email (email)" \
  --execute \
  --chunk-size=2000 \
  --max-lag=2s \
  --check-interval=5 \
  --alter-foreign-keys-method=auto \
  D=production,t=customers

# Change column type with data transformation
pt-online-schema-change \
  --alter "MODIFY COLUMN status ENUM('active','inactive','suspended') NOT NULL" \
  --execute \
  --chunk-size=1000 \
  --recursion-method=hosts \
  --max-load="Threads_running=150" \
  D=production,t=accounts

# Drop column from large table
pt-online-schema-change \
  --alter "DROP COLUMN obsolete_field" \
  --execute \
  --chunk-size=5000 \
  --dry-run \  # Always dry-run first!
  D=production,t=orders

# After successful dry-run, execute
pt-online-schema-change \
  --alter "DROP COLUMN obsolete_field" \
  --execute \
  --chunk-size=5000 \
  D=production,t=orders
```

### GitHub's gh-ost

gh-ost (GitHub's Online Schema Migrations) offers triggerless replication and pausable migrations.

```bash
# Add column using gh-ost
gh-ost \
  --user="migration_user" \
  --password="password" \
  --host="production-db-01" \
  --database="ecommerce" \
  --table="products" \
  --alter="ADD COLUMN featured BOOLEAN NOT NULL DEFAULT FALSE" \
  --chunk-size=1000 \
  --max-load="Threads_running=200" \
  --critical-load="Threads_running=300" \
  --throttle-control-replicas="replica-01:3306,replica-02:3306" \
  --max-lag-millis=1500 \
  --verbose \
  --execute

# Add index with replication lag monitoring
gh-ost \
  --user="migration_user" \
  --password="password" \
  --host="production-db-01" \
  --database="analytics" \
  --table="events" \
  --alter="ADD INDEX idx_user_timestamp (user_id, created_at)" \
  --chunk-size=2000 \
  --throttle-control-replicas="replica-01:3306" \
  --max-lag-millis=2000 \
  --postpone-cut-over-flag-file=/tmp/gh-ost.postpone \
  --panic-flag-file=/tmp/gh-ost.panic \
  --execute

# Change column type on very large table
gh-ost \
  --user="migration_user" \
  --password="password" \
  --host="production-db-01" \
  --database="logs" \
  --table="access_logs" \
  --alter="MODIFY COLUMN response_time INT UNSIGNED" \
  --chunk-size=5000 \
  --dml-batch-size=100 \
  --nice-ratio=2.0 \
  --allow-on-master \
  --execute
```

### Validation Strategy for Large Tables

If neither pt-online-schema-change nor gh-ost is available, document the limitation:

```sql
-- Migration: 20260209_05_add_index_large_table.sql
-- WARNING: This table has 5M+ rows
-- Recommended: Use pt-online-schema-change or gh-ost
--
-- pt-online-schema-change command:
-- pt-online-schema-change \
--   --alter "ADD INDEX idx_status_created (status, created_at)" \
--   --execute --chunk-size=1000 --max-lag=1s \
--   D=production,t=orders
--
-- If running directly, schedule during maintenance window:

-- Verify table size first
SELECT
  table_name,
  table_rows,
  ROUND(data_length / 1024 / 1024, 2) AS data_mb,
  ROUND(index_length / 1024 / 1024, 2) AS index_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'orders';

-- Add index with online DDL
ALTER TABLE orders
  ADD INDEX idx_status_created (status, created_at),
  ALGORITHM=INPLACE,
  LOCK=NONE;
```

## Foreign Key Considerations

Foreign key constraints require full table scans for validation and can significantly increase
migration time.

### Adding Foreign Keys

```sql
-- Adding FK to existing data requires validation
-- On large tables, this can take minutes to hours
ALTER TABLE order_items
  ADD CONSTRAINT fk_order_items_product_id
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- For very large tables, validate data first
SELECT order_items.id, order_items.product_id
FROM order_items
LEFT JOIN products ON order_items.product_id = products.id
WHERE products.id IS NULL
LIMIT 10;

-- If orphaned records exist, clean them up first
DELETE FROM order_items
WHERE product_id NOT IN (SELECT id FROM products);

-- Then add the constraint
ALTER TABLE order_items
  ADD CONSTRAINT fk_order_items_product_id
    FOREIGN KEY (product_id) REFERENCES products(id);
```

### Temporarily Disabling FK Checks

```sql
-- Disable FK checks for bulk operations (USE WITH EXTREME CARE)
SET FOREIGN_KEY_CHECKS=0;

-- Perform migration
ALTER TABLE order_items
  ADD CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE;

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS=1;

-- Validate data integrity after re-enabling
SELECT oi.id, oi.order_id
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;
```

### Removing Foreign Keys

```sql
-- Dropping FK is fast (metadata change)
ALTER TABLE order_items
  DROP FOREIGN KEY fk_order_items_product_id,
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Drop the associated index if no longer needed
SHOW CREATE TABLE order_items;  -- Check if FK created an index

ALTER TABLE order_items
  DROP INDEX fk_order_items_product_id,  -- Index name may differ
  ALGORITHM=INPLACE,
  LOCK=NONE;
```

### Multi-Step FK Migration

```sql
-- Step 1: Add column without FK
ALTER TABLE order_items
  ADD COLUMN warehouse_id INT UNSIGNED NULL;

-- Step 2: Backfill data
UPDATE order_items oi
JOIN products p ON oi.product_id = p.id
SET oi.warehouse_id = p.warehouse_id;

-- Step 3: Validate data
SELECT COUNT(*) FROM order_items WHERE warehouse_id IS NULL;

-- Step 4: Add NOT NULL constraint
ALTER TABLE order_items
  MODIFY COLUMN warehouse_id INT UNSIGNED NOT NULL;

-- Step 5: Add foreign key
ALTER TABLE order_items
  ADD CONSTRAINT fk_order_items_warehouse_id
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id);
```

## Migration Ordering

Consistent migration ordering prevents conflicts and enables sequential execution.

### Timestamp Prefix Format

```text
migrations/
├── 20260209_001_create_users_table.sql
├── 20260209_001_create_users_table_down.sql
├── 20260209_002_add_users_email_index.sql
├── 20260209_002_add_users_email_index_down.sql
├── 20260209_003_create_orders_table.sql
├── 20260209_003_create_orders_table_down.sql
└── 20260209_004_add_orders_status_column.sql
    20260209_004_add_orders_status_column_down.sql
```

### Sequential Migration Principles

```sql
-- CORRECT: One logical change per migration
-- Migration 001: Create table
CREATE TABLE products (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migration 002: Add column
ALTER TABLE products
  ADD COLUMN description TEXT NULL;

-- Migration 003: Add index
ALTER TABLE products
  ADD INDEX idx_name (name);

-- WRONG: Multiple unrelated changes in one migration
ALTER TABLE products
  ADD COLUMN description TEXT NULL,
  ADD COLUMN price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  ADD INDEX idx_name (name),
  ADD INDEX idx_price (price);
-- Problem: If one change fails, all fail. Hard to rollback partially.
```

### Dependency Management

```sql
-- Migration 010: Create parent table first
CREATE TABLE categories (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Migration 011: Create child table with FK
CREATE TABLE products (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_id INT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  CONSTRAINT fk_products_category_id
    FOREIGN KEY (category_id) REFERENCES categories(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Migration 012: Add data to parent first
INSERT INTO categories (name) VALUES
  ('Electronics'),
  ('Books'),
  ('Clothing');

-- Migration 013: Add data to child
INSERT INTO products (category_id, name) VALUES
  (1, 'Laptop'),
  (2, 'Database Guide');
```

## Guard Clauses

MySQL lacks comprehensive IF NOT EXISTS support for all DDL operations. Implement guard clauses to
make migrations idempotent.

### Table Creation Guards

```sql
-- CORRECT: Check if table exists
CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- WRONG: No guard clause
CREATE TABLE users (...);
-- Error on re-run: Table 'users' already exists
```

### Column Addition Guards

```sql
-- CORRECT: Check if column exists before adding
DELIMITER $$
CREATE PROCEDURE add_column_if_not_exists()
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND column_name = 'phone'
  ) THEN
    ALTER TABLE users ADD COLUMN phone VARCHAR(20) NULL;
  END IF;
END$$
DELIMITER ;

CALL add_column_if_not_exists();
DROP PROCEDURE IF EXISTS add_column_if_not_exists;

-- WRONG: No guard clause
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NULL;
-- Error on re-run: Duplicate column name 'phone'
```

### Index Creation Guards

```sql
-- CORRECT: Check if index exists
DELIMITER $$
CREATE PROCEDURE add_index_if_not_exists()
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND index_name = 'idx_email'
  ) THEN
    CREATE INDEX idx_email ON users(email);
  END IF;
END$$
DELIMITER ;

CALL add_index_if_not_exists();
DROP PROCEDURE IF EXISTS add_index_if_not_exists;

-- WRONG: No guard clause
CREATE INDEX idx_email ON users(email);
-- Error on re-run: Duplicate key name 'idx_email'
```

### Foreign Key Guards

```sql
-- CORRECT: Check if FK exists
DELIMITER $$
CREATE PROCEDURE add_fk_if_not_exists()
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_schema = DATABASE()
      AND table_name = 'orders'
      AND constraint_name = 'fk_orders_user_id'
      AND constraint_type = 'FOREIGN KEY'
  ) THEN
    ALTER TABLE orders
      ADD CONSTRAINT fk_orders_user_id
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE;
  END IF;
END$$
DELIMITER ;

CALL add_fk_if_not_exists();
DROP PROCEDURE IF EXISTS add_fk_if_not_exists;
```

## Zero-Downtime Pattern (Expand-Contract)

The expand-contract pattern enables schema changes without downtime by decomposing changes into
multiple backward-compatible steps.

### Pattern Overview

1. **Expand**: Add new schema elements (columns, tables) without removing old ones
2. **Migrate**: Update application to write to both old and new schema
3. **Backfill**: Copy data from old to new schema
4. **Switch**: Update application to read from new schema
5. **Contract**: Remove old schema elements

### Example: Renaming a Column

```sql
-- Current State:
-- Table: users
-- Column: login_name VARCHAR(100)
-- Goal: Rename to username VARCHAR(100)

-- === PHASE 1: EXPAND ===
-- Migration 20260209_010: Add new column
ALTER TABLE users
  ADD COLUMN username VARCHAR(100) NULL
  COMMENT 'New name for login_name column',
  ALGORITHM=INSTANT;

-- Migration 20260209_011: Create trigger to sync data
DELIMITER $$
CREATE TRIGGER users_before_insert_sync_username
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
  IF NEW.username IS NULL AND NEW.login_name IS NOT NULL THEN
    SET NEW.username = NEW.login_name;
  END IF;
  IF NEW.login_name IS NULL AND NEW.username IS NOT NULL THEN
    SET NEW.login_name = NEW.username;
  END IF;
END$$

CREATE TRIGGER users_before_update_sync_username
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
  IF NEW.username IS NULL AND NEW.login_name IS NOT NULL THEN
    SET NEW.username = NEW.login_name;
  END IF;
  IF NEW.login_name IS NULL AND NEW.username IS NOT NULL THEN
    SET NEW.login_name = NEW.username;
  END IF;
END$$
DELIMITER ;

-- Migration 20260209_012: Backfill existing data
-- For small tables (< 100k rows):
UPDATE users
SET username = login_name
WHERE username IS NULL;

-- For large tables, use batched updates:
-- Run as separate script, not in migration:
-- DELIMITER $$
-- CREATE PROCEDURE backfill_username()
-- BEGIN
--   DECLARE done INT DEFAULT 0;
--   DECLARE batch_size INT DEFAULT 1000;
--
--   WHILE NOT done DO
--     UPDATE users
--     SET username = login_name
--     WHERE username IS NULL
--     LIMIT batch_size;
--
--     IF ROW_COUNT() = 0 THEN
--       SET done = 1;
--     END IF;
--
--     DO SLEEP(0.1);  -- Throttle to avoid replication lag
--   END WHILE;
-- END$$
-- DELIMITER ;
--
-- CALL backfill_username();
-- DROP PROCEDURE backfill_username;

-- === DEPLOY APPLICATION V1 ===
-- Application now writes to both login_name and username
-- Application still reads from login_name

-- === VERIFY DATA SYNC ===
-- Check that all rows have both columns populated
SELECT COUNT(*) FROM users WHERE username IS NULL;
SELECT COUNT(*) FROM users WHERE login_name IS NULL;
SELECT COUNT(*) FROM users WHERE username != login_name;

-- === PHASE 2: SWITCH ===
-- Migration 20260209_013: Make username NOT NULL
ALTER TABLE users
  MODIFY COLUMN username VARCHAR(100) NOT NULL;

-- === DEPLOY APPLICATION V2 ===
-- Application now reads from username
-- Application still writes to both columns

-- === MONITORING PERIOD ===
-- Wait 24-48 hours, monitor for issues
-- Ensure no application errors
-- Verify all deployments complete

-- === PHASE 3: CONTRACT ===
-- Migration 20260209_014: Drop triggers
DROP TRIGGER IF EXISTS users_before_insert_sync_username;
DROP TRIGGER IF EXISTS users_before_update_sync_username;

-- Migration 20260209_015: Drop old column
ALTER TABLE users
  DROP COLUMN login_name,
  ALGORITHM=INSTANT;

-- === DEPLOY APPLICATION V3 ===
-- Application only uses username column
```

### Example: Splitting a Column

```sql
-- Current State:
-- Table: customers
-- Column: full_name VARCHAR(255)
-- Goal: Split into first_name and last_name

-- === PHASE 1: EXPAND ===
-- Migration 20260209_020: Add new columns
ALTER TABLE customers
  ADD COLUMN first_name VARCHAR(100) NULL,
  ADD COLUMN last_name VARCHAR(100) NULL,
  ALGORITHM=INSTANT;

-- Migration 20260209_021: Backfill data
UPDATE customers
SET
  first_name = SUBSTRING_INDEX(full_name, ' ', 1),
  last_name = CASE
    WHEN full_name LIKE '% %' THEN SUBSTRING_INDEX(full_name, ' ', -1)
    ELSE ''
  END
WHERE first_name IS NULL;

-- Migration 20260209_022: Create sync trigger
DELIMITER $$
CREATE TRIGGER customers_before_insert_sync_names
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
  IF NEW.first_name IS NOT NULL AND NEW.last_name IS NOT NULL THEN
    SET NEW.full_name = CONCAT(NEW.first_name, ' ', NEW.last_name);
  END IF;
  IF NEW.full_name IS NOT NULL AND NEW.first_name IS NULL THEN
    SET NEW.first_name = SUBSTRING_INDEX(NEW.full_name, ' ', 1);
    SET NEW.last_name = SUBSTRING_INDEX(NEW.full_name, ' ', -1);
  END IF;
END$$
DELIMITER ;

-- === DEPLOY APPLICATION V1 ===
-- Write to first_name/last_name, read from full_name

-- === PHASE 2: SWITCH ===
-- Migration 20260209_023: Make columns NOT NULL
ALTER TABLE customers
  MODIFY COLUMN first_name VARCHAR(100) NOT NULL,
  MODIFY COLUMN last_name VARCHAR(100) NOT NULL;

-- === DEPLOY APPLICATION V2 ===
-- Read from first_name/last_name

-- === PHASE 3: CONTRACT ===
-- Migration 20260209_024: Drop trigger and old column
DROP TRIGGER IF EXISTS customers_before_insert_sync_names;

ALTER TABLE customers
  DROP COLUMN full_name,
  ALGORITHM=INSTANT;
```

## Character Set Migrations

Converting character sets is a common requirement for internationalization support.

### UTF8MB4 Migration

```sql
-- Migration 20260209_030: Convert to utf8mb4
-- WARNING: This requires a full table rebuild
-- Recommended: Use pt-online-schema-change for tables > 1M rows

-- Check current character set
SELECT
  table_name,
  table_collation,
  character_set_name
FROM information_schema.tables t
JOIN information_schema.collations c ON t.table_collation = c.collation_name
WHERE table_schema = DATABASE()
  AND table_name = 'articles';

-- Convert table to utf8mb4
ALTER TABLE articles
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  ALGORITHM=COPY;

-- Convert specific columns
ALTER TABLE articles
  MODIFY COLUMN title VARCHAR(255)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  MODIFY COLUMN content TEXT
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  ALGORITHM=COPY;
```

### Database-Wide Character Set Migration

```sql
-- Migration 20260209_031: Set default character set for database
ALTER DATABASE production
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- Generate ALTER statements for all tables
SELECT CONCAT(
  'ALTER TABLE ', table_name,
  ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
) AS migration_sql
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE';

-- Execute generated statements in separate migrations
-- One table per migration for large tables
```

### Index Considerations

```sql
-- utf8mb4 requires more bytes per character
-- VARCHAR(255) with utf8mb4 = 1020 bytes (255 * 4)
-- InnoDB index prefix limit: 767 bytes (COMPACT/REDUNDANT) or 3072 bytes (DYNAMIC/COMPRESSED)

-- Before conversion, check for long indexes
SELECT
  table_name,
  index_name,
  column_name,
  character_maximum_length,
  character_maximum_length * 4 AS utf8mb4_bytes
FROM information_schema.statistics s
JOIN information_schema.columns c
  ON s.table_schema = c.table_schema
  AND s.table_name = c.table_name
  AND s.column_name = c.column_name
WHERE s.table_schema = DATABASE()
  AND c.data_type = 'varchar'
  AND character_maximum_length * 4 > 767;

-- Fix: Reduce column length or use index prefix
ALTER TABLE articles
  MODIFY COLUMN slug VARCHAR(191)  -- 191 * 4 = 764 bytes
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Or use index prefix
CREATE INDEX idx_title ON articles(title(191));
```

## Core Principles

1. **Safety First**: Always have a rollback plan before executing migrations
2. **Test on Replica**: Run migrations on a replica or staging environment first
3. **One Change Per Migration**: Each migration should make one logical change
4. **Idempotency**: Migrations should be safe to run multiple times
5. **Backward Compatibility**: New schema must work with old application code
6. **Monitor Impact**: Watch replication lag, query performance, and error rates
7. **Document Irreversibility**: Clearly mark and explain irreversible changes
8. **Batch Large Operations**: Process large data changes in chunks
9. **Validate Before Constraints**: Check data integrity before adding constraints
10. **Communicate Downtime**: Coordinate with stakeholders on maintenance windows

### Pre-Migration Checklist

```sql
-- 1. Verify current schema
SHOW CREATE TABLE target_table;

-- 2. Check table size
SELECT
  table_name,
  table_rows,
  ROUND(data_length / 1024 / 1024, 2) AS data_mb,
  ROUND(index_length / 1024 / 1024, 2) AS index_mb,
  ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'target_table';

-- 3. Check for active connections
SHOW PROCESSLIST;

-- 4. Check replication status
SHOW REPLICA STATUS\G

-- 5. Backup table (for critical changes)
CREATE TABLE target_table_backup_20260209 AS
SELECT * FROM target_table;

-- 6. Verify backup
SELECT COUNT(*) FROM target_table;
SELECT COUNT(*) FROM target_table_backup_20260209;
```

### Post-Migration Checklist

```sql
-- 1. Verify schema change applied
SHOW CREATE TABLE target_table;

-- 2. Check table statistics
ANALYZE TABLE target_table;

-- 3. Verify data integrity
SELECT COUNT(*) FROM target_table;

-- 4. Test queries
EXPLAIN SELECT * FROM target_table WHERE new_column = 'value';

-- 5. Check replication lag
SHOW REPLICA STATUS\G

-- 6. Monitor slow query log
-- Check for new slow queries related to schema changes
```

## Anti-Patterns

### 1. Irreversible Without Documentation

```sql
-- WRONG: No warning about data loss
ALTER TABLE logs DROP COLUMN request_body;

-- CORRECT: Document irreversibility and backup plan
-- WARNING: IRREVERSIBLE - Drops request_body column
-- Backup created: logs_backup_20260209.sql.gz
-- Data retained for 30 days
-- Contact DBA team to restore if needed
ALTER TABLE logs DROP COLUMN request_body;
```

### 2. Mixed Data and Schema Changes

```sql
-- WRONG: Schema and data in one migration
ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'user';
UPDATE users SET role = 'admin' WHERE email LIKE '%@company.com';

-- CORRECT: Separate migrations
-- Migration 001: Add column with safe default
ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'user';

-- Migration 002: Update data
UPDATE users SET role = 'admin' WHERE email LIKE '%@company.com';
```

### 3. Missing Down Migrations

```sql
-- WRONG: No down migration provided

-- CORRECT: Always provide down migration
-- Up: 20260209_040_add_user_level.sql
ALTER TABLE users ADD COLUMN level INT UNSIGNED NOT NULL DEFAULT 1;

-- Down: 20260209_040_add_user_level_down.sql
ALTER TABLE users DROP COLUMN level;
```

### 4. Long-Running Locks

```sql
-- WRONG: Blocking ALTER on large table during business hours
ALTER TABLE order_history
  ADD COLUMN processed_by VARCHAR(100),
  ALGORITHM=COPY;  -- Will lock table for hours!

-- CORRECT: Use online DDL or pt-online-schema-change
ALTER TABLE order_history
  ADD COLUMN processed_by VARCHAR(100),
  ALGORITHM=INPLACE,
  LOCK=NONE;

-- Or use pt-online-schema-change
-- pt-online-schema-change \
--   --alter "ADD COLUMN processed_by VARCHAR(100)" \
--   --execute --chunk-size=1000 --max-lag=1s \
--   D=production,t=order_history
```

### 5. Implicit Character Set Changes

```sql
-- WRONG: No character set specified (uses database default)
CREATE TABLE products (
  name VARCHAR(255) NOT NULL
);

-- CORRECT: Explicit character set
CREATE TABLE products (
  name VARCHAR(255) NOT NULL
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 6. No Validation Before Constraints

```sql
-- WRONG: Add constraint without checking data
ALTER TABLE orders
  ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id);
-- May fail if orphaned records exist

-- CORRECT: Validate first, clean up, then add constraint
-- Check for orphaned records
SELECT o.id, o.customer_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;

-- Clean up orphaned records or set to NULL
UPDATE orders SET customer_id = NULL WHERE customer_id NOT IN (SELECT id FROM customers);

-- Now add constraint
ALTER TABLE orders
  ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id);
```

### 7. No Monitoring During Migration

```sql
-- WRONG: Fire and forget

-- CORRECT: Monitor throughout migration
-- Terminal 1: Execute migration
ALTER TABLE large_table ADD INDEX idx_status (status);

-- Terminal 2: Monitor replication lag
-- while true; do mysql -e "SHOW REPLICA STATUS\G" | grep Seconds_Behind_Master; sleep 5; done

-- Terminal 3: Monitor active queries
-- watch -n 5 'mysql -e "SHOW PROCESSLIST"'

-- Terminal 4: Monitor table locks
-- watch -n 5 'mysql -e "SHOW OPEN TABLES WHERE In_use > 0"'
```
