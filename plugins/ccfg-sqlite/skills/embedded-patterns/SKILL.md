---
name: embedded-patterns
description:
  This skill should be used when embedding SQLite in applications, managing concurrent access,
  implementing backup strategies, or using libSQL/Turso.
version: 0.1.0
---

# Embedded Patterns

Patterns and best practices for embedding SQLite in applications across mobile, desktop, serverless,
and edge computing platforms. This skill covers connection management, concurrent access, backup
strategies, migration handling, and platform-specific considerations for production SQLite
deployments.

## Existing Repository Compatibility

When working with existing applications that use SQLite, respect the established patterns:

- **Connection management**: If the project uses a specific connection pattern (singleton, pool,
  per-request), follow it for consistency.
- **Migration approach**: If the project uses a migration tool or custom migration runner, work
  within that framework.
- **PRAGMA configuration**: If the project has specific PRAGMA settings, understand why before
  changing them. Some settings may be intentional for the platform.
- **Date storage**: If the project uses Unix timestamps instead of ISO-8601, continue that pattern
  for consistency within the project.
- **ORM/library conventions**: If the project uses an ORM (Room, SQLAlchemy, Prisma), follow that
  ORM's conventions and patterns.

## Connection Management

### The Fundamental Pattern: 1 Writer + N Readers

SQLite allows only one writer at a time. The recommended pattern is:

- **1 dedicated writer connection**: Handles all INSERT, UPDATE, DELETE operations
- **N reader connections**: Handle SELECT operations, one per concurrent reader thread
- **All connections**: Must have PRAGMAs configured immediately after opening

```python
# CORRECT: Writer + reader pattern (Python)
class Database:
    def __init__(self, path):
        self.path = path
        self._writer = self._open_connection()
        self._writer.execute("PRAGMA journal_mode = WAL")
        self._readers = threading.local()

    def _open_connection(self):
        conn = sqlite3.connect(self.path)
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA busy_timeout = 5000")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA cache_size = -64000")
        conn.execute("PRAGMA temp_store = MEMORY")
        return conn

    def read(self, sql, params=()):
        if not hasattr(self._readers, 'conn'):
            self._readers.conn = self._open_connection()
        return self._readers.conn.execute(sql, params).fetchall()

    def write(self, sql, params=()):
        with self._writer_lock:
            self._writer.execute(sql, params)
            self._writer.commit()
```

```python
# WRONG: Single connection shared across threads
db = sqlite3.connect('app.db')
# Thread 1: db.execute("INSERT ...")
# Thread 2: db.execute("SELECT ...")
# Data corruption, SQLITE_BUSY errors, undefined behavior
```

```python
# WRONG: New connection per query (no PRAGMA reuse)
def get_user(user_id):
    conn = sqlite3.connect('app.db')  # No PRAGMAs configured!
    result = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    conn.close()  # Connection overhead on every query
    return result.fetchone()
```

### Connection Pool Sizing

| Component | Count | Purpose                    |
| --------- | ----- | -------------------------- |
| Writer    | 1     | All write operations       |
| Readers   | 1-4   | Concurrent read operations |
| Total     | 2-5   | Keep total under 10        |

**Mobile apps**: 1 writer + 1-2 readers (limited concurrency). **Web servers**: 1 writer + 1 reader
per worker thread. **CLI tools**: Single connection usually sufficient.

### Go Connection Pattern

```go
// CORRECT: Separate writer and reader pools
func Open(path string) (*sql.DB, *sql.DB, error) {
    dsn := path + "?_journal_mode=WAL&_foreign_keys=ON&_busy_timeout=5000&_synchronous=NORMAL"

    writer, err := sql.Open("sqlite3", dsn)
    if err != nil {
        return nil, nil, err
    }
    writer.SetMaxOpenConns(1)

    reader, err := sql.Open("sqlite3", dsn+"&mode=ro")
    if err != nil {
        writer.Close()
        return nil, nil, err
    }
    reader.SetMaxOpenConns(4)

    return writer, reader, nil
}
```

### Node.js Connection Pattern

