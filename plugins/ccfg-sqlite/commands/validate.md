---
description: >
  Run SQLite schema quality gate suite including naming conventions, PRAGMA configuration checks,
  and antipattern detection across schema files and initialization scripts
argument-hint: '[--quick]'
allowed-tools: Bash(sqlite3 *), Bash(git *), Read, Grep, Glob
---

# /ccfg-sqlite:validate

Run the full SQLite schema quality gate suite. This command analyzes schema files, migration
scripts, and initialization SQL in the repository to detect naming issues, missing PRAGMA
configuration, and common antipatterns.

## Important: Source of Truth

This command operates on **repository artifacts only** — schema files, migration files, init
scripts, and SQL dumps found in the project. It does **not** open or inspect `.db` files by default.

- **To inspect a `.db` file**: The user must pass `--db <path>` and explicitly confirm they want the
  file opened.
- **Never open `.db` files** without the `--db` flag and explicit user confirmation.
- **Never connect to live databases** without explicit user approval.

## Execution Flow

### Step 1: Detect Project Structure

Scan the repository for SQLite-related files:

1. **Schema files**: Look for `*.sql` files containing `CREATE TABLE` statements:
   - `schema.sql`, `init.sql`, `create_tables.sql`
   - `migrations/*.sql`, `db/migrations/*.sql`
   - `sql/*.sql`, `database/*.sql`
2. **Init scripts**: Files with PRAGMA statements and table creation
3. **Migration files**: Numbered SQL files in migration directories
4. **Application code**: Files referencing SQLite (Python, JavaScript, Go, Rust, etc.)
5. **Conventions document**: Check for `docs/db/sqlite-conventions.md` or similar

```bash
# File detection patterns
glob: "**/*.sql"
glob: "**/schema.*"
glob: "**/migrations/**"
glob: "**/init*.sql"
grep: "CREATE TABLE" in *.sql files
grep: "sqlite3" in application source files
grep: "PRAGMA" in *.sql files
```

If no SQLite-related files are found, report and exit:

```text
SQLite Validate: No SQLite schema files or migration scripts found.
Result: SKIPPED (no SQLite artifacts detected)
```

### Step 2: Parse Schema Information

Extract schema information from detected files:

- Table names and column definitions
- Index definitions
- PRAGMA statements
- Foreign key relationships
- CHECK constraints
- Generated column definitions

### Step 3: Run Quality Gates

Execute gates based on mode (full or quick).

## Quality Gates

### Gate 1: Schema Naming (Full + Quick)

**Check**: All table and column names follow `snake_case` convention.

**Rules**:

- Table names: lowercase `snake_case`, no spaces, no special characters
- Column names: lowercase `snake_case`
- Index names: `idx_` prefix recommended
- Foreign key column names: should end with `_id`

```sql
-- CORRECT: Proper naming
CREATE TABLE user_profiles (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE INDEX idx_user_profiles_user ON user_profiles(user_id);
```

```sql
-- WRONG: Poor naming (will be flagged)
CREATE TABLE UserProfiles (        -- PascalCase
    ID INTEGER PRIMARY KEY,        -- UPPERCASE
    userId INTEGER,                -- camelCase
    "display name" TEXT,           -- Spaces (quoted identifier)
    AvatarURL TEXT                 -- Mixed case
);
```

**Reserved word check**: Flag table and column names that match SQLite reserved words from the
high-risk subset. The reserved word list is curated (~50-100 commonly-conflicting terms) and is not
exhaustive — it focuses on terms that cause actual SQL parsing ambiguities.

High-risk reserved words include: `order`, `group`, `select`, `table`, `index`, `key`, `value`,
`values`, `default`, `check`, `column`, `row`, `trigger`, `view`, `primary`, `foreign`,
`references`, `constraint`, `transaction`, `begin`, `end`, `case`, `when`, `then`, `else`, `create`,
`drop`, `alter`, `insert`, `update`, `delete`, `where`, `from`, `join`, `on`, `in`, `not`, `null`,
`true`, `false`, `and`, `or`, `like`, `between`, `exists`, `having`, `limit`, `offset`, `union`,
`except`, `intersect`, `replace`, `abort`, `action`, `add`, `after`, `all`, `analyze`, `as`, `asc`,
`attach`, `autoincrement`, `before`, `by`, `cascade`, `cast`, `collate`, `commit`, `conflict`,
`cross`, `current`, `database`, `desc`, `detach`, `distinct`, `do`, `each`, `escape`, `explain`,
`fail`, `for`, `full`, `glob`, `if`, `ignore`, `immediate`, `indexed`, `initially`, `inner`,
`instead`, `into`, `is`, `isnull`, `left`, `match`, `natural`, `no`, `nothing`, `notnull`, `of`,
`outer`, `plan`, `pragma`, `query`, `raise`, `recursive`, `reindex`, `release`, `rename`,
`restrict`, `right`, `rollback`, `savepoint`, `set`, `temp`, `temporary`, `to`, `unique`, `using`,
`vacuum`, `virtual`, `with`, `without`.

