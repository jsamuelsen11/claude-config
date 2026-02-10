---
description: >
  Autonomous per-module test coverage improvement loop for Rust projects
argument-hint: '[--threshold=90] [--module=<path>] [--dry-run] [--no-commit] [--llvm-cov]'
allowed-tools: 'Bash(cargo *), Bash(git *), Read, Write, Edit, Grep, Glob'
---

# Rust Coverage Improvement Command

You are executing the `coverage` command to autonomously improve test coverage across a Rust project
by analyzing gaps and generating comprehensive tests.

## Command Arguments

### Optional: --threshold

Minimum coverage percentage to achieve (default: 90).

```bash
ccfg-rust coverage --threshold=85
```

#### Optional: --module

Target a specific module instead of the entire project.

```bash
ccfg-rust coverage --module=src/service.rs
```

#### Optional: --dry-run

Report coverage gaps without generating tests.

```bash
ccfg-rust coverage --dry-run
```

#### Optional: --no-commit

Generate tests but do not auto-commit changes.

```bash
ccfg-rust coverage --no-commit
```

#### Optional: --llvm-cov

Use cargo-llvm-cov instead of the default cargo-tarpaulin.

```bash
ccfg-rust coverage --llvm-cov
```

## Execution Strategy

### Phase 1: Tool Detection

Determine which coverage tool is available and select it.

#### Default: cargo-tarpaulin

```bash
# Check for tarpaulin
cargo tarpaulin --version 2>/dev/null
```

If tarpaulin is available and `--llvm-cov` was not passed, use tarpaulin.

#### On Request: cargo-llvm-cov

```bash
# Check for llvm-cov
cargo llvm-cov --version 2>/dev/null
```

Use llvm-cov when `--llvm-cov` is passed. If the requested tool is not installed, report the
installation command and exit:

```bash
# Install tarpaulin
cargo install cargo-tarpaulin

# Install llvm-cov
cargo install cargo-llvm-cov
rustup component add llvm-tools-preview
```

### Phase 2: Baseline Coverage Measurement

Measure current coverage and produce a JSON report for parsing.

#### Tarpaulin JSON Output

```bash
# Full project coverage with JSON output
cargo tarpaulin --out json --output-dir coverage/ --skip-clean

# Specific module
cargo tarpaulin --out json --output-dir coverage/ --skip-clean \
    --files 'src/service.rs'
```

Parse the JSON output to extract per-file coverage:

```json
{
  "files": [
    {
      "path": "src/service.rs",
      "content": "...",
      "traces": [
        { "line": 10, "stats": { "Line": 1 } },
        { "line": 11, "stats": { "Line": 0 } }
      ],
      "covered": 45,
      "coverable": 60
    }
  ]
}
```

#### LLVM-Cov JSON Output

```bash
# Full project coverage with JSON output
cargo llvm-cov --json --output-path coverage/report.json

# Specific module
cargo llvm-cov --json --output-path coverage/report.json \
    -- --test-threads=1
```

Parse the LLVM-cov JSON format:

```json
{
  "data": [
    {
      "files": [
        {
          "filename": "src/service.rs",
          "summary": {
            "lines": { "count": 60, "covered": 45, "percent": 75.0 }
          }
        }
      ]
    }
  ]
}
```

### Phase 3: Gap Analysis

#### Per-File Coverage Ranking

After parsing the JSON output, rank files by coverage gap (difference between current coverage and
the threshold):

```text
## Coverage Report

| File | Lines | Covered | Coverage | Gap |
|------|-------|---------|----------|-----|
| src/error.rs | 40 | 15 | 37.5% | 52.5% |
| src/service.rs | 60 | 45 | 75.0% | 15.0% |
| src/handler.rs | 80 | 72 | 90.0% | 0.0% |
| src/config.rs | 20 | 20 | 100.0% | 0.0% |

Overall: 78.5% (threshold: 90%)
```

If `--dry-run` is passed, stop here and report the gaps.

#### Identifying Untested Code

For each file below threshold:

1. Read the source file to understand its structure
1. Identify functions, methods, and branches without coverage
1. Prioritize by impact: public API first, then internal logic
1. Check for existing test patterns in the module's `#[cfg(test)]` block

### Phase 4: Test Generation

#### Matching Existing Patterns

Before writing tests, analyze existing tests in the project to match their style:

1. Look for `#[cfg(test)]` modules in the same file
1. Check `tests/` directory for integration test patterns
1. Note naming conventions (snake_case test names starting with a verb)
1. Note use of helper functions, builders, or fixtures
1. Check if the project uses proptest, mockall, or other testing crates

