---
description: >
  Run shell script quality gate suite (shellcheck, shfmt, bats)
argument-hint: '[--exclude=<glob>]'
allowed-tools: Bash(shellcheck *), Bash(shfmt *), Bash(git *), Bash(bats *), Read, Grep, Glob
---

# validate

Run a comprehensive shell script quality gate suite to ensure scripts meet production standards.
This command orchestrates linting with shellcheck, format checking with shfmt, and test execution
with bats through a unified interface.

## Usage

```bash
ccfg shell validate                         # Full validation
ccfg shell validate --exclude='vendor/*'    # Exclude vendor directory
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Script Discovery**: Find all shell scripts in the repository
1. **Lint Check**: Run shellcheck for correctness and best practices
1. **Format Check**: Verify consistent formatting with shfmt
1. **Test Suite**: Run bats tests if available

All gates must pass for the validation to succeed. Tools that are not installed are skipped with a
warning rather than failing the entire run.

## Step-by-Step Process

### 1. Script Discovery

Discover shell scripts using multiple strategies to avoid missing any.

#### Strategy A: File Extension Matching

Find all git-tracked files with `.sh` or `.bash` extensions:

```bash
git ls-files --cached --others --exclude-standard -- '*.sh' '*.bash'
```

#### Strategy B: Shebang Detection in Known Directories

Check files in `bin/`, `scripts/`, `libexec/`, and project root for shell shebangs, even if they
lack a `.sh` extension:

```bash
# Find executable files in standard script directories
for dir in bin scripts libexec; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' file; do
            if head -1 "$file" | grep -qE '^#!\s*/.*\b(ba)?sh\b'; then
                echo "$file"
            fi
        done < <(find "$dir" -type f -executable -print0)
    fi
done
```

**Combining and filtering results**:

```bash
# Combine both strategies, sort, deduplicate
{ extension_files; shebang_files; } | sort -u > /tmp/shell-scripts.txt
```

**Applying exclusions**:

If `--exclude=<glob>` is provided, filter out matching paths. Multiple `--exclude` flags may be
used. Common exclusions include `vendor/`, `node_modules/`, and `third_party/`.

```bash
# Filter out excluded paths
while IFS= read -r file; do
    local excluded=false
    for pattern in "${exclude_patterns[@]}"; do
        if [[ "$file" == $pattern ]]; then
            excluded=true
            break
        fi
    done
    if [[ "$excluded" == "false" ]]; then
        echo "$file"
    fi
done < /tmp/shell-scripts.txt > /tmp/filtered-scripts.txt
```

**Empty discovery**: If no shell scripts are found, report and exit with success:

```text
No shell scripts found in repository. Nothing to validate.
```

### 2. Lint Check (shellcheck)

Run shellcheck to identify correctness and style issues.

**Tool detection**:

```bash
if ! command -v shellcheck &>/dev/null; then
    # SKIP gate, do not fail
    echo "[SKIP] Lint Check (shellcheck not installed)"
    echo "  Install: https://github.com/koalaman/shellcheck#installing"
fi
```

**Execution**:

```bash
shellcheck -x -f tty -- "${scripts[@]}"
```

Flags used:

- `-x`: Follow source directives to check sourced files
- `-f tty`: Human-readable output with colors when available

**What it checks**:

- Quoting issues (SC2086: double quote to prevent globbing)
- Unused variables (SC2034)
- Command substitution issues (SC2046)
- Conditional expression mistakes (SC2157)
- Deprecated syntax (SC2006: use `$()` instead of backticks)
- Unreachable code and dead conditions
- Portability warnings when scripts claim POSIX sh

**Respecting project configuration**:

If a `.shellcheckrc` file exists in the project root, shellcheck will read it automatically. Do not
override project-level shellcheck configuration.

**Success criteria**: Exit code 0 with no warnings or errors.

**On failure**: Display all violations with file locations, line numbers, and shellcheck codes. Do
NOT suggest adding `# shellcheck disable=` directives. Instead, analyze the violations and fix the
root causes.

### 3. Format Check (shfmt)

Verify consistent formatting across all shell scripts.

**Tool detection**:

```bash
if ! command -v shfmt &>/dev/null; then
    echo "[SKIP] Format Check (shfmt not installed)"
    echo "  Install: https://github.com/mvdan/sh#shfmt"
fi
```

**Execution**:

```bash
shfmt -d -- "${scripts[@]}"
```

The `-d` flag shows a diff of what would change without modifying files.

**Respecting .editorconfig**:

shfmt reads `.editorconfig` automatically. If the project has an `.editorconfig` file, shfmt will
use those settings (indent size, indent style, etc.). Do not pass explicit formatting flags that
would override `.editorconfig`.

If no `.editorconfig` exists, shfmt uses its defaults (tabs for indentation).

**Success criteria**: Exit code 0 indicating no formatting changes needed.

**On failure**: Show the diff of formatting differences. Suggest running `shfmt -w .` to apply fixes
automatically, but note that users should review the diff first if the project has custom formatting
conventions.

### 4. Test Suite (bats)

Run the bats (Bash Automated Testing System) test suite if available.

**Tool detection**:

```bash
if ! command -v bats &>/dev/null; then
    echo "[SKIP] Test Suite (bats not installed)"
    echo "  Install: https://github.com/bats-core/bats-core#installation"
fi
```

**Test file detection**:

```bash
# Find .bats test files
bats_files=$(find . -name '*.bats' -type f -not -path '*/node_modules/*' -not -path '*/.git/*')
if [[ -z "$bats_files" ]]; then
    echo "[SKIP] Test Suite (no .bats files found)"
fi
```

**Execution**:

```bash
bats --tap tests/
```

Or if test files are scattered:

```bash
bats $(find . -name '*.bats' -type f)
```

**What it checks**:

- All `@test` blocks pass
- Setup and teardown functions execute correctly
- Assertions match expected values
- Script behavior under various inputs

**Success criteria**: All tests pass (exit code 0).

**On failure**: Display test failures with the test name, expected vs actual output, and the line
number in the `.bats` file where the assertion failed.

### 5. Results Reporting

After all gates complete, generate a summary report.

**Success output**:

```text
Running shell script quality gates...

Discovered 23 shell scripts

[1/3] Lint Check
  -> Running: shellcheck -x
  OK: No issues found (23 files)

[2/3] Format Check
  -> Running: shfmt -d
  OK: All files properly formatted (23 files)

[3/3] Test Suite
  -> Running: bats tests/
  OK: 15 tests passed

==================================================
ALL GATES PASSED (3/3)
==================================================
```

**Failure output**:

```text
Running shell script quality gates...

Discovered 23 shell scripts

[1/3] Lint Check
  -> Running: shellcheck -x
  FAIL: Found 5 issues in 3 files:

  scripts/deploy.sh:45:5: warning: Use 'cd ... || exit' in case cd fails. [SC2164]
  scripts/deploy.sh:67:10: warning: Double quote to prevent globbing. [SC2086]
  scripts/backup.sh:12:1: error: Tips depend on target shell and target is sh. [SC2039]
  bin/setup:23:3: warning: Declare and assign separately. [SC2155]
  bin/setup:45:8: info: Use $(...) notation instead of backticks. [SC2006]

[2/3] Format Check
  -> Running: shfmt -d
  FAIL: 2 files would be reformatted:
  - scripts/deploy.sh
  - lib/utils.sh

[3/3] Test Suite
  -> Running: bats tests/
  OK: 15 tests passed

==================================================
VALIDATION FAILED (2/3 gates failed)
==================================================

Suggested fixes:
1. Fix shellcheck warnings in scripts/deploy.sh, scripts/backup.sh, bin/setup
2. Run 'shfmt -w scripts/deploy.sh lib/utils.sh' to fix formatting
3. Re-run validation after fixes
```

**Partial skip output**:

```text
Running shell script quality gates...

Discovered 12 shell scripts

[1/3] Lint Check
  -> Running: shellcheck -x
  OK: No issues found (12 files)

[2/3] Format Check
  [SKIP] shfmt not installed
  Install with: brew install shfmt  (macOS)
                go install mvdan.cc/sh/v3/cmd/shfmt@latest  (Go)
                snap install shfmt  (Linux)

[3/3] Test Suite
  [SKIP] No .bats test files found

==================================================
PASSED (1/1 active gates)
==================================================
```

## Key Rules and Requirements

### Tool Execution

1. **Never modify files**: The validate command only checks; it never auto-fixes. Use `shfmt -w`
   separately if the user wants to apply formatting.

1. **Never suggest suppression directives**: When shellcheck violations occur, fix the root cause.
   Do not recommend `# shellcheck disable=SC####` comments.

1. **Report all results**: Even if an early gate fails, run remaining gates and report all results.
   This gives developers a complete picture.

1. **Graceful tool detection**: Missing tools are SKIPped, not FAILed. Not every developer has every
   tool installed locally.

### Gate Status Definitions

- **PASS**: Gate executed successfully with no issues
- **FAIL**: Gate executed but found violations or errors
- **SKIP**: Gate not executed due to missing tool or missing test files