**Output format**:

```text
Gate 1: Schema Naming
  PASS  Table 'users' follows snake_case convention
  PASS  Table 'order_items' follows snake_case convention
  FAIL  Table 'UserProfiles' uses PascalCase — rename to 'user_profiles'
  WARN  Column 'order' in table 'line_items' matches reserved word
  Result: FAIL (1 error, 1 warning)
```

### Gate 2: PRAGMA Checks (Full Only)

**Check**: Verify that PRAGMA configuration is present and correct in init scripts or application
code.

**Rules**:

1. **WAL mode**: `PRAGMA journal_mode = WAL` should be configured somewhere (init script or
   application connection setup)
2. **Foreign keys**: `PRAGMA foreign_keys = ON` should be configured (defaults to OFF)
3. **Busy timeout**: `PRAGMA busy_timeout` should be set (defaults to 0 — immediate SQLITE_BUSY)
4. **Page size**: If configured, should be a power of 2 between 512 and 65536
5. **Synchronous**: If WAL mode is used, `synchronous = NORMAL` is recommended over the default
   `FULL`

**Network filesystem warning**: Scan database paths in application code and configuration files. If
paths contain indicators of network filesystem mounts, emit a WARN:

- `/mnt/` — common NFS mount point
- `/Volumes/` — macOS network volume mount
- `\\` or `//server` — UNC paths (Windows SMB)
- `/media/` — removable/network media
- `nfs`, `smb`, `cifs` in path components

```text
WARN  Database path '/mnt/shared/app.db' appears to be on a network filesystem.
      WAL mode is unreliable on NFS/SMB/CIFS. Consider moving to local storage.
      This is a heuristic — verify the actual filesystem type.
```

Even if no network filesystem paths are detected, include a note in the output:

```text
NOTE  WAL mode requires local filesystem storage. Network filesystems (NFS, SMB, CIFS)
      do not reliably support the shared-memory mechanisms WAL requires.
```

**Output format**:

```text
Gate 2: PRAGMA Configuration
  PASS  WAL mode configured in init.sql
  PASS  Foreign keys enabled in init.sql
  WARN  busy_timeout not explicitly configured — defaults to 0 (immediate SQLITE_BUSY)
  PASS  synchronous = NORMAL configured (appropriate for WAL mode)
  NOTE  No network filesystem paths detected in configuration
  Result: WARN (0 errors, 1 warning)
```

### Gate 3: Antipattern Detection (Full Only)

**Check**: Detect common SQLite antipatterns in schema definitions.

**Rules**:

1. **Missing WITHOUT ROWID on lookup tables**: Small tables with non-integer primary keys (TEXT PKs,
   composite PKs) that appear to be lookup/mapping tables should consider `WITHOUT ROWID`.

   ```sql
   -- Flagged: Small lookup table without WITHOUT ROWID
   CREATE TABLE country_codes (
       code TEXT PRIMARY KEY,
       name TEXT NOT NULL
   ) STRICT;
   -- Suggestion: Consider WITHOUT ROWID for this lookup table
   ```

2. **Non-ISO-8601 date storage**: Detect date/time columns that use non-standard formats. Flag
   columns named `*_date`, `*_at`, `*_time`, `*_timestamp` that are INTEGER type (suggesting Unix
   timestamps) or TEXT without ISO-8601 format validation.

   ```sql
   -- Flagged: Unix timestamp for dates
   CREATE TABLE events (
       id INTEGER PRIMARY KEY,
       event_date INTEGER  -- Unix timestamp — should be TEXT ISO-8601
   );
   ```

3. **Unnecessary AUTOINCREMENT**: Flag `AUTOINCREMENT` usage where plain `INTEGER PRIMARY KEY` would
   suffice. `AUTOINCREMENT` adds overhead (tracking table) and is rarely needed.

   ```sql
   -- Flagged: Unnecessary AUTOINCREMENT
   CREATE TABLE logs (
       id INTEGER PRIMARY KEY AUTOINCREMENT,  -- AUTOINCREMENT rarely needed
       message TEXT
   );
   -- Suggestion: Use INTEGER PRIMARY KEY unless rowid reuse prevention is required
   ```

