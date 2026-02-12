## SQLite Conventions

- Enable WAL mode: `PRAGMA journal_mode=WAL`
- Set `PRAGMA foreign_keys=ON` at every connection open
- Use `PRAGMA busy_timeout=5000` to handle concurrent access
- Transactions: wrap bulk inserts in explicit BEGIN/COMMIT
- Use parameterized queries — never concatenate user input
- Naming: snake_case, singular table names
- Keep database file in a writable directory with proper permissions
- Avoid excessive VACUUM — WAL mode handles most fragmentation