#### Writing Unit Tests

Add tests to the existing `#[cfg(test)]` module in each file, or create one if it does not exist.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_valid_input_returns_expected_output() {
        let result = parse("valid input").unwrap();
        assert_eq!(result.field, "expected");
    }

    #[test]
    fn parse_empty_input_returns_error() {
        let result = parse("");
        assert!(result.is_err());
    }

    #[test]
    fn parse_malformed_input_returns_specific_error() {
        let result = parse("malformed");
        assert!(matches!(result, Err(ParseError::InvalidFormat(_))));
    }
}
```

#### Test Quality Rules

1. Each test verifies one behavior
1. Test names describe what is being verified (verb + condition + expected outcome)
1. Cover happy path, error cases, and boundary conditions
1. Use `assert_eq!` for value comparisons, `assert!(matches!(...))` for enum variants
1. Do not test private functions directly; test through the public API
1. Add `#[should_panic]` only for functions documented to panic

### Phase 5: Validation

#### Verify Tests Pass

After generating tests for a module, run the tests to verify they compile and pass:

```bash
# Run tests for the specific module
cargo test --lib -- module_name

# If tests are in a separate file
cargo test --test test_file_name
```

#### Re-Measure Coverage

After tests pass, re-run coverage to verify improvement:

```bash
# Re-measure with tarpaulin
cargo tarpaulin --out json --output-dir coverage/ --skip-clean \
    --files 'src/module.rs'
```

Report the improvement:

```text
src/service.rs: 75.0% -> 92.5% (+17.5%)
```

### Phase 6: Commit

If `--no-commit` was not passed, commit the tests for each module separately:

```bash
git add src/service.rs
git commit -m "test(service): add unit tests to improve coverage to 92.5%"
```

One commit per module keeps the history clean and makes it easy to revert individual test additions.

### Phase 7: Cleanup

Remove coverage artifacts after completion:

```bash
# Remove tarpaulin artifacts
rm -rf coverage/
rm -f tarpaulin-report.json
rm -f cobertura.xml

# Remove llvm-cov artifacts
rm -f coverage/report.json
rm -rf target/llvm-cov-target/

# Remove profraw files
find . -name '*.profraw' -delete 2>/dev/null || true
```

## Output Format

### Final Report

```text
## Coverage Improvement Summary

### Before

Overall: 72.3% (threshold: 90%)
Files below threshold: 4

### After

Overall: 91.7% (threshold: 90%)
Files below threshold: 0

### Changes

| File | Before | After | Delta | Commit |
|------|--------|-------|-------|--------|
| src/error.rs | 37.5% | 95.0% | +57.5% | a1b2c3d |
| src/service.rs | 75.0% | 92.5% | +17.5% | d4e5f6a |
| src/handler.rs | 85.0% | 93.0% | +8.0% | b7c8d9e |
| src/parser.rs | 80.0% | 91.0% | +11.0% | f0a1b2c |

### Tests Added

- src/error.rs: 8 new tests
- src/service.rs: 5 new tests
- src/handler.rs: 3 new tests
- src/parser.rs: 4 new tests

Total: 20 new tests across 4 commits
```

## Error Handling

### Common Issues

#### No Coverage Tool Installed

Report installation instructions and exit:

```text
No coverage tool found. Install one of:
  cargo install cargo-tarpaulin
  cargo install cargo-llvm-cov && rustup component add llvm-tools-preview
```

#### Tests Fail After Generation

If generated tests fail:

1. Read the error message carefully
1. Fix the test logic (not the source code)
1. Re-run to verify the fix
1. If the test reveals a genuine bug, report it and skip that test

#### Coverage Tool Crashes

Tarpaulin can occasionally segfault on complex codebases:

1. Try with `--engine llvm` flag for tarpaulin
1. Suggest switching to cargo-llvm-cov with `--llvm-cov`
1. If both fail, fall back to `cargo test` and report that coverage measurement is unavailable

#### Workspace Projects

For workspace projects, coverage must be measured across all members:

```bash
# Tarpaulin with workspace
cargo tarpaulin --workspace --out json --output-dir coverage/ --skip-clean

# LLVM-cov with workspace
cargo llvm-cov --workspace --json --output-path coverage/report.json
```

When `--module` targets a specific file, verify which workspace member contains it before running
coverage for just that crate.

#### Async Code Coverage

