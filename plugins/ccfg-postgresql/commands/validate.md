---
description: >
  Run PostgreSQL schema quality gate suite (naming, type/constraint, antipatterns, migration
  hygiene, extension hygiene)
argument-hint: '[--quick]'
allowed-tools: Bash(psql *), Bash(pg_dump *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive PostgreSQL schema quality gate suite to ensure database schemas meet production
standards. This command analyzes schema artifacts in the repository to verify naming conventions,
data type compliance, constraint hygiene, antipattern detection, migration safety, and extension
usage consistency.

## Usage

```bash
ccfg postgresql validate                    # Full validation (all gates)
ccfg postgresql validate --quick            # Quick mode (naming + type/constraint only)
ccfg postgresql validate --live             # Validate against live database (requires confirmation)
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Schema Naming**: Verify snake_case identifiers, check reserved word conflicts
1. **Type/Constraint Check**: Flag deprecated types, missing NOT NULL, improper money handling
1. **Antipattern Detection**: Missing primary keys, serial vs identity, implicit casts, FLOAT abuse
1. **Migration Hygiene**: Irreversible operations, missing down migrations, table-locking DDL
1. **Extension Hygiene**: Unversioned CREATE EXTENSION, missing IF NOT EXISTS, orphaned extensions

All gates must pass for validation to succeed. In quick mode, only the first two gates run. The
validation operates on repository artifacts (schema files, migration files, SQL dumps) by default.
Live database validation requires explicit `--live` flag and user confirmation.

## Step-by-Step Process

### 1. Schema Discovery

Locate all PostgreSQL schema artifacts in the repository using multiple discovery strategies.

#### Strategy A: Schema File Detection

Find schema definition files with common extensions and naming patterns:

```bash
# SQL files in schema directories
git ls-files --cached --others --exclude-standard | grep -E 'schema/.*\.sql$'
git ls-files --cached --others --exclude-standard | grep -E 'database/.*\.sql$'

# Migration files (various tools)
git ls-files --cached --others --exclude-standard | grep -E 'migrations?/.*\.sql$'
git ls-files --cached --others --exclude-standard | grep -E 'db/migrate/.*\.sql$'

# Flyway-style migrations
git ls-files --cached --others --exclude-standard | grep -E 'V[0-9].*\.sql$'

# Alembic revisions (Python-based, may contain raw SQL)
git ls-files --cached --others --exclude-standard | grep -E 'alembic/versions/.*\.py$'
```

#### Strategy B: ORM Schema Detection

Detect ORM-generated schema artifacts:

```bash
# Prisma schema
git ls-files --cached --others --exclude-standard | grep -E 'prisma/schema\.prisma$'

# TypeORM entities
git ls-files --cached --others --exclude-standard | grep -E 'entities?/.*\.(ts|js)$'

# SQLAlchemy models
git ls-files --cached --others --exclude-standard | grep -E 'models?/.*\.py$'

# Drizzle schema
git ls-files --cached --others --exclude-standard | grep -E 'drizzle/.*\.ts$'
```

#### Strategy C: SQL Dump Detection

Find pg_dump output files:

```bash
# SQL dumps
git ls-files --cached --others --exclude-standard | grep -E '\.dump$'
git ls-files --cached --others --exclude-standard | grep -E '\.pg_dump$'
git ls-files --cached --others --exclude-standard | grep -E 'structure\.sql$'
```

If no schema files are found, report and exit:

```text
SKIP: No PostgreSQL schema artifacts found in repository.
Looked for: .sql files in schema/, database/, migrations/ directories;
pg_dump output; Prisma/TypeORM/SQLAlchemy/Drizzle schemas.
```

### 2. Gate 1: Schema Naming

Verify all database identifiers follow PostgreSQL naming conventions.

#### 2.1 Snake Case Enforcement

All identifiers (tables, columns, indexes, constraints, functions, schemas) must use lowercase
snake_case.

```sql
-- CORRECT: snake_case identifiers
CREATE TABLE user_accounts (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email_address text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- WRONG: camelCase identifiers
CREATE TABLE "userAccounts" (
    "firstName" text,
    "lastName" text,
    "emailAddress" text,
    "createdAt" timestamptz
);

-- WRONG: PascalCase identifiers
CREATE TABLE "UserAccounts" (
    "FirstName" text NOT NULL
);

-- WRONG: UPPERCASE identifiers
CREATE TABLE USER_ACCOUNTS (
    FIRST_NAME TEXT NOT NULL
);
```

Detection regex for naming violations:

```bash
# Find quoted identifiers (indicates non-snake_case names)
grep -nE '"[a-z][a-zA-Z]*[A-Z][a-zA-Z]*"' "$file"

# Find uppercase in CREATE TABLE/INDEX/FUNCTION statements
grep -nE 'CREATE\s+(TABLE|INDEX|FUNCTION|VIEW|TRIGGER)\s+[A-Z]' "$file"
```

Report format:

```text
FAIL [naming] file.sql:42 - Table "userAccounts" uses camelCase; use user_accounts
FAIL [naming] file.sql:43 - Column "firstName" uses camelCase; use first_name
WARN [naming] file.sql:50 - Quoted identifier "OrderStatus"; prefer unquoted snake_case
```

#### 2.2 Reserved Word Detection

Flag identifiers that conflict with PostgreSQL reserved words.

```sql
-- WRONG: Using reserved words as identifiers
CREATE TABLE "user" (          -- "user" is a reserved word
    "order" integer,           -- "order" is a reserved word
    "group" text,              -- "group" is a reserved word
    "table" text               -- "table" is a reserved word
);

-- CORRECT: Avoid reserved words
CREATE TABLE users (
    sort_order integer,
    group_name text,
    table_ref text
);
```

Common PostgreSQL reserved words to flag: `user`, `order`, `group`, `table`, `column`, `index`,
`key`, `value`, `type`, `time`, `date`, `check`, `default`, `primary`, `foreign`, `references`,
`select`, `insert`, `update`, `delete`, `from`, `where`, `join`, `limit`, `offset`, `grant`, `role`,
`schema`, `sequence`, `trigger`, `function`, `procedure`.

Report format:

```text
WARN [naming] file.sql:10 - Identifier "user" is a PostgreSQL reserved word; rename to "users"
WARN [naming] file.sql:12 - Identifier "order" is a reserved word; rename to "sort_order"
```

#### 2.3 Constraint and Index Naming

Verify that constraints and indexes follow standard naming prefixes.

```sql
-- CORRECT: Named constraints with standard prefixes
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id);

CREATE INDEX idx_orders_customer_id ON orders (customer_id);

ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

ALTER TABLE products ADD CONSTRAINT chk_products_price_positive
    CHECK (price > 0);

-- WRONG: Auto-generated constraint names
ALTER TABLE orders ADD FOREIGN KEY (customer_id) REFERENCES customers(id);
-- Gets auto-name like "orders_customer_id_fkey" (PostgreSQL default)

-- WRONG: Missing index name
CREATE INDEX ON orders (customer_id);
-- Gets auto-name, harder to reference in migrations and monitoring
```

Expected naming prefixes:

- `fk_` for foreign keys
- `idx_` for indexes
- `uq_` for unique constraints
- `chk_` for check constraints
- `pk_` for primary keys (optional, since most use unnamed PRIMARY KEY)
- `trg_` for triggers
- `excl_` for exclusion constraints

Report format:

```text
WARN [naming] file.sql:25 - Unnamed foreign key constraint; use fk_<table>_<column> pattern
WARN [naming] file.sql:30 - Unnamed index; use idx_<table>_<column(s)> pattern
```

### 3. Gate 2: Type/Constraint Check

Verify data type choices and constraint usage follow PostgreSQL best practices.

#### 3.1 Preferred Data Types

```sql
-- CORRECT: Modern PostgreSQL data types
CREATE TABLE events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- Identity column
    title text NOT NULL,                                   -- text over varchar(n)
    amount numeric(15, 2) NOT NULL,                        -- numeric for money
    is_active boolean NOT NULL DEFAULT true,                -- boolean for flags
    event_time timestamptz NOT NULL DEFAULT now(),          -- timestamptz over timestamp
    metadata jsonb DEFAULT '{}',                            -- jsonb over json
    tags text[] DEFAULT '{}',                               -- arrays for multi-value
    ip_addr inet,                                           -- inet for IP addresses
    session_id uuid DEFAULT gen_random_uuid()               -- uuid for identifiers
);

