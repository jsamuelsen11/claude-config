---
description: >
  Run MySQL schema quality gate suite (naming, engine/charset, antipatterns, migration hygiene)
argument-hint: '[--quick]'
allowed-tools: Bash(mysql *), Bash(mysqldump *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive MySQL schema quality gate suite to ensure database schemas meet production
standards. This command analyzes schema artifacts in the repository to verify naming conventions,
storage engine configuration, character set compliance, antipattern detection, and migration
hygiene.

## Usage

```bash
ccfg mysql validate                    # Full validation (all gates)
ccfg mysql validate --quick            # Quick mode (naming + engine/charset only)
ccfg mysql validate --live             # Validate against live database (requires confirmation)
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Schema Naming**: Verify snake_case identifiers, check reserved word conflicts
1. **Engine/Charset Check**: Flag non-InnoDB tables, non-utf8mb4 character sets
1. **Antipattern Detection**: Missing primary keys, ENUM misuse, FLOAT for money, TEXT/BLOB abuse
1. **Migration Hygiene**: Irreversible operations, missing down migrations, table-locking ops

All gates must pass for validation to succeed. In quick mode, only the first two gates run. The
validation operates on repository artifacts (schema files, migration files, SQL dumps) by default.
Live database validation requires explicit `--live` flag and user confirmation.

## Step-by-Step Process

### 1. Schema Discovery

Locate all MySQL schema artifacts in the repository using multiple discovery strategies.

#### Strategy A: Schema File Detection

Find schema definition files with common extensions and naming patterns:

```bash
# SQL files in schema directories
git ls-files --cached --others --exclude-standard | grep -E 'schema/.*\.sql$'
git ls-files --cached --others --exclude-standard | grep -E 'database/.*\.sql$'

# Dump files
git ls-files --cached --others --exclude-standard | grep -E '\.sql$|\.dump$'
```

#### Strategy B: Migration File Detection

Discover migration files from common migration frameworks:

```bash
# Rails-style migrations
git ls-files --cached --others --exclude-standard | grep -E 'db/migrate/.*\.sql$'

# Flyway migrations
git ls-files --cached --others --exclude-standard | grep -E 'V[0-9]+__.*\.sql$'

# Liquibase changelogs
git ls-files --cached --others --exclude-standard | grep -E 'db/changelog/.*\.(sql|xml)$'

# Prisma migrations
git ls-files --cached --others --exclude-standard | grep -E 'prisma/migrations/.*\.sql$'

# Laravel migrations
git ls-files --cached --others --exclude-standard | grep -E 'database/migrations/.*\.php$'
```

#### Strategy C: ORM Schema Detection

Check for ORM schema definitions:

```bash
# Prisma schema
git ls-files --cached --others --exclude-standard -- 'prisma/schema.prisma'

# Django models (Python)
git ls-files --cached --others --exclude-standard | grep -E 'models\.py$'

# TypeORM entities (TypeScript)
git ls-files --cached --others --exclude-standard | grep -E '\.entity\.ts$'

# Sequelize models (JavaScript)
git ls-files --cached --others --exclude-standard | grep -E 'models/.*\.js$'
```

**Combining and deduplicating results**:

```bash
# Collect all schema sources
{ strategy_a; strategy_b; strategy_c; } | sort -u > /tmp/mysql-schema-files.txt
```

**Empty discovery**: If no schema artifacts are found, check for conventions documentation:

```text
No MySQL schema artifacts found in repository.

Checked locations:
  - schema/*.sql, database/*.sql
  - db/migrate/*.sql
  - V*__*.sql (Flyway)
  - prisma/schema.prisma
  - **/models.py, *.entity.ts

Run 'ccfg mysql validate --live' to validate against a running database instead.
```

### 2. Schema Naming Gate

Verify that all database identifiers follow snake_case naming conventions and avoid reserved word
conflicts.

**Identifier extraction**:

Parse SQL files to extract table names, column names, index names, and constraint names. Use pattern
matching for CREATE TABLE, ALTER TABLE, and CREATE INDEX statements.

```bash
# Extract table names
grep -iE '^\s*CREATE\s+TABLE\s+(`[^`]+`|[a-zA-Z0-9_]+)' *.sql

# Extract column definitions
grep -iE '^\s*`?[a-zA-Z0-9_]+`?\s+(VARCHAR|INT|TEXT|DATETIME|DECIMAL)' *.sql
```

**Reserved word list source**:

Check for a curated reserved word list in the repository:

```bash
# Look for reserved words list
ls docs/db/mysql-reserved-words.txt 2>/dev/null
ls .mysql/reserved-words.txt 2>/dev/null
```

If no list exists, use a high-risk subset (approximately 50-100 commonly-conflicting terms):

```text
SELECT, FROM, WHERE, JOIN, LEFT, RIGHT, INNER, OUTER, GROUP, ORDER, BY, LIMIT,
OFFSET, INSERT, UPDATE, DELETE, TABLE, INDEX, KEY, PRIMARY, FOREIGN, REFERENCES,
CONSTRAINT, CASCADE, CHECK, DEFAULT, AUTO_INCREMENT, COLLATE, CHARACTER, SET,
ENGINE, COMMENT, STATUS, USER, ROLE, GRANT, REVOKE, TRIGGER, PROCEDURE, FUNCTION,
VIEW, SCHEMA, DATABASE, CREATE, ALTER, DROP, TRUNCATE, RENAME, CHANGE, MODIFY,
ADD, COLUMN, IF, ELSE, CASE, WHEN, THEN, END, BEGIN, DECLARE, HANDLER, CURSOR,
LOOP, REPEAT, WHILE, ITERATE, LEAVE, CALL, RETURN, SIGNAL, RESIGNAL, GET,
DIAGNOSTICS, ROWS, AFFECTED, FOUND, SQLSTATE, SQLEXCEPTION, SQLWARNING, NOTFOUND,
EXIT, UNDO, CONTINUE, SAVEPOINT, ROLLBACK, COMMIT, START, TRANSACTION, LOCK,
UNLOCK, PREPARE, EXECUTE, DEALLOCATE, DESCRIBE, EXPLAIN, SHOW, USE, HELP
```

**Note**: This list is curated for common conflicts and does not claim complete coverage of all
MySQL reserved words across all versions.

**Naming convention checks**:

- **snake_case requirement**: All identifiers must use lowercase with underscores
- **No camelCase**: Reject identifiers like `userId`, `firstName`, `orderItems`
- **No SCREAMING_CASE**: Reject all-uppercase names like `USER_ID`, `STATUS_CODE`
- **No mixed case**: Reject `User_ID`, `First_Name`
- **Consistent pluralization**: Flag inconsistent singular/plural (if detectable)

**Reserved word conflicts**:

Check each identifier against the reserved word list. Flag exact matches as high-risk conflicts.

**Success output**:

```text
[1/4] Schema Naming
  -> Scanning: 12 schema files (45 tables, 287 columns)
  OK: All identifiers use snake_case
  OK: No reserved word conflicts detected
```

**Failure output**:

```text
[1/4] Schema Naming
  -> Scanning: 12 schema files (45 tables, 287 columns)
  FAIL: Found 8 naming violations:

  schema/users.sql:15
    Table: UserProfiles (violates snake_case)
    Suggestion: user_profiles

  schema/orders.sql:23
    Column: firstName VARCHAR(100) (violates snake_case)
    Suggestion: first_name

  schema/orders.sql:24
    Column: lastName VARCHAR(100) (violates snake_case)
    Suggestion: last_name

  schema/products.sql:12
    Table: `order` (reserved word conflict)
    Suggestion: orders or customer_order

  schema/products.sql:45
    Column: `status` INT (reserved word conflict)
    Suggestion: product_status or status_id

  schema/inventory.sql:8
    Table: item_group (mixed singular/plural with items table)
    Suggestion: item_groups for consistency

  schema/payments.sql:19
    Index: IDX_USER (violates snake_case)
    Suggestion: idx_user or user_idx

  db/migrate/20240115_add_user_fields.sql:7
    Column: GROUP VARCHAR(50) (reserved word conflict)
    Suggestion: user_group or group_name
```

### 3. Engine/Charset Check

Verify that all tables use InnoDB storage engine and utf8mb4 character set with the recommended
collation.

**Detection strategy**:

Parse CREATE TABLE statements for explicit ENGINE and CHARSET/COLLATE directives. Flag any table
that does not explicitly specify InnoDB and utf8mb4.

```sql
-- Good: Explicit InnoDB and utf8mb4
CREATE TABLE users (
  id INT PRIMARY KEY
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Bad: MyISAM engine
CREATE TABLE logs (
  id INT PRIMARY KEY
) ENGINE=MyISAM;

-- Bad: Legacy utf8 (3-byte)
CREATE TABLE products (
  id INT PRIMARY KEY
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Bad: No explicit engine/charset (relies on server defaults)
CREATE TABLE orders (
  id INT PRIMARY KEY
);
```

**Checks performed**:

1. **Storage engine**: All tables must use ENGINE=InnoDB
   - InnoDB provides ACID compliance, foreign key support, crash recovery
   - MyISAM, MEMORY, CSV engines are flagged as non-compliant
   - Missing ENGINE clause is flagged (relies on server default)

2. **Character set**: All tables must use CHARSET=utf8mb4
   - utf8mb4 supports full Unicode including emoji and supplementary characters
   - Legacy utf8 (alias for utf8mb3) is 3-byte and incomplete
   - latin1, ascii, and other character sets are flagged

3. **Collation**: Recommend utf8mb4_0900_ai_ci (MySQL 8.0+) or utf8mb4_unicode_ci
   - utf8mb4_0900_ai_ci: Modern, accurate Unicode collation (MySQL 8.0+)
   - utf8mb4_unicode_ci: Fallback for MySQL 5.7
   - utf8mb4_general_ci: Less accurate sorting, flag as suboptimal
   - Case-sensitive collations (\_cs): Flag and verify intentional

**Success output**:

```text
[2/4] Engine/Charset Check
  -> Scanning: 45 tables across 12 schema files
  OK: All tables use InnoDB storage engine
  OK: All tables use utf8mb4 character set
  OK: All tables use utf8mb4_0900_ai_ci collation
```

**Failure output**:

```text
[2/4] Engine/Charset Check
  -> Scanning: 45 tables across 12 schema files
  FAIL: Found 5 configuration issues:

  schema/logs.sql:12
    Table: access_logs
    Issue: Uses MyISAM storage engine
    Suggestion: Change to ENGINE=InnoDB for ACID compliance and crash recovery

  schema/sessions.sql:8
    Table: user_sessions
    Issue: Uses MEMORY storage engine
    Suggestion: Change to ENGINE=InnoDB; consider Redis for session storage

  schema/legacy_users.sql:15
    Table: old_users
    Issue: Uses utf8 character set (3-byte, incomplete Unicode)
    Suggestion: Change to DEFAULT CHARSET=utf8mb4

  schema/products.sql:23
    Table: product_catalog
    Issue: No explicit ENGINE specified (relies on server default)
    Suggestion: Add ENGINE=InnoDB to table definition

  schema/categories.sql:9
    Table: categories
    Issue: Uses utf8mb4_general_ci collation (less accurate)
    Suggestion: Change to COLLATE=utf8mb4_0900_ai_ci (MySQL 8.0+)
               or utf8mb4_unicode_ci (MySQL 5.7)
```

### 4. Antipattern Detection

Identify common MySQL antipatterns that lead to performance issues, data integrity problems, or
maintenance difficulties.

**Antipattern categories**:

#### 4.1 Missing Primary Keys

Every table should have a primary key for efficient row identification and replication.

```sql
-- Bad: No primary key
CREATE TABLE event_logs (
  timestamp DATETIME,
  event_type VARCHAR(50),
  user_id INT
) ENGINE=InnoDB;

-- Good: Explicit primary key
CREATE TABLE event_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  timestamp DATETIME,
  event_type VARCHAR(50),
  user_id INT
) ENGINE=InnoDB;
```

**Detection**: Search for CREATE TABLE statements without PRIMARY KEY constraint.

#### 4.2 ENUM for Mutable Values

ENUM should only be used for truly immutable value sets. Mutable enumerations belong in lookup
tables.

```sql
-- Bad: Order status as ENUM (statuses change over time)
CREATE TABLE orders (
  id INT PRIMARY KEY,
  status ENUM('pending', 'processing', 'shipped', 'delivered')
);

-- Good: Status in lookup table
CREATE TABLE orders (
  id INT PRIMARY KEY,
  status_id INT,
  FOREIGN KEY (status_id) REFERENCES order_statuses(id)
);

CREATE TABLE order_statuses (
  id INT PRIMARY KEY,
  name VARCHAR(50) UNIQUE
);
```

**Detection**: Flag ENUM columns in tables related to business logic (orders, users, products). Flag
ENUMs with more than 5 values as likely mutable.

#### 4.3 FLOAT/DOUBLE for Money

Floating-point types introduce rounding errors. Use DECIMAL for monetary values.

```sql
-- Bad: FLOAT for money (rounding errors)
CREATE TABLE products (
  id INT PRIMARY KEY,
  price FLOAT
);

-- Good: DECIMAL for money (exact precision)
CREATE TABLE products (
  id INT PRIMARY KEY,
  price DECIMAL(10, 2)
);
```

**Detection**: Flag FLOAT and DOUBLE columns with names containing: price, cost, amount, balance,
fee, tax, total, subtotal, discount.

#### 4.4 TEXT/BLOB in Frequently Filtered Queries

TEXT and BLOB columns cannot be indexed effectively and cause performance issues when used in WHERE
clauses.

```sql
-- Bad: TEXT column without separate indexed column
CREATE TABLE articles (
  id INT PRIMARY KEY,
  content TEXT,
  INDEX (content(100))  -- Prefix index is inefficient
);

-- Better: Add indexed summary column
CREATE TABLE articles (
  id INT PRIMARY KEY,
  title VARCHAR(255),
  summary VARCHAR(500),
  content TEXT,
  INDEX (title, summary)
);
```

**Detection**: Flag TEXT/BLOB columns that appear in WHERE clauses or have prefix indexes.

#### 4.5 Implicit Type Conversions in WHERE Clauses

String columns queried with numeric values force full table scans due to type conversion.

```sql
-- Bad: Numeric comparison on VARCHAR (implicit conversion)
SELECT * FROM users WHERE user_id = 12345;  -- user_id is VARCHAR

-- Good: Proper data type
SELECT * FROM users WHERE user_id = 12345;  -- user_id is INT
```

**Detection**: Cross-reference column types with query patterns in migrations or comments. Flag
VARCHAR columns named: id, user_id, order_id, etc.

**Success output**:

```text
[3/4] Antipattern Detection
  -> Analyzing: 45 tables for common antipatterns
  OK: All tables have primary keys
  OK: No ENUM types found in business logic tables
  OK: No FLOAT/DOUBLE columns used for monetary values
  OK: No TEXT/BLOB columns with prefix indexes
  OK: No implicit type conversion risks detected
```

**Failure output**:

```text
[3/4] Antipattern Detection
  -> Analyzing: 45 tables for common antipatterns
  FAIL: Found 7 antipatterns:

  schema/logs.sql:45
    Table: event_logs
    Issue: Missing primary key
    Impact: Poor replication performance, inefficient row identification
    Suggestion: Add BIGINT AUTO_INCREMENT PRIMARY KEY

  schema/orders.sql:19
    Table: orders
    Column: status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled')
    Issue: ENUM used for mutable business values
    Impact: Schema changes required to add/modify statuses
    Suggestion: Create order_statuses lookup table with foreign key

  schema/products.sql:23
    Table: products
    Column: price FLOAT
    Issue: FLOAT used for monetary value
    Impact: Rounding errors in financial calculations
    Suggestion: Change to DECIMAL(10, 2)

  schema/products.sql:29
    Table: products
    Column: wholesale_cost DOUBLE
    Issue: DOUBLE used for monetary value
    Impact: Precision loss in bulk calculations
    Suggestion: Change to DECIMAL(10, 4)

  schema/articles.sql:12
    Table: articles
    Column: content TEXT
    Issue: TEXT column with prefix index INDEX(content(100))
    Impact: Inefficient queries on large text fields
    Suggestion: Add indexed summary or title column for filtering

  schema/users.sql:15
    Table: users
    Column: user_id VARCHAR(20)
    Issue: VARCHAR used for identifier (likely numeric)
    Impact: Implicit type conversion in WHERE user_id = 123 forces table scan
    Suggestion: Change to INT or BIGINT if values are numeric

  schema/transactions.sql:34
    Table: transactions
    Column: payment_amount FLOAT
    Issue: FLOAT used for payment amounts
    Impact: Cumulative rounding errors in financial reporting
    Suggestion: Change to DECIMAL(12, 2)
```

### 5. Migration Hygiene

Analyze migration files for dangerous operations, missing rollback procedures, and table-locking
changes that impact production uptime.

**Migration framework detection**:

Identify the migration framework in use by checking for characteristic files and patterns:

```bash
# Rails migrations
ls db/migrate/*.rb

# Flyway migrations
ls db/migration/V*.sql

# Liquibase changelogs
ls db/changelog/*.xml

# Laravel migrations
ls database/migrations/*.php

# Prisma migrations
ls prisma/migrations/*/migration.sql
```

**Checks performed**:

#### 5.1 Irreversible Operations Without Guards

Operations that destroy data should have explicit guards or confirmation requirements.

```sql
-- Bad: Unguarded DROP COLUMN (data loss)
ALTER TABLE users DROP COLUMN legacy_field;

-- Good: Guarded with comment
-- IRREVERSIBLE: Drops legacy_field column - backup data first
ALTER TABLE users DROP COLUMN legacy_field;

-- Bad: TRUNCATE without guard
TRUNCATE TABLE staging_data;

-- Good: Conditional delete with safety check
DELETE FROM staging_data WHERE created_at < NOW() - INTERVAL 90 DAY;
```

**Detection**: Flag DROP COLUMN, DROP TABLE, TRUNCATE, and ALTER COLUMN TYPE without explicit safety
comments.

#### 5.2 Missing Down Migrations

Every up migration should have a corresponding down migration for rollback capability.

```text
# Rails convention
db/migrate/20240115120000_add_user_fields.rb  (requires `def down` or `change`)

# Flyway convention
V001__add_user_fields.sql  (should have U001__add_user_fields.sql)

# Liquibase rollback tags
<rollback> tags required for destructive changes
```

**Detection**: Check for paired up/down migrations or reversible changesets. Flag one-way migrations
that modify schema.

#### 5.3 Mixed Data and Schema Migrations

Schema changes and data migrations should be separate for safer rollback and debugging.

```sql
-- Bad: Schema change mixed with data migration
ALTER TABLE users ADD COLUMN full_name VARCHAR(200);
UPDATE users SET full_name = CONCAT(first_name, ' ', last_name);
ALTER TABLE users DROP COLUMN first_name, DROP COLUMN last_name;

-- Good: Split into two migrations
-- Migration 1: Add column
ALTER TABLE users ADD COLUMN full_name VARCHAR(200);

-- Migration 2: Populate data (after testing)
UPDATE users SET full_name = CONCAT(first_name, ' ', last_name);

-- Migration 3: Drop old columns (after verification)
ALTER TABLE users DROP COLUMN first_name, DROP COLUMN last_name;
```

**Detection**: Flag migrations containing both DDL (CREATE, ALTER, DROP) and DML (INSERT, UPDATE,
DELETE) statements.

#### 5.4 Operations That Lock Tables

Identify operations that acquire table locks and block concurrent writes on large tables.

```sql
-- High-risk: ALTER TABLE on large table (locks entire table)
ALTER TABLE orders ADD COLUMN tracking_number VARCHAR(100);

-- Better: Online schema change
ALTER TABLE orders ADD COLUMN tracking_number VARCHAR(100), ALGORITHM=INPLACE, LOCK=NONE;

-- High-risk: Add index without ALGORITHM (locks table)
CREATE INDEX idx_user_email ON users(email);

-- Better: Online index creation (MySQL 5.6+)
CREATE INDEX idx_user_email ON users(email) ALGORITHM=INPLACE LOCK=NONE;
```

**Detection**: Flag ALTER TABLE and CREATE INDEX without ALGORITHM=INPLACE or LOCK=NONE on tables
likely to have significant data.

**Success output**:

```text
[4/4] Migration Hygiene
  -> Analyzing: 23 migration files (Flyway)
  OK: All destructive operations have safety guards
  OK: All migrations have corresponding rollbacks
  OK: Schema and data migrations are separated
  OK: All ALTER TABLE operations use ALGORITHM=INPLACE
```

**Failure output**:

```text
[4/4] Migration Hygiene
  -> Analyzing: 23 migration files (Flyway)
  FAIL: Found 6 hygiene violations:

  db/migration/V015__remove_legacy_fields.sql:7
    Issue: Irreversible operation without guard
    Statement: ALTER TABLE users DROP COLUMN legacy_status
    Impact: Permanent data loss if migration runs unexpectedly
    Suggestion: Add safety comment: -- IRREVERSIBLE: drops legacy_status

  db/migration/V015__remove_legacy_fields.sql
    Issue: Missing down migration
    File: V015__remove_legacy_fields.sql exists
    Missing: U015__remove_legacy_fields.sql
    Impact: Cannot rollback schema change
    Suggestion: Create U015 with ALTER TABLE users ADD COLUMN legacy_status

  db/migration/V018__user_name_consolidation.sql:3-12
    Issue: Mixed schema and data migration
    Contains: ALTER TABLE (line 3), UPDATE (line 5), ALTER TABLE (line 12)
    Impact: Difficult to rollback partially, higher risk of data inconsistency
    Suggestion: Split into 3 separate migrations: add column, populate data, drop columns

  db/migration/V020__add_product_index.sql:5
    Issue: CREATE INDEX without online algorithm
    Statement: CREATE INDEX idx_product_category ON products(category_id)
    Impact: Locks products table during index creation (may take minutes on large tables)
    Suggestion: Add ALGORITHM=INPLACE LOCK=NONE for online index creation

  db/migration/V022__add_order_notes.sql:8
    Issue: ALTER TABLE without online algorithm
    Statement: ALTER TABLE orders ADD COLUMN notes TEXT
    Impact: Locks orders table during schema change
    Suggestion: Add ALGORITHM=INPLACE LOCK=NONE (MySQL 5.6+)

  db/migration/V023__cleanup_staging.sql:1
    Issue: TRUNCATE without guard
    Statement: TRUNCATE TABLE staging_imports
    Impact: Irreversible data deletion
    Suggestion: Use DELETE with WHERE clause or add safety comment
```

### 6. Results Reporting

After all gates complete, generate a comprehensive summary report.

**Success output**:

```text
Running MySQL schema quality gates...

Discovered schema artifacts:
  - 12 SQL schema files (45 tables)
  - 23 migration files (Flyway)
  - 0 ORM schemas

[1/4] Schema Naming
  -> Scanning: 45 tables, 287 columns, 34 indexes
  OK: All identifiers use snake_case
  OK: No reserved word conflicts

[2/4] Engine/Charset Check
  -> Scanning: 45 tables
  OK: All tables use InnoDB storage engine
  OK: All tables use utf8mb4 character set
  OK: All tables use utf8mb4_0900_ai_ci collation

[3/4] Antipattern Detection
  -> Analyzing: 45 tables for common antipatterns
  OK: All tables have primary keys
  OK: No ENUM misuse detected
  OK: No FLOAT/DOUBLE for monetary values
  OK: No TEXT/BLOB indexing issues

[4/4] Migration Hygiene
  -> Analyzing: 23 migration files
  OK: All destructive operations have guards
  OK: All migrations have rollbacks
  OK: Schema and data migrations separated
  OK: No table-locking operations without online algorithm

==================================================
ALL GATES PASSED (4/4)
==================================================

Schema quality: EXCELLENT
Ready for production deployment
```

**Failure output**:

```text
Running MySQL schema quality gates...

Discovered schema artifacts:
  - 12 SQL schema files (45 tables)
  - 23 migration files (Flyway)
  - 1 ORM schema (Prisma)

[1/4] Schema Naming
  -> Scanning: 45 tables, 287 columns, 34 indexes
  FAIL: Found 8 naming violations
    - 3 tables violate snake_case
    - 2 reserved word conflicts
    - 3 columns violate snake_case
  See details above

[2/4] Engine/Charset Check
  -> Scanning: 45 tables
  FAIL: Found 5 configuration issues
    - 2 tables use non-InnoDB engines
    - 1 table uses legacy utf8 charset
    - 2 tables missing explicit engine/charset
  See details above

[3/4] Antipattern Detection
  -> Analyzing: 45 tables for common antipatterns
  FAIL: Found 7 antipatterns
    - 1 table missing primary key
    - 2 ENUM columns for mutable values
    - 4 FLOAT/DOUBLE columns for money
  See details above

[4/4] Migration Hygiene
  -> Analyzing: 23 migration files
  FAIL: Found 6 hygiene violations
    - 2 unguarded destructive operations
    - 1 missing down migration
    - 1 mixed schema/data migration
    - 2 table-locking operations
  See details above

==================================================
VALIDATION FAILED (4/4 gates failed)
==================================================

Critical issues: 26 total violations
Priority fixes:
  1. Change FLOAT/DOUBLE to DECIMAL for monetary columns
  2. Add primary key to event_logs table
  3. Convert non-InnoDB tables to InnoDB
  4. Rename tables/columns to snake_case
  5. Add down migrations for V015
  6. Add ALGORITHM=INPLACE to V020, V022

Run 'ccfg mysql validate' after fixes to verify
```

**Quick mode output**:

```text
Running MySQL schema quality gates (quick mode)...

Discovered schema artifacts:
  - 12 SQL schema files (45 tables)

[1/2] Schema Naming
  -> Scanning: 45 tables, 287 columns, 34 indexes
  OK: All identifiers use snake_case
  OK: No reserved word conflicts

[2/2] Engine/Charset Check
  -> Scanning: 45 tables
  OK: All tables use InnoDB storage engine
  OK: All tables use utf8mb4 character set

==================================================
QUICK VALIDATION PASSED (2/2)
==================================================

Note: Quick mode skips antipattern detection and migration hygiene
Run 'ccfg mysql validate' for full validation
```

**Conventions documentation check**:

If a `docs/` directory exists, check for MySQL conventions documentation:

```bash
ls docs/db/mysql-conventions.md 2>/dev/null
ls docs/database/conventions.md 2>/dev/null
ls CONVENTIONS.md 2>/dev/null
```

If found, report location in summary:

```text
==================================================
ALL GATES PASSED (4/4)
==================================================

Schema quality: EXCELLENT
Conventions doc: docs/db/mysql-conventions.md
```

If `docs/` directory exists but no conventions doc found:

```text
==================================================
ALL GATES PASSED (4/4)
==================================================

Note: No MySQL conventions documentation found
Consider creating: docs/db/mysql-conventions.md
```

If no `docs/` directory:

```text
[SKIP] Conventions documentation check (no docs/ directory)
```

## Key Rules and Requirements

### Source of Truth

1. **Repository artifacts only by default**: Validate schema files, migration files, SQL dumps, and
   ORM schemas that exist in the repository. Never connect to a live database unless explicitly
   requested.

2. **Live database requires confirmation**: The `--live` flag must be accompanied by explicit user
   confirmation to prevent accidental production database introspection.

3. **Git-tracked files preferred**: Prioritize git-tracked files using `git ls-files` to avoid
   validating temporary or ignored files.

### Validation Behavior

1. **Never suggest disabling checks**: When violations are found, always suggest fixes to address
   the root cause. Never recommend suppressing warnings or skipping checks.

2. **Report all gate results**: Even if an early gate fails, continue running remaining gates and
   report all results. This provides a complete picture of schema quality.

3. **Detect-and-skip pattern**: If a check's tool is not available or a required file is missing,
   mark that gate as SKIPPED rather than FAIL. Report what was skipped and why.

4. **Quick mode gates**: In `--quick` mode, run only Schema Naming and Engine/Charset checks. Skip
   Antipattern Detection and Migration Hygiene.

### Gate Status Definitions

- **PASS**: Gate executed successfully with no violations
- **FAIL**: Gate executed but found violations or antipatterns
- **SKIP**: Gate not executed due to missing tool, missing files, or mode selection

### Reserved Word Handling

1. **Curated list**: Use a high-risk subset of 50-100 commonly-conflicting reserved words, not a
   complete list of all MySQL reserved words across all versions.

2. **Repository-provided list**: Check for a project-specific reserved words list in
   `docs/db/mysql-reserved-words.txt` or `.mysql/reserved-words.txt`. If found, use that instead.

3. **No completeness claim**: Clearly document that the reserved word check is not exhaustive and
   focuses on common conflicts.

### Configuration Detection

**MySQL version detection**:

Detect MySQL version from migration comments, docker-compose.yml, or CI configuration. This affects
recommendations:

- MySQL 8.0+: Recommend utf8mb4_0900_ai_ci collation
- MySQL 5.7: Recommend utf8mb4_unicode_ci collation
- MySQL 5.6: Warn about online DDL limitations

**Migration framework detection**:

Detect migration framework from file patterns and adjust hygiene checks:

- Flyway: Check for V/U file pairs
- Liquibase: Check for rollback tags in XML
- Rails: Check for reversible change methods
- Laravel: Check for down() methods
- Prisma: Check for migration_lock.toml

### Error Handling

When a gate fails, provide actionable feedback:

1. **Display file location**: Show exact file path, line number when possible
2. **Explain impact**: Describe why the violation matters for production systems
3. **Suggest concrete fixes**: Offer specific SQL statements or refactoring approaches
4. **Prioritize by severity**: Critical issues (data loss, corruption) before optimization issues

### Exit Behavior

The command should result in the following exit status:

- Exit 0: All active gates passed (skipped gates are not failures)
- Exit 1: One or more gates failed with violations
- Exit 2: Command invocation error (bad arguments, missing required files)

## Common Scenarios

### Scenario 1: Rails Project with Active Record Migrations

Project uses Rails with schema.rb and timestamped migrations.

**Expected behavior**:

- Parse `db/schema.rb` for current schema state
- Analyze `db/migrate/*.rb` files for migration hygiene
- Check for `def change` (reversible) vs `def up/down` (explicit)
- Flag migrations missing `def down` method

### Scenario 2: Flyway Migrations Only

Project uses pure SQL migrations with Flyway naming convention.

**Expected behavior**:

- Discover `V*__*.sql` files in `db/migration/`
- Check for corresponding `U*__*.sql` undo migrations
- Parse SQL for CREATE TABLE, ALTER TABLE statements
- Report missing undo migrations as hygiene violations

### Scenario 3: ORM Schema Without SQL Files

Project uses Prisma with no raw SQL files, only `schema.prisma`.

**Expected behavior**:

- Parse `prisma/schema.prisma` for model definitions
- Extract table names, column types, indexes from Prisma syntax
- Check migration files in `prisma/migrations/*/migration.sql`
- Apply all gates to Prisma-generated schema

### Scenario 4: Mixed SQL Dump and Migrations

Project has both a full `schema.sql` dump and incremental migrations.

**Expected behavior**:

- Parse `schema.sql` as authoritative current state
- Validate migration files for hygiene only
- Flag conflicts between schema.sql and migration final state
- Suggest using migrations as source of truth

### Scenario 5: Live Database Validation

Developer wants to validate a running database, not repository files.

**Expected behavior**:

- Require `--live` flag explicitly
- Prompt for database connection details (host, port, database, user)
- Request confirmation: "Connect to live database? Type 'yes' to confirm:"
- Use mysqldump or INFORMATION_SCHEMA queries to extract schema
- Run all gates on live schema
- Never modify the database, only read schema metadata

## Troubleshooting

### "No MySQL schema artifacts found"

**Cause**: Validate command cannot locate any schema files in the repository.

**Solutions**:

1. Verify schema files exist in expected locations:

   ```bash
   ls schema/*.sql
   ls db/migrate/*.sql
   ls prisma/schema.prisma
   ```

2. Check if files are git-tracked:

   ```bash
   git ls-files | grep -E '\.sql$'
   ```

3. Use `--live` flag to validate against a running database instead:

   ```bash
   ccfg mysql validate --live
   ```

### "Reserved word conflicts detected"

**Cause**: Table or column names match MySQL reserved words.

**Solutions**:

1. Rename identifiers to avoid conflicts:

   ```sql
   -- Bad
   CREATE TABLE `order` (id INT PRIMARY KEY);

   -- Good
   CREATE TABLE orders (id INT PRIMARY KEY);
   ```

2. Use descriptive suffixes:

   ```sql
   -- Bad
   ALTER TABLE users ADD COLUMN `group` VARCHAR(50);

   -- Good
   ALTER TABLE users ADD COLUMN user_group VARCHAR(50);
   ```

3. Do NOT rely on backtick quoting - rename the identifier instead

### "Table locks during ALTER TABLE"

**Cause**: ALTER TABLE without ALGORITHM=INPLACE blocks concurrent writes.

**Solutions**:

1. For MySQL 5.6+, add online DDL syntax:

   ```sql
   ALTER TABLE orders
   ADD COLUMN notes TEXT,
   ALGORITHM=INPLACE,
   LOCK=NONE;
   ```

2. For large tables, use pt-online-schema-change:

   ```bash
   pt-online-schema-change \
     --alter "ADD COLUMN notes TEXT" \
     D=mydb,t=orders \
     --execute
   ```

3. Schedule schema changes during low-traffic windows

### "ENUM antipattern detected"

**Cause**: ENUM used for values that change over time (statuses, categories).

**Solutions**:

1. Migrate ENUM to lookup table:

   ```sql
   -- Step 1: Create lookup table
   CREATE TABLE order_statuses (
     id INT PRIMARY KEY AUTO_INCREMENT,
     name VARCHAR(50) UNIQUE NOT NULL
   );

   INSERT INTO order_statuses (name) VALUES
     ('pending'), ('processing'), ('shipped'), ('delivered');

   -- Step 2: Add foreign key column
   ALTER TABLE orders ADD COLUMN status_id INT;

   -- Step 3: Migrate data
   UPDATE orders o
   JOIN order_statuses s ON o.status = s.name
   SET o.status_id = s.id;

   -- Step 4: Drop ENUM column
   ALTER TABLE orders DROP COLUMN status;
   ```

### "FLOAT used for monetary values"

**Cause**: FLOAT/DOUBLE columns cause rounding errors in financial calculations.

**Solutions**:

1. Change to DECIMAL with appropriate precision:

   ```sql
   -- For prices in dollars with cents
   ALTER TABLE products
   MODIFY COLUMN price DECIMAL(10, 2);

   -- For cryptocurrency with 8 decimal places
   ALTER TABLE crypto_balances
   MODIFY COLUMN amount DECIMAL(20, 8);
   ```

2. Audit existing data for rounding errors:

   ```sql
   -- Find rows with suspicious precision
   SELECT id, price FROM products
   WHERE price != ROUND(price, 2);
   ```

### "Missing down migration"

**Cause**: Migration file has no corresponding rollback procedure.

**Solutions**:

1. For Flyway, create undo migration:

   ```bash
   # If you have V015__add_user_fields.sql
   # Create U015__add_user_fields.sql with rollback
   ```

2. For Rails, use reversible change:

   ```ruby
   def change
     add_column :users, :full_name, :string
   end
   ```

3. For irreversible changes, explicitly state:

   ```sql
   -- IRREVERSIBLE: This migration drops the legacy_data column
   -- Backup data with: SELECT * FROM users INTO OUTFILE '/tmp/users_backup.csv'
   ALTER TABLE users DROP COLUMN legacy_data;
   ```

### "utf8 character set detected"

**Cause**: Table uses legacy utf8 (3-byte) instead of utf8mb4 (4-byte).

**Solutions**:

1. Convert table to utf8mb4:

   ```sql
   ALTER TABLE users
   CONVERT TO CHARACTER SET utf8mb4
   COLLATE utf8mb4_0900_ai_ci;
   ```

2. Update default for future tables:

   ```sql
   ALTER DATABASE mydb
   CHARACTER SET utf8mb4
   COLLATE utf8mb4_0900_ai_ci;
   ```

3. Verify no data loss during conversion:

   ```sql
   -- Check for 4-byte characters before conversion
   SELECT id, column_name
   FROM table_name
   WHERE LENGTH(column_name) != CHAR_LENGTH(column_name);
   ```

## Summary

The validate command provides comprehensive MySQL schema quality assurance through four progressive
gates: naming conventions, storage engine configuration, antipattern detection, and migration
hygiene. By analyzing repository artifacts rather than requiring live database access, it integrates
seamlessly into CI/CD pipelines and development workflows. The detect-and-skip pattern ensures
validation works across diverse project setups, while actionable error messages guide developers
toward production-ready database schemas. Always address root causes of violations rather than
suppressing checks or relying on workarounds.
