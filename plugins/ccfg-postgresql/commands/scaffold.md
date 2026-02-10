---
description: >
  Scaffold PostgreSQL migration directory or connection configuration for a new or existing project
argument-hint: '[--type=migration-dir|connection-config]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize PostgreSQL migration infrastructure or connection configuration for your project. This
command detects existing migration tools and scaffolds appropriate directory structures, or creates
database connection configuration following security best practices.

## Usage

```bash
ccfg postgresql scaffold                           # Default: migration directory
ccfg postgresql scaffold --type=migration-dir      # Explicit migration directory
ccfg postgresql scaffold --type=connection-config  # Connection configuration
```

## Overview

The scaffold command provides two essential scaffolding operations for PostgreSQL database projects:

- **Migration Directory**: Detects and scaffolds migrations following your existing tool's
  conventions, or creates a tool-agnostic numbered migration structure if no tool is detected
- **Connection Configuration**: Creates environment-based connection configuration with secure
  defaults and framework-specific connection pool settings

All scaffolded files follow security best practices, including proper .gitignore configuration to
prevent credential leaks and placeholder values for sensitive data.

## Scaffold Types

### migration-dir (Default)

Creates or enhances migration directory structure based on detected migration tooling.

**Supported Migration Tools**:

1. **Flyway** (Java/JVM)
   - Detection: `flyway.conf` or `sql/` directory with `V*.sql` files
   - Convention: Versioned migrations with `V<version>__<description>.sql`

2. **Alembic** (Python/SQLAlchemy)
   - Detection: `alembic.ini` or `alembic/` directory with `env.py`
   - Convention: Revision files with `upgrade()` and `downgrade()` functions

3. **golang-migrate** (Go)
   - Detection: `migrate.go` or migrations directory with `*.up.sql` / `*.down.sql` pairs
   - Convention: Timestamped pairs `<timestamp>_<name>.up.sql` / `<timestamp>_<name>.down.sql`

4. **dbmate** (Go, multi-language)
   - Detection: `database.yml` or `.dbmate` directory
   - Convention: Timestamped SQL files with `-- migrate:up` / `-- migrate:down` sections

5. **Prisma** (TypeScript/JavaScript)
   - Detection: `prisma/schema.prisma` with `provider = "postgresql"`
   - Convention: Prisma schema with `prisma migrate dev` workflow

6. **Knex** (JavaScript/TypeScript)
   - Detection: `knexfile.js` or `knexfile.ts`
   - Convention: Timestamped JS/TS migration files with `up()` and `down()` methods

7. **TypeORM** (TypeScript/JavaScript)
   - Detection: `ormconfig.json`, `ormconfig.ts`, or `data-source.ts`
   - Convention: Timestamped TS migration classes with `up()` and `down()` methods

8. **Sequelize** (JavaScript/TypeScript)
   - Detection: `.sequelizerc` or `config/database.json`
   - Convention: Timestamped JS files with `up()` and `down()` methods

9. **Django** (Python)
   - Detection: `manage.py` with `django` in requirements
   - Convention: Numbered migration files per app, auto-generated

10. **Tool-agnostic** (Fallback)
    - Detection: No recognized tool found
    - Convention: Numbered SQL files `001_<name>.sql` with header comments

### connection-config

Creates environment-based connection configuration with secure defaults.

## Step-by-Step Process

### Phase 1: Environment Detection

Scan the project to identify existing tools, frameworks, and conventions.

```bash
# Check for migration tool configuration files
ls flyway.conf 2>/dev/null
ls alembic.ini 2>/dev/null
ls alembic/env.py 2>/dev/null
ls prisma/schema.prisma 2>/dev/null
ls knexfile.js knexfile.ts 2>/dev/null
ls ormconfig.json ormconfig.ts 2>/dev/null
ls .sequelizerc 2>/dev/null
ls manage.py 2>/dev/null

# Check for existing migration directories
ls -d migrations/ db/migrate/ sql/ database/migrations/ 2>/dev/null

# Detect primary language/framework from project files
ls package.json 2>/dev/null     # Node.js
ls requirements.txt Pipfile pyproject.toml 2>/dev/null  # Python
ls go.mod 2>/dev/null           # Go
ls pom.xml build.gradle 2>/dev/null  # Java/JVM
ls Gemfile 2>/dev/null          # Ruby
ls mix.exs 2>/dev/null          # Elixir
ls Cargo.toml 2>/dev/null       # Rust
```

If multiple tools are detected, prefer the one with existing migrations. If no migrations exist,
prefer the tool with a configuration file.