-- WRONG: Deprecated or suboptimal types
CREATE TABLE bad_events (
    id serial PRIMARY KEY,                     -- serial is legacy, use identity
    title varchar(255) NOT NULL,               -- varchar(n) is rarely needed
    amount float NOT NULL,                     -- float is imprecise for money
    is_active int NOT NULL DEFAULT 1,          -- int for boolean is an antipattern
    event_time timestamp NOT NULL,             -- timestamp lacks timezone
    metadata json DEFAULT '{}',                -- json is slower than jsonb
    tags text NOT NULL,                        -- comma-separated string is wrong
    ip_addr text,                              -- text for IP loses validation
    session_id text                            -- text for UUID loses validation
);
```

Detection patterns:

```bash
# serial/bigserial (should be identity columns)
grep -niE '\b(big)?serial\b' "$file"

# varchar(n) where text would suffice
grep -niE 'varchar\([0-9]+\)' "$file"

# timestamp without time zone
grep -niE '\btimestamp\b' "$file" | grep -viE 'timestamptz|timestamp\s+with\s+time\s+zone'

# float/real/double precision for monetary values
grep -niE '\b(float|real|double precision)\b' "$file"

# json (not jsonb)
grep -niE '\bjson\b' "$file" | grep -viE 'jsonb'

