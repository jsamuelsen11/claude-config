## Go Conventions

- Toolchain: go modules, golangci-lint (lint), gofumpt (format), go test (test)
- Always check errors — never use `_` for error returns
- Wrap errors with `fmt.Errorf("context: %w", err)`
- Accept interfaces, return structs
- Use table-driven tests with `t.Run()` subtests
- Context: first parameter, never store in structs
- Naming: MixedCaps (exported), mixedCaps (unexported), no underscores
- Concurrency: prefer channels over shared memory with mutexes
