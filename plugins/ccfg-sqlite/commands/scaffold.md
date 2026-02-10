---
description: >
  Initialize SQLite database initialization scripts and migration directory structure with
  recommended PRAGMAs, STRICT tables, and schema conventions for embedded applications
argument-hint: '[--type=init-script|migration-dir]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# /ccfg-sqlite:scaffold

Initialize database initialization scripts and migration directory structure for SQLite projects.
This command generates production-ready database setup with recommended PRAGMA configuration, STRICT
table definitions, and idempotent schema creation.

## Important: Safety Rules

- **Never generate actual database credentials** — all configuration uses placeholder values.
- **Never open or modify existing `.db` files** — scaffold creates SQL scripts and configuration
  files only.
- **If inside a git repo**, verify `.gitignore` includes `*.db`, `*.db-wal`, `*.db-shm`.
- **Always include the recommended PRAGMA block** in init scripts — this is non-negotiable for
  SQLite database health.
- **Use STRICT tables** where the target SQLite version supports it (3.37+). Include a comment
  noting the version requirement.

## Scaffold Types

### init-script (default)

Generate a database initialization SQL script with recommended PRAGMAs and schema creation.

#### Step 1: Detect Existing Project Context

Scan the project for existing SQLite usage:

```bash
# Detection patterns
glob: "**/*.db"              # Existing databases
glob: "**/schema.sql"        # Existing schema files
glob: "**/init*.sql"         # Existing init scripts
grep: "sqlite3" in source    # SQLite usage in application code
grep: "PRAGMA" in *.sql      # Existing PRAGMA configuration
```

If existing SQLite configuration is found, respect it and augment rather than replace.

#### Step 2: Generate Init Script

Create `db/init.sql` (or appropriate path based on project structure):

```sql
-- =============================================================================
-- SQLite Database Initialization
-- =============================================================================
-- This script initializes the database with recommended PRAGMAs and creates
-- the schema. Run this script on every new database creation.
--
-- Usage:
--   sqlite3 app.db < db/init.sql
--
-- Note: PRAGMAs marked [per-connection] must also be set in application code
-- on every new connection. Only journal_mode and page_size persist in the
-- database file.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PRAGMA Configuration
-- ---------------------------------------------------------------------------
-- These PRAGMAs configure SQLite for optimal performance and data integrity.
-- See: https://www.sqlite.org/pragma.html

-- Write-Ahead Logging for concurrent read/write access [per-database, persisted]
PRAGMA journal_mode = WAL;

-- Enforce foreign key constraints [per-connection, OFF by default!]
PRAGMA foreign_keys = ON;

-- Wait up to 5 seconds for locks instead of failing immediately [per-connection]
PRAGMA busy_timeout = 5000;

-- Limit WAL file growth to 64MB [per-database]
PRAGMA journal_size_limit = 67108864;

-- NORMAL is safe with WAL mode and faster than FULL [per-connection]
PRAGMA synchronous = NORMAL;

-- 64MB page cache in memory [per-connection]
PRAGMA cache_size = -64000;

-- Use memory for temporary tables and indexes [per-connection]
PRAGMA temp_store = MEMORY;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
-- All tables use STRICT modifier for type safety (requires SQLite 3.37+).
-- All tables use IF NOT EXISTS for idempotent execution.
-- Dates stored as TEXT in ISO-8601 format.
-- Booleans stored as INTEGER (0/1) with CHECK constraints.

-- Example table (replace with your actual schema)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

-- Example: Auto-update timestamps trigger
CREATE TRIGGER IF NOT EXISTS users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    UPDATE users SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE id = old.id;
END;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ---------------------------------------------------------------------------
-- Seed Data (Development Only)
-- ---------------------------------------------------------------------------
-- Uncomment for development/testing environments:
--
-- INSERT OR IGNORE INTO users (id, email, name) VALUES
--     (1, 'alice@example.com', 'Alice'),
--     (2, 'bob@example.com', 'Bob');
```

#### Step 3: Generate Application Connection Helper

Detect the application language/framework and generate a connection helper:

**Python** (detected via `requirements.txt`, `pyproject.toml`, or `*.py` files):