# integer for boolean
grep -niE '\binteger\b.*\bDEFAULT\s+[01]\b' "$file"
```

Report format:

```text
FAIL [types] file.sql:5 - Column uses "serial"; prefer "bigint GENERATED ALWAYS AS IDENTITY"
WARN [types] file.sql:8 - Column uses "varchar(255)"; prefer "text" unless length limit is required
FAIL [types] file.sql:10 - Column uses "float" for amount; use "numeric(p,s)" for monetary values
FAIL [types] file.sql:12 - Column uses "timestamp"; prefer "timestamptz" for timezone awareness
WARN [types] file.sql:14 - Column uses "json"; prefer "jsonb" for indexing and performance
```

#### 3.2 NOT NULL and Default Constraints

```sql
-- CORRECT: Explicit NOT NULL on required columns
CREATE TABLE users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- WRONG: Missing NOT NULL on clearly required columns
CREATE TABLE bad_users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text,          -- Should be NOT NULL for a required field
    name text,           -- Should be NOT NULL for a required field
    created_at timestamptz DEFAULT now()  -- Missing NOT NULL
);
```

Report format:

```text
WARN [constraints] file.sql:15 - Column "email" may need NOT NULL (common required field)
WARN [constraints] file.sql:18 - Column "created_at" has DEFAULT but no NOT NULL
```

#### 3.3 Foreign Key Index Coverage

Every foreign key column should have a supporting index for JOIN and CASCADE performance.

```sql
-- CORRECT: Foreign key with index
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id);
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- WRONG: Foreign key without index (causes slow JOINs and CASCADE deletes)
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id);
-- Missing: CREATE INDEX idx_orders_customer_id ON orders (customer_id);
```

Report format:

```text
FAIL [constraints] file.sql:20 - Foreign key on "orders.customer_id" has no supporting index
```

### 4. Gate 3: Antipattern Detection

Identify common PostgreSQL schema antipatterns that lead to performance issues, data integrity
problems, or maintainability concerns.

#### 4.1 Missing Primary Key

```sql
-- WRONG: Table without primary key
CREATE TABLE event_log (
    event_type text,
    event_data jsonb,
    created_at timestamptz DEFAULT now()
);
-- No PRIMARY KEY: replication issues, no VACUUM efficiency, no row identity