### Phase 2: Migration Directory Scaffold

#### Flyway Migration Structure

```text
sql/
  V001__create_users_table.sql
  V002__create_orders_table.sql
  V003__add_user_indexes.sql
flyway.conf
```

Scaffold `flyway.conf`:

```ini
# Flyway Configuration
# Documentation: https://documentation.red-gate.com/fd/parameters-184127474.html

# PostgreSQL JDBC URL
flyway.url=jdbc:postgresql://localhost:5432/mydb

# Credentials (use environment variables in production)
# flyway.user=${PGUSER}
# flyway.password=${PGPASSWORD}
flyway.user=CHANGE_ME
flyway.password=CHANGE_ME

# Migration locations
flyway.locations=filesystem:sql

# Schema
flyway.defaultSchema=public
flyway.schemas=public

# Settings
flyway.validateOnMigrate=true
flyway.cleanDisabled=true
flyway.baselineOnMigrate=false

# PostgreSQL-specific
flyway.postgresql.transactional.lock=false
```

Scaffold initial migration `sql/V001__initial_schema.sql`:

```sql
-- Flyway Migration: V001__initial_schema.sql
-- Description: Initial database schema setup
-- Author: scaffold
-- Date: 2026-02-09

-- Enable recommended extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create initial table (replace with your schema)
CREATE TABLE schema_version_info (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE schema_version_info IS 'Tracks manual schema documentation';
```

#### Alembic Migration Structure

```text
alembic/
  env.py
  script.py.mako
  versions/
    001_initial_schema.py
alembic.ini
```

Scaffold `alembic.ini`:

```ini
[alembic]
# Path to migration scripts
script_location = alembic

# Connection string (override with environment variable in production)
# sqlalchemy.url = postgresql+psycopg://user:password@localhost:5432/mydb
sqlalchemy.url = driver://user:pass@localhost/dbname

# Logging configuration
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

Scaffold `alembic/env.py`:

```python
"""Alembic environment configuration for PostgreSQL."""
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Override connection string from environment variable
database_url = os.environ.get("DATABASE_URL")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

target_metadata = None  # Import your models' metadata here


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (generates SQL scripts)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (connects to database)."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

#### golang-migrate Structure

```text
migrations/
  000001_initial_schema.up.sql
  000001_initial_schema.down.sql
```

Scaffold up migration `migrations/000001_initial_schema.up.sql`:

```sql
-- golang-migrate: Up Migration
-- Description: Initial database schema setup

-- Enable recommended extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create initial table (replace with your schema)
CREATE TABLE schema_info (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
```

Scaffold down migration `migrations/000001_initial_schema.down.sql`:

```sql
-- golang-migrate: Down Migration
-- Description: Reverse initial database schema setup

DROP TABLE IF EXISTS schema_info;

-- Note: Extension drops are commented out; only drop if no other tables depend on them
-- DROP EXTENSION IF EXISTS pgcrypto;
-- DROP EXTENSION IF EXISTS "uuid-ossp";
```

#### dbmate Structure

```text
db/
  migrations/
    20260209000000_initial_schema.sql
  schema.sql
.dbmate
```

Scaffold migration `db/migrations/20260209000000_initial_schema.sql`:

```sql
-- migrate:up
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE schema_info (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);

-- migrate:down
DROP TABLE IF EXISTS schema_info;
```

#### Prisma Structure

Scaffold `prisma/schema.prisma`:

```prisma
// Prisma Schema for PostgreSQL
// Documentation: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// Example model (replace with your schema)
model User {
  id        BigInt   @id @default(autoincrement())
  email     String   @unique
  name      String
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz()
  updatedAt DateTime @updatedAt @map("updated_at") @db.Timestamptz()

  @@map("users")
}
```

#### Knex Structure

Scaffold `knexfile.ts`:

```typescript
import type { Knex } from 'knex';

const config: Record<string, Knex.Config> = {
  development: {
    client: 'pg',
    connection: {
      host: process.env.PGHOST || 'localhost',
      port: Number(process.env.PGPORT) || 5432,
      user: process.env.PGUSER || 'CHANGE_ME',
      password: process.env.PGPASSWORD || 'CHANGE_ME',
      database: process.env.PGDATABASE || 'mydb_dev',
    },
    pool: { min: 2, max: 10 },
    migrations: {
      directory: './migrations',
      tableName: 'knex_migrations',
    },
    seeds: {
      directory: './seeds',
    },
  },

  production: {
    client: 'pg',
    connection: {
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: true },
    },
    pool: { min: 5, max: 20 },
    migrations: {
      directory: './migrations',
      tableName: 'knex_migrations',
    },
  },
};

export default config;
```