4. **Missing STRICT modifier**: Flag tables without the `STRICT` modifier where type safety matters
   (tables with numeric columns, financial data, etc.). This is an advisory check — STRICT requires
   SQLite 3.37+ and may not be appropriate for all environments.

   ```sql
   -- Flagged: Missing STRICT on table with numeric columns
   CREATE TABLE invoices (
       id INTEGER PRIMARY KEY,
       amount REAL,          -- Without STRICT, text could be inserted here
       quantity INTEGER
   );
   -- Suggestion: Consider adding STRICT modifier for type safety
   ```

5. **Missing primary key**: Tables without an explicit primary key or rowid alias.

6. **REAL for money**: Using `REAL` (floating point) for monetary values.

   ```sql
   -- Flagged: REAL for financial data
   CREATE TABLE transactions (
       id INTEGER PRIMARY KEY,
       amount REAL  -- Floating point rounding errors
   );
   -- Suggestion: Use INTEGER (cents) for monetary values
   ```

**Output format**:

```text
Gate 3: Antipattern Detection
  WARN  Table 'country_codes' has TEXT PK without WITHOUT ROWID — consider for lookup tables
  FAIL  Column 'event_date' in 'events' is INTEGER — use TEXT ISO-8601 for dates
  WARN  Table 'logs' uses AUTOINCREMENT — consider plain INTEGER PRIMARY KEY
  WARN  Table 'invoices' missing STRICT modifier — type safety not enforced
  FAIL  Column 'amount' in 'transactions' uses REAL — use INTEGER cents for money
  Result: FAIL (2 errors, 3 warnings)
```

### Gate 4: Conventions Document (Full + Quick)

**Check**: Verify presence of a conventions document.

```text
Gate 4: Conventions Document
  PASS  Found conventions document at docs/db/sqlite-conventions.md
```

Or:

```text
Gate 4: Conventions Document
  SKIPPED  No docs/ directory found — conventions document check skipped
```

Note: This gate never fails — it only reports PASS or SKIPPED. Missing documentation is not a schema
quality issue.

## Quick Mode (`--quick`)

When invoked with `--quick`, run only:

1. **Gate 1: Schema Naming** — Same as full mode
2. **Gate 4: Conventions Document** — Same as full mode

Skip Gate 2 (PRAGMA checks) and Gate 3 (antipattern detection) for speed.

Quick mode is designed for fast iteration during development — highest-signal checks only,
completing in seconds rather than scanning the full codebase.

```text
SQLite Validate (Quick Mode)
=============================

Gate 1: Schema Naming
  PASS  All 5 tables follow snake_case convention
  PASS  No reserved word conflicts detected
  Result: PASS

Gate 4: Conventions Document
  PASS  Found conventions document at docs/db/sqlite-conventions.md

Summary: 2 gates passed, 0 failed, 2 skipped (quick mode)
```

## Output Format

### Full Mode Output

```text
SQLite Validate
================

Detected: 3 schema files, 5 migration files, 1 init script
Database: Not inspected (use --db <path> to inspect a .db file)

Gate 1: Schema Naming ..................................... PASS
Gate 2: PRAGMA Configuration .............................. WARN
Gate 3: Antipattern Detection ............................. FAIL
Gate 4: Conventions Document .............................. PASS

Summary: 2 gates passed, 1 failed, 1 warning

Details:
--------

Gate 2: PRAGMA Configuration
  WARN  busy_timeout not explicitly configured

Gate 3: Antipattern Detection
  FAIL  Column 'amount' in 'transactions' uses REAL — use INTEGER cents for money
  WARN  Table 'logs' uses AUTOINCREMENT — consider plain INTEGER PRIMARY KEY

Action required: Fix 1 error before proceeding. Warnings are advisory.
```

## Key Rules

1. **Repo artifacts only**: Default source of truth is schema files, migration files, and init
   scripts in the repository. Never opens `.db` files without `--db` flag and confirmation.
2. **Never suggest disabling checks**: If a gate fails, fix the root cause. Never recommend
   `--skip-gate` or similar workarounds.
3. **Report all results**: Show all gate results, not just the first failure. Developers need the
   full picture.
4. **Detect-and-skip**: If a check requires a tool that is not available (e.g., no migration
   directory found), skip that gate and report it as SKIPPED. Never fail on missing optional
   infrastructure.
5. **Conventions document check**: Reports SKIPPED if no `docs/` directory exists — never fails on
   missing documentation structure.
6. **Severity levels**:
   - FAIL: Must be fixed before proceeding
   - WARN: Should be reviewed, may be intentional
   - PASS: Gate check passed
   - SKIPPED: Gate check could not run (missing prerequisites)
   - NOTE: Informational message, no action required