-- CORRECT: Always have a primary key
CREATE TABLE event_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type text NOT NULL,
    event_data jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
```

Report format:

```text
FAIL [antipattern] file.sql:1 - Table "event_log" has no PRIMARY KEY
```

#### 4.2 Implicit Type Casts

```sql
-- WRONG: Comparing text column with integer (implicit cast)
SELECT * FROM users WHERE phone_number = 5551234;
-- phone_number is text, but compared with integer -- forces sequential scan

-- CORRECT: Use matching types
SELECT * FROM users WHERE phone_number = '5551234';

-- WRONG: Implicit cast in JOIN condition
SELECT * FROM orders o
JOIN products p ON o.product_code = p.id;
-- If product_code is text and id is integer, implicit cast prevents index use

-- CORRECT: Ensure matching types in JOIN conditions
SELECT * FROM orders o
JOIN products p ON o.product_id = p.id;  -- Both bigint
```

#### 4.3 ENUM Overuse

```sql
-- WRONG: ENUM for values that change frequently
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high');
-- Cannot remove or rename values, only add new ones

-- CORRECT: Check constraint for mutable value sets
CREATE TABLE tickets (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical'))
);

-- CORRECT: Lookup table for complex value sets
CREATE TABLE priorities (
    id smallint PRIMARY KEY,
    name text NOT NULL UNIQUE,
    sort_order smallint NOT NULL,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE tickets (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    priority_id smallint NOT NULL REFERENCES priorities(id)
);
```

#### 4.4 Wide Tables

```sql
-- WRONG: Table with too many columns (> 20-30 is suspicious)
CREATE TABLE user_profiles (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name text, last_name text, email text, phone text,
    address_line1 text, address_line2 text, city text, state text,
    zip text, country text, bio text, avatar_url text,
    twitter text, linkedin text, github text, website text,
    company text, job_title text, department text,
    birth_date date, hire_date date, last_login_at timestamptz,
    login_count integer, notification_prefs jsonb,
    theme_prefs jsonb, language text, timezone text
    -- 27+ columns, consider splitting into related tables
);

-- CORRECT: Normalized into focused tables
CREATE TABLE users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL UNIQUE,
    first_name text NOT NULL,
    last_name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_profiles (
    user_id bigint PRIMARY KEY REFERENCES users(id),
    bio text,
    avatar_url text,
    birth_date date,
    language text DEFAULT 'en',
    timezone text DEFAULT 'UTC'
);

CREATE TABLE user_social_links (
    user_id bigint PRIMARY KEY REFERENCES users(id),
    twitter text,
    linkedin text,
    github text,
    website text
);
```

#### 4.5 EAV (Entity-Attribute-Value) Pattern

```sql
-- WRONG: EAV pattern (destroys type safety and query performance)
CREATE TABLE settings (
    entity_id bigint NOT NULL,
    attribute_name text NOT NULL,
    attribute_value text,  -- Everything is text, no type safety
    PRIMARY KEY (entity_id, attribute_name)
);

-- CORRECT: Use jsonb for flexible attributes
CREATE TABLE settings (
    entity_id bigint PRIMARY KEY,
    data jsonb NOT NULL DEFAULT '{}',
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Index specific jsonb paths that are frequently queried
CREATE INDEX idx_settings_theme ON settings USING btree ((data->>'theme'));
CREATE INDEX idx_settings_data ON settings USING gin (data);
```

#### 4.6 Polymorphic Associations

```sql
-- WRONG: Polymorphic foreign key (no referential integrity)
CREATE TABLE comments (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    commentable_type text NOT NULL,  -- 'post' or 'photo'
    commentable_id bigint NOT NULL,   -- Cannot have FK constraint
    body text NOT NULL
);

-- CORRECT: Separate nullable foreign keys
CREATE TABLE comments (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id bigint REFERENCES posts(id),
    photo_id bigint REFERENCES photos(id),
    body text NOT NULL,
    CHECK (
        (post_id IS NOT NULL AND photo_id IS NULL) OR
        (post_id IS NULL AND photo_id IS NOT NULL)
    )
);

-- CORRECT: Separate join tables
CREATE TABLE post_comments (
    comment_id bigint PRIMARY KEY REFERENCES comments(id),
    post_id bigint NOT NULL REFERENCES posts(id)
);

CREATE TABLE photo_comments (
    comment_id bigint PRIMARY KEY REFERENCES comments(id),
    photo_id bigint NOT NULL REFERENCES photos(id)
);
```

Report format for all antipatterns:

```text
FAIL [antipattern] file.sql:1 - Table "event_log" has no PRIMARY KEY
WARN [antipattern] file.sql:15 - Table "user_profiles" has 27 columns (wide table); consider split
WARN [antipattern] file.sql:30 - EAV pattern detected in "settings"; consider jsonb instead
WARN [antipattern] file.sql:45 - Polymorphic association in "comments"; use proper FK references
```

### 5. Gate 4: Migration Hygiene

Verify that migration files follow safety standards for production deployments.

#### 5.1 Irreversible Operation Detection

Flag operations that cannot be safely reversed.

```sql
-- FLAG: Column drops (data loss)
ALTER TABLE users DROP COLUMN legacy_notes;

-- FLAG: Table drops
DROP TABLE IF EXISTS old_sessions;

-- FLAG: Type changes that lose precision
ALTER TABLE products ALTER COLUMN price TYPE integer;  -- Was numeric(15,2)

-- FLAG: Constraint drops without replacement
ALTER TABLE orders DROP CONSTRAINT chk_orders_amount_positive;

-- FLAG: TRUNCATE (data loss)
TRUNCATE TABLE audit_log;
```

Report format:

```text
WARN [migration] V005__cleanup.sql:3 - DROP COLUMN is irreversible (data loss)
WARN [migration] V005__cleanup.sql:6 - DROP TABLE is irreversible
FAIL [migration] V005__cleanup.sql:9 - Type change loses precision (numeric -> integer)
WARN [migration] V005__cleanup.sql:12 - TRUNCATE is irreversible (data loss)
```

#### 5.2 Table-Locking DDL Detection

Flag DDL operations that acquire AccessExclusiveLock and block all operations on the table.

```sql
-- WRONG: Adding column with volatile default (locks table, rewrites)
-- (Pre-PostgreSQL 11; PG 11+ handles simple defaults without rewrite)
ALTER TABLE users ADD COLUMN score integer DEFAULT compute_score();

-- WRONG: CREATE INDEX without CONCURRENTLY (locks writes)
CREATE INDEX idx_orders_status ON orders (status);

-- CORRECT: CREATE INDEX CONCURRENTLY (no write lock)
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);

-- WRONG: Adding NOT NULL without default on existing table (scans entire table)
ALTER TABLE users ADD COLUMN middle_name text NOT NULL;
-- Fails because existing rows have NULL

-- CORRECT: Add nullable, backfill, then add constraint
ALTER TABLE users ADD COLUMN middle_name text;
-- Backfill in batches...
ALTER TABLE users ALTER COLUMN middle_name SET NOT NULL;

-- WRONG: Changing column type (rewrites table)
ALTER TABLE products ALTER COLUMN description TYPE varchar(500);

-- FLAG: CLUSTER and VACUUM FULL (rewrite entire table)
CLUSTER orders USING idx_orders_created_at;
VACUUM FULL large_table;

-- FLAG: Adding foreign key without VALID (scans and locks)
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);

