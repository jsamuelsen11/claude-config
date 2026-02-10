---
description: >
  Scaffold MySQL migration directory or connection configuration for a new or existing project
argument-hint: '[--type=migration-dir|connection-config]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize MySQL migration infrastructure or connection configuration for your project. This command
detects existing migration tools and scaffolds appropriate directory structures, or creates database
connection configuration following security best practices.

## Usage

```bash
ccfg mysql scaffold                           # Default: migration directory
ccfg mysql scaffold --type=migration-dir      # Explicit migration directory
ccfg mysql scaffold --type=connection-config  # Connection configuration
```

## Overview

The scaffold command provides two essential scaffolding operations for MySQL database projects:

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

2. **Liquibase** (Java/JVM)
   - Detection: `liquibase.properties` or `changelog-master.xml`
   - Convention: XML/YAML/SQL changelogs with master changelog

3. **golang-migrate** (Go)
   - Detection: `migrate.go` or `migrations/` directory with `*.up.sql`/`*.down.sql` pairs
   - Convention: Timestamp-based with up/down pairs

4. **Prisma** (Node.js/TypeScript)
   - Detection: `prisma/schema.prisma` file
   - Convention: Prisma manages migrations via schema file

5. **Knex** (Node.js)
   - Detection: `knexfile.js` or `package.json` with `knex` dependency
   - Convention: Timestamp-based migrations in `migrations/` directory

6. **Sequelize** (Node.js)
   - Detection: `package.json` with `sequelize` dependency
   - Convention: Timestamp-based migrations in `migrations/` directory

7. **TypeORM** (TypeScript/Node.js)
   - Detection: `package.json` with `typeorm` dependency or `ormconfig.json`
   - Convention: Timestamp-based migrations with TypeScript classes

**Tool-Agnostic Structure**:

If no migration tool is detected, creates a numbered migration directory that works with any tool:

```text
migrations/
├── 001_initial_schema.up.sql
├── 001_initial_schema.down.sql
├── 002_add_users_table.up.sql
├── 002_add_users_table.down.sql
└── README.md
```

### connection-config

Creates secure database connection configuration for your project's framework or language.

**Generated Files**:

1. `.env.example` - Template with placeholder credentials
2. Connection pool configuration snippet for detected framework
3. Updated `.gitignore` to exclude `.env` files

**Framework/Language Support**:

- Node.js (mysql2, @mysql/xdevapi)
- Python (mysql-connector-python, PyMySQL, SQLAlchemy)
- Java (JDBC, HikariCP)
- Go (go-sql-driver/mysql)
- PHP (PDO, mysqli)
- Ruby (mysql2 gem)
- C# (.NET MySQL Connector)

## Step-by-Step Process

### Migration Directory Scaffolding

#### Step 1: Detect Migration Tool

Scan the project for migration tool indicators using file existence and content checks.

**Detection Strategy**:

```bash
# Check for Flyway
if [[ -f "flyway.conf" ]] || [[ -d "sql" && -n "$(find sql -name 'V*.sql' 2>/dev/null)" ]]; then
    TOOL="flyway"
fi

# Check for Liquibase
if [[ -f "liquibase.properties" ]] || [[ -f "changelog-master.xml" ]] || [[ -f "db.changelog-master.xml" ]]; then
    TOOL="liquibase"
fi

# Check for golang-migrate
if [[ -f "migrate.go" ]] || [[ -d "migrations" && -n "$(find migrations -name '*.up.sql' 2>/dev/null)" ]]; then
    TOOL="golang-migrate"
fi

# Check for Prisma
if [[ -f "prisma/schema.prisma" ]]; then
    TOOL="prisma"
fi

# Check for Node.js migration tools (requires package.json)
if [[ -f "package.json" ]]; then
    if grep -q '"knex"' package.json; then
        TOOL="knex"
    elif grep -q '"sequelize"' package.json; then
        TOOL="sequelize"
    elif grep -q '"typeorm"' package.json; then
        TOOL="typeorm"
    fi
fi
```

**Best-Effort Detection**:

Migration tool detection is best-effort and non-prescriptive. The command never forces a specific
tool choice or suggests changing existing tooling.

#### Step 2: Create Tool-Specific Structure

Based on detected tool, create appropriate migration structure.

