# Plugin: ccfg-sqlite

The SQLite data plugin. Provides schema design and embedded application agents, schema validation,
database initialization scaffolding, and opinionated conventions for consistent SQLite development.
Focuses on WAL mode, PRAGMA configuration, embedded application patterns, and concurrent access
strategies. Intentionally leaner than other data plugins — SQLite lacks replication, sharding, and
complex DBA concerns, but has unique embedded-specific considerations.

## Directory Structure

```text
plugins/ccfg-sqlite/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── sqlite-specialist.md
│   └── embedded-engineer.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
├── skills/
│   ├── sqlite-conventions/
│   │   └── SKILL.md
│   └── embedded-patterns/
│       └── SKILL.md
└── .mcp.json
```

## plugin.json

```json
{
  "name": "ccfg-sqlite",
  "description": "SQLite data plugin: schema design and embedded application agents, schema validation, database initialization scaffolding, and conventions for consistent SQLite development with WAL mode and PRAGMA tuning",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["sqlite", "sql", "embedded", "wal", "pragma", "turso", "libsql"]
}
```

## MCP Configuration

`.mcp.json` — provides direct SQLite database access for schema inspection and query testing:

```json
{
  "mcpServers": {
    "sqlite-mcp": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-sqlite"]
    }
  }
}
```

The sqlite-mcp server is **disabled by default**. It must be explicitly enabled by the user before
the plugin will open or inspect any `.db` file. Scaffold does not activate MCP automatically — the
user must opt in by uncommenting or adding the configuration.

## Agents (2)

| Agent               | Role                                                                   | Model  |
| ------------------- | ---------------------------------------------------------------------- | ------ |
| `sqlite-specialist` | SQLite 3.40+, WAL mode, JSON functions, FTS5, schema design, PRAGMAs   | sonnet |
| `embedded-engineer` | SQLite in apps (mobile, desktop, serverless), libSQL/Turso, concurrent | sonnet |
|                     | access patterns, connection management                                 |        |

No coverage command — coverage is a code concept, not a database concept. This is intentional and
differs from language plugins.

## Commands (2)

### /ccfg-sqlite:validate

**Purpose**: Run the full SQLite schema quality gate suite in one command.

**Trigger**: User invokes before shipping schema changes or reviewing database design.

**Allowed tools**: `Bash(sqlite3 *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Schema naming**: Verify snake_case table and column names, no names matching the high-risk
   reserved word subset (a curated in-repo keyword list of ~50-100 commonly-conflicting terms, not a
   claim of complete coverage)
2. **PRAGMA checks**: Verify WAL mode is configured (`journal_mode=wal`), foreign keys enforcement
   is on (`foreign_keys=ON`), appropriate page size for workload, `busy_timeout` is set for
   concurrent access. WARN if database paths appear to reference network filesystem mounts (NFS,
   SMB, CIFS) — WAL mode is unreliable on network filesystems. Best-effort detection via path
   heuristics (e.g., `/mnt/`, `/Volumes/`, UNC paths); document this risk prominently in output even
   when not detected
3. **Antipattern detection**: Missing `WITHOUT ROWID` on small lookup/mapping tables where the
   primary key is the only access pattern, non-ISO-8601 date storage (SQLite has no native date type
   — text in ISO-8601 format is canonical), `AUTOINCREMENT` where plain `INTEGER PRIMARY KEY`
   suffices (AUTOINCREMENT prevents rowid reuse but adds overhead), missing `STRICT` table modifier
   (SQLite 3.37+) where type safety matters
4. Report pass/fail for each gate with output
5. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Schema naming**: Same as full mode (reserved words use high-risk subset only)
2. Report pass/fail — skips PRAGMA checks and antipattern detection for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — schema files, migration files, and init scripts. Does not
  open or inspect `.db` files by default. Inspecting a `.db` file requires the `--db <path>` flag
  and explicit user confirmation. Never connects to a live database without confirmation
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available, skip that gate and report it as
  SKIPPED
- Checks for presence of conventions document (`docs/db/sqlite-conventions.md` or similar). Reports
  SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-sqlite:scaffold

**Purpose**: Initialize database initialization scripts and migration setup for SQLite projects.

**Trigger**: User invokes when setting up SQLite in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=init-script|migration-dir]`

**Behavior**:

**init-script** (default):

1. Create database initialization SQL with recommended PRAGMAs:

   ```sql
   -- Database initialization
   PRAGMA journal_mode = WAL;
   PRAGMA foreign_keys = ON;
   PRAGMA busy_timeout = 5000;
   PRAGMA journal_size_limit = 67108864;  -- 64MB
   PRAGMA synchronous = NORMAL;           -- Safe with WAL mode
   PRAGMA cache_size = -64000;            -- 64MB cache
   PRAGMA temp_store = MEMORY;
   ```

2. Include schema creation statements with appropriate type affinities
3. Include seed data for development
4. Wrap schema creation in `IF NOT EXISTS` for idempotent execution

**migration-dir**:

1. Detect project's migration approach from project files:
   - golang-migrate: `migrations/` with `*.up.sql`/`*.down.sql`
   - Alembic: `alembic.ini` or `alembic/` directory
   - Application-specific: check for common patterns in the codebase
2. If detected, scaffold according to that tool's conventions
3. If no tool detected, create tool-agnostic numbered SQL directory:

   ```text
   migrations/
   ├── 001_initial_schema.up.sql
   ├── 001_initial_schema.down.sql
   └── README.md
   ```

4. Include a README.md explaining migration conventions

**Key rules**:

- Migration tool detection is best-effort — never prescribe a tool
- Init scripts always include the recommended PRAGMA block
- Schema uses `STRICT` table modifier where supported (SQLite 3.37+)
- Uses `IF NOT EXISTS` / `IF EXISTS` for idempotent operations
- Scaffold recommends creating a conventions document at `docs/db/sqlite-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (2)

### sqlite-conventions

**Trigger description**: "This skill should be used when working on SQLite databases, writing SQL
schemas, configuring PRAGMAs, using FTS5, or designing embedded database schemas."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project doesn't use WAL mode, understand why before changing it (some embedded platforms have
constraints). If the project uses a specific PRAGMA configuration, follow it. These preferences
apply to new databases and scaffold output only.

**PRAGMA rules**:

- Always enable WAL mode (`PRAGMA journal_mode = WAL`) for concurrent read/write access. WAL allows
  multiple readers during writes. Only exception: if the database is on a network filesystem (WAL
  requires shared memory)
- Always enable foreign keys (`PRAGMA foreign_keys = ON`) — SQLite defaults to OFF for backwards
  compatibility
- Set `busy_timeout` (e.g., 5000ms) to handle concurrent access gracefully instead of immediate
  `SQLITE_BUSY` errors
- Set `synchronous = NORMAL` when using WAL mode (FULL is only needed for DELETE journal mode)
- Set `journal_size_limit` to prevent WAL file from growing unbounded (64MB is a reasonable default)
- Set `cache_size` based on available memory (`-N` for N KB, positive for N pages)
- PRAGMAs must be set per-connection — they are not persisted (except `journal_mode` and `page_size`
  which are per-database)

**Type affinity rules**:

- SQLite uses type affinity, not strict types. The five affinities: TEXT, NUMERIC, INTEGER, REAL,
  BLOB
- Use `STRICT` tables (SQLite 3.37+) when type safety matters — strict tables enforce declared types
- Store dates as TEXT in ISO-8601 format (`YYYY-MM-DD HH:MM:SS.SSS`) — use SQLite date functions for
  queries
- Store booleans as INTEGER (0/1) — SQLite has no native boolean type
- Store UUIDs as TEXT (lowercase, with hyphens) or BLOB (16 bytes) — TEXT is more debuggable, BLOB
  is more compact
- Use `INTEGER PRIMARY KEY` for auto-incrementing rowid alias. Avoid `AUTOINCREMENT` unless you
  specifically need to prevent rowid reuse (adds overhead and a tracking table)

**Feature rules**:

- Use JSON functions (`json()`, `json_extract()`, `json_each()`) for semi-structured data (SQLite
  3.38+)
- Use FTS5 for full-text search — create FTS tables with `CREATE VIRTUAL TABLE ... USING fts5(...)`
- Use `WITHOUT ROWID` for small lookup/mapping tables where the primary key is the only access
  pattern (saves storage overhead of separate rowid)
- Use `INSERT ... ON CONFLICT` (UPSERT) for idempotent inserts (SQLite 3.24+)
- Use window functions for analytics queries (SQLite 3.25+)
- Use `RETURNING` clause for getting inserted/updated rows (SQLite 3.35+)

**Connection management rules**:

- One writer at a time (WAL mode allows concurrent reads during writes)
- Use a connection pool: 1 writer connection + N reader connections
- Set `busy_timeout` on all connections
- Close connections properly — SQLite file locks are per-process, leaked connections cause
  `SQLITE_BUSY`

### embedded-patterns

**Trigger description**: "This skill should be used when embedding SQLite in applications, managing
concurrent access, implementing backup strategies, or using libSQL/Turso."

**Contents**:

- **Connection management**: Use a connection pool pattern: one dedicated write connection, multiple
  read connections. In WAL mode, readers don't block writers and writers don't block readers. Set
  `busy_timeout` on all connections to handle contention gracefully. Close all connections on
  application shutdown
- **Concurrent access**: WAL mode is essential for concurrent access. Without WAL, only one
  connection can write and readers are blocked during writes. With WAL + `busy_timeout`, concurrent
  access is well-handled for most workloads. For very high write concurrency, consider batching
  writes through a single writer goroutine/thread
- **Backup strategies**: Use the SQLite Online Backup API for hot backups (copies database while
  it's in use). For simpler cases, `VACUUM INTO 'backup.db'` creates a compacted copy. For periodic
  backups, checkpoint the WAL first (`PRAGMA wal_checkpoint(TRUNCATE)`) then copy the database file
  (no WAL/SHM files needed after truncate checkpoint)
- **Migration in embedded contexts**: Apply migrations at application startup. Use a
  `schema_version` PRAGMA or a migrations table to track applied migrations. Keep migrations
  idempotent (`IF NOT EXISTS`). Roll forward, not back — embedded systems rarely need down
  migrations
- **Turso/libSQL**: libSQL is a fork of SQLite with added features: multi-tenant support, HTTP API,
  replication. Turso provides managed libSQL with edge replication. Connection patterns are similar
  but use libSQL-specific client libraries. Embedded replicas allow local reads with remote writes
- **In-memory test databases**: Use `:memory:` or `file::memory:?cache=shared` for test databases.
  Apply the same migrations and PRAGMAs as production. Shared cache allows multiple connections to
  the same in-memory database (useful for testing concurrent access patterns)
- **File locking considerations**: SQLite uses file-system locks. Don't use SQLite on network
  filesystems (NFS, SMB) — locking is unreliable. On Docker volumes, ensure proper file permissions.
  On mobile (iOS/Android), use the app's sandboxed storage directory
