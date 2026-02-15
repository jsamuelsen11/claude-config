# Plugin: ccfg-postgresql

The PostgreSQL data plugin. Provides DBA, query optimization, replication, and extension agents,
schema validation, migration scaffolding, and opinionated conventions for consistent PostgreSQL
development. Focuses on schema design, indexing strategies, migration patterns, and performance
tuning. Safety is paramount — never connects to production databases without explicit user
confirmation.

## Directory Structure

```text
plugins/ccfg-postgresql/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── postgres-dba.md
│   ├── query-optimizer.md
│   ├── replication-specialist.md
│   └── extension-developer.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── postgres-conventions/
    │   └── SKILL.md
    ├── migration-patterns/
    │   └── SKILL.md
    └── performance-tuning/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-postgresql",
  "description": "PostgreSQL data plugin: DBA, query optimization, replication, and extension agents, schema validation, migration scaffolding, and conventions for consistent PostgreSQL development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["postgresql", "postgres", "sql", "schema", "migration", "indexing", "replication"],
  "suggestedPermissions": {
    "allow": []
  }
}
```

## Agents (4)

| Agent                    | Role                                                                   | Model  |
| ------------------------ | ---------------------------------------------------------------------- | ------ |
| `postgres-dba`           | PostgreSQL 15+, schema design, indexing, partitioning, VACUUM, pg_stat | sonnet |
| `query-optimizer`        | EXPLAIN ANALYZE, index selection, query rewriting, CTE optimization    | sonnet |
| `replication-specialist` | Streaming replication, logical replication, pgBouncer, HA (Patroni)    | sonnet |
| `extension-developer`    | pg extensions (PostGIS, pgvector, pg_trgm, TimescaleDB), custom types  | sonnet |

No coverage command — coverage is a code concept, not a database concept. This is intentional and
differs from language plugins.

## Commands (2)

### /ccfg-postgresql:validate

**Purpose**: Run the full PostgreSQL schema quality gate suite in one command.

**Trigger**: User invokes before applying migrations or reviewing schema changes.

**Allowed tools**: `Bash(psql *), Bash(pg_dump *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Schema naming**: Verify snake*case table and column names, no names matching the high-risk
   reserved word subset (a curated in-repo keyword list of ~50-100 commonly-conflicting terms, not a
   claim of complete coverage), plural tables configurable, constraint naming prefixes
   (`fk*`, `idx*`, `chk*`, `uq\_`)
2. **Index coverage**: Flag foreign keys without indexes, unindexed columns used in WHERE/JOIN
   clauses in migration files or schema dumps
3. **Antipattern detection**: `SELECT *` in views, missing primary keys, Entity-Attribute-Value
   patterns, polymorphic associations, `serial` instead of `identity`, `timestamp` instead of
   `timestamptz`
4. **Migration hygiene**: Irreversible operations without guards, missing down migrations, mixed
   data+schema migrations, migrations that hold locks too long. Flag `CREATE INDEX CONCURRENTLY`
   inside explicit `BEGIN`/`COMMIT` transaction blocks — concurrent index creation cannot run inside
   a transaction and will fail
5. **Extension hygiene**: If migrations enable extensions (`CREATE EXTENSION`), verify extensions
   are documented and gated (conditional on environment or behind `IF NOT EXISTS`). Flag extensions
   enabled in migrations but not documented in conventions/README
6. Report pass/fail for each gate with output
7. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Schema naming**: Same as full mode
2. **Basic schema checks**: Reserved words (high-risk subset only), missing PKs
3. Report pass/fail — skips index coverage, antipattern detection, migration hygiene, and extension
   hygiene for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — schema files, migration files, and SQL dumps. Does not
  connect to a live database by default. Live DB validation requires the `--live` flag and explicit
  user confirmation before any connection is established
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available (e.g., no migration directory
  found), skip that gate and report it as SKIPPED
- Checks for presence of conventions document (`docs/db/postgresql-conventions.md` or similar).
  Reports SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-postgresql:scaffold

**Purpose**: Initialize migration directory structure and connection configuration for PostgreSQL
projects.

**Trigger**: User invokes when setting up PostgreSQL in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=migration-dir|connection-config]`

