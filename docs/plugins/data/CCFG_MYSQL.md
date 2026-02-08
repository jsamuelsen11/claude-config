# Plugin: ccfg-mysql

The MySQL data plugin. Provides DBA, query optimization, and replication agents, schema validation,
migration scaffolding, and opinionated conventions for consistent MySQL development. Focuses on
InnoDB optimization, character set best practices, migration patterns, and performance tuning.
Safety is paramount — never connects to production databases without explicit user confirmation.

## Directory Structure

```text
plugins/ccfg-mysql/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── mysql-dba.md
│   ├── query-optimizer.md
│   └── replication-specialist.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── mysql-conventions/
    │   └── SKILL.md
    ├── migration-patterns/
    │   └── SKILL.md
    └── performance-tuning/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-mysql",
  "description": "MySQL data plugin: DBA, query optimization, and replication agents, schema validation, migration scaffolding, and conventions for consistent MySQL development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["mysql", "sql", "innodb", "schema", "migration", "replication"]
}
```

## Agents (3)

| Agent                    | Role                                                                 | Model  |
| ------------------------ | -------------------------------------------------------------------- | ------ |
| `mysql-dba`              | MySQL 8.0+, schema design, InnoDB optimization, character sets, JSON | sonnet |
| `query-optimizer`        | EXPLAIN, index selection, query rewriting, optimizer hints, slow log | sonnet |
| `replication-specialist` | Source-replica, Group Replication, InnoDB Cluster, ProxySQL, GTIDs   | sonnet |

No coverage command — coverage is a code concept, not a database concept. This is intentional and
differs from language plugins.

## Commands (2)

### /ccfg-mysql:validate

**Purpose**: Run the full MySQL schema quality gate suite in one command.

**Trigger**: User invokes before applying migrations or reviewing schema changes.

**Allowed tools**: `Bash(mysql *), Bash(mysqldump *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Schema naming**: Verify snake_case table and column names, no names matching the high-risk
   reserved word subset (a curated in-repo keyword list of ~50-100 commonly-conflicting terms, not a
   claim of complete coverage)
2. **Engine/charset check**: Flag non-InnoDB tables, non-utf8mb4 character set,
   non-utf8mb4_0900_ai_ci collation
3. **Antipattern detection**: Missing primary keys, `ENUM` for mutable values, `FLOAT`/`DOUBLE` for
   money, `TEXT`/`BLOB` columns in frequently filtered queries, implicit conversions in WHERE
   clauses
4. **Migration hygiene**: Irreversible operations without guards, missing down migrations, mixed
   data+schema migrations, operations that lock tables for extended periods
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Schema naming**: Same as full mode (reserved words use high-risk subset only)
2. **Engine/charset check**: Same as full mode
3. Report pass/fail — skips antipattern detection and migration hygiene for speed

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
- Checks for presence of conventions document (`docs/db/mysql-conventions.md` or similar). Reports
  SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-mysql:scaffold

**Purpose**: Initialize migration directory structure and connection configuration for MySQL
projects.

**Trigger**: User invokes when setting up MySQL in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=migration-dir|connection-config]`

**Behavior**:

**migration-dir** (default):

1. Detect project's migration tool from project files:
   - Flyway: `flyway.conf` or `sql/` directory with `V*.sql` pattern
   - Liquibase: `liquibase.properties` or `changelog-master.xml`
   - golang-migrate: `migrate.go` or `migrations/` with `*.up.sql`/`*.down.sql`
   - Prisma: `prisma/schema.prisma`
   - Knex: check package.json for `knex` dependency
   - Sequelize: check package.json for `sequelize` dependency
   - TypeORM: check package.json for `typeorm` dependency
2. If detected, scaffold according to that tool's conventions
3. If no tool detected, create tool-agnostic numbered SQL directory:

   ```text
   migrations/
   ├── 001_initial_schema.up.sql
   ├── 001_initial_schema.down.sql
   └── README.md
   ```

4. Include a README.md in the migration directory explaining naming conventions

**connection-config**:

1. Create `.env.example` with:

   ```text
   DATABASE_URL=mysql://user:password@localhost:3306/dbname
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
- Scaffold recommends creating a conventions document at `docs/db/mysql-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (3)

### mysql-conventions

**Trigger description**: "This skill should be used when working on MySQL databases, writing SQL
schemas, creating tables, designing database architecture, or reviewing MySQL code."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses MyISAM tables, don't blindly convert to InnoDB without understanding the reason. If the
project uses latin1 charset, flag it but don't change without coordination. These preferences apply
to new schemas and scaffold output only.

**Engine and charset rules**:

- Always use InnoDB engine — never MyISAM for new tables (InnoDB provides transactions, row-level
  locking, crash recovery)