-- CORRECT: Add NOT VALID first, then VALIDATE separately
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id) NOT VALID;
-- Later, in separate transaction:
ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_customer;
```

Detection patterns:

```bash
# Non-concurrent index creation
grep -niE 'CREATE\s+INDEX\b' "$file" | grep -viE 'CONCURRENTLY'

# Table-rewriting ALTER operations
grep -niE 'ALTER\s+TABLE.*ALTER\s+COLUMN.*TYPE\b' "$file"
grep -niE 'ALTER\s+TABLE.*ADD\s+COLUMN.*NOT\s+NULL\b' "$file"
grep -niE '\bCLUSTER\b' "$file"
grep -niE '\bVACUUM\s+FULL\b' "$file"

# Foreign key without NOT VALID
grep -niE 'FOREIGN\s+KEY' "$file" | grep -viE 'NOT\s+VALID'
```

Report format:

```text
FAIL [migration] V010__add_index.sql:2 - CREATE INDEX without CONCURRENTLY; blocks writes
WARN [migration] V011__alter_type.sql:3 - ALTER COLUMN TYPE rewrites table; blocks all access
WARN [migration] V012__add_fk.sql:5 - FOREIGN KEY without NOT VALID; scans and locks table
```

#### 5.3 Down Migration Verification

Check that up migrations have corresponding down migrations.

```bash
# Flyway: V<version>__<desc>.sql should have U<version>__<desc>.sql (if undo is used)
# golang-migrate: <timestamp>_<name>.up.sql should have <timestamp>_<name>.down.sql
# Alembic: Each revision should have both upgrade() and downgrade() functions
# dbmate: Each file should have -- migrate:up and -- migrate:down sections
```

Report format:

```text
WARN [migration] 20260209_add_orders.up.sql - No matching down migration found
WARN [migration] alembic/versions/abc123.py - downgrade() function is empty or missing
```

#### 5.4 Transaction Safety

```sql
-- CORRECT: Migration wrapped in transaction
BEGIN;
ALTER TABLE users ADD COLUMN status text DEFAULT 'active';
CREATE INDEX CONCURRENTLY idx_users_status ON users (status);  -- ERROR!
COMMIT;
-- Note: CREATE INDEX CONCURRENTLY cannot run inside a transaction

