---
name: mysql-conventions
description:
  This skill should be used when working on MySQL databases, writing SQL schemas, creating tables,
  designing database architecture, or reviewing MySQL code.
version: 0.1.0
---

# MySQL Conventions

These are comprehensive conventions for MySQL database development, covering schema design, indexing
strategies, data type selection, and query patterns. Following these conventions ensures optimal
performance, data integrity, and maintainability across MySQL 8.0+ environments.

## Existing Repository Compatibility

When working with existing MySQL databases and projects, always respect established conventions and
patterns before applying these preferences.

- **Audit before changing**: Review existing table definitions, character sets, and engine choices
  to understand the project's current state and historical decisions.
- **MyISAM compatibility**: If the project uses MyISAM for specific tables (e.g., full-text search
  on legacy MySQL 5.5), understand the rationale before converting to InnoDB. Migration requires
  testing for locking behavior changes and performance impacts.
- **Character set migrations**: If the project uses `latin1` or `utf8`, flag the limitation but do
  not change without coordinating with the team. Character set conversion requires table rebuilds
  and can impact replication, backups, and application compatibility.
- **Collation consistency**: Mixed collations across tables can cause implicit conversions and
  performance degradation. Document inconsistencies but plan migrations carefully.
- **Backward compatibility**: When suggesting improvements, provide migration paths and rollback
  procedures for production systems.

**These conventions apply primarily to new schemas, new tables, and scaffold output. For existing
systems, propose changes through proper change management processes.**

## Engine and Charset Rules

Modern MySQL deployments should standardize on InnoDB with utf8mb4 for maximum compatibility,
performance, and data integrity.

### Storage Engine: Always InnoDB

InnoDB provides critical features required for production databases:

- **ACID transactions**: Full commit/rollback support with isolation levels
- **Row-level locking**: Better concurrency than table-level locks (MyISAM)
- **Crash recovery**: Automatic recovery using redo logs and doublewrite buffer
- **Foreign key constraints**: Referential integrity enforcement at database level
- **Online DDL**: Many ALTER operations without blocking reads/writes (MySQL 8.0+)

```sql
-- CORRECT: InnoDB with explicit engine declaration
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: MyISAM lacks transactions, FK support, and crash recovery
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM;

-- WRONG: Omitting engine may default to MyISAM on older configurations
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL
);
```

### Character Set: Always utf8mb4

The `utf8mb4` character set is the only MySQL charset that supports full Unicode, including emoji,
mathematical symbols, and supplementary CJK characters.

- **utf8mb4**: Full 4-byte UTF-8, supports all Unicode characters including emoji (U+1F600+)
- **utf8**: Legacy 3-byte subset, cannot store characters outside BMP (Basic Multilingual Plane)
- **latin1**: Single-byte, Western European only, breaks with international text