- Always use `utf8mb4` character set with `utf8mb4_0900_ai_ci` collation (MySQL 8.0+). Never use
  `utf8` (only 3-byte, can't store emoji/CJK supplementary)
- Set at table level: `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci`

**Schema design rules**:

- Use `snake_case` for all identifiers
- Use `BIGINT UNSIGNED AUTO_INCREMENT` for primary keys, or `BINARY(16)` for UUID (stored as binary,
  not char(36))
- Prefer `TIMESTAMP` for point-in-time values (4 bytes, UTC-normalized); prefer `DATETIME` for
  calendar concepts that shouldn't shift with timezone. Neither is universally correct — choose
  based on whether the value represents a point-in-time (TIMESTAMP) or a calendar concept
  (DATETIME). TIMESTAMP has a 2038 upper limit, which may matter for future dates
- Use `DECIMAL(precision, scale)` for money, never `FLOAT` or `DOUBLE` (IEEE 754 rounding errors)
- Use `JSON` column type for semi-structured data with generated columns for frequently queried
  paths
- For frequently queried JSON paths, prefer generated columns with indexes over repeated
  `JSON_EXTRACT()` in queries — this avoids per-row function evaluation and enables index-backed
  lookups
- Avoid `ENUM` for values that may change — use a lookup/reference table instead. `ENUM` changes
  require `ALTER TABLE`
- Use `TINYINT(1)` for booleans (MySQL convention, same as `BOOL`/`BOOLEAN`)
- Always define `NOT NULL` with a `DEFAULT` value unless nullable is intentional and documented
- Use generated (virtual) columns for computed values:
  `ALTER TABLE ADD total_price DECIMAL(10,2) GENERATED ALWAYS AS (qty * unit_price)`

**Index rules**:

- Every foreign key must have an index (InnoDB requires this for FK constraints)
- Use composite indexes following leftmost prefix rule — column order matters
- Use `FULLTEXT` indexes for text search (InnoDB supports FULLTEXT in MySQL 5.6+)
- Avoid redundant indexes (a composite index on `(a, b)` already covers queries on `a` alone)
- Use index hints (`FORCE INDEX`, `USE INDEX`) as last resort — prefer query restructuring

**Window function and CTE rules**:

- Use CTEs (`WITH`) for readable multi-step queries (MySQL 8.0+)
- Use window functions (`ROW_NUMBER()`, `RANK()`, `LAG()`, `LEAD()`) over self-joins and subqueries
  for ranking and sequential analysis
- Avoid stored procedures for application logic — keep business logic in the application layer

### migration-patterns

**Trigger description**: "This skill should be used when writing database migrations, altering
tables, adding columns, creating indexes, or planning schema changes for MySQL."

**Contents**:

- **Up/down pairs**: Every migration must have a reversible down migration. Document irreversible
  migrations clearly
- **Online DDL**: Use `ALGORITHM=INPLACE` or `ALGORITHM=INSTANT` (MySQL 8.0.12+) for non-blocking
  DDL where supported. Adding a column with a default is INSTANT in MySQL 8.0.12+. Adding an index
  uses INPLACE by default
- **Large table changes**: For tables over ~1M rows, recommend `pt-online-schema-change` (Percona
  Toolkit) or `gh-ost` (GitHub Online Schema Change) to avoid long-running locks. These tools create
  a shadow table, copy data, and swap atomically. If neither tool is available, validate reports
  WARN (not hard fail) unless the user explicitly indicates a production migration context
- **Foreign key considerations**: Adding FKs requires a full table scan for validation. On large
  tables, consider adding the FK with `SET FOREIGN_KEY_CHECKS=0` during migration (with care) or
  validating in the application layer
- **Migration ordering**: Timestamp or sequential prefixed, one logical change per migration. Never
  mix schema changes with data migrations
- **Guard clauses**: MySQL doesn't support `IF NOT EXISTS` for all DDL. Use conditional checks in
  migration code or rely on migration tool's idempotency features
- **Zero-downtime pattern**: Same expand-contract as PostgreSQL: add nullable column → backfill →
  add constraint → remove old column. Each step in a separate migration
- **Character set migrations**: Changing character set on existing tables requires table rebuild.
  Use `ALTER TABLE ... CONVERT TO CHARACTER SET utf8mb4` during maintenance windows for large tables

### performance-tuning

**Trigger description**: "This skill should be used when analyzing MySQL query performance, running
EXPLAIN, tuning indexes, configuring the buffer pool, or optimizing database performance."

**Contents**:

- **EXPLAIN**: Use `EXPLAIN FORMAT=TREE` (MySQL 8.0.18+) or `EXPLAIN FORMAT=JSON` for detailed
  execution plans. Key metrics: rows examined, filtered percentage, access type (const > eq_ref >
  ref > range > index > ALL). Look for full table scans (type=ALL), filesort, temporary tables
- **Index types**: B-tree (default, equality and range), FULLTEXT (text search), Spatial (GIS data),
  Hash (MEMORY engine only). InnoDB uses clustered index on PK — secondary index lookups require
  double lookup (index → PK → row)
- **Buffer pool tuning**: Set `innodb_buffer_pool_size` to 70-80% of available RAM on dedicated
  servers. Use `innodb_buffer_pool_instances` (multiple instances reduce contention, set to 8
  for >1GB pool). Monitor `SHOW ENGINE INNODB STATUS` buffer pool hit rate
- **Slow query log**: Enable `slow_query_log` with `long_query_time=1` (seconds). Use
  `mysqldumpslow` or `pt-query-digest` to analyze. Look for queries with high `Lock_time`,
  `Rows_examined >> Rows_sent` ratio
- **Optimizer hints**: Use `/*+ ... */` hints sparingly — `BKA()`, `NO_BKA()`, `HASH_JOIN()`,
  `NO_HASH_JOIN()`, `INDEX()`, `NO_INDEX()`. Prefer query restructuring over hints
- **Common wins**: Enable `performance_schema` for detailed instrumentation. Set
  `innodb_flush_log_at_trx_commit=2` for non-critical workloads (better performance, slight
  durability trade-off). Use `innodb_io_capacity` and `innodb_io_capacity_max` to match storage
  IOPS. Set `innodb_log_file_size` to handle 1 hour of writes