**Flyway Structure**:

```text
sql/
├── V001__initial_schema.sql
├── V002__create_users_table.sql
└── README.md
```

Example migration file:

```sql
-- V001__initial_schema.sql
-- Flyway migration
-- Description: Initialize database schema

CREATE DATABASE IF NOT EXISTS myapp_production
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE myapp_production;
```

**Liquibase Structure**:

```text
db/
├── changelog/
│   ├── db.changelog-master.xml
│   └── changes/
│       ├── v001_initial_schema.sql
│       └── v002_create_users_table.sql
└── README.md
```

Example changelog:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">

    <include file="changes/v001_initial_schema.sql" relativeToChangelogFile="true"/>

</databaseChangeLog>
```

**golang-migrate Structure**:

```text
migrations/
├── 000001_initial_schema.up.sql
├── 000001_initial_schema.down.sql
├── 000002_create_users_table.up.sql
├── 000002_create_users_table.down.sql
└── README.md
```

Example migration:

```sql
-- 000001_initial_schema.up.sql
CREATE TABLE IF NOT EXISTS schema_info (
    version INT NOT NULL PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

```sql
-- 000001_initial_schema.down.sql
DROP TABLE IF EXISTS schema_info;
```

**Knex Structure**:

```text
migrations/
├── 20260209120000_initial_schema.js
├── 20260209120001_create_users_table.js
└── README.md
```

Example Knex migration:

```javascript
/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function (knex) {
  return knex.schema.createTable('users', function (table) {
    table.increments('id').primary();
    table.string('email').notNullable().unique();
    table.string('name').notNullable();
    table.timestamps(true, true);
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {
  return knex.schema.dropTable('users');
};
```

**Sequelize Structure**:

```text
migrations/
├── 20260209120000-create-users.js
└── README.md
```

**TypeORM Structure**:

```text
src/migrations/
├── 1707483600000-InitialSchema.ts
└── README.md
```

**Prisma Structure**:

Prisma uses schema-first approach. Scaffold adds migration folder reference:

```text
prisma/
├── schema.prisma (existing)
└── migrations/
    └── README.md
```

**Tool-Agnostic Structure** (No Tool Detected):

```text
migrations/
├── 001_initial_schema.up.sql
├── 001_initial_schema.down.sql
├── 002_example_table.up.sql
├── 002_example_table.down.sql
└── README.md
```

Example tool-agnostic migration:

```sql
-- 001_initial_schema.up.sql
-- Migration: Initial Schema
-- Created: 2026-02-09

CREATE TABLE IF NOT EXISTS migration_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    version VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```sql
-- 001_initial_schema.down.sql
-- Rollback: Initial Schema

DROP TABLE IF EXISTS migration_history;
```

#### Step 3: Create README.md

Generate comprehensive README explaining migration conventions, naming patterns, and workflow.

**README Template**:

````markdown
# Database Migrations

This directory contains MySQL database migrations for the project.

## Migration Tool

[Detected Tool Name] or [Tool-Agnostic]

## Naming Convention

[Tool-specific naming pattern explanation]

### Examples

- `001_initial_schema.up.sql` / `001_initial_schema.down.sql`
- `002_add_users_table.up.sql` / `002_add_users_table.down.sql`

## Creating New Migrations

[Tool-specific commands or manual process]

## Running Migrations

[Tool-specific execution commands]

## Best Practices

1. **Always include down migrations** for rollback capability
2. **Test migrations** on development database before production
3. **Use transactions** where possible (`START TRANSACTION; ... COMMIT;`)
4. **Avoid destructive changes** in production without backups
5. **Keep migrations atomic** - one logical change per migration
6. **Use descriptive names** that explain what the migration does

## Migration Checklist

Before running a migration:

- [ ] SQL syntax is valid
- [ ] Migration is idempotent (safe to run multiple times)
- [ ] Down migration successfully reverses up migration
- [ ] Tested on development database
- [ ] Performance impact assessed for large tables
- [ ] Backup plan exists for production

## MySQL Best Practices

### Character Set and Collation

Always specify for new tables:

```sql
CREATE TABLE example (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;
```
````

### Indexes

Add indexes for foreign keys and frequently queried columns:

```sql
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_created_at ON users(created_at);
```

### Foreign Keys

Use foreign keys for referential integrity:

```sql
ALTER TABLE orders
ADD CONSTRAINT fk_user_id
FOREIGN KEY (user_id) REFERENCES users(id)
ON DELETE CASCADE
ON UPDATE CASCADE;
```

## Troubleshooting

### Migration Failed

1. Check MySQL error logs
2. Verify database connection
3. Ensure user has required privileges
4. Test migration syntax in MySQL client

### Rollback Needed

Run down migration to revert changes:

[Tool-specific rollback command]

````text

#### Step 4: Recommend Conventions Document

If project has `docs/` directory, offer to create `docs/db/mysql-conventions.md`:

**Check for docs directory**:

```bash
if [[ -d "docs" ]]; then
    echo "Would you like to create docs/db/mysql-conventions.md? (recommended)"
fi
````

**Conventions Document Template**:

````markdown
# MySQL Database Conventions

## Table Design

- Use singular names: `user`, `order`, `product`
- Use lowercase with underscores: `user_preference`, `order_item`
- Always include primary key named `id`
- Always include timestamp columns: `created_at`, `updated_at`

## Column Naming

- Use descriptive lowercase names with underscores
- Boolean columns: prefix with `is_`, `has_`, `can_`
- Foreign keys: `{table}_id` (e.g., `user_id`, `order_id`)

## Data Types

- **Strings**: VARCHAR(255) for most cases, TEXT for long content
- **Integers**: INT for IDs, BIGINT for large counters
- **Decimals**: DECIMAL(10,2) for currency
- **Dates**: DATETIME for timestamps, DATE for dates only
- **Booleans**: TINYINT(1) or BOOLEAN

## Indexes

- Primary key on `id` column (auto-increment)
- Unique indexes on natural keys (email, username)
- Indexes on foreign keys
- Composite indexes for multi-column queries
- Avoid over-indexing (impacts write performance)

## Character Set

Always use UTF-8 for international support:

```sql
DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
```
````

## Engine

Use InnoDB for ACID compliance and foreign key support:

```sql
ENGINE=InnoDB
```

````text

### Connection Configuration Scaffolding

#### Step 1: Detect Project Framework/Language

Identify the primary programming language and framework to generate appropriate configuration.

**Detection Indicators**:

- `package.json` - Node.js/TypeScript
- `requirements.txt` or `pyproject.toml` - Python
- `pom.xml` or `build.gradle` - Java
- `go.mod` - Go
- `composer.json` - PHP
- `Gemfile` - Ruby
- `*.csproj` - C#/.NET

#### Step 2: Create .env.example

Generate environment variable template with secure defaults and placeholder values.

**Basic .env.example**:

```bash
# MySQL Database Configuration
# Copy this file to .env and replace with actual values

# Database Connection
DATABASE_URL=mysql://username:password@localhost:3306/database_name
# Or separate variables:
DB_HOST=localhost
DB_PORT=3306
DB_NAME=myapp_production
DB_USER=myapp_user
DB_PASSWORD=secure_password_here

# Connection Pool Settings
DB_POOL_SIZE=10
DB_POOL_TIMEOUT=30
DB_POOL_MAX_IDLE=5

# Connection Options
DB_CHARSET=utf8mb4
DB_TIMEZONE=+00:00
DB_SSL_MODE=REQUIRED

# Query Settings
DB_QUERY_TIMEOUT=30
DB_SLOW_QUERY_LOG=false
DB_SLOW_QUERY_THRESHOLD=2000

# Connection Retry
DB_RETRY_ATTEMPTS=3
DB_RETRY_DELAY=1000

# Environment
NODE_ENV=production
````

**Security Notes in .env.example**:

```bash
# SECURITY NOTES:
# - Never commit .env file to version control
# - Use strong passwords (min 16 characters)
# - Enable SSL for production connections
# - Use read-only user for read-only operations
# - Rotate credentials regularly
# - Use secrets management in production (AWS Secrets Manager, HashiCorp Vault)
```

### Step 3: Generate Framework-Specific Configuration

Create connection pool configuration snippet for detected framework.

**Node.js with mysql2**:

```javascript
// config/database.js
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: parseInt(process.env.DB_POOL_SIZE || '10'),
  maxIdle: parseInt(process.env.DB_POOL_MAX_IDLE || '5'),
  idleTimeout: parseInt(process.env.DB_POOL_TIMEOUT || '30') * 1000,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  charset: process.env.DB_CHARSET || 'utf8mb4',
  timezone: process.env.DB_TIMEZONE || '+00:00',
  ssl: process.env.DB_SSL_MODE === 'REQUIRED' ? { rejectUnauthorized: true } : false,
});