Scaffold initial migration `migrations/20260209000000_initial_schema.ts`:

```typescript
import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  await knex.raw('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
  await knex.raw('CREATE EXTENSION IF NOT EXISTS pgcrypto');

  await knex.schema.createTable('schema_info', (table) => {
    table.bigIncrements('id').primary();
    table.text('description').notNullable();
    table.timestamp('applied_at', { useTz: true }).notNullable().defaultTo(knex.fn.now());
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTableIfExists('schema_info');
}
```

#### TypeORM Structure

Scaffold `data-source.ts`:

```typescript
import { DataSource } from 'typeorm';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.PGHOST || 'localhost',
  port: Number(process.env.PGPORT) || 5432,
  username: process.env.PGUSER || 'CHANGE_ME',
  password: process.env.PGPASSWORD || 'CHANGE_ME',
  database: process.env.PGDATABASE || 'mydb_dev',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false,
  synchronize: false, // NEVER true in production
  logging: process.env.NODE_ENV !== 'production',
  entities: ['src/entity/**/*.ts'],
  migrations: ['src/migration/**/*.ts'],
  migrationsTableName: 'typeorm_migrations',
  extra: {
    // Connection pool settings
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  },
});
```

#### Tool-Agnostic Fallback Structure

When no migration tool is detected, create a simple numbered SQL migration structure.

```text
database/
  migrations/
    001_initial_schema.sql
    README.md
  seeds/
    seed_reference_data.sql
```

Scaffold `database/migrations/001_initial_schema.sql`:

```sql
-- Migration: 001_initial_schema.sql
-- Description: Initial database schema setup
-- Author: scaffold
-- Date: 2026-02-09
-- PostgreSQL Version: 15+

-- =============================================================================
-- UP MIGRATION
-- =============================================================================

-- Enable recommended extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create initial table (replace with your schema)
CREATE TABLE schema_info (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- DOWN MIGRATION (reverse the above changes)
-- =============================================================================
-- To roll back, run these statements in reverse order:
--
-- DROP TABLE IF EXISTS schema_info;
-- DROP EXTENSION IF EXISTS pgcrypto;
-- DROP EXTENSION IF EXISTS "uuid-ossp";
```

### Phase 3: Connection Configuration Scaffold

#### Environment Variable Template

Scaffold `.env.example`:

```bash
# PostgreSQL Connection Configuration
# Copy this file to .env and fill in your values
# NEVER commit the .env file to version control

# Individual connection parameters
PGHOST=localhost
PGPORT=5432
PGDATABASE=mydb_dev
PGUSER=CHANGE_ME
PGPASSWORD=CHANGE_ME
PGSSLMODE=prefer

# Connection string format (alternative to individual params)
# DATABASE_URL=postgresql://user:password@localhost:5432/mydb?sslmode=prefer

# Connection pool settings
PG_POOL_MIN=2
PG_POOL_MAX=10
PG_IDLE_TIMEOUT_MS=30000
PG_CONNECTION_TIMEOUT_MS=5000

# SSL Configuration (for production)
# PGSSLMODE=verify-full
# PGSSLCERT=/path/to/client-cert.pem
# PGSSLKEY=/path/to/client-key.pem
# PGSSLROOTCERT=/path/to/ca-cert.pem
```

#### .gitignore Configuration

Append to or create `.gitignore`:

```gitignore
# PostgreSQL credentials and local config
.env
.env.local
.env.*.local
*.pem
*.key

# Database dumps
*.dump
*.pg_dump
*.sql.gz
*.sql.bz2

# pgpass file
.pgpass
```

#### Python Connection Configuration

For Python projects (SQLAlchemy/psycopg detected):

Scaffold `config/database.py`:

```python
"""PostgreSQL connection configuration."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class DatabaseConfig:
    """Database connection configuration loaded from environment."""

    host: str = os.environ.get("PGHOST", "localhost")
    port: int = int(os.environ.get("PGPORT", "5432"))
    database: str = os.environ.get("PGDATABASE", "mydb_dev")
    user: str = os.environ.get("PGUSER", "CHANGE_ME")
    password: str = os.environ.get("PGPASSWORD", "CHANGE_ME")
    sslmode: str = os.environ.get("PGSSLMODE", "prefer")
    pool_min: int = int(os.environ.get("PG_POOL_MIN", "2"))
    pool_max: int = int(os.environ.get("PG_POOL_MAX", "10"))

    @property
    def url(self) -> str:
        """Return SQLAlchemy-compatible connection URL."""
        return (
            f"postgresql+psycopg://{self.user}:{self.password}"
            f"@{self.host}:{self.port}/{self.database}"
            f"?sslmode={self.sslmode}"
        )

    @property
    def async_url(self) -> str:
        """Return async SQLAlchemy-compatible connection URL."""
        return (
            f"postgresql+asyncpg://{self.user}:{self.password}"
            f"@{self.host}:{self.port}/{self.database}"
        )


# Singleton configuration
db_config = DatabaseConfig()
```

#### Node.js Connection Configuration

For Node.js projects (pg, knex, typeorm, prisma detected):

Scaffold `config/database.ts`:

```typescript
/**
 * PostgreSQL connection configuration.
 * Loaded from environment variables with sensible defaults.
 */

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  ssl: boolean | { rejectUnauthorized: boolean };
  pool: {
    min: number;
    max: number;
    idleTimeoutMillis: number;
    connectionTimeoutMillis: number;
  };
}

function getConfig(env: string = process.env.NODE_ENV || 'development'): DatabaseConfig {
  const base = {
    host: process.env.PGHOST || 'localhost',
    port: Number(process.env.PGPORT) || 5432,
    database: process.env.PGDATABASE || 'mydb_dev',
    user: process.env.PGUSER || 'CHANGE_ME',
    password: process.env.PGPASSWORD || 'CHANGE_ME',
  };

  if (env === 'production') {
    return {
      ...base,
      database: process.env.PGDATABASE || 'mydb_prod',
      ssl: { rejectUnauthorized: true },
      pool: {
        min: Number(process.env.PG_POOL_MIN) || 5,
        max: Number(process.env.PG_POOL_MAX) || 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 5000,
      },
    };
  }

  if (env === 'test') {
    return {
      ...base,
      database: process.env.PGDATABASE || 'mydb_test',
      ssl: false,
      pool: {
        min: 1,
        max: 5,
        idleTimeoutMillis: 10000,
        connectionTimeoutMillis: 3000,
      },
    };
  }

  // Development
  return {
    ...base,
    ssl: false,
    pool: {
      min: Number(process.env.PG_POOL_MIN) || 2,
      max: Number(process.env.PG_POOL_MAX) || 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    },
  };
}

export const dbConfig = getConfig();
export default dbConfig;
```

#### Go Connection Configuration

For Go projects (pgx, database/sql detected):

Scaffold `config/database.go`:

```go
package config

import (
	"fmt"
	"os"
	"strconv"
)

// DatabaseConfig holds PostgreSQL connection settings.
type DatabaseConfig struct {
	Host            string
	Port            int
	Database        string
	User            string
	Password        string
	SSLMode         string
	PoolMaxConns    int
	PoolMinConns    int
	PoolMaxIdleTime string
}

// NewDatabaseConfig creates a DatabaseConfig from environment variables.
func NewDatabaseConfig() *DatabaseConfig {
	port, _ := strconv.Atoi(getEnv("PGPORT", "5432"))
	poolMax, _ := strconv.Atoi(getEnv("PG_POOL_MAX", "10"))
	poolMin, _ := strconv.Atoi(getEnv("PG_POOL_MIN", "2"))

	return &DatabaseConfig{
		Host:            getEnv("PGHOST", "localhost"),
		Port:            port,
		Database:        getEnv("PGDATABASE", "mydb_dev"),
		User:            getEnv("PGUSER", "CHANGE_ME"),
		Password:        getEnv("PGPASSWORD", "CHANGE_ME"),
		SSLMode:         getEnv("PGSSLMODE", "prefer"),
		PoolMaxConns:    poolMax,
		PoolMinConns:    poolMin,
		PoolMaxIdleTime: "30s",
	}
}

// ConnectionString returns a PostgreSQL connection string.
func (c *DatabaseConfig) ConnectionString() string {
	return fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=%s "+
			"pool_max_conns=%d pool_min_conns=%d",
		c.Host, c.Port, c.Database, c.User, c.Password, c.SSLMode,
		c.PoolMaxConns, c.PoolMinConns,
	)
}

// DSN returns a PostgreSQL DSN URL.
func (c *DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"postgresql://%s:%s@%s:%d/%s?sslmode=%s",
		c.User, c.Password, c.Host, c.Port, c.Database, c.SSLMode,
	)
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
```