```javascript
// CORRECT: better-sqlite3 (synchronous, recommended for Node.js)
const Database = require('better-sqlite3');

const db = new Database('app.db');
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');
db.pragma('synchronous = NORMAL');
db.pragma('cache_size = -64000');

// Prepared statements for performance
const getUser = db.prepare('SELECT * FROM users WHERE id = ?');
const insertUser = db.prepare('INSERT INTO users (name, email) VALUES (@name, @email)');

// Transaction helper (automatic rollback on error)
const bulkInsert = db.transaction((users) => {
  for (const user of users) insertUser.run(user);
});
```

```javascript
// WRONG: Async sqlite3 package without proper error handling
const sqlite3 = require('sqlite3');
const db = new sqlite3.Database('app.db');
// No PRAGMA configuration, callback hell, poor error handling
```

## Concurrent Access

### WAL Mode Concurrency Model

With WAL mode enabled:

| Operation | Blocks Writers?     | Blocks Readers? |
| --------- | ------------------- | --------------- |
| Reader    | No                  | No              |
| Writer    | No                  | No              |
| Writer    | Yes (other writers) | No              |

- Multiple readers operate simultaneously without blocking.
- One writer can operate without blocking readers.
- Only one writer at a time — second writer waits for `busy_timeout`.
- Readers see a consistent snapshot from when their transaction started.

### Handling SQLITE_BUSY

Even with `busy_timeout`, applications should handle SQLITE_BUSY:

```python
# CORRECT: Retry with backoff
import time

def execute_with_retry(conn, sql, params=(), max_retries=3):
    for attempt in range(max_retries):
        try:
            result = conn.execute(sql, params)
            conn.commit()
            return result
        except sqlite3.OperationalError as e:
            if "database is locked" in str(e) and attempt < max_retries - 1:
                time.sleep(0.1 * (attempt + 1))
                continue
            raise
```

### Write Batching for High Concurrency

When many threads need to write, funnel through a write queue:

```python
# CORRECT: Write queue pattern
import queue
import threading

class WriteQueue:
    def __init__(self, db_path):
        self._queue = queue.Queue()
        self._conn = sqlite3.connect(db_path)
        # ... configure PRAGMAs ...
        self._thread = threading.Thread(target=self._process, daemon=True)
        self._thread.start()

    def _process(self):
        while True:
            batch = [self._queue.get()]
            # Drain queue for batching
            while not self._queue.empty() and len(batch) < 100:
                try:
                    batch.append(self._queue.get_nowait())
                except queue.Empty:
                    break

            self._conn.execute("BEGIN IMMEDIATE")
            for sql, params, future in batch:
                try:
                    result = self._conn.execute(sql, params)
                    future.set_result(result.lastrowid)
                except Exception as e:
                    future.set_exception(e)
            self._conn.execute("COMMIT")
```

### BEGIN IMMEDIATE for Write Transactions

```sql
-- CORRECT: Acquire write lock immediately
BEGIN IMMEDIATE;
INSERT INTO orders (customer_id, total) VALUES (42, 5000);
UPDATE inventory SET quantity = quantity - 1 WHERE product_id = 7;
COMMIT;
```

```sql
-- WRONG: Deferred BEGIN for write transactions
BEGIN;  -- Doesn't acquire write lock yet
SELECT * FROM orders;  -- Read succeeds
INSERT INTO orders ...;  -- May get SQLITE_BUSY here mid-transaction!
COMMIT;
-- Use BEGIN IMMEDIATE for write transactions to fail fast at BEGIN.
```

## Backup Strategies

### Online Backup API (Recommended)

Safe hot backup while the database is in use:

```python
# CORRECT: Online Backup API
def backup(source_path, backup_path):
    source = sqlite3.connect(source_path)
    dest = sqlite3.connect(backup_path)
    with dest:
        source.backup(dest, pages=100, progress=lambda s, r, t: None)
    dest.close()
    source.close()
```

### VACUUM INTO (SQLite 3.27+)

Creates a compacted copy:

```sql
-- CORRECT: Compacted backup
VACUUM INTO '/backups/app_2024_03_15.db';
-- Original database unchanged, backup is defragmented
```

### Checkpoint-and-Copy

For simpler needs:

```python
# CORRECT: Checkpoint then file copy
conn = sqlite3.connect(db_path)
conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")  # Flush WAL to main file
conn.close()
shutil.copy2(db_path, backup_path)  # Safe to copy just .db file
```

```python
# WRONG: Copy without checkpoint
shutil.copy2('app.db', 'backup.db')
# With WAL mode, the .db file may not contain recent writes.
# The -wal and -shm files are also needed. Always checkpoint first.
```

### Backup Schedule

- **Critical data**: Hourly backup, keep 24 hourly + 7 daily
- **Important data**: Every 6 hours, keep 7 daily
- **Always**: Backup before schema migrations

## Migration in Embedded Contexts

### Apply Migrations at Startup

```python
# CORRECT: Startup migration pattern
def migrate(db_path, migrations_dir):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")

    current_version = conn.execute("PRAGMA user_version").fetchone()[0]

    for migration_file in sorted(glob.glob(f"{migrations_dir}/*.up.sql")):
        version = int(os.path.basename(migration_file).split("_")[0])
        if version <= current_version:
            continue

        with open(migration_file) as f:
            conn.executescript(f.read())

        conn.execute(f"PRAGMA user_version = {version}")
        conn.commit()

    conn.close()
```

### Migration Best Practices

- **Roll forward only**: Embedded apps rarely need down migrations. Users don't downgrade.
- **Idempotent**: Use `CREATE TABLE IF NOT EXISTS`, check column existence before ALTER.
- **Atomic**: Each migration in a single transaction.
- **Test with real data**: Not just empty databases.
- **Version tracking**: Use `PRAGMA user_version` or a migrations table.

```sql
-- CORRECT: Idempotent migration
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
) STRICT;

-- Adding a column (check existence in application code first)
-- SELECT COUNT(*) FROM pragma_table_info('users') WHERE name = 'phone';
-- If 0: ALTER TABLE users ADD COLUMN phone TEXT;
```

```sql
-- WRONG: Non-idempotent migration
CREATE TABLE users (...);  -- Fails if exists
ALTER TABLE users ADD COLUMN phone TEXT;  -- Fails if column exists
```

## Turso and libSQL

### Embedded Replicas

libSQL embedded replicas provide local reads with remote writes:

```typescript
// CORRECT: Turso embedded replica
import { createClient } from '@libsql/client';

const db = createClient({
  url: 'file:local-replica.db', // Local for fast reads
  syncUrl: 'libsql://your-db.turso.io', // Remote for replication
  authToken: process.env.TURSO_AUTH_TOKEN,
  syncInterval: 60, // Seconds between syncs
});

// Reads hit local replica (fast, no network)
const users = await db.execute('SELECT * FROM users WHERE id = ?', [userId]);

// Writes go to remote, replicate back
await db.execute('INSERT INTO users (name) VALUES (?)', [name]);

// Manual sync
await db.sync();
```

### Connection Patterns

```typescript
// Remote-only (serverless)
const remote = createClient({
  url: 'libsql://your-db.turso.io',
  authToken: process.env.TURSO_AUTH_TOKEN,
});

// Local-only (same as SQLite)
const local = createClient({ url: 'file:app.db' });

// Embedded replica (best of both)
const replica = createClient({
  url: 'file:local.db',
  syncUrl: 'libsql://your-db.turso.io',
  authToken: process.env.TURSO_AUTH_TOKEN,
});
```

## In-Memory Test Databases

### Basic In-Memory

```python
# CORRECT: In-memory database with production PRAGMAs
def create_test_db():
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON")
    # Apply same migrations as production
    with open("db/init.sql") as f:
        conn.executescript(f.read())
    return conn
```

### Shared In-Memory (Concurrent Access Testing)

