# Plugin: ccfg-golang

The Go language plugin. Provides framework agents for web and RPC development, specialist agents for
testing and concurrency, project scaffolding, autonomous coverage improvement, and opinionated
conventions for consistent Go development with golangci-lint, gofumpt, and go modules.

## Directory Structure

```text
plugins/ccfg-golang/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── golang-pro.md
│   ├── gin-developer.md
│   ├── grpc-developer.md
│   ├── go-test-specialist.md
│   └── concurrency-specialist.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
└── skills/
    ├── go-conventions/
    │   └── SKILL.md
    ├── testing-patterns/
    │   └── SKILL.md
    └── module-conventions/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-golang",
  "description": "Go language plugin: framework and specialist agents, project scaffolding, coverage automation, and conventions for consistent development with golangci-lint, gofumpt, and go modules",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["go", "golang", "gin", "grpc", "golangci-lint", "gofumpt"]
}
```

## Agents (5)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent            | Role                                                                     | Model  |
| ---------------- | ------------------------------------------------------------------------ | ------ |
| `golang-pro`     | Modern Go 1.22+, generics, error handling, stdlib patterns, idiomatic Go | sonnet |
| `gin-developer`  | Gin/Echo/Chi web APIs, middleware, routing, request validation, OpenAPI  | sonnet |
| `grpc-developer` | gRPC services, protobuf schema design, streaming, interceptors, Connect  | sonnet |

### Specialist Agents

| Agent                    | Role                                                                                                       | Model  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- | ------ |
| `go-test-specialist`     | Table-driven tests, testify, gomock, httptest, benchmarks, fuzzing, golden files, test fixtures            | sonnet |
| `concurrency-specialist` | Goroutines, channels, sync primitives, errgroup, context propagation, race condition prevention, profiling | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-golang:validate

**Purpose**: Run the full Go quality gate suite in one command.

**Trigger**: User invokes before committing or shipping Go code.

**Allowed tools**:
`Bash(go *), Bash(golangci-lint *), Bash(gofumpt *), Bash(govulncheck *), Bash(task *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Vet**: `go vet ./...`
2. **Format check**: `gofumpt -l .` (list unformatted files)
3. **Tests**: `go test ./... -v -race`
4. **Lint**: `golangci-lint run`
5. **Vuln check**: `govulncheck ./...` (if installed, skip with notice if not)
6. Report pass/fail for each gate with output
7. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Build**: `go build ./...` (compilation check only)
2. **Vet**: `go vet ./...`
3. **Format check**: `gofumpt -l .`
4. Report pass/fail — skips tests, lint, and vuln check for speed

**Key rules**:

- Full mode always runs tests with `-race` flag
- Quick mode is for inner-loop iteration (~2s vs ~30s+)
- Uses `task` (Taskfile) when available, falls back to direct commands
- Fix the root cause instead of adding `nolint`. If a `nolint` is genuinely necessary (false
  positive, intentionally-ignored error, generated code), require `//nolint:<linter> // reason` with
  both linter name and explanation. Never add bare `nolint`
- Reports all gate results, not just the first failure
- Detect-and-skip: if a tool is not installed (e.g., `golangci-lint`, `govulncheck`), skip that gate
  and report it as SKIPPED. Never fail because an optional tool is missing

### /ccfg-golang:scaffold

**Purpose**: Initialize a new Go project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new Go project or service.

**Allowed tools**: `Bash(go *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<module-path> [--type=service|library|cli]`

**Behavior**:

1. Create project directory with standard Go layout:

   ```text
   <name>/
   ├── cmd/<name>/
   │   └── main.go
   ├── internal/
   │   └── .gitkeep
   ├── pkg/
   │   └── .gitkeep
   ├── go.mod
   ├── go.sum
   ├── Taskfile.yml
   ├── .golangci.yml
   ├── .gitignore
   └── README.md
   ```

2. Generate `go.mod` with module path and Go version
3. Generate `.golangci.yml` with opinionated linter set (errcheck, govet, staticcheck, revive,
   gosec, ineffassign, misspell)
4. Generate `Taskfile.yml` with targets: test, lint, fmt, build, coverage
5. Scaffold differs by type:
   - `service`: adds HTTP/gRPC server skeleton, health endpoint, graceful shutdown
   - `library`: adds public API in `pkg/`, example usage
   - `cli`: adds Cobra skeleton with root command
6. Initialize with `go mod tidy` and verify `go test ./...` passes

**Key rules**:

- Uses `cmd/` + `internal/` + `pkg/` layout
- Includes Taskfile.yml (not Makefile) as build runner
- Configures golangci-lint with strict linter set
- main.go includes graceful shutdown pattern for services

### /ccfg-golang:coverage