### Phase 4: Post-Scaffold Verification

After scaffolding, verify the generated structure.

#### Verification Checklist

```bash
# 1. Check that all files were created
echo "=== Scaffold Verification ==="

# Check migration directory exists
if [ -d "migrations" ] || [ -d "sql" ] || [ -d "db/migrations" ] || \
   [ -d "database/migrations" ] || [ -d "alembic/versions" ]; then
    echo "PASS: Migration directory exists"
else
    echo "FAIL: No migration directory found"
fi

# Check .gitignore includes credential patterns
if grep -q '.env' .gitignore 2>/dev/null; then
    echo "PASS: .gitignore includes .env"
else
    echo "WARN: .gitignore missing .env pattern"
fi

# Check no actual credentials in tracked files
if git ls-files | xargs grep -l 'password.*=.*[^C]' 2>/dev/null | \
   grep -v '.example' | grep -v 'CHANGE_ME'; then
    echo "FAIL: Possible credentials in tracked files"
else
    echo "PASS: No credentials detected in tracked files"
fi
```

#### Output Format

```text
============================================================
PostgreSQL Scaffold Report
============================================================
Type: migration-dir
Tool Detected: Flyway
============================================================

Created files:
  + flyway.conf
  + sql/V001__initial_schema.sql
  + .gitignore (updated)
  + .env.example

Skipped (already exists):
  ~ sql/ (directory exists)

Next steps:
  1. Edit flyway.conf with your database connection details
  2. Copy .env.example to .env and fill in credentials
  3. Customize sql/V001__initial_schema.sql with your initial schema
  4. Run: flyway migrate

============================================================
```

## Conflict Resolution

### Existing Files

When a file already exists:

1. **Never overwrite** existing migration files or configuration without confirmation
2. **Merge .gitignore** entries (append new patterns, don't replace)
3. **Skip existing directories** and report them as "already exists"
4. **Offer to create** the next numbered migration instead

```text
INFO: migrations/000001_initial_schema.up.sql already exists
INFO: Creating migrations/000002_scaffold_additions.up.sql instead
```

### Multiple Tools Detected

When multiple migration tools are detected:

```text
NOTICE: Multiple migration tools detected:
  1. Alembic (alembic.ini found)
  2. Prisma (prisma/schema.prisma found)

Using Alembic (has existing migrations).
Override with: ccfg postgresql scaffold --tool=prisma
```

## Troubleshooting

### "No project detected"

**Cause**: No recognizable project files (package.json, go.mod, requirements.txt, etc.)

**Resolution**:

- Verify you're in the correct project directory
- The scaffold command will use tool-agnostic fallback
- Specify tool explicitly if needed

### "Permission denied creating directory"

**Cause**: Cannot create files in target directory

**Resolution**:

- Report specific permission error
- Suggest running with appropriate permissions
- Check if directory is writable
- Provide alternative locations if available

### "Existing migration numbering conflict"

**Cause**: Auto-generated migration number conflicts with existing migration

**Resolution**:

- Detect highest existing migration number
- Use next available number
- Report the numbering scheme detected

### "Database URL format not recognized"

**Cause**: Environment variable uses unexpected format

**Resolution**:

- Support multiple URL formats:
  - `postgresql://user:pass@host:port/db`
  - `postgres://user:pass@host:port/db`
  - Individual `PG*` environment variables
- Report which format was detected and suggest corrections

## Security Checklist

Every scaffold operation must verify these security requirements:

1. **No hardcoded credentials**: All generated files use `CHANGE_ME` placeholders
2. **.gitignore updated**: `.env`, `.pgpass`, `*.pem`, `*.key` patterns present
3. **SSL in production**: Production configs default to `sslmode=verify-full` or equivalent
4. **Connection pooling**: Production configs include pool size limits
5. **.env.example provided**: Template file with all required variables documented
6. **No secrets in output**: Scaffold report never displays actual credential values
7. **synchronize: false**: ORM configs always disable auto-sync in production

## Summary

The scaffold command simplifies PostgreSQL database infrastructure setup by intelligently detecting
existing migration tools and frameworks, then generating appropriate configuration following
security best practices and industry conventions.

By supporting both migration directory scaffolding and connection configuration, the command covers
the two most common database setup needs. Best-effort detection ensures compatibility with existing
projects while tool-agnostic fallbacks guarantee utility even in unique or custom environments.

All generated files use placeholder credentials, include comprehensive documentation, and follow
security best practices including proper .gitignore configuration to prevent accidental credential
exposure.