```sql
-- CORRECT: utf8mb4 with MySQL 8.0+ default collation
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  content TEXT NOT NULL,
  emoji_reaction VARCHAR(100) DEFAULT NULL  -- Can store 😀👍🎉
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: utf8 (3-byte) will fail inserting emoji or rare CJK characters
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  content TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- WRONG: latin1 breaks with any non-Western European characters
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

### Collation: utf8mb4_0900_ai_ci for MySQL 8.0+

- **utf8mb4_0900_ai_ci**: MySQL 8.0+ default, Unicode 9.0 support, accurate sorting
- **utf8mb4_general_ci**: Faster but less accurate sorting, acceptable for legacy compatibility
- **utf8mb4_bin**: Binary comparison, case-sensitive, use for tokens/hashes

```sql
-- CORRECT: Modern collation with Unicode 9.0 support
CREATE TABLE categories (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL COLLATE utf8mb4_0900_ai_ci,
  slug VARCHAR(100) NOT NULL COLLATE utf8mb4_bin  -- Case-sensitive slugs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ACCEPTABLE: utf8mb4_general_ci for MySQL 5.7 compatibility
CREATE TABLE legacy_categories (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

### Server Configuration

Set server defaults to prevent incorrect charset/collation on new tables:

```ini
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-storage-engine=InnoDB
```

## Schema Design Rules

Well-designed schemas improve query performance, enforce data integrity, and reduce application
complexity through database-level constraints and defaults.

### Identifier Naming: snake_case

Use lowercase snake_case for all database identifiers to ensure cross-platform compatibility and
readability.

- **Tables**: Plural nouns (`users`, `order_items`, `product_categories`)
- **Columns**: Descriptive names (`created_at`, `email_verified_at`, `total_price`)
- **Indexes**: Prefixed pattern (`idx_users_email`, `fk_orders_user_id`)
- **Constraints**: Descriptive (`chk_price_positive`, `uniq_users_email`)

```sql
-- CORRECT: Consistent snake_case naming
CREATE TABLE order_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_order_items_order_id (order_id),
  INDEX idx_order_items_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: Mixed case and inconsistent naming
CREATE TABLE OrderItems (
  ID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  OrderID BIGINT UNSIGNED NOT NULL,
  productId BIGINT UNSIGNED NOT NULL,
  UnitPrice DECIMAL(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Primary Keys: BIGINT UNSIGNED AUTO_INCREMENT or UUID

Choose primary key strategy based on scale requirements and distribution needs.

#### BIGINT UNSIGNED AUTO_INCREMENT (Recommended for Most Cases)

- **8-byte integer**: 0 to 18,446,744,073,709,551,615 (18 quintillion)
- **Sequential**: Better for InnoDB clustered index, optimal page fill
- **Compact**: 8 bytes vs 16 bytes for UUID
- **Performance**: Faster joins, smaller indexes, better caching

```sql
-- CORRECT: BIGINT UNSIGNED for scalability
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  UNIQUE KEY uniq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: INT will overflow at 4.2 billion (or 2.1B if signed)
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: UNSIGNED omitted, wastes half the range on negative numbers
CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

#### BINARY(16) for UUIDs (Distributed Systems)

Use UUIDs when you need globally unique identifiers across distributed databases or want to prevent
ID enumeration attacks.

```sql
-- CORRECT: BINARY(16) with UUID generation
CREATE TABLE distributed_events (
  id BINARY(16) PRIMARY KEY,  -- Store UUID as binary, not CHAR(36)
  event_type VARCHAR(50) NOT NULL,
  payload JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_events_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Application layer: INSERT INTO distributed_events (id, ...) VALUES (UUID_TO_BIN(UUID()), ...);
-- Query: SELECT BIN_TO_UUID(id) as id, ... FROM distributed_events;

-- WRONG: CHAR(36) wastes space (36 bytes vs 16 bytes)
CREATE TABLE distributed_events (
  id CHAR(36) PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: VARCHAR is even worse due to length prefix overhead
CREATE TABLE distributed_events (
  id VARCHAR(36) PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Timestamp vs DateTime

Choose based on whether you need point-in-time (timezone-aware) or calendar time (timezone-naive).

#### TIMESTAMP: Point-in-time Events

- **Timezone-aware**: Stores UTC, converts based on session `time_zone`
- **Range**: 1970-01-01 00:00:01 UTC to 2038-01-19 03:14:07 UTC (Y2038 limitation)
- **Use for**: Audit logs, event timestamps, created_at/updated_at

```sql
-- CORRECT: TIMESTAMP for audit fields
CREATE TABLE audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

#### DATETIME: Calendar Time

- **Timezone-naive**: Stores literal date/time value (no timezone conversion)
- **Range**: 1000-01-01 00:00:00 to 9999-12-31 23:59:59
- **Use for**: Scheduled events, business hours, birthdays, appointments

```sql
-- CORRECT: DATETIME for scheduled events
CREATE TABLE scheduled_tasks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  task_name VARCHAR(100) NOT NULL,
  scheduled_for DATETIME NOT NULL,  -- "Run at 2026-03-15 09:00:00 local time"
  timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',  -- Store timezone separately if needed
  INDEX idx_scheduled_tasks_scheduled_for (scheduled_for)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: TIMESTAMP for far-future dates (Y2038 problem)
CREATE TABLE appointments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL,
  appointment_time TIMESTAMP NOT NULL  -- Breaks for dates after 2038-01-19
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Decimal vs Float for Money

Always use DECIMAL for financial data to avoid rounding errors from binary floating-point
representation.

```sql
-- CORRECT: DECIMAL(precision, scale) for exact arithmetic
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subtotal DECIMAL(10,2) NOT NULL,  -- Max 99,999,999.99
  tax DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_orders_total CHECK (total = subtotal + tax)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: FLOAT/DOUBLE cause rounding errors
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subtotal FLOAT NOT NULL,  -- 19.99 + 0.01 might = 19.999999...
  tax FLOAT NOT NULL,
  total FLOAT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Example of FLOAT error:
-- SELECT 19.99 + 0.01;  -- Returns 20.000000476837158 (FLOAT)
-- SELECT CAST(19.99 AS DECIMAL(10,2)) + CAST(0.01 AS DECIMAL(10,2));  -- Returns 20.00 (DECIMAL)
```

### JSON Columns with Generated Columns

MySQL 8.0+ supports JSON columns with generated columns for indexing specific paths.

```sql
-- CORRECT: JSON with generated indexed columns
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  attributes JSON NOT NULL,
  -- Generated columns for indexing
  brand VARCHAR(100) GENERATED ALWAYS AS (attributes->>'$.brand') STORED,
  price DECIMAL(10,2) GENERATED ALWAYS AS (CAST(attributes->>'$.price' AS DECIMAL(10,2))) STORED,
  INDEX idx_products_brand (brand),
  INDEX idx_products_price (price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Query using generated column index:
-- SELECT * FROM products WHERE brand = 'Acme' AND price < 100.00;

-- WRONG: JSON without indexes (full table scan on every query)
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  attributes JSON NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Query without index (slow):
-- SELECT * FROM products WHERE attributes->>'$.brand' = 'Acme';
```

### ENUM vs Lookup Tables

Avoid ENUM for values that may change over time. Use lookup tables for maintainability.

```sql
-- CORRECT: Lookup table for mutable values
CREATE TABLE order_statuses (
  id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  description TEXT,
  UNIQUE KEY uniq_order_statuses_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO order_statuses (name, description) VALUES
  ('pending', 'Order received, awaiting payment'),
  ('processing', 'Payment confirmed, preparing shipment'),
  ('shipped', 'Order dispatched'),
  ('delivered', 'Order delivered to customer');

CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  status_id TINYINT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY fk_orders_status_id (status_id) REFERENCES order_statuses(id),
  INDEX idx_orders_status_id (status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: ENUM requires ALTER TABLE to add/remove values
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'processing', 'shipped', 'delivered') NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Adding 'cancelled' status requires table rebuild:
-- ALTER TABLE orders MODIFY status ENUM('pending','processing','shipped','delivered','cancelled');
```

**When ENUM is acceptable:**

- Fixed, immutable sets (e.g., `gender ENUM('M', 'F', 'O', 'U')` if schema unlikely to change)
- Small value sets (2-4 values) with no business logic

### Boolean Values: TINYINT(1)

MySQL has no native BOOLEAN type. Use TINYINT(1) for boolean columns.

```sql
-- CORRECT: TINYINT(1) for boolean flags
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  email_verified TINYINT(1) NOT NULL DEFAULT 0,  -- 0 = false, 1 = true
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  is_admin TINYINT(1) NOT NULL DEFAULT 0,
  INDEX idx_users_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Query: SELECT * FROM users WHERE email_verified = 1 AND is_active = 1;

-- ACCEPTABLE: BIT(1) (less common, same storage)
CREATE TABLE settings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  feature_enabled BIT(1) NOT NULL DEFAULT b'0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: CHAR(1) or VARCHAR wastes space
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  is_active CHAR(1) NOT NULL DEFAULT 'N'  -- 1 byte vs 1 byte for TINYINT, but less clear
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### NOT NULL with Defaults

Prefer NOT NULL with meaningful defaults to simplify application logic and avoid NULL handling.

```sql
-- CORRECT: NOT NULL with defaults where sensible
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  bio TEXT NOT NULL DEFAULT '',  -- Empty string instead of NULL
  login_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL DEFAULT NULL,  -- NULL intentional for soft deletes
  UNIQUE KEY uniq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: Nullable columns without clear reason
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255),  -- Should be NOT NULL
  login_count INT UNSIGNED,  -- Should default to 0
  created_at TIMESTAMP  -- Should default to CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**When NULL is appropriate:**

- Optional foreign keys (e.g., `manager_id` for employees without managers)
- Soft delete timestamps (`deleted_at`)
- Truly optional data (e.g., `middle_name`, `phone_number`)

### Generated (Virtual) Columns

Use generated columns for computed values to ensure consistency and enable indexing.

```sql
-- CORRECT: Generated columns for computed values
CREATE TABLE rectangles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  width DECIMAL(10,2) NOT NULL,
  height DECIMAL(10,2) NOT NULL,
  area DECIMAL(20,4) GENERATED ALWAYS AS (width * height) VIRTUAL,
  perimeter DECIMAL(20,4) GENERATED ALWAYS AS (2 * (width + height)) VIRTUAL,
  INDEX idx_rectangles_area (area)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- VIRTUAL: Computed on read, not stored (saves space)
-- STORED: Computed on write, stored physically (faster reads, uses disk space)

-- CORRECT: Stored generated column for expensive computations
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_rate DECIMAL(5,4) NOT NULL,  -- e.g., 0.0825 for 8.25%
  tax DECIMAL(10,2) GENERATED ALWAYS AS (subtotal * tax_rate) STORED,
  total DECIMAL(10,2) GENERATED ALWAYS AS (subtotal + (subtotal * tax_rate)) STORED,
  INDEX idx_orders_total (total)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: Storing computed values manually (data inconsistency risk)
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  subtotal DECIMAL(10,2) NOT NULL,
  tax_rate DECIMAL(5,4) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,  -- Application must compute and keep in sync
  total DECIMAL(10,2) NOT NULL  -- Application must compute and keep in sync
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

## Index Rules

Proper indexing is critical for query performance. Every query should use an index to avoid full
table scans.

### Foreign Key Indexes

Every foreign key column must have an index for efficient joins and ON DELETE/UPDATE operations.

```sql
-- CORRECT: Indexes on all foreign keys
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  author_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(500) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_posts_author_id (author_id),  -- Required for FK
  INDEX idx_posts_category_id (category_id),  -- Required for FK
  FOREIGN KEY fk_posts_author_id (author_id) REFERENCES users(id),
  FOREIGN KEY fk_posts_category_id (category_id) REFERENCES categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- WRONG: Missing index on foreign key (slow joins and cascades)
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  author_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(500) NOT NULL,
  FOREIGN KEY fk_posts_author_id (author_id) REFERENCES users(id)
  -- Missing INDEX on author_id and category_id
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Composite Index Leftmost Prefix Rule

Composite indexes can satisfy queries using any leftmost prefix of the indexed columns.

```sql
-- CORRECT: Composite index design
CREATE TABLE user_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  event_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- Composite index: (user_id, event_date, event_type)
  INDEX idx_user_events_composite (user_id, event_date, event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- This index can satisfy these queries:
-- SELECT * FROM user_events WHERE user_id = 123;
-- SELECT * FROM user_events WHERE user_id = 123 AND event_date = '2026-02-01';
-- SELECT * FROM user_events WHERE user_id = 123 AND event_date = '2026-02-01'
--   AND event_type = 'login';

-- This index CANNOT satisfy:
-- SELECT * FROM user_events WHERE event_date = '2026-02-01';  -- Missing user_id prefix
-- SELECT * FROM user_events WHERE event_type = 'login';  -- Missing user_id prefix

-- WRONG: Redundant indexes
CREATE TABLE user_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  event_date DATE NOT NULL,
  INDEX idx_user_events_user_id (user_id),  -- Redundant with composite
  INDEX idx_user_events_composite (user_id, event_date)  -- Contains user_id prefix
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Remove idx_user_events_user_id: the composite index covers it
```

**Index column order guidelines:**

1. Equality conditions first (user_id = 123)
2. Range conditions last (event_date > '2026-01-01')
3. High cardinality before low cardinality (user_id before event_type)

### FULLTEXT Indexes for Text Search

Use FULLTEXT indexes for natural language search queries instead of LIKE '%term%'.

```sql
-- CORRECT: FULLTEXT index for text search
CREATE TABLE articles (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  body TEXT NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FULLTEXT INDEX ft_articles_title_body (title, body),
  INDEX idx_articles_author_id (author_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Query using FULLTEXT index:
SELECT id, title, MATCH(title, body) AGAINST ('mysql performance' IN NATURAL LANGUAGE MODE) AS score
FROM articles
WHERE MATCH(title, body) AGAINST ('mysql performance' IN NATURAL LANGUAGE MODE)
ORDER BY score DESC
LIMIT 20;

-- Boolean mode for advanced queries:
SELECT id, title FROM articles
WHERE MATCH(title, body) AGAINST ('+mysql -oracle' IN BOOLEAN MODE);

-- WRONG: LIKE with wildcards (full table scan)
SELECT id, title FROM articles
WHERE title LIKE '%mysql%' OR body LIKE '%mysql%';
```

### Avoid Redundant Indexes

Redundant indexes waste disk space and slow down writes (INSERT/UPDATE/DELETE).

```sql
-- WRONG: Redundant indexes
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(100) NOT NULL,
  name VARCHAR(255) NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  INDEX idx_products_sku (sku),
  UNIQUE KEY uniq_products_sku (sku),  -- REDUNDANT: unique index covers idx_products_sku
  INDEX idx_products_category_price (category_id, price),
  INDEX idx_products_category_id (category_id)  -- REDUNDANT: composite index covers this
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CORRECT: Remove redundant indexes
CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(100) NOT NULL,
  name VARCHAR(255) NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  UNIQUE KEY uniq_products_sku (sku),  -- Only this one for sku
  INDEX idx_products_category_price (category_id, price)  -- Covers category_id queries too
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Check for redundant indexes:**

```sql
-- Query to find potential redundant indexes
SELECT
  table_name,
  GROUP_CONCAT(index_name ORDER BY index_name) AS indexes,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM information_schema.statistics
WHERE table_schema = 'your_database'
GROUP BY table_name, index_name
HAVING COUNT(*) > 0
ORDER BY table_name, index_name;
```

### Index Hints as Last Resort

Avoid forcing index usage with hints. Let the optimizer choose based on statistics.

```sql
-- WRONG: Index hints force optimizer behavior
SELECT * FROM orders FORCE INDEX (idx_orders_created_at)
WHERE user_id = 123 AND created_at > '2026-01-01';

-- CORRECT: Let optimizer choose, ensure statistics are up to date
ANALYZE TABLE orders;
SELECT * FROM orders
WHERE user_id = 123 AND created_at > '2026-01-01';

-- If optimizer chooses poorly, investigate and fix the root cause:
-- 1. Update table statistics: ANALYZE TABLE orders;
-- 2. Check index cardinality: SHOW INDEX FROM orders;
-- 3. Add missing composite index: CREATE INDEX idx_orders_user_created (user_id, created_at);
-- 4. Review query structure for implicit type conversions
```

## Window Function and CTE Rules

MySQL 8.0+ supports window functions and CTEs for advanced analytical queries.

### CTEs for Readable Multi-Step Queries

Common Table Expressions (CTEs) improve readability and maintainability for complex queries.

```sql
-- CORRECT: CTE for multi-step aggregation
WITH monthly_sales AS (
  SELECT
    user_id,
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(total) AS total_sales,
    COUNT(*) AS order_count
  FROM orders
  WHERE order_date >= '2025-01-01'
  GROUP BY user_id, DATE_FORMAT(order_date, '%Y-%m')
),
top_customers AS (
  SELECT
    user_id,
    month,
    total_sales,
    RANK() OVER (PARTITION BY month ORDER BY total_sales DESC) AS sales_rank
  FROM monthly_sales
)
SELECT
  u.email,
  tc.month,
  tc.total_sales,
  tc.sales_rank
FROM top_customers tc
JOIN users u ON tc.user_id = u.id
WHERE tc.sales_rank <= 10
ORDER BY tc.month DESC, tc.sales_rank ASC;

-- WRONG: Deeply nested subqueries (hard to read and maintain)
SELECT u.email, subq.month, subq.total_sales, subq.sales_rank
FROM (
  SELECT
    user_id, month, total_sales,
    RANK() OVER (PARTITION BY month ORDER BY total_sales DESC) AS sales_rank
  FROM (
    SELECT
      user_id,
      DATE_FORMAT(order_date, '%Y-%m') AS month,
      SUM(total) AS total_sales
    FROM orders
    WHERE order_date >= '2025-01-01'
    GROUP BY user_id, DATE_FORMAT(order_date, '%Y-%m')
  ) AS inner_subq
) AS subq
JOIN users u ON subq.user_id = u.id
WHERE subq.sales_rank <= 10
ORDER BY subq.month DESC, subq.sales_rank ASC;
```

### Window Functions Over Self-Joins

Window functions eliminate the need for expensive self-joins in many scenarios.

```sql
-- CORRECT: Window function for running totals
SELECT
  order_date,
  total,
  SUM(total) OVER (ORDER BY order_date) AS running_total,
  AVG(total) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM orders
WHERE user_id = 123
ORDER BY order_date;

-- WRONG: Self-join for running total (slow and complex)
SELECT
  o1.order_date,
  o1.total,
  SUM(o2.total) AS running_total
FROM orders o1
JOIN orders o2 ON o2.user_id = o1.user_id AND o2.order_date <= o1.order_date
WHERE o1.user_id = 123
GROUP BY o1.order_date, o1.total
ORDER BY o1.order_date;

-- CORRECT: ROW_NUMBER for pagination
SELECT user_id, email, created_at
FROM (
  SELECT
    user_id,
    email,
    created_at,
    ROW_NUMBER() OVER (ORDER BY created_at DESC) AS row_num
  FROM users
  WHERE is_active = 1
) AS numbered
WHERE row_num BETWEEN 101 AND 120;  -- Page 6 (20 per page)

-- CORRECT: RANK and DENSE_RANK for leaderboards
SELECT
  u.email,
  s.score,
  RANK() OVER (ORDER BY s.score DESC) AS rank_with_gaps,
  DENSE_RANK() OVER (ORDER BY s.score DESC) AS rank_no_gaps
FROM scores s
JOIN users u ON s.user_id = u.id
WHERE s.game_id = 42
ORDER BY s.score DESC
LIMIT 100;
```

### No Stored Procedures for Application Logic

Keep application logic in application code, not database stored procedures.

```sql
-- WRONG: Complex business logic in stored procedure
DELIMITER //
CREATE PROCEDURE process_order(IN p_user_id BIGINT, IN p_cart_json JSON)
BEGIN
  DECLARE v_order_id BIGINT;
  DECLARE v_total DECIMAL(10,2);

  -- Complex procedural logic mixing business rules with data access
  START TRANSACTION;
  -- ... 50 lines of procedural code ...
  COMMIT;
END//
DELIMITER ;

-- CORRECT: Database enforces constraints, application handles logic
-- In application code (Python/Node.js/etc):
-- def process_order(user_id, cart_items):
--     total = calculate_total(cart_items)
--     with transaction():
--         order_id = db.execute("INSERT INTO orders (user_id, total) VALUES (?, ?)",
--                               user_id, total)
--         for item in cart_items:
--             db.execute("INSERT INTO order_items (order_id, ...) VALUES (?, ...)",
--                        order_id, ...)
--     return order_id
```

**When stored procedures are acceptable:**

- Bulk data transformations (ETL processes)
- Scheduled maintenance tasks (triggered by events)
- Database-specific operations (partition management)

## Core Principles

Following these core principles ensures maintainable, performant, and reliable MySQL databases:

- **InnoDB always**: Use InnoDB for ACID transactions, row-level locking, crash recovery, and
  foreign key support. Never use MyISAM in production.

- **utf8mb4 everywhere**: Use utf8mb4 character set and utf8mb4_0900_ai_ci collation for full
  Unicode support including emoji and supplementary characters.

- **BIGINT UNSIGNED for primary keys**: Future-proof with 18 quintillion possible values instead of
  risking overflow with INT (4 billion limit).

- **Index foreign keys**: Every FK column must have an index for efficient joins and ON
  DELETE/UPDATE cascade operations.

- **DECIMAL for money**: Never use FLOAT or DOUBLE for financial data due to binary floating-point
  rounding errors.

- **NOT NULL with defaults**: Prefer NOT NULL columns with sensible defaults to simplify application
  logic and avoid NULL handling complexity.

- **Generated columns for computed values**: Ensure data consistency and enable indexing on computed
  values using VIRTUAL or STORED generated columns.

- **Lookup tables over ENUM**: Use lookup tables for mutable value sets to avoid ALTER TABLE
  operations and schema locks.

- **Window functions over self-joins**: Leverage MySQL 8.0+ window functions for running totals,
  rankings, and moving averages instead of expensive self-joins.

- **CTEs for readability**: Use Common Table Expressions to break complex queries into readable,
  maintainable steps.

- **Explicit constraints**: Define CHECK constraints, foreign keys, and unique indexes at the
  database level to enforce data integrity.

- **snake_case naming**: Use consistent lowercase snake_case for all identifiers (tables, columns,
  indexes) for cross-platform compatibility.

## Anti-Patterns to Avoid

### 1. Using MyISAM Instead of InnoDB

MyISAM lacks critical production features and should never be used for modern applications.

```sql
-- WRONG: MyISAM lacks transactions, foreign keys, and crash recovery
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM;

-- Problems:
-- - No transaction support (can't rollback failed multi-table operations)
-- - Table-level locking (poor concurrency under writes)
-- - No foreign key constraints (referential integrity must be in application)
-- - Crash recovery requires manual table repair

-- CORRECT: InnoDB with full ACID support
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY fk_orders_user_id (user_id) REFERENCES users(id),
  INDEX idx_orders_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 2. Using utf8 Instead of utf8mb4

The `utf8` character set is a legacy 3-byte subset that cannot store emoji or supplementary CJK
characters.

```sql
-- WRONG: utf8 (3-byte) breaks with emoji and rare characters
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  content TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- INSERT INTO posts (title, content) VALUES ('Hello 😀', 'Great post! 👍');
-- ERROR 1366 (HY000): Incorrect string value: '\xF0\x9F\x98\x80' for column 'title'

-- CORRECT: utf8mb4 supports full Unicode
CREATE TABLE posts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  content TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- INSERT succeeds with emoji and all Unicode characters
```

### 3. Using FLOAT/DOUBLE for Money

Binary floating-point types cause rounding errors in financial calculations.

```sql
-- WRONG: FLOAT causes rounding errors
CREATE TABLE transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  amount FLOAT NOT NULL,
  fee FLOAT NOT NULL,
  total FLOAT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- INSERT INTO transactions (amount, fee, total) VALUES (19.99, 0.01, 20.00);
-- SELECT amount + fee AS calculated, total FROM transactions;
-- Result: calculated = 20.000000476837158, total = 20.00 (inconsistent!)

-- CORRECT: DECIMAL for exact arithmetic
CREATE TABLE transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  amount DECIMAL(10,2) NOT NULL,
  fee DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) GENERATED ALWAYS AS (amount + fee) STORED,
  CONSTRAINT chk_transactions_total_positive CHECK (total > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- SELECT amount + fee AS calculated, total FROM transactions;
-- Result: calculated = 20.00, total = 20.00 (exact match)
```

### 4. Using ENUM for Changing Values

ENUM changes require ALTER TABLE, causing table locks and downtime.

```sql
-- WRONG: ENUM for status values
CREATE TABLE tickets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status ENUM('open', 'in_progress', 'closed') NOT NULL DEFAULT 'open',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Business requirement: add 'pending_customer' status
-- ALTER TABLE tickets MODIFY status ENUM('open','in_progress','pending_customer','closed')
--   NOT NULL DEFAULT 'open';
-- This rebuilds the entire table, locking it for the duration

-- CORRECT: Lookup table for flexibility
CREATE TABLE ticket_statuses (
  id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  display_order INT UNSIGNED NOT NULL,
  UNIQUE KEY uniq_ticket_statuses_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO ticket_statuses (name, display_order) VALUES
  ('open', 1), ('in_progress', 2), ('closed', 3);

CREATE TABLE tickets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_id TINYINT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY fk_tickets_status_id (status_id) REFERENCES ticket_statuses(id),
  INDEX idx_tickets_status_id (status_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Add new status without ALTER TABLE:
-- INSERT INTO ticket_statuses (name, display_order) VALUES ('pending_customer', 3);
-- UPDATE ticket_statuses SET display_order = 4 WHERE name = 'closed';
```

### 5. SELECT \* Everywhere

Selecting all columns wastes bandwidth, breaks application compatibility when schema changes, and
prevents index-only scans.

```sql
-- WRONG: SELECT * wastes resources
SELECT * FROM users WHERE email = 'user@example.com';
-- Returns all columns including large TEXT/BLOB fields, even if only id and email are needed

-- WRONG: SELECT * in application code
-- for user in db.query("SELECT * FROM users WHERE is_active = 1"):
--     send_email(user['email'])  -- Only needs email, but fetches all columns

-- CORRECT: Select only needed columns
SELECT id, email, full_name FROM users WHERE email = 'user@example.com';

-- CORRECT: Enable covering index optimization
SELECT id, email FROM users WHERE email = 'user@example.com';
-- If UNIQUE KEY (email) exists, this is a covering index scan (no table access needed)

-- CORRECT: Explicit columns in application code
-- for user in db.query("SELECT id, email FROM users WHERE is_active = 1"):
--     send_email(user['email'])
```

### 6. Missing Primary Keys

Every table must have a primary key for InnoDB clustered index optimization and replication.

```sql
-- WRONG: No primary key (poor InnoDB performance)
CREATE TABLE logs (
  user_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_logs_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- InnoDB creates a hidden 6-byte row ID, wasting space and preventing optimizations

-- CORRECT: Auto-increment primary key
CREATE TABLE logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_logs_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CORRECT: Composite primary key for join tables
CREATE TABLE user_roles (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY fk_user_roles_user_id (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY fk_user_roles_role_id (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  INDEX idx_user_roles_role_id (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### 7. Implicit Type Conversions

Comparing columns with mismatched types prevents index usage and causes full table scans.

```sql
-- WRONG: Comparing VARCHAR column to INTEGER (index not used)
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  external_id VARCHAR(50) NOT NULL,
  UNIQUE KEY uniq_users_external_id (external_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Query with type mismatch:
SELECT * FROM users WHERE external_id = 12345;  -- external_id is VARCHAR, 12345 is INTEGER
-- MySQL converts ALL external_id values to integers for comparison (full table scan!)

-- CORRECT: Match types in query
SELECT * FROM users WHERE external_id = '12345';  -- Uses index

-- WRONG: TIMESTAMP comparison with string (index not used efficiently)
SELECT * FROM orders WHERE created_at = '2026-02-09';
-- Better: SELECT * FROM orders WHERE created_at >= '2026-02-09' AND created_at < '2026-02-10';

-- CORRECT: Use proper types in schema
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  external_id BIGINT UNSIGNED NOT NULL,  -- If IDs are numeric, use numeric type
  UNIQUE KEY uniq_users_external_id (external_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Now query uses index:
SELECT * FROM users WHERE external_id = 12345;
```

**Check query execution plans:**

```sql
-- Use EXPLAIN to verify index usage
EXPLAIN SELECT * FROM users WHERE external_id = '12345'\G

-- Look for:
-- type: const or ref (good) vs ALL (full table scan, bad)
-- key: index name (good) vs NULL (no index used, bad)
-- rows: low number (good) vs millions (table scan, bad)
```