**Purpose**: Autonomous per-package test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**: `Bash(go *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**: `[--threshold=90] [--package=<path>] [--dry-run] [--no-commit]`

**Behavior**:

1. **Measure**: Run `go test ./... -coverprofile=coverage.out` then
   `go tool cover -func=coverage.out`
2. **Identify**: Parse output, rank packages by uncovered functions (most gaps first). Within each
   package, identify specific files and functions with the lowest coverage
3. **Target**: For each under-threshold package: a. Read the source files and existing tests b.
   Identify untested functions, branches, and edge cases at the function level c. Write table-driven
   tests following project's existing test patterns d. Run `go test ./...` to confirm new tests pass
   e. Run `golangci-lint run` on new test files f. Commit:
   `git add <test-file> && git commit -m "test: add coverage for <package>"`
4. **Report**: Summary table of before/after coverage per package
5. Clean up: `rm coverage.out`

**Modes**:

- **Default**: Write tests and auto-commit after each package
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Reads existing tests first to match project patterns (table-driven, testify, etc.)
- One commit per package (not one giant commit)
- Tests must exercise real behavior with meaningful assertions
- Always uses table-driven test pattern for multiple cases
- Tests run with `-race` flag
- Targets functions, not just packages — prioritize specific uncovered functions within each package
  for precise coverage improvement

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### go-conventions

**Trigger description**: "This skill should be used when working on Go projects, writing Go code,
running Go tests, managing Go dependencies, or reviewing Go code."

**Existing repo compatibility**: For existing projects, respect the established toolchain, directory
layout, and conventions. If the project uses a Makefile instead of Taskfile, use `make`. If the
project uses a different linter configuration, follow it. These preferences apply to new projects
and scaffold output only.

**Error handling rules**:

- Always check returned errors. Never `_ = err`
- Use `fmt.Errorf("context: %w", err)` for error wrapping
- Define sentinel errors with `errors.New` at package level
- Use `errors.Is` and `errors.As` for error checking, never string comparison
- Return errors, don't panic. Reserve `panic` for truly unrecoverable states

**Code style rules**:

- Use `gofumpt` for formatting (stricter than `gofmt`)
- Use `golangci-lint` for linting (not individual linters)
- Prefer stdlib over third-party where comparable (e.g., `net/http` over Gin for simple cases)
- Use `context.Context` as first parameter for functions that may block or need cancellation
- Receiver names: short, consistent, never `this` or `self`
- Interface names: verb-er pattern (`Reader`, `Writer`, `Closer`)
- Unexported by default. Only export what the package API requires
- Use `enum` pattern with `iota` for related constants
- Use struct embedding for composition, not inheritance-style patterns

**Tooling rules**:

- Use `task` (Taskfile) for build/test/lint commands where available
- Use `gofumpt` for formatting, `golangci-lint` for linting
- Run `go mod tidy` after dependency changes
- Run `govulncheck ./...` periodically to check for known vulnerabilities in dependencies

**`go generate` hygiene**:

- Generated files must include the `// Code generated by <tool>; DO NOT EDIT.` header
- Commit generated files to the repository
- In CI, run `go generate ./...` and verify no diff — stale generated files are a common source of
  bugs
- Document generators in `//go:generate` comments above the relevant code

### testing-patterns

**Trigger description**: "This skill should be used when writing Go tests, creating test fixtures,
benchmarks, table-driven tests, mocking dependencies, or improving test coverage."

**Contents**:

- **Table-driven tests**: Default pattern for all tests with multiple cases. Use `tt` as loop
  variable. Name test cases descriptively
- **Naming**: Test files: `<file>_test.go` in same package. Test functions:
  `Test<Function>_<scenario>`. Benchmark functions: `Benchmark<Function>`
- **testify**: Use `require` for fatal assertions (stops test), `assert` for non-fatal. Prefer
  `require.NoError` over `assert.NoError` for error checks
- **httptest**: Use `httptest.NewServer` for integration tests, `httptest.NewRecorder` for handler
  unit tests
- **gomock**: Generate mocks with `mockgen`. Keep mock definitions in `internal/mocks/`. Use
  `gomock.InOrder` for sequence verification
- **Subtests**: Use `t.Run("name", func(t *testing.T) {...})` for grouping related test cases
- **Test helpers**: Use `t.Helper()` in all test helper functions for correct line reporting
- **Benchmarks**: Use `b.ResetTimer()` after setup. Report allocations with `b.ReportAllocs()`
- **Fuzzing**: Use `f.Fuzz` for input-dependent functions. Seed corpus with known edge cases
- **Parallel**: Mark independent tests with `t.Parallel()` for faster execution
- **Golden files**: Use `testdata/` directory for fixture files and expected outputs

### module-conventions

**Trigger description**: "This skill should be used when creating or editing go.mod, managing Go
dependencies, configuring Go modules, or organizing Go packages and module boundaries."

**Contents**:

- **Module path**: Use full repository path (e.g., `github.com/org/repo`). Internal tools can use
  shorter paths
- **Go version**: Specify minimum Go version in `go.mod`. Use `.go-version` for toolchain pinning
- **Dependencies**: Run `go mod tidy` after changes. Audit with `go mod verify`. Use
  `go mod why <dep>` to check if a dependency is actually needed
- **Replace directives**: Use only for local development. Never commit `replace` directives pointing
  to local paths
- **Package organization**: `cmd/` for entry points, `internal/` for private packages, `pkg/` for
  public packages. Keep packages small and focused
- **Versioning**: Use semantic versioning with `v` prefix tags. For v2+, update module path to
  include major version suffix (`/v2`)
- **Vendoring**: Prefer module proxy over vendoring. Use `go mod vendor` only when reproducibility
  requires it
- **Multi-module repos**: Avoid when possible. If needed, each module gets its own `go.mod` at its
  root directory
- **Workspaces**: For multi-module local development, use `go work` to create a workspace file
  (`go.work`). Add `go.work` and `go.work.sum` to `.gitignore` — workspace files are
  developer-local, not committed
