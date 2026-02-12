## MySQL Conventions

- Use InnoDB engine for all tables (ACID transactions)
- Primary keys: unsigned BIGINT AUTO_INCREMENT
- Always define CHARACTER SET utf8mb4, COLLATE utf8mb4_unicode_ci
- Index foreign keys and columns used in WHERE/JOIN/ORDER BY
- Use prepared statements — never concatenate user input into SQL
- Migrations: versioned, forward-only, idempotent
- Naming: snake_case for tables and columns, singular table names
- Avoid SELECT \* — always list columns explicitly