```python
# CORRECT: Multiple connections to same in-memory database
conn1 = sqlite3.connect("file::memory:?cache=shared", uri=True)
conn2 = sqlite3.connect("file::memory:?cache=shared", uri=True)

conn1.execute("PRAGMA foreign_keys = ON")
conn2.execute("PRAGMA foreign_keys = ON")

# Both connections share the same database
conn1.execute("CREATE TABLE test (id INTEGER PRIMARY KEY) STRICT")
conn1.commit()
conn2.execute("SELECT * FROM test")  # Works — same database
```

### Named In-Memory (Test Isolation)

```python
# CORRECT: Isolated test databases
import uuid

def isolated_test_db():
    name = f"test_{uuid.uuid4().hex[:8]}"
    conn = sqlite3.connect(f"file:{name}?mode=memory&cache=shared", uri=True)
    conn.execute("PRAGMA foreign_keys = ON")
    return conn
```

## Platform-Specific Considerations

### iOS

- **Storage**: Use Application Support directory (`applicationSupportDirectory`)
- **Backup**: Exclude large databases from iCloud with `isExcludedFromBackup`
- **Threading**: WAL mode is thread-safe on iOS
- **Data protection**: Consider `SQLITE_OPEN_FILEPROTECTION_*` flags
- **Framework**: Core Data uses SQLite internally; direct SQLite is also common

### Android

- **Framework**: Room (recommended) wraps SQLite with compile-time verification
- **Storage**: Internal storage (`context.getDatabasePath()`)
- **WAL mode**: Default in Room since API 16
- **Threading**: Never query on main thread in production
- **Migration**: Room handles migration with `Migration` objects

```kotlin
// CORRECT: Room database with WAL
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
    .addMigrations(MIGRATION_1_2)
    .build()
```

### Electron

- **Process**: Run SQLite in main process only, expose via IPC
- **Library**: Use `better-sqlite3` (synchronous, faster, fewer bugs)
- **Storage**: `app.getPath('userData')` for persistent storage
- **Native modules**: Rebuild for Electron's Node.js version
- **Windows**: Handle backslash paths correctly

### Serverless (Lambda, Workers)

- **Storage**: `/tmp` is ephemeral — download database on cold start
- **Read-only**: Download from S3/R2 for read-only workloads
- **Read-write**: Use Turso/libSQL embedded replicas or Cloudflare D1
- **Size limit**: Lambda `/tmp` is 512MB default (up to 10GB)
- **Cold start**: Database download adds to cold start latency

## File Locking and Filesystem

### Network Filesystems (NEVER)

SQLite relies on POSIX file locking. Network filesystems do not reliably support this:

```text
NEVER use SQLite on:
  /mnt/nfs/...        NFS mount
  /Volumes/...        macOS network volume
  \\server\share\...  Windows UNC path (SMB)
  /mnt/cifs/...       CIFS mount

Consequences: silent data corruption, WAL failures, lock starvation
```

### Docker Volumes

```yaml
# CORRECT: Named volume (local filesystem)
services:
  app:
    volumes:
      - sqlite-data:/app/data
volumes:
  sqlite-data: # Local filesystem, reliable locks
```

```yaml
# WRONG: Network filesystem bind mount
services:
  app:
    volumes:
      - /mnt/nfs/data:/app/data # Unreliable locks!
```

### File Permissions

```bash
# CORRECT: Restrict database file access
chmod 640 app.db app.db-wal app.db-shm
chmod 750 /app/data/  # Directory must be writable for temp files
```

## Common Pitfalls

| Pitfall           | Cause                     | Solution                               |
| ----------------- | ------------------------- | -------------------------------------- |
| SQLITE_BUSY       | No busy_timeout           | `PRAGMA busy_timeout = 5000`           |
| FK not enforced   | Default is OFF            | `PRAGMA foreign_keys = ON`             |
| WAL file grows    | No size limit             | `PRAGMA journal_size_limit = 67108864` |
| Slow bulk inserts | Auto-commit per statement | Use explicit transactions              |
| Data corruption   | Network filesystem        | Use local storage only                 |
| Slow reads        | Missing indexes           | Use `EXPLAIN QUERY PLAN`               |
| Type coercion     | Non-STRICT table          | Use STRICT tables (3.37+)              |