// Test connection
pool
  .getConnection()
  .then((connection) => {
    console.log('Database connection established');
    connection.release();
  })
  .catch((err) => {
    console.error('Database connection failed:', err);
    process.exit(1);
  });

module.exports = pool;
```

**Python with mysql-connector-python**:

```python
# config/database.py
import os
from mysql.connector import pooling
from typing import Any

db_config: dict[str, Any] = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', '3306')),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME'),
    'charset': os.getenv('DB_CHARSET', 'utf8mb4'),
    'collation': 'utf8mb4_unicode_ci',
    'autocommit': False,
    'pool_size': int(os.getenv('DB_POOL_SIZE', '10')),
    'pool_name': 'myapp_pool',
}

# Create connection pool
connection_pool = pooling.MySQLConnectionPool(**db_config)

def get_connection():
    """Get connection from pool."""
    return connection_pool.get_connection()
```

**Python with SQLAlchemy**:

```python
# config/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

DATABASE_URL = os.getenv('DATABASE_URL') or (
    f"mysql+pymysql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '3306')}"
    f"/{os.getenv('DB_NAME')}?charset=utf8mb4"
)

engine = create_engine(
    DATABASE_URL,
    pool_size=int(os.getenv('DB_POOL_SIZE', '10')),
    max_overflow=int(os.getenv('DB_POOL_MAX_OVERFLOW', '20')),
    pool_timeout=int(os.getenv('DB_POOL_TIMEOUT', '30')),
    pool_pre_ping=True,  # Verify connections before using
    pool_recycle=3600,   # Recycle connections after 1 hour
    echo=os.getenv('DB_ECHO', 'false').lower() == 'true'
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```

**Go with go-sql-driver/mysql**:

```go
// config/database.go
package config

import (
    "database/sql"
    "fmt"
    "os"
    "strconv"
    "time"

    _ "github.com/go-sql-driver/mysql"
)

func NewDatabaseConnection() (*sql.DB, error) {
    host := getEnv("DB_HOST", "localhost")
    port := getEnv("DB_PORT", "3306")
    user := os.Getenv("DB_USER")
    password := os.Getenv("DB_PASSWORD")
    dbName := os.Getenv("DB_NAME")
    charset := getEnv("DB_CHARSET", "utf8mb4")

    dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=%s&parseTime=true&loc=UTC",
        user, password, host, port, dbName, charset)

    db, err := sql.Open("mysql", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }

    // Connection pool settings
    poolSize, _ := strconv.Atoi(getEnv("DB_POOL_SIZE", "10"))
    maxIdle, _ := strconv.Atoi(getEnv("DB_POOL_MAX_IDLE", "5"))
    timeout, _ := strconv.Atoi(getEnv("DB_POOL_TIMEOUT", "30"))

    db.SetMaxOpenConns(poolSize)
    db.SetMaxIdleConns(maxIdle)
    db.SetConnMaxLifetime(time.Duration(timeout) * time.Second)

    // Test connection
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    return db, nil
}