-- CORRECT: Separate concurrent index creation
-- Migration 1: Add column (can be in transaction)
BEGIN;
ALTER TABLE users ADD COLUMN status text DEFAULT 'active';
COMMIT;

-- Migration 2: Add index (must be outside transaction)
CREATE INDEX CONCURRENTLY idx_users_status ON users (status);
```

Report format:

```text
FAIL [migration] V015__combined.sql - CREATE INDEX CONCURRENTLY inside BEGIN/COMMIT block
```

### 6. Gate 5: Extension Hygiene

Verify extension usage follows best practices for reproducible and safe deployments.

#### 6.1 Unversioned Extension Creation

```sql
-- WRONG: No version specified
CREATE EXTENSION postgis;

-- CORRECT: Pinned version for reproducibility
CREATE EXTENSION IF NOT EXISTS postgis VERSION '3.4.0';
```

#### 6.2 Missing IF NOT EXISTS

```sql
-- WRONG: Will fail if extension already exists
CREATE EXTENSION pgvector;

-- CORRECT: Idempotent
CREATE EXTENSION IF NOT EXISTS pgvector;
```

#### 6.3 Extension Schema Placement

```sql
-- WRONG: Extension in default schema without explicit declaration
CREATE EXTENSION pg_trgm;

-- CORRECT: Explicit schema placement
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;
```

#### 6.4 Extension Dependency Documentation

Check that migrations installing extensions document their requirements.

```sql
-- CORRECT: Documented extension migration
-- Migration: V001__add_extensions.sql
-- Requires: postgresql-15-pgvector package installed on server
-- Requires: shared_preload_libraries includes 'pg_stat_statements' (restart needed)
-- Tested on: PostgreSQL 15.4, pgvector 0.5.1, PostGIS 3.4.0

