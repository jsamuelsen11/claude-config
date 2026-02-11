## PostgreSQL Conventions

- Use native types: UUID, JSONB, TIMESTAMPTZ, INET, ARRAY
- Primary keys: UUID with gen_random_uuid() or BIGINT GENERATED ALWAYS
- Always use TIMESTAMPTZ (not TIMESTAMP) for time data
- Index strategy: B-tree default, GIN for JSONB/arrays, GiST for geometry
- Use prepared statements — never concatenate user input into SQL
- Migrations: versioned, forward-only, wrap DDL in transactions
- Naming: snake_case, singular table names, `_id` suffix for foreign keys
- Prefer CTEs over nested subqueries for readability