**Behavior**:

**migration-dir** (default):

1. Detect project's migration tool from project files:
   - Flyway: `flyway.conf` or `sql/` directory with `V*.sql` pattern
   - Alembic: `alembic.ini` or `alembic/` directory
   - golang-migrate: `migrate.go` or `migrations/` with `*.up.sql`/`*.down.sql`
   - dbmate: `db/migrations/` directory
   - Prisma: `prisma/schema.prisma`
   - Knex/TypeORM/Sequelize: check package.json dependencies
2. If detected, scaffold according to that tool's conventions
3. If no tool detected, create tool-agnostic numbered SQL directory:

   ```text
   migrations/
   ├── 001_initial_schema.up.sql
   ├── 001_initial_schema.down.sql
   └── README.md
   ```

4. Include a README.md in the migration directory explaining naming conventions and running
   migrations

**connection-config**:

1. Create `.env.example` with:

   ```text
   DATABASE_URL=postgresql://user:password@localhost:5432/dbname
   DATABASE_POOL_SIZE=10
   DATABASE_POOL_TIMEOUT=30
   ```

2. Add connection pool configuration snippet appropriate to detected framework/language
3. Ensure `.env` is in `.gitignore` (add entry if missing)

**Key rules**:

- Migration tool detection is best-effort — never prescribe a tool, respect what the project already
  uses