func getEnv(key, fallback string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return fallback
}
```

**Java with HikariCP**:

```java
// config/DatabaseConfig.java
package com.myapp.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

import javax.sql.DataSource;

public class DatabaseConfig {

    public static DataSource createDataSource() {
        HikariConfig config = new HikariConfig();

        config.setJdbcUrl(System.getenv("DATABASE_URL"));
        // Or build from components:
        // String url = String.format("jdbc:mysql://%s:%s/%s",
        //     getEnv("DB_HOST", "localhost"),
        //     getEnv("DB_PORT", "3306"),
        //     System.getenv("DB_NAME"));
        // config.setJdbcUrl(url);

        config.setUsername(System.getenv("DB_USER"));
        config.setPassword(System.getenv("DB_PASSWORD"));

        // Connection pool settings
        config.setMaximumPoolSize(
            Integer.parseInt(getEnv("DB_POOL_SIZE", "10"))
        );
        config.setMinimumIdle(
            Integer.parseInt(getEnv("DB_POOL_MAX_IDLE", "5"))
        );
        config.setConnectionTimeout(
            Integer.parseInt(getEnv("DB_POOL_TIMEOUT", "30")) * 1000L
        );

        // Performance settings
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");
        config.addDataSourceProperty("useServerPrepStmts", "true");

        return new HikariDataSource(config);
    }

