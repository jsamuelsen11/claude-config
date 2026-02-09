---
description: Run Go quality gates - vet, format, test, lint, vuln check
argument-hint: '[--quick]'
allowed-tools:
  'Bash(go *), Bash(golangci-lint *), Bash(gofumpt *), Bash(govulncheck *), Bash(task *), Bash(git
  *), Read, Grep, Glob'
---

# Go Validation Command

You are executing the `validate` command for a Go project. This command runs a comprehensive suite
of quality gates to ensure code meets production standards.

## Command Modes

### Full Mode (default)

Runs all quality gates in sequence:

1. `go vet ./...` - Static analysis for common mistakes
2. `gofumpt -l .` - Format checking (stricter than gofmt)
3. `go test ./... -v -race` - Full test suite with race detector
4. `golangci-lint run` - Comprehensive linting
5. `govulncheck ./...` - Vulnerability scanning (if installed)

#### Quick Mode (--quick flag)

Runs only fast checks for inner-loop development:

1. `go build ./...` - Verify compilation
2. `go vet ./...` - Static analysis
3. `gofumpt -l .` - Format checking

Quick mode skips tests, linting, and vulnerability checks to provide rapid feedback during active
development.

## Execution Strategy

### Initial Setup

1. Detect project root by locating go.mod file
1. Check if Taskfile.yml exists and contains validation targets
1. Detect available tools: gofumpt, golangci-lint, govulncheck
1. Parse command arguments to determine mode
1. Initialize result tracking for all gates

#### Tool Detection

Before running gates, check which tools are available:

```bash
# Check for gofumpt (preferred formatter)
which gofumpt

# Check for golangci-lint
which golangci-lint

# Check for govulncheck
which govulncheck

# Check for Taskfile
which task
```

If a tool is missing, skip that gate gracefully and report it. Never fail validation because a tool
is unavailable - only fail on actual code issues.

#### Taskfile Integration

If a Taskfile.yml exists, check for these targets:

1. `task --list` to enumerate available tasks
1. Look for: `vet`, `fmt`, `test`, `lint`, `vuln`, `validate`
1. If `task validate` exists, offer to use it instead of individual commands
1. Otherwise, use individual task targets when available

Example Taskfile detection:

```bash
task --list 2>/dev/null | grep -E "^  (validate|vet|fmt|test|lint|vuln):"
```

## Quality Gate Execution

### Gate 1: Go Vet

Run static analysis to catch common programming errors.

```bash
go vet ./...
```

Expected successful output:

```text
# No output means success
```

Expected failure output:

```text
# github.com/user/project/internal/service
internal/service/handler.go:45:2: Printf format %s reads arg #1, but call has 0 args
```

Error handling:

1. If vet fails, capture the error output
1. Parse file paths and line numbers
1. Report specific issues found
1. Continue to next gate (don't stop on first failure)

Common vet errors to explain:

1. Printf format mismatches - explain the format string issue
1. Unreachable code - explain control flow problem
1. Shadowed variables - explain scope issue
1. Composite literal uses unkeyed fields - explain struct initialization

#### Gate 2: Format Checking

Check code formatting using gofumpt (stricter than gofmt).

```bash
gofumpt -l .
```

If gofumpt is not available, fall back to gofmt:

```bash
gofmt -l .
```

Expected successful output:

```text
# No output means all files are formatted
```

Expected failure output:

```text
cmd/server/main.go
internal/service/handler.go
pkg/models/user.go
```

Error handling:

1. If files are listed, formatting is incorrect
1. Offer to fix automatically with `gofumpt -w .`
1. Count total files needing formatting
1. In quick mode, report but don't auto-fix
1. Continue to next gate

Auto-fix suggestion:

```text
Found 3 files with formatting issues. Run: gofumpt -w .
```

#### Gate 3: Build Check (Quick Mode Only)

In quick mode, verify the project compiles:

```bash
go build ./...
```

Expected successful output:

```text
# No output or package names only
```

Expected failure output:

```text
# github.com/user/project/internal/service
internal/service/handler.go:23:15: undefined: context.Context
```

Error handling:

1. Parse compilation errors with file/line information
1. Report specific build failures
1. This is a critical failure - mark validation as failed

#### Gate 4: Test Suite (Full Mode Only)

Run the full test suite with race detection:

```bash
go test ./... -v -race -timeout=10m
```

Use shorter timeout for smaller projects:

```bash
go test ./... -v -race -timeout=5m
```

Expected successful output:

```text
=== RUN   TestUserService
=== RUN   TestUserService/Create
=== RUN   TestUserService/Update
--- PASS: TestUserService (0.23s)
    --- PASS: TestUserService/Create (0.12s)
    --- PASS: TestUserService/Update (0.11s)
PASS
ok      github.com/user/project/internal/service    0.234s
```

Expected failure output:

```text
=== RUN   TestUserService
=== RUN   TestUserService/Create
    handler_test.go:45: Expected user ID to be 123, got 124
--- FAIL: TestUserService (0.12s)
    --- FAIL: TestUserService/Create (0.12s)
FAIL
FAIL    github.com/user/project/internal/service    0.125s
```

Race detector output:

```text
==================
WARNING: DATA RACE
Write at 0x00c0001a0180 by goroutine 8:
  github.com/user/project/internal/service.(*Handler).Update()
      /home/user/project/internal/service/handler.go:89 +0x123

Previous read at 0x00c0001a0180 by goroutine 7:
  github.com/user/project/internal/service.(*Handler).Get()
      /home/user/project/internal/service/handler.go:67 +0x89
==================
```

Error handling:

1. Capture test failures with package, test name, and error message
1. If race detector triggers, treat as critical failure
1. Parse race detector output to identify conflicting goroutines
1. Report timeout if tests exceed deadline
1. Continue to next gate even on failure

Race condition detection:

1. Look for "WARNING: DATA RACE" in output
1. Extract the conflicting code locations
1. Explain that race conditions must be fixed before merge
1. Suggest running specific package tests with -race for debugging

Test timeout handling:

1. If tests timeout, suggest running packages individually
1. Identify which package was running when timeout occurred
1. Recommend increasing timeout or optimizing slow tests

#### Gate 5: Linting (Full Mode Only)

Run comprehensive linting with golangci-lint:

```bash
golangci-lint run ./...
```

If .golangci.yml exists, it will be used automatically. Otherwise, use default linters.

Expected successful output:

```text
# No output or summary line only
```

Expected failure output:

```text
internal/service/handler.go:45:2: Error return value is not checked (errcheck)
    defer file.Close()
    ^
internal/service/handler.go:67:1: exported function `CreateUser` should have comment or be unexported (revive)
func CreateUser(ctx context.Context, req *CreateUserRequest) (*User, error) {
^
pkg/models/user.go:23:1: ST1003: struct field `UserID` should be `UserID` (stylecheck)
type User struct {
```

Error handling:

1. Parse linter output by file, line, and linter name
1. Group issues by severity: error vs warning
1. Count total issues and issues per linter
1. Explain common issues and how to fix them
1. Never suggest adding `//nolint` - fix the root cause
1. Continue to next gate

Common linter issues to explain:

1. errcheck - always check error returns or explicitly ignore with `_ = fn()`
1. revive/golint - add documentation for exported symbols
1. stylecheck - follow Go naming conventions
1. govet - use composite literal with field names
1. gosec - security issues must be addressed
1. ineffassign - remove unused assignments
1. staticcheck - various static analysis issues

Linter configuration detection:

1. Check if .golangci.yml exists
1. If found, note which linters are enabled
1. Report if using strict or permissive configuration
1. Suggest enabling recommended linters if config is minimal

#### Gate 6: Vulnerability Check (Full Mode Only)

Run vulnerability scanning if govulncheck is installed:

```bash
govulncheck ./...
```

Expected successful output:

```text
No vulnerabilities found.
```

Expected failure output:

```text
Vulnerability #1: GO-2023-1234
    Package: golang.org/x/text
    Version: v0.3.7
    Fixed in: v0.3.8
    Details: https://pkg.go.dev/vuln/GO-2023-1234

    Call stacks in your code:
    internal/service/handler.go:45:18
```

Error handling:

1. If govulncheck is not installed, skip gracefully
1. Parse vulnerability reports with GO-ID, package, and version
1. Extract fixed version information
1. Report call stacks showing where vulnerable code is used
1. Suggest running `go get -u` to update dependencies
1. Mark as critical failure if vulnerabilities found

Vulnerability reporting:

1. Count total vulnerabilities by severity
1. Group by package for clarity
1. Provide upgrade commands for each vulnerable dependency
1. Link to vulnerability database for details

## Result Reporting

After all gates complete, provide a comprehensive summary.

### Success Report Format

```text
=== Go Validation: PASSED ===

✓ go vet        PASSED (0.8s)
✓ format check  PASSED (0.3s)
✓ tests         PASSED (12.4s) - 47 tests, 89% coverage
✓ linting       PASSED (3.2s)
✓ vuln check    PASSED (1.1s)

Total time: 17.8s
All quality gates passed. Code is ready for commit/merge.
```

#### Failure Report Format

```text
=== Go Validation: FAILED ===

✓ go vet        PASSED (0.8s)
✗ format check  FAILED (0.3s) - 3 files need formatting
✗ tests         FAILED (8.2s) - 2 failures, 1 race condition
✗ linting       FAILED (3.1s) - 12 issues (8 errcheck, 4 revive)
✓ vuln check    PASSED (1.2s)

Total time: 13.6s

Critical issues found:
1. Race condition in internal/service/handler.go:89
2. Test failures in internal/service package
3. 12 linting issues must be resolved

Fix these issues before committing.
```

#### Quick Mode Report Format

```text
=== Go Validation: PASSED (quick mode) ===

✓ build         PASSED (1.2s)
✓ go vet        PASSED (0.7s)
✓ format check  PASSED (0.2s)

Total time: 2.1s
Quick validation passed. Run full validation before merge.
```

#### Detailed Issue Reporting

For each failed gate, provide actionable details:

Format issues:

```text
Format Check Details:
  3 files need formatting:
    - cmd/server/main.go
    - internal/service/handler.go
    - pkg/models/user.go

  Fix with: gofumpt -w .
```

Test failures:

```text
Test Failure Details:
  Package: internal/service
  Test: TestUserService/Create
  File: handler_test.go:45
  Error: Expected user ID to be 123, got 124

  Package: internal/service
  Test: TestUserService/Update
  File: handler_test.go:67
  Race condition detected between:
    - handler.go:89 (write)
    - handler.go:67 (read)
```

Linting issues:

```text
Linting Issue Details:
  errcheck (8 issues):
    - internal/service/handler.go:45 - defer file.Close()
    - internal/service/handler.go:78 - rows.Close()
    Fix: Always check errors or explicitly ignore with _ = fn()

  revive (4 issues):
    - internal/service/handler.go:67 - exported function needs comment
    - pkg/models/user.go:12 - exported type needs comment
    Fix: Add godoc comments for all exported symbols
```

## Configuration File Detection

Check for and respect project configuration files.

### golangci-lint Configuration

Look for .golangci.yml, .golangci.yaml, or .golangci.toml:

```bash
ls -la .golangci.{yml,yaml,toml} 2>/dev/null
```

If found, note which linters are enabled:

```bash
golangci-lint linters
```

Report configuration in summary:

```text
Using golangci-lint config: .golangci.yml
Enabled linters: errcheck, gosimple, govet, ineffassign, staticcheck, unused, revive, stylecheck
```

#### Test Configuration

Check for custom test flags in go.mod or Taskfile:

1. Look for `//go:build` tags that might affect test selection
1. Check Taskfile for test target with custom flags
1. Respect existing timeout configurations

## Error Recovery Patterns

### Build Failures

If `go build` fails:

1. Check for missing dependencies: suggest `go mod tidy`
1. Check for syntax errors: report exact location
1. Check for type errors: explain the type mismatch
1. Don't continue to other gates if build fails

#### Module Issues

If module errors occur:

```bash
# Fix common module issues
go mod download
go mod tidy
go mod verify
```

#### Tool Installation

If required tools are missing, provide installation instructions:

gofumpt:

```bash
go install mvdan.cc/gofumpt@latest
```

golangci-lint:

```bash
# Install latest version
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
```

govulncheck:

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
```

## Performance Optimization

### Parallel Execution

Where possible, run independent checks in parallel:

1. `go vet` and `gofumpt -l` can run simultaneously
1. Never parallelize tests (they may conflict)
1. `govulncheck` can run in parallel with linting

#### Caching

Leverage Go's build cache:

1. Tests benefit from cached builds
1. `go vet` uses cached analysis
1. Don't clear cache unless explicitly requested

#### Incremental Validation

For large projects, consider package-level validation:

```bash
# Validate only changed packages
go list -f '{{.Dir}}' ./... | grep -E "(internal|pkg)" | xargs -L1 go vet
```

## Common Patterns

### CI/CD Integration

This command is designed for CI pipelines:

```yaml
# Example GitHub Actions usage
- name: Validate Go code
  run: claude-code ccfg-golang validate
```

Full mode is appropriate for CI. Quick mode is for local development.

#### Pre-commit Hook

Use quick mode for pre-commit validation:

```bash
#!/bin/bash
# .git/hooks/pre-commit
claude-code ccfg-golang validate --quick
```

#### Development Workflow

Recommended workflow:

1. Make changes
1. Run `validate --quick` frequently
1. Before commit, run full `validate`
1. Fix all issues before pushing

## Exit Codes

Return appropriate exit codes for scripting:

1. `0` - All gates passed
1. `1` - One or more gates failed
1. `2` - Command error (invalid arguments, missing go.mod)

## Advanced Scenarios

### Monorepo Support

For monorepos with multiple Go modules:

1. Detect all go.mod files in subdirectories
1. Run validation for each module independently
1. Report per-module results
1. Fail if any module fails validation

```bash
find . -name go.mod -type f -exec dirname {} \; | while read dir; do
  (cd "$dir" && go vet ./...)
done
```

#### Custom Test Flags

Respect environment variables for test customization:

```bash
# Support custom test flags
${GOTEST_FLAGS:--v -race -timeout=10m}
```

#### Selective Linting

If linting takes too long, support package filtering:

```bash
# Lint only changed packages
golangci-lint run ./internal/... ./pkg/...
```

## Best Practices Enforcement

### Non-Negotiable Rules

1. Always run tests with `-race` flag in full mode
1. Never suggest `//nolint` directives - fix the issue
1. Format issues must be fixed, not ignored
1. Race conditions are critical failures
1. Vulnerabilities must be addressed

#### Code Quality Standards

1. Test coverage should be reported when available
1. All exported symbols must have documentation
1. Error returns must be checked
1. Use proper error wrapping with `fmt.Errorf`
1. Follow effective Go guidelines

#### Security Requirements

1. Run `govulncheck` when available
1. Report gosec security findings as critical
1. Never suggest disabling security checks
1. Encourage updating vulnerable dependencies

## Output Formatting

Use consistent formatting for readability:

1. Gate names aligned and prefixed with checkmark/X
1. Timing information in parentheses
1. File paths relative to project root
1. Line numbers included for all issues
1. Clear separation between gates
1. Summary section at the end

## Tool-Specific Guidance

### gofumpt vs gofmt

Prefer gofumpt (stricter formatting):

1. Groups imports properly
1. Removes extra empty lines
1. Enforces consistent style

Fall back to gofmt only if gofumpt unavailable.

#### golangci-lint Best Practices

1. Use `.golangci.yml` for configuration
1. Enable at least: errcheck, gosimple, govet, ineffassign, staticcheck, unused
1. Recommended additions: revive, stylecheck, gosec
1. Avoid disabling linters without good reason

#### govulncheck Usage

1. Run regularly (daily in CI)
1. Fail builds on HIGH/CRITICAL vulnerabilities
1. Document exceptions if update not possible
1. Check both direct and indirect dependencies

## Final Validation

Before reporting results:

1. Ensure all gates were attempted (or skipped with reason)
1. Provide clear pass/fail for each gate
1. Include timing information
1. Give actionable next steps
1. Return appropriate exit code
