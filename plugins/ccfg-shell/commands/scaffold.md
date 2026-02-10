---
description: >
  Scaffold a new shell script or shell project with production-ready defaults
argument-hint: '<name> [--type=script|project] [--shell=bash|sh]'
allowed-tools: Bash(chmod *), Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Create a new shell script or shell project with production-ready structure, safety defaults, and
consistent conventions. Scripts are immediately executable and pass shellcheck and shfmt validation.

## Usage

```bash
ccfg shell scaffold deploy.sh                        # Single bash script (default)
ccfg shell scaffold install.sh --shell=sh            # Single POSIX sh script
ccfg shell scaffold mytools --type=project            # Full project layout
ccfg shell scaffold mytools --type=project --shell=sh # POSIX sh project
```

## Overview

The scaffold command creates shell scripts or projects with:

- **Safety preamble**: `set -euo pipefail` (bash) or `set -eu` (POSIX sh)
- **main() pattern**: Structured code organization with functions
- **Trap cleanup**: Automatic resource cleanup on exit
- **Argument parsing**: Template for handling flags and arguments
- **Executable permissions**: `chmod +x` applied automatically
- **shellcheck compliance**: Generated code passes shellcheck without warnings

All generated code follows shell best practices and is immediately usable.

## Script Types

### Single Script (Default)

A standalone executable shell script with full safety features.

**Generated file (bash)**:

```bash
#!/usr/bin/env bash
#
# deploy.sh - [Brief description]
#
# Usage: deploy.sh [OPTIONS] <args>
#
set -euo pipefail

# --- Script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging ---
log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
err()  { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { err "$@"; exit 1; }

# --- Cleanup ---
cleanup() {
    # Remove temporary files, kill background processes, etc.
    :
}
trap cleanup EXIT

# --- Usage ---
usage() {
    cat <<'EOF'
Usage: deploy.sh [OPTIONS] <args>

[Description of what this script does]

Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output

Arguments:
  args           [Description of required arguments]

Examples:
  deploy.sh -v target
  deploy.sh --help
EOF
}

# --- Argument parsing ---
parse_args() {
    VERBOSE=false

    while (( $# > 0 )); do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            --) shift; break ;;
            -*) die "Unknown option: $1" ;;
            *) break ;;
        esac
    done

    # Validate required arguments
    if (( $# < 1 )); then
        die "Missing required argument. Run with --help for usage."
    fi
}

# --- Main ---
main() {
    parse_args "$@"
    log "Starting..."

    # Script logic here

    log "Done"
}

main "$@"
```

**Generated file (POSIX sh)**:

```sh
#!/bin/sh
#
# install.sh - [Brief description]
#
# Usage: install.sh [OPTIONS] <args>
#
set -eu

# --- Logging ---
log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
err()  { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { err "$@"; exit 1; }

# --- Cleanup ---
cleanup() {
    :
}
trap cleanup EXIT

# --- Usage ---
usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS] <args>

[Description of what this script does]

Options:
  -h    Show this help message
  -v    Enable verbose output

Arguments:
  args  [Description of required arguments]
EOF
}

# --- Argument parsing ---
VERBOSE=false

while getopts ":hv" opt; do
    case $opt in
        h) usage; exit 0 ;;
        v) VERBOSE=true ;;
        *) die "Unknown option: -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

# --- Main ---
main() {
    if [ $# -lt 1 ]; then
        die "Missing required argument. Run with -h for usage."
    fi

    log "Starting..."

    # Script logic here

    log "Done"
}

main "$@"
```

**Key differences between bash and POSIX sh scripts**:

| Feature          | Bash                        | POSIX sh                   |
| ---------------- | --------------------------- | -------------------------- |
| Preamble         | `set -euo pipefail`         | `set -eu`                  |
| Test syntax      | `[[ ]]`                     | `[ ]`                      |
| Arrays           | Supported                   | Not available              |
| Local variables  | `local var=`                | Use function-scoped naming |
| Pattern matching | `[[ $x == *.txt ]]`         | `case $x in *.txt)`        |
| Arg parsing      | `while+case` with long opts | `getopts` with short opts  |
| Script dir       | `${BASH_SOURCE[0]}`         | `$0` (less reliable)       |

### Project Layout

A multi-file shell project with organized directory structure.

**Generated structure**:

```text
mytools/
  bin/
    mytool             # Main entry point (executable, no extension)
  lib/
    logging.sh         # Logging functions
    utils.sh           # Utility functions
  test/
    mytool.bats        # bats test file
  Makefile             # Build and validation targets
  .shellcheckrc        # shellcheck configuration
  .editorconfig        # Editor and shfmt configuration
  README.md            # Project documentation
```