    private static String getEnv(String key, String defaultValue) {
        String value = System.getenv(key);
        return value != null ? value : defaultValue;
    }
}
```

#### Step 4: Update .gitignore

Verify `.env` files are excluded from version control.

**Check if .gitignore exists**:

```bash
if [[ ! -f ".gitignore" ]]; then
    # Create new .gitignore
    cat > .gitignore << 'EOF'
# Environment variables
.env
.env.local
.env.*.local
EOF
else
    # Check if .env is already ignored
    if ! grep -q "^\.env" .gitignore; then
        echo "Adding .env to .gitignore"
        cat >> .gitignore << 'EOF'

# Environment variables
.env
.env.local
.env.*.local
EOF
    fi
fi
```

**Git Repository Check**:

Only update .gitignore if inside a git repository:

```bash
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Update .gitignore
else
    echo "Note: Not in a git repository. Remember to add .env to .gitignore when initializing git."
fi
```

#### Step 5: Create Database Configuration Documentation

Save configuration snippet to appropriate location based on project structure.

**File Locations**:

- Node.js: `config/database.js` or `src/config/database.ts`
- Python: `config/database.py` or `src/config/database.py`
- Go: `config/database.go` or `internal/config/database.go`
- Java: `src/main/java/com/myapp/config/DatabaseConfig.java`

**Documentation Header**:

```text
# MySQL Connection Configuration

This file was generated by ccfg-mysql scaffold command.

## Usage

[Framework-specific usage instructions]

## Environment Variables

See .env.example for all available configuration options.

## Connection Pool

The connection pool is configured with sensible defaults:
- Pool size: 10 connections
- Max idle: 5 connections
- Timeout: 30 seconds

Adjust these values based on your application's load profile.

## Security

- Always use environment variables for credentials
- Enable SSL for production connections (DB_SSL_MODE=REQUIRED)
- Use secrets management in production environments
- Rotate credentials regularly

## Testing Connection