CREATE EXTENSION IF NOT EXISTS vector VERSION '0.5.1';
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- WRONG: Undocumented extension installation
CREATE EXTENSION timescaledb;  -- Requires shared_preload_libraries + restart!
```

Detection patterns:

```bash
# CREATE EXTENSION without version
grep -niE 'CREATE\s+EXTENSION' "$file" | grep -viE 'VERSION'

# CREATE EXTENSION without IF NOT EXISTS
grep -niE 'CREATE\s+EXTENSION\b' "$file" | grep -viE 'IF\s+NOT\s+EXISTS'

# Extensions requiring shared_preload_libraries
grep -niE 'CREATE\s+EXTENSION.*(timescaledb|pg_stat_statements|auto_explain|pg_cron|pgaudit)' \
    "$file"
```

Report format:

```text
WARN [extension] V001__add_ext.sql:3 - CREATE EXTENSION without VERSION; pin for reproducibility
FAIL [extension] V001__add_ext.sql:5 - CREATE EXTENSION without IF NOT EXISTS; not idempotent
WARN [extension] V001__add_ext.sql:7 - timescaledb requires shared_preload_libraries; document
```

### 7. Live Validation Mode

When `--live` is specified, connect to a running PostgreSQL instance and validate the actual schema.

#### Safety Protocol

```text
WARNING: Live validation requires connecting to a PostgreSQL database.
This will run READ-ONLY queries to inspect the schema.
No data will be modified.

Target: postgresql://user@host:5432/dbname
Continue? [y/N]
```

**Never proceed without explicit user confirmation.**

#### Live Validation Queries

```sql
-- Check for tables without primary keys
SELECT schemaname, tablename
FROM pg_tables t
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class cl ON c.conrelid = cl.oid
    JOIN pg_namespace n ON cl.relnamespace = n.oid
    WHERE c.contype = 'p'
      AND n.nspname = t.schemaname
      AND cl.relname = t.tablename
  );

-- Check for unindexed foreign keys
SELECT
    tc.table_schema, tc.table_name, kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes pi
    WHERE pi.schemaname = tc.table_schema
      AND pi.tablename = tc.table_name
      AND pi.indexdef LIKE '%' || kcu.column_name || '%'
  );

-- Check for serial columns (should be identity)
SELECT table_schema, table_name, column_name, column_default
FROM information_schema.columns
WHERE column_default LIKE 'nextval%'
  AND table_schema NOT IN ('pg_catalog', 'information_schema');

-- Check for timestamp without timezone
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE data_type = 'timestamp without time zone'
  AND table_schema NOT IN ('pg_catalog', 'information_schema');