- Never generates actual database credentials in config files — always placeholder values
- `.env.example` uses generic placeholder values, never real credentials
- If inside a git repo, verify `.gitignore` includes `.env`
- Scaffold recommends creating a conventions document at `docs/db/postgresql-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (3)

### postgres-conventions

**Trigger description**: "This skill should be used when working on PostgreSQL databases, writing
SQL schemas, creating tables, designing database architecture, or reviewing PostgreSQL code."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses `serial` instead of `identity`, follow the existing pattern. If the project uses
singular table names, follow that convention. If the project uses a specific migration tool, work
within that tool's patterns. These preferences apply to new schemas and scaffold output only.

**Schema design rules**:

- Use `snake_case` for all identifiers (tables, columns, indexes, constraints)
- Use `timestamptz` over `timestamp` — always store timezone-aware timestamps
- Use `identity` columns over `serial`/`bigserial` (PostgreSQL 10+ standard)
- Use `uuid` primary keys where appropriate (especially for distributed systems or public-facing
  IDs)
- Use `text` over `varchar(n)` unless there's a genuine max-length constraint (PostgreSQL `text` has
  no performance penalty over `varchar`)
- Constraint naming prefixes: `fk_` for foreign keys, `idx_` for indexes, `chk_` for check
  constraints, `uq_` for unique constraints
- Use `NOT NULL` by default — nullable columns should be the exception with documented reason
- Use `CHECK` constraints for domain validation over application-level checks where practical

**Data type rules**:

- Money: `numeric(precision, scale)` or integer cents, never `money` type or `float`
- Booleans: Use `boolean`, not integers or chars
- Enums: Default to `text` with `CHECK` constraints for value sets that evolve frequently (CHECK
  constraints are easy to modify). `ENUM` types are acceptable when the value set is stable and type
  safety at the database level is desired. Avoid absolutism — the tradeoff is flexibility vs type
  enforcement
- JSON: Use `jsonb` over `json` (indexable, more efficient). Use typed columns where structure is
  known
- Arrays: Use sparingly — prefer junction tables for many-to-many. Arrays are appropriate for tags,
  small fixed lists
- IP addresses: Use `inet`/`cidr` types, not `text`
- Date ranges: Use range types (`daterange`, `tstzrange`) with exclusion constraints

**Index rules**:

- Every foreign key column must have an index
- Create indexes for columns used in WHERE, JOIN, and ORDER BY clauses
- Use partial indexes for filtered queries (`WHERE status = 'active'`)
- Use GIN indexes for `jsonb`, array, and full-text search columns
- Use GiST indexes for geometric, range, and PostGIS data
- Use BRIN indexes for naturally ordered data (timestamps, sequential IDs in append-only tables)
- Avoid over-indexing — each index adds write overhead. Profile before adding

### migration-patterns

**Trigger description**: "This skill should be used when writing database migrations, altering
tables, adding columns, creating indexes, or planning schema changes for PostgreSQL."

**Contents**:

- **Up/down pairs**: Every migration must have a reversible down migration. If a migration is
  genuinely irreversible (dropping a column with data), document it clearly and add a guard comment
- **Zero-downtime changes**: Follow the expand-contract pattern:
  1. Add new nullable column
  2. Backfill data (separate migration)
  3. Add NOT NULL constraint (separate migration)
  4. Remove old column (separate migration, after application code updated)
- **Lock-safe operations**: Use `CREATE INDEX CONCURRENTLY` (not inside a transaction). Use
  `ALTER TABLE ... ADD COLUMN` with defaults (PostgreSQL 11+ doesn't rewrite table for non-volatile
  defaults). Avoid `ALTER TABLE ... ALTER COLUMN TYPE` on large tables without planning
- **Migration ordering**: Number-prefixed (timestamp or sequential), one logical change per
  migration. Never mix schema changes with data migrations in the same file
- **Tool-agnostic principles**: These patterns apply regardless of migration tool (Alembic, Flyway,
  golang-migrate, etc.). The tool manages ordering and execution; the principles manage safety
- **Guard clauses**: Use `IF NOT EXISTS` / `IF EXISTS` for idempotent migrations. Check column
  existence before adding. This prevents failures on re-run and partial application
- **Large table operations**: For tables over ~1M rows, use batched backfills, `pg_repack` for table
  rewrites, and `CREATE INDEX CONCURRENTLY` for indexes. Never hold `ACCESS EXCLUSIVE` locks on
  large tables during business hours

### performance-tuning

**Trigger description**: "This skill should be used when analyzing PostgreSQL query performance,
running EXPLAIN ANALYZE, tuning indexes, configuring connection pooling, or optimizing database
performance."

**Contents**:

- **EXPLAIN ANALYZE**: Always use `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` for readable output. Key
  metrics: actual time, rows vs estimated rows, buffer hits vs reads. Look for sequential scans on
  large tables, nested loops with high row counts, sort operations spilling to disk
- **Index types**: B-tree (default, equality and range), GIN (arrays, jsonb, full-text), GiST
  (geometric, range types, nearest-neighbor), BRIN (large naturally-ordered tables), Hash
  (equality-only, rarely useful over B-tree)
- **Partitioning**: Use declarative partitioning (PostgreSQL 10+). Partition by range (time-series),
  list (tenant ID), or hash (even distribution). Partition pruning requires the partition key in
  WHERE clauses. Don't partition tables under ~10M rows
- **Connection pooling**: Use pgBouncer or application-level pooling. Transaction mode for stateless
  queries, session mode when using prepared statements or temp tables. Size pool to:
  `(2 * CPU cores) + effective_spindle_count` as starting point
- **VACUUM tuning**: Monitor `pg_stat_user_tables.n_dead_tup`. Tune `autovacuum_vacuum_scale_factor`
  for large tables (default 20% is too high). Use `VACUUM (VERBOSE)` to diagnose. Never disable
  autovacuum
- **pg_stat views**: `pg_stat_user_tables` for table I/O, `pg_stat_user_indexes` for index usage,
  `pg_stat_activity` for active queries, `pg_stat_statements` for query patterns (top queries by
  total_time). These views are the primary diagnostic tools
- **Common wins**: Enable `pg_stat_statements` extension. Set `random_page_cost = 1.1` for SSD
  storage. Increase `effective_cache_size` to ~75% of RAM. Set `work_mem` appropriately for
  sort/hash operations (start at 4MB, increase for analytics workloads). Use
  `shared_preload_libraries` for extensions that need it