[Framework-specific test instructions]
```

## Key Rules and Requirements

### Never Prescribe Migration Tools

The scaffold command detects existing tools but never suggests or forces adoption of a specific
migration framework. If no tool is detected, create a tool-agnostic structure that works
universally.

### Security First

All generated configuration files must:

- Use placeholder credentials (never real values)
- Include security warnings in comments
- Ensure .env is in .gitignore
- Recommend SSL for production
- Suggest secrets management systems

### Idempotent Operations

Scaffolding should be safe to run multiple times:

- Don't overwrite existing migration files
- Preserve user modifications
- Only add missing files
- Update .gitignore additively

### No Credentials in Examples

Never generate actual credentials or connection strings with real values. Always use:

- `username` or `myapp_user` for usernames
- `password` or `secure_password_here` for passwords
- `database_name` or `myapp_production` for database names
- `localhost` for hosts

### Documentation Location

Only create `docs/db/mysql-conventions.md` if:

- Project has existing `docs/` directory
- User confirms they want conventions documentation
- Documentation doesn't already exist

Never create `docs/` directory structure if it doesn't exist.

### Framework Detection Accuracy

Best-effort framework detection is acceptable. If detection fails or is ambiguous:

- Ask user which framework to use
- Provide generic configuration that works across frameworks
- Document manual customization steps

## Common Scenarios

### Scenario 1: New Project with No Migration Tool

```bash
ccfg mysql scaffold
```

**Result**:

- Creates `migrations/` directory with tool-agnostic structure
- Adds numbered migration examples (001, 002)
- Includes comprehensive README explaining conventions
- Provides both up and down migration templates

**User Workflow**:

1. Review generated migration structure
2. Create first real migration by copying template
3. Run migrations using custom script or manual execution
4. Optional: Adopt migration tool later (structure is compatible)

### Scenario 2: Existing Flyway Project

```bash
ccfg mysql scaffold
```

**Detection**: Finds `flyway.conf` in project root

**Result**:

- Detects Flyway migration tool
- Creates `sql/` directory if missing
- Adds Flyway-compatible migration examples
- Generates README with Flyway-specific commands
- Respects existing migrations (doesn't overwrite)

**User Workflow**:

1. Review Flyway migration examples
2. Run `flyway migrate` to apply migrations
3. Use `flyway info` to check status

### Scenario 3: Node.js Project Needs Connection Config

```bash
ccfg mysql scaffold --type=connection-config
```

**Detection**: Finds `package.json` with mysql2 dependency

**Result**:

- Creates `.env.example` with Node.js-appropriate variables
- Generates `config/database.js` with mysql2 pool configuration
- Updates `.gitignore` to exclude `.env`
- Provides usage examples in comments

**User Workflow**:

1. Copy `.env.example` to `.env`
2. Fill in actual database credentials
3. Import `config/database.js` in application
4. Test connection with provided test code

### Scenario 4: Python Project with SQLAlchemy

```bash
ccfg mysql scaffold --type=connection-config
```

**Detection**: Finds `requirements.txt` or `pyproject.toml` with sqlalchemy

**Result**:

- Creates `.env.example` with Python-style variable names
- Generates `config/database.py` with SQLAlchemy engine configuration
- Includes session management patterns
- Documents connection pool settings

**User Workflow**:

1. Copy `.env.example` to `.env`
2. Add actual credentials
3. Import SessionLocal from config
4. Use in FastAPI dependencies or Flask app context

### Scenario 5: Go Microservice

```bash
ccfg mysql scaffold --type=connection-config
```

**Detection**: Finds `go.mod` with github.com/go-sql-driver/mysql

**Result**:

- Creates `.env.example` with Go-friendly format
- Generates `config/database.go` with sql.DB configuration
- Includes connection testing and error handling
- Documents DSN format and options

**User Workflow**:

1. Copy `.env.example` to `.env`
2. Load env vars using godotenv or similar
3. Call NewDatabaseConnection() in main.go
4. Pass \*sql.DB to repository layer

## Connection Configuration Troubleshooting

### "Migration directory already exists"

**Cause**: Project already has migration directory

**Resolution**:

- Scaffold command should not overwrite existing migrations
- Only adds README.md if missing
- Warns user that migrations directory exists
- Asks if user wants to add README only

### "Multiple migration tools detected"

**Cause**: Project has multiple migration tool indicators (e.g., both Flyway and Liquibase files)

**Resolution**:

- List detected tools
- Ask user which tool is actively used
- Scaffold for selected tool only
- Warn about conflicting configurations

### "No framework detected"

**Cause**: Cannot determine programming language or framework for connection config

**Resolution**:

- Create generic .env.example with all variables
- Provide documentation for manual configuration
- Link to MySQL connector documentation for various languages
- Suggest common frameworks user might be using

### ".env.example already exists"

**Cause**: Project already has environment variable template

**Resolution**:

- Don't overwrite existing file
- Display suggested additions
- Ask if user wants to merge new database variables
- Preserve existing non-database configuration

### "Not in git repository"

**Cause**: .gitignore cannot be created/updated outside git repo

**Resolution**:

- Create .gitignore anyway with warning
- Inform user that .env must be excluded from version control
- Provide reminder message about security
- Suggest initializing git if appropriate

### "Insufficient permissions"

**Cause**: Cannot create files in target directory

**Resolution**:

- Report specific permission error
- Suggest running with appropriate permissions
- Check if directory is writable
- Provide alternative locations if available

## Summary

The scaffold command simplifies MySQL database infrastructure setup by intelligently detecting
existing migration tools and frameworks, then generating appropriate configuration following
security best practices and industry conventions.

By supporting both migration directory scaffolding and connection configuration, the command covers
the two most common database setup needs. Best-effort detection ensures compatibility with existing
projects while tool-agnostic fallbacks guarantee utility even in unique or custom environments.

All generated files use placeholder credentials, include comprehensive documentation, and follow
security best practices including proper .gitignore configuration to prevent accidental credential
exposure.
