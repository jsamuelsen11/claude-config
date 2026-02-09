---
description: Run Python quality gate suite (ruff, mypy, pytest)
argument-hint: [--quick]
allowed-tools: Bash(uv *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive Python quality gate suite to ensure code meets production standards. This
command orchestrates linting, formatting, type checking, and test execution through a unified
interface.

## Usage

```bash
ccfg python validate                  # Full validation with test suite
ccfg python validate --quick          # Fast validation, skip tests
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Lint Check**: Verify code follows Python best practices and style rules
1. **Format Check**: Ensure consistent code formatting across the project
1. **Type Check**: Validate type annotations and catch type-related bugs
1. **Test Suite**: Run the full test suite with coverage reporting (full mode only)

All gates must pass for the validation to succeed. The command uses `uv run` to ensure all tools run
in the project's virtual environment with correct dependencies.

## Execution Modes

### Full Mode (Default)

Runs all quality gates including the complete test suite. This is the recommended mode for
pre-commit validation and CI/CD pipelines.

Gates executed:

- Ruff linting
- Ruff formatting verification
- Mypy type checking (if configured)
- Pytest test suite

### Quick Mode

Skips the test suite for rapid feedback during development. Use this for fast iteration when you
need to check code quality without waiting for tests.

Gates executed:

- Ruff linting
- Ruff formatting verification
- Mypy type checking (if configured)

## Step-by-Step Process

### 1. Environment Detection

Before running any gates, verify the project structure:

- Check for `pyproject.toml` in the current directory or parent directories
- Verify `uv` is available on the system
- Detect if the project uses a `src/` layout or flat layout
- Identify the package name from pyproject.toml

### 2. Lint Check

Run ruff to identify code quality issues:

```bash
uv run ruff check .
```

**What it checks**:

- Unused imports and variables
- Undefined names and scope issues
- Complexity violations
- Security vulnerabilities (bandit rules)
- Import ordering and grouping
- Docstring presence and format
- Line length and whitespace
- Python version compatibility issues

**Success criteria:**Exit code 0 with no violations reported**On failure:** Display all violations
with file locations, line numbers, and rule codes. Do NOT suggest using `# noqa` comments or
disabling rules. Instead, analyze the violations and fix the root causes.

### 3. Format Check

Verify code formatting consistency:

```bash
uv run ruff format --check .
```

**What it checks**:

- Indentation consistency
- Quote style (single vs double)
- Trailing commas in multiline structures
- Line breaks around operators
- Blank line usage between definitions
- String quote normalization

**Success criteria:**Exit code 0 indicating no formatting changes needed**On failure:** Show which
files would be reformatted. Suggest running `uv run ruff format .` to apply fixes automatically.

### 4. Type Check

Run mypy for static type analysis:

```bash
uv run mypy src/
```

**Configuration detection**:

- Look for `[tool.mypy]` section in pyproject.toml
- Check for standalone mypy.ini or .mypy.ini
- If no mypy configuration exists, SKIP this gate and report:

  ```text
  TYPE CHECK: SKIPPED (mypy not configured in pyproject.toml)
  ```

**What it checks**:

- Function signature compatibility
- Variable type consistency
- Missing type annotations (if strict mode enabled)
- Generic type parameter correctness
- Protocol compliance
- Import resolution

**Success criteria:**Exit code 0 with no type errors**On failure:** Display all type errors with
context. Analyze errors to distinguish between:

- Missing type annotations (add them)
- Actual type mismatches (fix the logic)
- Third-party library stub issues (add type stubs to dev dependencies)

### 5. Test Suite (Full Mode Only)

Execute the complete test suite:

```bash
uv run pytest tests/ -v
```

**What it runs**:

- All test files matching `test_*.py` or `*_test.py`
- Captures output and displays failures
- Shows test duration for performance tracking
- Reports coverage statistics if configured

**Success criteria:**All tests pass (exit code 0)**On failure:** Display test failures with full
tracebacks, captured output, and assertion details. Identify patterns in failures (e.g., multiple
tests failing in one module suggests a shared fixture or import issue).

### 6. Results Reporting

After all gates complete, generate a summary report:

```text
QUALITY GATE RESULTS
====================

[PASS] Lint Check (ruff check)
[PASS] Format Check (ruff format)
[SKIP] Type Check (mypy not configured)
[PASS] Test Suite (142 tests passed)

Overall: PASSED (3/3 active gates)
```

Or on failure:

```text
QUALITY GATE RESULTS
====================

[PASS] Lint Check (ruff check)
[FAIL] Format Check (ruff format)
       12 files would be reformatted
[PASS] Type Check (mypy)
[STOP] Test Suite (not run due to previous failures)

Overall: FAILED (2/3 gates passed)

Run 'uv run ruff format .' to fix formatting issues.
```

## Key Rules and Requirements

### Tool Execution

1. **Always use uv run**: Never invoke tools directly (e.g., `pytest`, `ruff`, `mypy`). Always use
   `uv run <tool>` to ensure correct virtual environment activation and dependency resolution.

1. **Never suggest lint suppressions**: When lint violations occur, fix the root cause. Do not
   recommend:
   - `# noqa` comments
   - `# type: ignore` without investigation
   - Disabling rules in configuration
   - Relaxing strictness settings

1. **Report all results**: Even if an early gate fails, run remaining gates (except tests in full
   mode if earlier gates fail) and report all results. This gives developers a complete picture of
   code quality.

### Gate Status Definitions

- **PASS**: Gate executed successfully with no issues
- **FAIL**: Gate executed but found violations or errors
- **SKIP**: Gate not executed due to missing configuration (not an error)
- **STOP**: Gate not executed because a previous gate failed

### Configuration Detection

Each quality tool should be detected and handled appropriately:

**Ruff (required)**:

- Must be in `[project.dependencies]` or `[dependency-groups.dev]`
- Configuration typically in `[tool.ruff]` section of pyproject.toml
- If missing, fail with clear error: "ruff not found in dependencies"

**Mypy (optional)**:

- Check for `[tool.mypy]` in pyproject.toml
- If not configured, skip type checking with notice
- If configured but mypy not installed, fail with error

**Pytest (required)**:

- Must be in dev dependencies for full mode
- Configuration typically in `[tool.pytest.ini_options]`
- Quick mode doesn't require pytest

### Error Handling

When a gate fails, provide actionable feedback:

1. **Display the actual error output**: Don't just report "failed", show what failed
1. **Categorize the failures**: Group related issues together
1. **Suggest concrete fixes**: Offer specific solutions, not generic advice
1. **Preserve context**: Include file paths, line numbers, and surrounding code
1. **Prioritize fixes**: Indicate which failures to address first

### Exit Behavior

The command should exit with appropriate codes:

- Exit 0: All active gates passed
- Exit 1: One or more gates failed
- Exit 2: Command invocation error (wrong arguments, missing config)

### Performance Considerations

- Run gates sequentially, not in parallel (easier to attribute failures)
- Stream output in real-time when possible
- Use pytest's `-v` flag for detailed test information
- Consider timeout limits for test execution (default 5 minutes)

## Output Format

### Success Output

```text
Running Python quality gates...

[1/4] Lint Check
  → Running: uv run ruff check .
  ✓ No issues found

[2/4] Format Check
  → Running: uv run ruff format --check .
  ✓ All files properly formatted

[3/4] Type Check
  → Running: uv run mypy src/
  ✓ No type errors found

[4/4] Test Suite
  → Running: uv run pytest tests/ -v
  ✓ 142 tests passed in 4.2s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ ALL GATES PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Failure Output

```text
Running Python quality gates...

[1/4] Lint Check
  → Running: uv run ruff check .
  ✗ Found 3 issues:

  src/api/handlers.py:45:5: F841 Local variable `result` is assigned but never used
  src/core/processor.py:102:1: E501 Line too long (92 > 88 characters)
  tests/test_api.py:23:8: F401 `typing.List` imported but unused

[2/4] Format Check
  → Running: uv run ruff format --check .
  ✗ Would reformat 2 files:
  - src/api/handlers.py
  - src/core/processor.py

[3/4] Type Check
  → Running: uv run mypy src/
  ✓ No type errors found

[4/4] Test Suite
  ⊘ Skipped due to previous failures

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✗ VALIDATION FAILED (2/3 gates failed)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Suggested fixes:
1. Remove unused imports and variables
1. Run 'uv run ruff format .' to fix formatting
1. Re-run validation after fixes
```

## Integration with Development Workflow

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
ccfg python validate --quick
if [ $? -ne 0 ]; then
  echo "Quality gates failed. Commit aborted."
  exit 1
fi
```

### CI/CD Pipeline

```yaml
# .github/workflows/validate.yml
- name: Run Python validation
  run: ccfg python validate
```

### IDE Integration

Many IDEs can run custom commands on save or via keyboard shortcuts. Map
`ccfg python validate --quick` to a hotkey for instant feedback.

## Common Scenarios

### Scenario 1: First-time Setup

Project has no quality tools configured yet.

**Expected behavior**:

- Ruff check fails: "ruff not found in dependencies"
- Suggest running: `uv add --dev ruff mypy pytest`
- Provide sample pyproject.toml configuration

### Scenario 2: Legacy Codebase

Project has many existing violations.

**Expected behavior**:

- Report all violations clearly
- Group by file and violation type
- Prioritize critical issues (undefined names, security)
- Suggest incremental fixes starting with automated ones (formatting)

### Scenario 3: Type Checking Adoption

Project has ruff and pytest but no mypy.

**Expected behavior**:

- Skip type check gate with notice
- Report other gates normally
- Suggest adding mypy configuration if desired

### Scenario 4: Intermittent Test Failures

Tests pass locally but fail in CI.

**Expected behavior**:

- Capture full test output including fixtures and captured logs
- Note timing differences if relevant
- Suggest running with `--verbose` and `--log-cli-level=DEBUG`

## Advanced Usage

### Targeting Specific Paths

While not exposed as a flag, you can run gates on specific paths:

```bash
# Validate only changed files
uv run ruff check $(git diff --name-only --diff-filter=ACMR "*.py")
```

### Parallel Execution

For very large projects, consider running independent gates in parallel:

```bash
# Not recommended for normal use, but possible:
uv run ruff check . & uv run mypy src/ & wait
```

### Custom Gate Configuration

Projects can customize gate behavior via pyproject.toml:

```toml
[tool.ruff]
line-length = 100
select = ["E", "F", "I", "N", "W", "B", "C90"]

[tool.mypy]
strict = true
warn_unreachable = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --strict-markers --cov=src"
```

## Troubleshooting

### "uv: command not found"

Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`

### "No pyproject.toml found"

Run from project root or use `ccfg python scaffold` to create a new project.

### "ruff not installed"

Add to dependencies: `uv add --dev ruff`

### Type checking finds too many errors

Start with basic mypy config, then gradually enable strict mode:

```toml
[tool.mypy]
strict = false
check_untyped_defs = true
```

### Tests pass locally but fail in validate

Check for:

- Environment-specific dependencies
- Test isolation issues
- Race conditions in async tests
- Fixture scope problems

## Summary

The validate command provides a single entry point for all Python quality checks, ensuring
consistency across local development and CI/CD environments. By using uv for all tool execution, it
guarantees reproducible results and eliminates "works on my machine" issues.

Always address root causes of violations rather than suppressing warnings. The goal is high-quality,
maintainable code that can be confidently deployed to production.