Async code can have lower coverage than expected because of generated state machine code. When
analyzing coverage for async functions:

1. Focus on the logical lines inside the async function body
1. Ignore coverage of the generated Future implementation details
1. Write async tests with `#[tokio::test]` to exercise async paths
1. Use `tokio::time::pause()` for time-dependent async code

## Test Generation Strategies

### Strategy by Code Pattern

Different code patterns require different testing approaches:

#### Error Handling Code

For functions that return `Result`, generate tests for:

1. The success path with valid input
1. Each error variant that the function can return
1. Boundary conditions (empty input, maximum values, invalid formats)

```rust
// Example: testing error handling
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_valid_config_succeeds() {
        let input = "host=localhost\nport=8080";
        let config = parse_config(input).unwrap();
        assert_eq!(config.host, "localhost");
        assert_eq!(config.port, 8080);
    }

    #[test]
    fn parse_missing_host_returns_missing_field_error() {
        let input = "port=8080";
        assert!(matches!(
            parse_config(input),
            Err(ConfigError::MissingField(field)) if field == "host"
        ));
    }

    #[test]
    fn parse_invalid_port_returns_parse_error() {
        let input = "host=localhost\nport=notanumber";
        assert!(matches!(
            parse_config(input),
            Err(ConfigError::InvalidValue { .. })
        ));
    }
}
```

#### Enum Match Arms

For functions with match expressions, generate a test for each arm:

```rust
// Source code
pub fn status_message(code: StatusCode) -> &'static str {
    match code {
        StatusCode::Ok => "success",
        StatusCode::NotFound => "not found",
        StatusCode::Unauthorized => "unauthorized",
        StatusCode::Internal => "internal error",
    }
}

// Generated tests cover every variant
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_message_ok() {
        assert_eq!(status_message(StatusCode::Ok), "success");
    }

    #[test]
    fn status_message_not_found() {
        assert_eq!(status_message(StatusCode::NotFound), "not found");
    }

    #[test]
    fn status_message_unauthorized() {
        assert_eq!(status_message(StatusCode::Unauthorized), "unauthorized");
    }

    #[test]
    fn status_message_internal() {
        assert_eq!(status_message(StatusCode::Internal), "internal error");
    }
}
```

#### Trait Implementations

When a struct implements a trait, generate tests that verify the trait contract:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_formats_correctly() {
        let error = AppError::NotFound("user-123".into());
        assert_eq!(error.to_string(), "not found: user-123");
    }

    #[test]
    fn from_io_error_converts_correctly() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
        let app_err: AppError = io_err.into();
        assert!(matches!(app_err, AppError::Io(_)));
    }
}
```

### Avoiding Low-Value Tests

Do not generate tests for:

1. Simple getters and setters with no logic
1. Derived implementations (Debug, Clone, etc.)
1. Code that only delegates to another function without transformation
1. Private helper functions (test them through the public API instead)

## Coverage Thresholds by File Type

### Recommended Thresholds

Different file types have different reasonable coverage targets:

- **Business logic** (service.rs, handler.rs): 90%+ target
- **Error types** (error.rs): 85%+ target (some error paths are hard to trigger)
- **Configuration** (config.rs): 80%+ target (environment-dependent paths)
- **Main entry point** (main.rs): Exclude from coverage (integration test territory)
- **Generated code**: Exclude from coverage

### Excluding Files from Coverage

Some files should be excluded from coverage analysis:

```bash
# Tarpaulin exclusion
cargo tarpaulin --exclude-files 'src/main.rs' --exclude-files 'src/generated/*'

# LLVM-cov exclusion
cargo llvm-cov --ignore-filename-regex 'main\.rs|generated'
```

Report excluded files in the coverage summary so the exclusions are transparent.

## Workspace Coverage Aggregation

### Measuring Per-Crate Coverage

For workspace projects, report coverage per crate and overall:

```text
## Workspace Coverage Report

| Crate | Lines | Covered | Coverage | Status |
|-------|-------|---------|----------|--------|
| project-core | 500 | 470 | 94.0% | PASS |
| project-api | 300 | 255 | 85.0% | FAIL |
| project-cli | 100 | 78 | 78.0% | FAIL |

Overall: 803/900 = 89.2% (threshold: 90%)
```

### Prioritizing Crates

When improving coverage across a workspace, prioritize:

1. Core/library crates (most reused, highest impact)
1. API crates (public-facing, highest risk)
1. CLI crates (least impactful, often hard to unit test)