```python
# db/connection.py
"""
SQLite connection management.

Usage:
    from db.connection import get_db, get_reader, get_writer

    # For read operations
    with get_reader() as conn:
        rows = conn.execute("SELECT * FROM users").fetchall()

    # For write operations
    with get_writer() as conn:
        conn.execute("INSERT INTO users (email, name) VALUES (?, ?)",
                     ("alice@example.com", "Alice"))
"""
import sqlite3
import os
import threading

DATABASE_PATH = os.environ.get("DATABASE_PATH", "app.db")

_writer_lock = threading.Lock()
_local = threading.local()


def _configure(conn: sqlite3.Connection) -> None:
    """Apply per-connection PRAGMAs."""
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA busy_timeout = 5000")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA cache_size = -64000")
    conn.execute("PRAGMA temp_store = MEMORY")


def get_db() -> sqlite3.Connection:
    """Get a configured database connection (general purpose)."""
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    _configure(conn)
    return conn


def get_reader() -> sqlite3.Connection:
    """Get a read-only connection (thread-local, reused)."""
    if not hasattr(_local, "reader"):
        _local.reader = sqlite3.connect(
            f"file:{DATABASE_PATH}?mode=ro", uri=True
        )
        _local.reader.row_factory = sqlite3.Row
        _configure(_local.reader)
    return _local.reader


def get_writer() -> sqlite3.Connection:
    """Get the writer connection (singleton, thread-safe via lock)."""
    if not hasattr(_local, "writer"):
        _local.writer = sqlite3.connect(DATABASE_PATH)
        _local.writer.row_factory = sqlite3.Row
        _configure(_local.writer)
        _local.writer.execute("PRAGMA journal_mode = WAL")
    return _local.writer


def init_db() -> None:
    """Initialize the database with schema."""
    conn = get_writer()
    with open(os.path.join(os.path.dirname(__file__), "init.sql")) as f:
        conn.executescript(f.read())
```

**Node.js** (detected via `package.json`):

```javascript
// db/connection.js
/**
 * SQLite connection management using better-sqlite3.
 *
 * Usage:
 *   const { db } = require('./db/connection');
 *   const users = db.prepare('SELECT * FROM users').all();
 */
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const DATABASE_PATH = process.env.DATABASE_PATH || 'app.db';

const db = new Database(DATABASE_PATH);

// Apply PRAGMAs
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');
db.pragma('synchronous = NORMAL');
db.pragma('cache_size = -64000');
db.pragma('temp_store = MEMORY');

/**
 * Initialize database with schema from init.sql
 */
function initDb() {
  const initSql = fs.readFileSync(path.join(__dirname, 'init.sql'), 'utf-8');
  db.exec(initSql);
}

/**
 * Close database connection (call on shutdown)
 */
function close() {
  db.close();
}

module.exports = { db, initDb, close };
```

**Go** (detected via `go.mod`):

Generate connection helper using `github.com/mattn/go-sqlite3` or `modernc.org/sqlite`.

#### Step 4: Generate .gitignore Entries

Check if `.gitignore` exists and includes SQLite database files:

```gitignore
# SQLite database files
*.db
*.db-wal
*.db-shm
*.sqlite
*.sqlite-wal
*.sqlite-shm
```

If `.gitignore` exists but doesn't include these patterns, add them. If `.gitignore` doesn't exist,
create it with these entries.

#### Step 5: Recommend Conventions Document

If the project has a `docs/` directory, offer to create `docs/db/sqlite-conventions.md`:

```text
Scaffold recommends creating a conventions document at:
  docs/db/sqlite-conventions.md

This documents your project's SQLite conventions including PRAGMA configuration,
naming conventions, type affinity choices, and migration strategy.

Create conventions document? [Y/n]
```

If no `docs/` directory exists, note it in the output and skip:

```text
NOTE: No docs/ directory found. Skipping conventions document creation.
      Consider creating docs/db/sqlite-conventions.md when your project
      establishes a documentation structure.
```

### migration-dir

Generate a migration directory structure.

#### Step 1: Detect Migration Tool

Scan the project for existing migration tools:

1. **golang-migrate**: `migrations/` directory with `*.up.sql`/`*.down.sql` pattern, or `migrate.go`
   in source
2. **Alembic**: `alembic.ini` or `alembic/` directory
3. **Application-specific**: Check for common patterns in the codebase (e.g., a custom `migrate.py`
   or `migrations/` directory)

If a tool is detected, scaffold according to that tool's conventions.

#### Step 2: Generate Migration Directory

If no migration tool is detected, create a tool-agnostic numbered SQL directory:

```text
migrations/
├── 001_initial_schema.up.sql
├── 001_initial_schema.down.sql
└── README.md
```

**001_initial_schema.up.sql**:

```sql
-- Migration 001: Initial Schema
-- Created: YYYY-MM-DD
--
-- This migration creates the initial database schema.
-- PRAGMAs should be applied by the application at connection time,
-- not in migrations (except journal_mode which is per-database).

-- Ensure WAL mode is set (idempotent)
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TRIGGER IF NOT EXISTS users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    UPDATE users SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE id = old.id;
END;
```

**001_initial_schema.down.sql**:

```sql
-- Migration 001: Rollback Initial Schema
-- WARNING: This drops all tables and data. Use with caution.

DROP TRIGGER IF EXISTS users_updated_at;
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
```

