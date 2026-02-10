---
description: >
  Run Rust quality gates - clippy, fmt, test, deny/audit, with workspace detection
argument-hint: '[--quick] [--all-features]'
allowed-tools: 'Bash(cargo *), Bash(rustfmt *), Bash(git *), Read, Grep, Glob'
---

# Rust Validation Command

You are executing the `validate` command for a Rust project. This command runs a comprehensive suite
of quality gates to ensure code meets production standards before merging.

## Command Modes

### Full Mode (default)

Runs all quality gates in sequence:

1. `cargo clippy --all-targets -- -D warnings` - Lint with all warnings as errors
2. `cargo fmt --all -- --check` - Verify formatting
3. `cargo test` - Run the full test suite
4. Security audit: `cargo deny check` or `cargo audit` (whichever is available), or skip

#### Quick Mode (--quick flag)

Runs only fast checks for inner-loop development:

1. `cargo check` - Verify compilation
2. `cargo fmt --all -- --check` - Verify formatting

Quick mode skips tests, clippy, and security checks to provide rapid feedback during active
development.

#### All-Features Mode (--all-features flag)

When `--all-features` is passed, adds `--all-features` to cargo clippy, check, and test commands.
This is opt-in rather than default because many crates have mutually exclusive features that cannot
be enabled simultaneously.

## Execution Strategy

### Initial Setup

1. Detect project root by locating Cargo.toml
1. Determine if this is a workspace project (contains `[workspace]` in root Cargo.toml)
1. Detect available tools: clippy, rustfmt, cargo-deny, cargo-audit
1. Parse command arguments to determine mode and flags
1. Initialize result tracking for all gates

#### Workspace Detection

Check whether the project is a cargo workspace:

```bash
# Read root Cargo.toml to check for workspace
grep -q '\[workspace\]' Cargo.toml
```

If `[workspace]` is found, add `--workspace` to all cargo commands (clippy, check, test, fmt). This
ensures all workspace members are validated together.

```bash
# Workspace mode
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check
cargo test --workspace

# Single crate mode
cargo clippy --all-targets -- -D warnings
cargo fmt --all -- --check
cargo test
```

#### Tool Detection

Before running gates, check which tools are available:

```bash
# Check for clippy (should be installed via rustup)
rustup component list --installed | grep clippy

# Check for rustfmt
rustup component list --installed | grep rustfmt

# Check for cargo-deny (preferred security tool)
cargo deny --version 2>/dev/null

# Check for cargo-audit (fallback security tool)
cargo audit --version 2>/dev/null
```

If a tool is missing, skip that gate gracefully and report it. Never fail validation because a tool
is unavailable; only fail on actual code issues.

### Gate 1: Clippy Linting

#### Clippy Overview

Clippy is the definitive Rust style guide. Run it with all warnings treated as errors.

#### Running Clippy

```bash
# Without --all-features (default)
cargo clippy --all-targets -- -D warnings

# With --all-features
cargo clippy --all-targets --all-features -- -D warnings

# Workspace variant
cargo clippy --workspace --all-targets -- -D warnings
```

#### Clippy Warning Categories

Common categories of clippy warnings:

- **style**: Naming, formatting, unnecessary operations
- **complexity**: Overly complex expressions that can be simplified
- **perf**: Unnecessary allocations or inefficient patterns
- **correctness**: Likely bugs
- **pedantic**: Stricter rules (not enabled by default)

#### Handling Clippy Failures

When clippy reports warnings:

1. Report each warning with file location and explanation
1. Group warnings by category
1. Suggest fixes for common patterns
1. Never suggest blanket `#[allow(clippy::all)]` suppressions
1. If a lint must be suppressed, use the specific lint name with a comment

### Gate 2: Format Check

#### Format Check Overview

Verify all code is formatted according to rustfmt standards.

#### Running Format Check

```bash
# Check formatting without modifying files
cargo fmt --all -- --check
```

#### Handling Format Failures

When formatting violations are found:

1. Report which files need formatting
1. Show the diff if available
1. Offer to run `cargo fmt --all` to fix
1. Never auto-format without asking

### Gate 3: Test Suite

#### Test Suite Overview

Run the complete test suite including unit tests, integration tests, and doc tests.

#### Running Tests

```bash
# Default
cargo test

# With --all-features
cargo test --all-features

# Workspace variant
cargo test --workspace

# Verbose output for debugging failures
cargo test -- --nocapture
```

#### Parsing Test Output

Parse test output for:

- Total tests run, passed, failed, ignored
- Which specific tests failed and their error messages
- Any compilation errors in test code

#### Handling Test Failures

When tests fail:

1. Report each failing test with its error output
1. Check if the failure is a compilation error vs runtime assertion
1. Look for common patterns: stale test data, race conditions, missing test fixtures
1. Report test coverage if coverage tools are available

### Gate 4: Security Audit

#### Security Audit Overview

Check dependencies for known security vulnerabilities.

#### Security Tool Priority

Use `cargo deny` if available (comprehensive: licenses + advisories + bans). Fall back to
`cargo audit` (advisories only). Skip if neither is available.

#### Running Security Checks

```bash
# Preferred: cargo deny
cargo deny check

# Fallback: cargo audit
cargo audit

# If neither is available, skip with a notice
```

#### Interpreting Security Results

For cargo deny:

- **advisories**: Known CVEs in dependencies
- **licenses**: License compatibility issues
- **bans**: Forbidden dependencies
- **sources**: Unauthorized registries

For cargo audit:

- **vulnerabilities**: Known CVEs with severity levels
- **warnings**: Yanked or unmaintained crates

#### Handling Security Failures

When security issues are found:

1. Report each vulnerability with severity, affected crate, and advisory URL
1. Check if a patched version is available
1. Suggest `cargo update` if a patch exists
1. Note that some advisories may be false positives for the specific usage

## Output Format

### Report Structure

Present results in this format after all gates complete:

```text
## Validation Results

| Gate | Status | Details |
|------|--------|---------|
| Clippy | PASS | No warnings |
| Format | PASS | All files formatted |
| Tests | PASS | 142 passed, 0 failed, 3 ignored |
| Security | PASS | No advisories found |

Overall: PASS
```

For failures:

```text
## Validation Results

| Gate | Status | Details |
|------|--------|---------|
| Clippy | FAIL | 3 warnings (2 style, 1 complexity) |
| Format | PASS | All files formatted |
| Tests | FAIL | 140 passed, 2 failed, 3 ignored |
| Security | SKIP | cargo-deny not installed |

Overall: FAIL

### Clippy Warnings

1. `src/handler.rs:42` - unnecessary `clone()` on a reference (clippy::clone_on_ref_ptr)
2. `src/handler.rs:58` - this `if` has identical blocks (clippy::if_same_then_else)
3. `src/service.rs:15` - redundant closure (clippy::redundant_closure)

### Test Failures

1. `tests::handler::test_create_user` - assertion failed: expected 201, got 400
2. `tests::service::test_timeout` - task timed out after 5s
```

## Error Recovery

### Common Issues and Solutions

#### Compilation Errors

If `cargo check` or `cargo clippy` fails with compilation errors, stop immediately and report the
errors. Do not proceed to later gates since they will also fail.

#### Lock File Conflicts

If Cargo.lock is out of date:

```bash
cargo update
```

Report that the lock file was updated and re-run validation.

#### Missing Features

If `--all-features` fails because of mutually exclusive features, report the error and suggest
running without `--all-features`.

#### Flaky Tests

If a test passes on retry but failed initially:

1. Report it as a flaky test
1. Suggest investigating the root cause (race condition, time dependency, external service)
1. Count the retry pass as a pass but flag it for follow-up

## Workspace-Specific Behavior

### Multi-Crate Workspaces

For workspaces, validate all members together:

```bash
# List workspace members
cargo metadata --no-deps --format-version 1 | jq '.workspace_members[]'

# Run clippy across all members
cargo clippy --workspace --all-targets -- -D warnings

# Run tests across all members
cargo test --workspace
```

### Virtual Workspaces

Virtual workspaces (no root crate) are detected by the absence of `[package]` alongside
`[workspace]` in the root Cargo.toml. All commands use `--workspace` flag automatically.

### Per-Member Validation

If the workspace is large and a full validation is slow, consider validating only changed members.
Detect changed members by checking git diff against the base branch:

```bash
# Find changed files
git diff --name-only origin/main...HEAD

# Map changed files to workspace members
cargo metadata --no-deps --format-version 1 | \
    jq -r '.packages[] | "\(.manifest_path | rtrimstr("/Cargo.toml")) \(.name)"'
```

Cross-reference the changed files with workspace member paths to determine which crates need
validation. Always validate a member if any of its source files, Cargo.toml, or build.rs changed.

## Advanced Clippy Configuration

### Respecting Project Lint Configuration

Before running clippy, check if the project has lint configuration in Cargo.toml:

```bash
# Check for [lints.clippy] in Cargo.toml
grep -q '\[lints.clippy\]' Cargo.toml
```

If `[lints.clippy]` is configured, clippy will automatically use those settings. The `-D warnings`
flag ensures that any lint configured as `warn` is treated as an error during validation.

#### Workspace Lint Inheritance

In workspaces, check for lint inheritance:

```bash
# Check if workspace root defines lints
grep -q '\[workspace.lints\]' Cargo.toml

# Check if members inherit lints
grep -q 'workspace = true' crates/*/Cargo.toml
```

### Common Clippy Fix Patterns

When clippy reports issues, here are the most common fixes:

#### Unnecessary Clone

```text
warning: using `clone` on type which implements `Copy`
```

Fix: Remove `.clone()` and use the value directly. Copy types are implicitly copied.

#### Redundant Closure

```text
warning: redundant closure
```

Fix: Replace `|x| foo(x)` with `foo` when passing a function as a closure.

#### Single Match Arm

```text
warning: you seem to be trying to use `match` for destructuring
```

Fix: Replace `match` with `if let` when there is only one meaningful arm.

#### Missing Return Type

```text
warning: this function's return value is unnecessarily wrapped in `Result`
```

Fix: If a function can never fail, return the value directly instead of `Ok(value)`.

## Test Execution Details

### Test Parallelism

By default, `cargo test` runs tests in parallel using all available CPU cores. For tests that
require exclusive access to shared resources (files, ports, databases), use test serialization:

```bash
# Run tests sequentially
cargo test -- --test-threads=1
```

The validate command should use the default parallel execution unless tests fail with
non-deterministic errors, in which case it should retry with `--test-threads=1` and report the
potential concurrency issue.

### Doc Test Compilation

Doc tests are compiled as independent programs and are slower than unit tests. If doc tests fail
with import errors, check that the documented examples use the correct crate name and that all
dependencies are available.

```bash
# Run only doc tests
cargo test --doc

# Run only unit and integration tests (skip doc tests)
cargo test --lib --tests
```

### Test Output Parsing

Parse cargo test output to extract statistics:

```text
running 42 tests
test service::tests::create_user ... ok
test service::tests::delete_user ... ok
test service::tests::update_user ... FAILED
test handler::tests::health_check ... ok

failures:

---- service::tests::update_user stdout ----
thread 'service::tests::update_user' panicked at 'assertion failed: `(left == right)`
  left: `"Alice"`,
 right: `"Bob"`'

test result: FAILED. 41 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out
```

Extract:

- **passed**: Number after "passed" in the result line
- **failed**: Number after "failed" in the result line
- **ignored**: Number after "ignored" in the result line
- **failure details**: Everything between "failures:" and "test result:"

## Pre-Validation Checks

### Ensure Clean Working Directory

Before running validation, check if there are uncommitted changes that might affect results:

```bash
git status --porcelain
```

Warn the user if there are unstaged changes, as validation results may not match what would be
tested in CI.

### Verify Toolchain Version

Report the active Rust toolchain for reproducibility:

```bash
rustc --version
cargo --version
```

If the project specifies `rust-version` in Cargo.toml, verify the active toolchain meets the MSRV
requirement:

```bash
# Extract rust-version from Cargo.toml
grep 'rust-version' Cargo.toml
```

### Check for Build Scripts

If the project has a `build.rs`, note that clippy and tests may require external tools or system
libraries. Compilation failures from build scripts should be reported separately from lint or test
failures.

```bash
# Detect build scripts
test -f build.rs && echo "build script detected"
find . -path '*/build.rs' -not -path './target/*' 2>/dev/null
```

## Continuous Integration Guidance

### CI-Equivalent Validation

The validate command should produce the same results as a CI pipeline. To ensure equivalence:

1. Use `--locked` to prevent Cargo.lock changes during validation
1. Use `--frozen` in offline environments
1. Set `CARGO_INCREMENTAL=0` for reproducible builds

```bash
# CI-like validation
CARGO_INCREMENTAL=0 cargo clippy --workspace --all-targets --locked -- -D warnings
cargo fmt --all -- --check
CARGO_INCREMENTAL=0 cargo test --workspace --locked
cargo deny check
```

### Environment Variables

Report relevant environment variables that may affect validation:

- `RUSTFLAGS`: Additional compiler flags
- `CARGO_INCREMENTAL`: Incremental compilation toggle
- `RUST_BACKTRACE`: Backtrace behavior on panics
- `CARGO_TERM_COLOR`: Color output setting