## Step-by-Step Process

### 1. Validate Arguments

Before creating any files, validate the input:

**For single script**:

- Name must end in `.sh` or `.bash`, or have no extension (for `bin/` scripts)
- Name must not contain path traversal (`..`)
- File must not already exist (refuse to overwrite without confirmation)

**For project**:

- Name must be a valid directory name (alphanumeric, hyphens, underscores)
- Directory must not already exist
- Name should follow naming conventions (lowercase with hyphens)

**Validation**:

```bash
validate_script_name() {
    local name="$1"
    if [[ "$name" == *".."* ]]; then
        die "Invalid name: contains path traversal"
    fi
    if [[ -e "$name" ]]; then
        die "File already exists: $name"
    fi
}

validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        die "Invalid project name: must be lowercase, start with letter, contain only letters/numbers/hyphens/underscores"
    fi
    if [[ -d "$name" ]]; then
        die "Directory already exists: $name"
    fi
}
```

### 2. Determine Shell Variant

The `--shell` flag controls which shell dialect to generate:

- `--shell=bash` (default): Bash 4+ with full features
- `--shell=sh`: POSIX sh compatible (no bashisms)

**POSIX sh restrictions** (enforced in generated code):

- No `[[ ]]` (use `[ ]` with proper quoting)
- No arrays (use positional parameters or files)
- No `local` keyword (widely supported but not strictly POSIX)
- No `pipefail` option
- No `${BASH_SOURCE[0]}` (use `$0`)
- No pattern matching in `[[ ]]` (use `case` statements)
- No `<<<` here-strings
- No process substitution `<()` or `>()`
- No `{1..10}` brace expansion

### 3. Create Single Script

For `--type=script` (the default):

**Write the script file**:

Generate the appropriate template based on `--shell` (see templates above in Script Types section).

**Set executable permissions**:

```bash
chmod +x "$script_name"
```

**Display success message**:

```text
Created: deploy.sh (bash script)

Next steps:
  1. Edit deploy.sh to add your logic
  2. Run: shellcheck deploy.sh
  3. Run: ./deploy.sh --help
```

### 4. Create Project Layout

For `--type=project`:

**Create directory structure**:

```bash
mkdir -p "$name"/{bin,lib,test}
```

**Generate bin/mytool (main entry point)**:

The main entry point in `bin/` has no file extension. It sources libraries from `lib/` and
implements the main logic.

```bash
#!/usr/bin/env bash
#
# mytool - [Brief description]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# shellcheck source=../lib/logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=../lib/utils.sh
source "$LIB_DIR/utils.sh"

usage() {
    cat <<'EOF'
Usage: mytool [OPTIONS] <command> [args...]

Commands:
  run        Execute the main operation
  check      Verify prerequisites
  help       Show this help message

Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  --version      Show version
EOF
}

VERSION="0.1.0"

main() {
    local verbose=false

    while (( $# > 0 )); do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--verbose) verbose=true; shift ;;
            --version) echo "mytool $VERSION"; exit 0 ;;
            --) shift; break ;;
            -*) die "Unknown option: $1" ;;
            *) break ;;
        esac
    done

    local command="${1:-help}"
    shift || true

    case "$command" in
        run)   cmd_run "$@" ;;
        check) cmd_check "$@" ;;
        help)  usage ;;
        *)     die "Unknown command: $command. Run 'mytool help' for usage." ;;
    esac
}

cmd_run() {
    log "Running main operation..."
    # Implementation here
    log "Done"
}

cmd_check() {
    log "Checking prerequisites..."
    require_cmd "curl"
    require_cmd "jq"
    log "All prerequisites met"
}

main "$@"
```

**Generate lib/logging.sh**:

```bash
#!/usr/bin/env bash
# logging.sh - Logging utility functions
#
# Source this file to get structured logging functions.
# All log output goes to stderr so stdout remains clean for data.

[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return 0
_LOGGING_SH_LOADED=1

# Detect color support
if [[ -t 2 ]]; then
    _LOG_RED='\033[0;31m'
    _LOG_GREEN='\033[0;32m'
    _LOG_YELLOW='\033[0;33m'
    _LOG_BLUE='\033[0;34m'
    _LOG_RESET='\033[0m'
else
    _LOG_RED='' _LOG_GREEN='' _LOG_YELLOW='' _LOG_BLUE='' _LOG_RESET=''
fi

log() {
    printf "${_LOG_BLUE}[%s]${_LOG_RESET} %s\n" "$(date '+%H:%M:%S')" "$*" >&2
}

warn() {
    printf "${_LOG_YELLOW}[%s] WARN:${_LOG_RESET} %s\n" "$(date '+%H:%M:%S')" "$*" >&2
}

err() {
    printf "${_LOG_RED}[%s] ERROR:${_LOG_RESET} %s\n" "$(date '+%H:%M:%S')" "$*" >&2
}

die() {
    err "$@"
    exit 1
}

success() {
    printf "${_LOG_GREEN}[%s] OK:${_LOG_RESET} %s\n" "$(date '+%H:%M:%S')" "$*" >&2
}
```