**README.md**:

```markdown
# Database Migrations

## Naming Convention

Migrations use sequential numbering with descriptive names:

    NNN_description.up.sql   - Forward migration
    NNN_description.down.sql - Rollback migration

Examples:

    001_initial_schema.up.sql
    002_add_user_roles.up.sql
    003_create_orders_table.up.sql

## Running Migrations

### Manual

Apply all pending migrations in order:

    for f in migrations/*.up.sql; do sqlite3 app.db < "$f"; done

### With golang-migrate

    migrate -path migrations -database "sqlite3://app.db" up

### In Application Code

Apply migrations at application startup using PRAGMA user_version to track the current schema
version.

## Migration Rules

1. **One logical change per migration**: Don't mix table creation with data changes.
2. **Idempotent operations**: Use IF NOT EXISTS / IF EXISTS where possible.
3. **Always provide down migration**: Even if irreversible, document what would need to happen to
   roll back.
4. **STRICT tables**: Use STRICT modifier on all new tables (SQLite 3.37+).
5. **Test migrations**: Test on a copy of production data, not just empty databases.
6. **No PRAGMA in migrations**: PRAGMAs should be set at connection time by the application, not in
   migrations. Exception: journal_mode (per-database).
```

#### Step 3: Generate Migration Runner (Optional)

If no migration tool is detected, offer a simple migration runner:

**Python**:

```python
# db/migrate.py
"""Simple SQLite migration runner using PRAGMA user_version."""
import sqlite3
import glob
import os
import sys


def migrate(db_path, migrations_dir="migrations"):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")

    current = conn.execute("PRAGMA user_version").fetchone()[0]
    print(f"Current schema version: {current}")

    migrations = sorted(glob.glob(os.path.join(migrations_dir, "*.up.sql")))

    for path in migrations:
        version = int(os.path.basename(path).split("_")[0])
        if version <= current:
            continue

        print(f"Applying migration {version}: {os.path.basename(path)}")
        with open(path) as f:
            conn.executescript(f.read())
        conn.execute(f"PRAGMA user_version = {version}")
        conn.commit()

    final = conn.execute("PRAGMA user_version").fetchone()[0]
    print(f"Schema version after migration: {final}")
    conn.close()


if __name__ == "__main__":
    db = sys.argv[1] if len(sys.argv) > 1 else "app.db"
    migrate(db)
```

## Output Format

### Successful Scaffold

```text
SQLite Scaffold (init-script)
==============================

Created:
  db/init.sql                    PRAGMA configuration + schema template
  db/connection.py               Python connection helper (detected Python project)

Updated:
  .gitignore                     Added *.db, *.db-wal, *.db-shm patterns

Notes:
  - Edit db/init.sql to define your actual schema
  - Set DATABASE_PATH environment variable for non-default paths
  - Run: sqlite3 app.db < db/init.sql

Recommendations:
  - Create docs/db/sqlite-conventions.md for team conventions
  - Review PRAGMA configuration for your specific workload
```

### Existing Project Detection

```text
SQLite Scaffold (init-script)
==============================

Detected:
  Existing schema at db/schema.sql
  Existing init script at db/setup.sql
  Python project with sqlite3 usage

Action:
  SKIPPED  db/init.sql — existing init script found at db/setup.sql
  Created  db/connection.py — connection helper (no existing helper found)

Updated:
  .gitignore                     Added *.db-wal, *.db-shm patterns (*.db already present)

Notes:
  - Review db/connection.py and integrate with your existing setup
  - Existing PRAGMA configuration in db/setup.sql was preserved
```

## Key Rules

1. **Migration tool detection is best-effort**: Never prescribe a specific migration tool. If the
   project uses a tool, scaffold within that tool's conventions.
2. **Init scripts always include the PRAGMA block**: The recommended PRAGMA configuration is
   included in every init script, with comments explaining each setting.
3. **STRICT tables where supported**: All generated table definitions use the STRICT modifier with a
   comment noting the SQLite 3.37+ requirement.
4. **IF NOT EXISTS for idempotency**: All CREATE TABLE, CREATE INDEX, and CREATE TRIGGER statements
   use IF NOT EXISTS / IF EXISTS for safe re-execution.
5. **Never generate real credentials**: All configuration uses placeholder values.
6. **Respect existing setup**: If migration directories or init scripts already exist, don't
   overwrite them. Report what was found and what was created.
7. **.gitignore safety**: Always ensure `.db`, `.db-wal`, and `.db-shm` files are in `.gitignore` to
   prevent accidentally committing database files.
8. **Conventions document**: Recommend creating `docs/db/sqlite-conventions.md` if a `docs/`
   directory exists. Skip if no `docs/` structure exists — never create directory structures beyond
   the immediate need.