### Script Discovery Rules

1. **Git-tracked files only**: Only validate files that are tracked by git or would be tracked
   (unignored). Never validate files inside `.git/`, `node_modules/`, or `.venv/`.

1. **Shebang detection**: Files in `bin/`, `scripts/`, and `libexec/` without extensions must be
   checked by reading the first line for a `#!/bin/bash`, `#!/usr/bin/env bash`, `#!/bin/sh`, or
   `#!/usr/bin/env sh` shebang.

1. **Respect .gitignore**: Use `git ls-files` to automatically respect `.gitignore` patterns.

1. **Exclude support**: The `--exclude=<glob>` flag filters out additional paths. Multiple
   `--exclude` flags may be combined.

### Configuration Detection

**shellcheck (.shellcheckrc)**:

- If `.shellcheckrc` exists, shellcheck reads it automatically
- Common directives: `shell=bash`, `disable=SC1091`, `external-sources=true`
- Do not override or conflict with the project's shellcheckrc

**shfmt (.editorconfig)**:

- shfmt reads `.editorconfig` for indent style and size
- Common settings: `indent_style = space`, `indent_size = 4`
- Do not pass `-i` or `-ci` flags if `.editorconfig` exists

**bats (no standard config file)**:

- Look for `.bats` files in `test/`, `tests/`, or project root
- Check for `bats-core`, `bats-support`, and `bats-assert` helper libraries

### Error Handling

When a gate fails, provide actionable feedback:

1. **Display the actual error output**: Show file, line, column, and error message
1. **Categorize the failures**: Group by file for easier navigation
1. **Suggest concrete fixes**: Offer specific solutions, not generic advice
1. **Preserve context**: Include shellcheck error codes so developers can look up explanations
1. **Prioritize fixes**: Errors before warnings before informational messages

### Exit Behavior

The command should result in the following exit status:

- Exit 0: All active gates passed (skipped gates are not failures)
- Exit 1: One or more gates failed
- Exit 2: Command invocation error (bad arguments)

## Common Scenarios

### Scenario 1: New Project with No Tools

Project has shell scripts but no shellcheck, shfmt, or bats installed.

**Expected behavior**:

- All three gates are SKIP
- Report: "0/0 active gates (all tools missing)"
- Suggest installing each tool with platform-specific instructions

### Scenario 2: Mixed Bash and POSIX sh Scripts

Project has both `#!/bin/bash` and `#!/bin/sh` scripts.

**Expected behavior**:

- shellcheck detects the shell from the shebang and applies appropriate rules
- POSIX sh scripts are flagged for bash-specific syntax (arrays, `[[ ]]`, etc.)
- Format check works for both shells

### Scenario 3: Scripts Without Extensions

Project has executable files in `bin/` with no `.sh` extension.

**Expected behavior**:

- Shebang detection finds these scripts
- All quality gates run on them
- Report uses the full path (`bin/deploy`, not `deploy.sh`)

### Scenario 4: Vendor Scripts

Project includes third-party scripts that should not be validated.

**Expected behavior**:

- User runs `ccfg shell validate --exclude='vendor/*'`
- Vendor scripts are excluded from all gates
- Report shows the exclusion: "Excluded 5 files matching vendor/\*"

## Troubleshooting

### "shellcheck: command not found"

Install shellcheck:

```bash
# macOS
brew install shellcheck

# Ubuntu/Debian
apt-get install shellcheck

# Fedora
dnf install ShellCheck

# From binary
curl -sL https://github.com/koalaman/shellcheck/releases/latest/download/shellcheck-v0.10.0.linux.x86_64.tar.xz | tar -xJf -
```

### "shfmt: command not found"

Install shfmt:

```bash
# macOS
brew install shfmt

# Go install
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Binary download
curl -sL https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.8.0_linux_amd64 -o /usr/local/bin/shfmt
chmod +x /usr/local/bin/shfmt
```

### "bats: command not found"

Install bats-core:

```bash
# macOS
brew install bats-core

# npm
npm install -g bats

# From source
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local
```

### shellcheck reports errors in sourced files

Add to `.shellcheckrc`:

```text
external-sources=true
```

Or use source path directives in scripts:

```bash
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
```

### shfmt conflicts with project style

Create or update `.editorconfig`:

```text
[*.sh]
indent_style = space
indent_size = 4
```

## Summary

The validate command provides a single entry point for all shell script quality checks. By detecting
and skipping missing tools gracefully, it works in any environment from minimal CI containers to
fully-equipped developer machines. Always address root causes of violations rather than suppressing
warnings.