-- Check for unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (
    SELECT indexrelid FROM pg_index WHERE indisunique
  )
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check for bloated tables
SELECT schemaname, relname,
       n_dead_tup,
       n_live_tup,
       round(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC;

-- Check for extensions without version pinning (in pg_extension)
SELECT extname, extversion, extrelocatable
FROM pg_extension
WHERE extname NOT IN ('plpgsql');
```

### 8. Output Format

#### Summary Report

```text
============================================================
PostgreSQL Schema Validation Report
============================================================
Repository: my-project
Files scanned: 23
Timestamp: 2026-02-09T14:30:00Z
============================================================

Gate 1: Schema Naming ........................... PASS (0 errors, 2 warnings)
Gate 2: Type/Constraint Check ................... FAIL (3 errors, 5 warnings)
Gate 3: Antipattern Detection ................... FAIL (1 error, 4 warnings)
Gate 4: Migration Hygiene ....................... PASS (0 errors, 3 warnings)
Gate 5: Extension Hygiene ....................... PASS (0 errors, 1 warning)

============================================================
RESULT: FAIL (4 errors, 15 warnings)
============================================================

Errors (must fix):
  [types]        schema.sql:45   - "serial" should be identity column
  [types]        schema.sql:48   - "float" used for monetary value
  [types]        schema.sql:52   - "timestamp" without timezone
  [antipattern]  schema.sql:80   - Table "event_log" missing PRIMARY KEY

Warnings (should fix):
  [naming]       schema.sql:10   - Unnamed foreign key constraint
  [types]        schema.sql:30   - "varchar(255)" could be "text"
  ...
```

#### Quick Mode Output

```text
============================================================
PostgreSQL Schema Validation (Quick Mode)
============================================================

Gate 1: Schema Naming ........................... PASS
Gate 2: Type/Constraint Check ................... PASS

RESULT: PASS (quick mode; run full validation for complete results)
============================================================
```

### 9. Error Handling

#### No Schema Files Found

```text
SKIP: No PostgreSQL schema artifacts detected.
Searched: schema/, database/, migrations/, db/migrate/
ORM schemas: Prisma, TypeORM, SQLAlchemy, Drizzle
Dumps: .sql, .dump, .pg_dump, structure.sql

To validate a specific file: ccfg postgresql validate path/to/schema.sql
```

#### Parse Errors

```text
WARN [parse] file.sql:42 - Could not parse SQL statement; skipping line
     Context: Complex PL/pgSQL block or dynamic SQL detected
```

#### Live Connection Failures

```text
FAIL [connection] Could not connect to PostgreSQL at host:5432
     Error: connection refused
     Check: Is PostgreSQL running? Is the host/port correct?
     Check: Does the user have CONNECT privilege on the database?
```

### 10. Remediation Guidance

For each violation type, provide actionable fix instructions.

#### Serial to Identity Migration

```sql
-- Current (wrong)
CREATE TABLE users (id serial PRIMARY KEY);

-- Fix: Convert serial to identity
ALTER TABLE users ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS users_id_seq;
ALTER TABLE users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY;

-- Or for new tables, just use identity from the start:
CREATE TABLE users (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY);
```

#### Timestamp to Timestamptz Migration

```sql
-- Current (wrong)
ALTER TABLE events ALTER COLUMN created_at TYPE timestamp;

-- Fix: Convert to timestamptz
ALTER TABLE events ALTER COLUMN created_at TYPE timestamptz
    USING created_at AT TIME ZONE 'UTC';
-- Note: This rewrites the table. Plan for downtime on large tables.
```

#### Adding Missing Foreign Key Indexes

```sql
-- Find unindexed foreign keys and generate CREATE INDEX statements
SELECT format(
    'CREATE INDEX CONCURRENTLY idx_%s_%s ON %s.%s (%s);',
    tc.table_name, kcu.column_name,
    tc.table_schema, tc.table_name, kcu.column_name
)
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema');
```

#### Non-Concurrent to Concurrent Index

```sql
-- Current (wrong): Locks writes during index creation
CREATE INDEX idx_orders_status ON orders (status);

-- Fix: Use CONCURRENTLY
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);
-- Note: Cannot be inside a transaction block
-- Note: May fail and leave an INVALID index; check and retry if needed
```

## Summary

The validate command provides comprehensive PostgreSQL schema quality assurance through five
progressive gates: naming conventions, type and constraint compliance, antipattern detection,
migration hygiene, and extension hygiene. By analyzing repository artifacts rather than requiring
live database access, it integrates seamlessly into CI/CD pipelines and development workflows. The
detect-and-skip pattern ensures validation works across diverse project setups, while actionable
error messages and remediation guidance direct developers toward production-ready database schemas.
Always address root causes of violations rather than suppressing checks or relying on workarounds.