**Generate lib/utils.sh**:

```bash
#!/usr/bin/env bash
# utils.sh - Common utility functions
#
# Source this file to get common helpers.

[[ -n "${_UTILS_SH_LOADED:-}" ]] && return 0
_UTILS_SH_LOADED=1

# Check if a command exists
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        die "Required command not found: $cmd"
    fi
}

# Confirm action with user
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        printf '%s [Y/n] ' "$prompt" >&2
    else
        printf '%s [y/N] ' "$prompt" >&2
    fi

    local reply
    read -r reply
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Create a temporary directory with automatic cleanup
make_temp_dir() {
    local prefix="${1:-tmp}"
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX")
    # Note: caller should set up trap for cleanup
    echo "$tmpdir"
}

# Retry a command with backoff
retry() {
    local max_attempts="${1:?max_attempts required}"
    local delay="${2:?delay required}"
    shift 2

    local attempt=1
    until "$@"; do
        if (( attempt >= max_attempts )); then
            err "Command failed after $max_attempts attempts: $*"
            return 1
        fi
        warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
        sleep "$delay"
        (( attempt++ ))
        (( delay *= 2 ))
    done
}
```

**Generate test/mytool.bats**:

```bash
#!/usr/bin/env bats

# Test suite for mytool

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PATH="$SCRIPT_DIR/bin:$PATH"
}

@test "mytool --help exits 0" {
    run mytool --help
    [ "$status" -eq 0 ]
}

@test "mytool --help shows usage" {
    run mytool --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "mytool --version shows version" {
    run mytool --version
    [ "$status" -eq 0 ]
    [[ "${output}" == *"0.1.0"* ]]
}

@test "mytool unknown command fails" {
    run mytool nonexistent
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Unknown command"* ]]
}

@test "mytool unknown option fails" {
    run mytool --nonexistent
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Unknown option"* ]]
}
```

**Generate Makefile**:

```makefile
SHELL := /bin/bash
.DEFAULT_GOAL := help

SCRIPTS := $(shell find bin lib -type f -name '*.sh' -o -type f -executable 2>/dev/null)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: lint
lint: ## Run shellcheck
	@shellcheck -x $(SCRIPTS)

.PHONY: format
format: ## Format with shfmt
	@shfmt -w $(SCRIPTS)

.PHONY: format-check
format-check: ## Check formatting
	@shfmt -d $(SCRIPTS)

.PHONY: test
test: ## Run bats tests
	@bats test/

.PHONY: validate
validate: lint format-check test ## Run all checks
```

**Generate .shellcheckrc**:

```text
# ShellCheck configuration
# https://www.shellcheck.net/wiki/

# Follow source directives
external-sources=true

# Default shell (can be overridden by shebang)
shell=bash
```

**Generate .editorconfig**:

```text
# EditorConfig for shell scripts
# https://editorconfig.org/

root = true

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true

[*.{sh,bash}]
indent_style = space
indent_size = 4

[Makefile]
indent_style = tab

[*.bats]
indent_style = space
indent_size = 4
```

**Set executable permissions**:

```bash
chmod +x "$name/bin/mytool"
```

### 5. POSIX sh Project Variant

When `--shell=sh` is used with `--type=project`, the following changes apply:

- Shebang is `#!/bin/sh` instead of `#!/usr/bin/env bash`
- No `[[ ]]`, use `[ ]` with proper quoting
- No arrays, no local, no pipefail
- No `${BASH_SOURCE[0]}`, use `$0`
- Library guard uses a different pattern:

```sh
# POSIX sh guard against double-source
if [ "${_LOGGING_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || true
fi
_LOGGING_SH_LOADED=1
```

- `.shellcheckrc` sets `shell=sh`
- Argument parsing uses `getopts` instead of `while+case` with long options

### 6. Display Success Message

**Single script success**:

```text
Created: deploy.sh (bash script with main() pattern)

  chmod +x deploy.sh  (already done)

Next steps:
  1. Edit deploy.sh to add your script logic
  2. Validate: shellcheck deploy.sh && shfmt -d deploy.sh
  3. Run: ./deploy.sh --help
```

**Project success**:

```text
Created project: mytools/

  mytools/
    bin/mytool           Main entry point
    lib/logging.sh       Logging functions
    lib/utils.sh         Utility functions
    test/mytool.bats     Test suite
    Makefile             Build targets
    .shellcheckrc        shellcheck config
    .editorconfig        Editor config

Next steps:
  1. cd mytools
  2. Edit bin/mytool to add commands
  3. Run tests:  make test
  4. Validate:   make validate
  5. Try it:     bin/mytool --help
```

## Key Rules and Requirements

### Safety Defaults Are Mandatory

Every generated script must include the appropriate safety preamble:

- **Bash**: `set -euo pipefail` (always, no exceptions)
- **POSIX sh**: `set -eu` (always, no exceptions)

Never generate scripts without these safety settings.

### The main() Pattern Is Required

Every generated script must use the main() pattern:

- Define functions above main
- Call `main "$@"` at the bottom of the file
- This prevents accidental execution of code during sourcing

### Trap Cleanup Is Required

Every generated script must include a cleanup function and EXIT trap, even if the cleanup function
is initially empty. This establishes the pattern for developers to fill in.

### chmod +x Is Automatic

Always set executable permissions on generated scripts. The user should never have to manually
`chmod +x` a scaffolded script.

### No Overwriting Existing Files

Never overwrite existing files without explicit confirmation. If the target file or directory
already exists, report the conflict and exit.

### POSIX sh Must Be Truly Portable

When `--shell=sh` is selected, the generated code must not contain ANY bashisms:

- No `[[ ]]` conditionals
- No arrays (indexed or associative)
- No `local` keyword (though widely supported, avoid for strict POSIX)
- No `pipefail`
- No `${BASH_SOURCE[0]}`
- No `<<<` here-strings
- No `<()` or `>()` process substitution
- No `{1..10}` brace expansion
- No `$(( ))` with `++` or `--` operators
- No `==` in `[ ]` (use `=` instead)

### Generated Code Must Pass Validation

All generated code must pass `shellcheck -x` and `shfmt -d` immediately after creation. This is a
hard requirement. Never generate code with known shellcheck warnings.

## Common Scenarios

### Scenario 1: Quick Utility Script

Developer needs a one-off script for a deployment task.

```bash
ccfg shell scaffold deploy-staging.sh
```

Creates a single bash script with argument parsing, logging, and cleanup. Developer fills in the
logic.

### Scenario 2: POSIX Installer Script

Project needs a portable installer that works on any Unix system.

```bash
ccfg shell scaffold install.sh --shell=sh
```

Creates a POSIX sh script that avoids all bashisms. Safe to run on Alpine, BusyBox, dash, and other
minimal shells.

### Scenario 3: CLI Tool Project

Team is building a multi-command shell tool.

```bash
ccfg shell scaffold myctl --type=project
```

Creates a full project with `bin/`, `lib/`, `test/`, Makefile, and configuration files. The main
entry point supports subcommands.

### Scenario 4: Adding a Script to Existing Project

Developer wants to add a script to an existing project.

```bash
ccfg shell scaffold scripts/backup.sh
```

Creates the script in the specified path (creating parent directories if needed) without generating
a full project structure.

## Troubleshooting

### "File already exists"

Choose a different name or remove the existing file first. The scaffold command will never silently
overwrite existing files.

### "Invalid project name"

Project names must start with a lowercase letter and contain only lowercase letters, numbers,
hyphens, and underscores. Examples: `my-tool`, `deploy_utils`, `backup2`.

### "shellcheck reports warnings in generated code"

This should never happen. Generated code must pass shellcheck. If it does, this is a bug in the
scaffold command template.

### Scripts not executable after scaffolding

The scaffold command runs `chmod +x` automatically. If permissions are wrong, check filesystem
restrictions (e.g., FAT32/exFAT filesystems do not support Unix permissions).

## Summary

The scaffold command creates production-ready shell scripts and projects with safety defaults,
structured organization, and immediate shellcheck compliance. By enforcing the main() pattern, trap
cleanup, and strict mode, scaffolded scripts establish good habits from the first line of code.
Choose `--shell=sh` when portability across minimal Unix environments is required, and
`--shell=bash` (the default) when Bash 4+ features are needed.
