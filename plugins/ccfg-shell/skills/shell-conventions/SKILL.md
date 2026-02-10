---
name: shell-conventions
description:
  This skill should be used when working on shell scripts, writing bash or sh code, reviewing shell
  scripts, or running shell-based automation. It covers safety rules, style rules, portability
  rules, and structure rules for production-quality shell scripting.
version: 0.1.0
---

# Shell Conventions

This skill defines comprehensive conventions for writing safe, consistent, and maintainable shell
scripts. These conventions apply to both Bash and POSIX sh scripts and prioritize correctness,
safety, and shellcheck compliance.

## Safety Rules

### Always Use Strict Mode

Every bash script must begin with the strict mode preamble. This catches undefined variables,
command failures, and pipeline errors at the earliest point.

```bash
# CORRECT: Bash strict mode
#!/usr/bin/env bash
set -euo pipefail
```

```sh
# CORRECT: POSIX sh strict mode (no pipefail available)
#!/bin/sh
set -eu
```

```bash
# WRONG: Missing strict mode
#!/usr/bin/env bash
# No safety net -- errors are silently ignored
echo "This script is dangerous"
```

```bash
# WRONG: Only partial strict mode
#!/usr/bin/env bash
set -e
# Missing -u (unset variables go undetected)
# Missing -o pipefail (pipe failures are hidden)
echo "Partially dangerous: $UNDEFINED_VAR"
```

**Why each flag matters**:

- `set -e`: Exit on the first command that returns non-zero. Without this, the script continues
  after errors, causing cascading failures.
- `set -u`: Treat unset variables as errors. Without this, typos in variable names silently expand
  to empty strings.
- `set -o pipefail`: A pipeline returns the exit status of the last command to exit with non-zero
  status. Without this, `failing_cmd | good_cmd` appears to succeed.

### Always Quote Variables

Every variable expansion must be double-quoted unless intentional word splitting or globbing is
needed (and explicitly documented).

```bash
# CORRECT: Quoted variables
name="John Doe"
echo "$name"
cp "$source" "$dest"
rm -rf "${tmpdir:?}/"
[[ -f "$config_file" ]] && source "$config_file"

# CORRECT: Quoted in array expansion
files=("file one.txt" "file two.txt")
for f in "${files[@]}"; do
    process "$f"
done

# CORRECT: Quoted in function arguments
greet() {
    local name="$1"
    echo "Hello, $name"
}
greet "$user_name"
```

```bash
# WRONG: Unquoted variables
name="John Doe"
echo $name                 # Word splits into "John" and "Doe"
cp $source $dest           # Breaks on spaces or glob characters
rm -rf $tmpdir/            # Catastrophic if tmpdir is empty
[ -f $config_file ]        # Fails if config_file has spaces
```

```bash
# CORRECT: Intentional unquoting (with comment)
# Word splitting is intentional here: flags is a space-separated list
# shellcheck disable=SC2086
curl $curl_flags "$url"

# BETTER: Use an array instead of word splitting
curl_flags=(-sf --retry 3)
curl "${curl_flags[@]}" "$url"
```

### Use Safe Default Values

Protect against unset variables with parameter expansion defaults. Use `:?` to enforce required
variables.

```bash
# CORRECT: Default values for optional variables
log_level="${LOG_LEVEL:-info}"
output_dir="${OUTPUT_DIR:-./build}"
max_retries="${MAX_RETRIES:-3}"

# CORRECT: Required variables with error messages
database_url="${DATABASE_URL:?DATABASE_URL environment variable is required}"
api_key="${API_KEY:?API_KEY must be set}"

# CORRECT: Safe directory removal (prevent rm -rf /)
rm -rf "${BUILD_DIR:?BUILD_DIR must be set}/"
```

```bash
# WRONG: No defaults or guards
log_level="$LOG_LEVEL"           # Fails with set -u if unset
rm -rf "$BUILD_DIR/"             # rm -rf / if BUILD_DIR is empty
```

### Use Trap for Cleanup

Every script that creates temporary files, starts background processes, or acquires resources must
use a trap handler to clean up.

```bash
# CORRECT: Trap cleanup on EXIT
tmpdir=""
cleanup() {
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -rf "$tmpdir"
    fi
}
trap cleanup EXIT

tmpdir=$(mktemp -d)
# Work with tmpdir... cleanup is automatic
```

```bash
# WRONG: Manual cleanup at end of script
tmpdir=$(mktemp -d)
# ... do work ...
rm -rf "$tmpdir"    # Never reached if script fails
```

```bash
# WRONG: No cleanup at all
tmpdir=$(mktemp -d)
# ... do work ...
# Temp files accumulate over time
```

### Separate Declaration and Assignment

When using `local`, declare and assign on separate lines to preserve exit codes. Combined
declaration masks the return value of the command substitution.

```bash
# CORRECT: Separate declare and assign (SC2155)
local output
output=$(some_command)

local exit_code
exit_code=$?
```

```bash
# WRONG: Combined declaration masks return value
local output=$(some_command)    # $? is always 0 here, even if some_command fails
```

## Style Rules

### Use shellcheck

All shell scripts must pass `shellcheck -x` without warnings. Do not globally disable rules. When a
specific rule must be disabled for a line, add a comment explaining why.

```bash
# CORRECT: shellcheck is clean
#!/usr/bin/env bash
set -euo pipefail

name="${1:?name required}"
echo "Hello, $name"
```

```bash
# CORRECT: Targeted disable with explanation
# Variable is exported for use by child processes
# shellcheck disable=SC2034
EXPORTED_CONFIG="$config_path"

# Source path hint so shellcheck can follow the source
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
```

```bash
# WRONG: Blanket disabling
# shellcheck disable=SC2086,SC2046,SC2034
# Disabling multiple rules hides real bugs
```

### Use shfmt for Formatting

All shell scripts must be formatted with `shfmt`. Respect project `.editorconfig` if present.

```bash
# CORRECT: Consistent formatting (4-space indent, shfmt default style)
if [[ -f "$config" ]]; then
    source "$config"
    log "Config loaded: $config"
else
    warn "No config file found"
fi

case "$action" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    *)
        die "Unknown action: $action"
        ;;
esac
```

```bash
# WRONG: Inconsistent formatting
if [[ -f "$config" ]]; then
  source "$config"           # 2-space indent
    log "Config loaded"      # 4-space indent -- mixed
else
warn "No config"             # No indent
fi
```

### Use snake_case for Variables and Functions

Shell convention is `snake_case` for variable names and function names. Constants use
`UPPER_SNAKE_CASE`.

```bash
# CORRECT: snake_case for variables and functions
log_file="/var/log/app.log"
max_retries=3
output_dir="./build"

process_input() {
    local input_file="$1"
    local output_format="${2:-json}"
    # ...
}

# CORRECT: UPPER_SNAKE_CASE for constants
readonly MAX_CONNECTIONS=100
readonly DEFAULT_PORT=8080
readonly CONFIG_DIR="/etc/myapp"
```

```bash
# WRONG: camelCase or PascalCase
logFile="/var/log/app.log"         # Not shell convention
maxRetries=3                       # Use snake_case
outputDir="./build"                # Use snake_case

processInput() {                   # Use snake_case
    local inputFile="$1"           # Use snake_case
}
```

### Use printf Over echo

`echo` has inconsistent behavior across platforms and shells. `printf` is predictable and portable.

```bash
# CORRECT: printf for output
printf '%s\n' "$message"
printf 'Name: %s, Age: %d\n' "$name" "$age"
printf 'Error: %s\n' "$error_msg" >&2

# CORRECT: echo is OK for simple, literal strings
echo "Starting server..."
echo ""
```

```bash
# WRONG: echo with flags or variables that may contain special chars
echo -e "column1\tcolumn2"     # -e is not portable
echo -n "no newline"           # -n is not portable
echo "$user_input"             # If user_input is "-n", echo eats it
```

### Use [[]] in Bash and [ ] in POSIX sh

```bash
# CORRECT: [[ ]] in bash scripts
#!/usr/bin/env bash
if [[ -z "$var" ]]; then echo "empty"; fi
if [[ "$name" == *.txt ]]; then echo "text file"; fi
if [[ "$num" =~ ^[0-9]+$ ]]; then echo "numeric"; fi
```

```sh
# CORRECT: [ ] in POSIX sh scripts
#!/bin/sh
if [ -z "$var" ]; then echo "empty"; fi
# Use case for pattern matching in POSIX sh
case "$name" in
    *.txt) echo "text file" ;;
esac
```

```bash
# WRONG: [ ] in bash when [[ ]] is available
#!/usr/bin/env bash
if [ -z $var ]; then echo "empty"; fi     # Unquoted, breaks on spaces
if [ "$a" = "*.txt" ]; then echo "no"; fi # No pattern matching in [ ]
if [ -f "$a" -a -r "$a" ]; then           # -a is deprecated
    echo "readable"
fi
```

### Use command -v for Command Detection

```bash
# CORRECT: command -v is POSIX compliant
if command -v docker &>/dev/null; then
    echo "Docker is available"
fi

# CORRECT: Require a command or die
require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "Required command not found: $1"
    fi
}
```

```bash
# WRONG: which is not POSIX and behaves differently across systems
if which docker &>/dev/null; then
    echo "Docker found"
fi

# WRONG: type -P is bash-only
if type -P docker &>/dev/null; then
    echo "Docker found"
fi
```

## Portability Rules

### Know Bash vs POSIX sh Differences

When writing scripts that must run in POSIX sh (`/bin/sh`), avoid all bash extensions. Here is a
complete reference of features to avoid:

```bash
# BASH-ONLY FEATURES (not available in POSIX sh):

# 1. [[ ]] extended test
[[ "$x" == *.txt ]]          # Use: case "$x" in *.txt) ... ;; esac

# 2. Arrays
arr=("a" "b" "c")            # Use: set -- "a" "b" "c" ; for item in "$@"

# 3. Associative arrays
declare -A map                # No POSIX equivalent (use files or awk)

# 4. pipefail
set -o pipefail               # Not available; check each pipe component

# 5. Process substitution
diff <(sort f1) <(sort f2)   # Use: sort f1 > /tmp/s1; sort f2 > /tmp/s2; diff /tmp/s1 /tmp/s2

# 6. Here-strings
grep "x" <<< "$var"          # Use: printf '%s\n' "$var" | grep "x"

# 7. BASH_SOURCE
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"   # Use: SCRIPT_DIR="$(dirname "$0")"

# 8. Regex matching
[[ "$x" =~ ^[0-9]+$ ]]      # Use: echo "$x" | grep -qE '^[0-9]+$'

# 9. Brace expansion
echo {1..5}                   # Use: seq 1 5  or  i=1; while [ $i -le 5 ]; do ... done

# 10. Case modification
echo "${var,,}"               # Use: echo "$var" | tr '[:upper:]' '[:lower:]'
```

### POSIX sh Pattern Matching

```sh
# CORRECT: Use case for pattern matching in POSIX sh
#!/bin/sh

is_shell_script() {
    case "$1" in
        *.sh|*.bash) return 0 ;;
        *)           return 1 ;;
    esac
}

validate_env() {
    case "$1" in
        dev|development) echo "development" ;;
        stg|staging)     echo "staging" ;;
        prd|production)  echo "production" ;;
        *)               echo "unknown"; return 1 ;;
    esac
}
```

```sh
# WRONG: Using bash pattern matching in POSIX sh
#!/bin/sh
if [[ "$1" == *.sh ]]; then    # [[ ]] not available
    echo "shell script"
fi
```

### Cross-Platform Considerations

```bash
# CORRECT: Detect OS and adjust commands
stat_size() {
    case "$(uname -s)" in
        Darwin) stat -f%z "$1" ;;
        Linux)  stat -c%s "$1" ;;
        *)      wc -c < "$1" | tr -d ' ' ;;
    esac
}

# CORRECT: Cross-platform sed in-place
sed_inplace() {
    if [ "$(uname -s)" = "Darwin" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# CORRECT: Portable mktemp (macOS requires template with X's)
make_tempfile() {
    mktemp "${TMPDIR:-/tmp}/myapp.XXXXXX"
}
```

```bash
# WRONG: Linux-specific commands without fallback
stat -c%s "$file"              # Fails on macOS
sed -i 's/old/new/' file.txt   # Fails on macOS (needs -i '')
readlink -f "$path"            # Fails on macOS (no -f option)
```

### Shebang Best Practices

```bash
# CORRECT: Use env for portability
#!/usr/bin/env bash

# CORRECT: Direct path for system scripts where env may not be available
#!/bin/bash

# CORRECT: POSIX sh for maximum portability
#!/bin/sh
```

```bash
# WRONG: Hardcoded non-standard paths
#!/usr/local/bin/bash          # Not available on many systems
#!/usr/bin/bash                # Not standard on all Linux distros
```

## Structure Rules

### Use the main() Pattern

Every script beyond a trivial one-liner must use the main() pattern. This prevents accidental
execution during sourcing and provides clear structure.

```bash
# CORRECT: main() pattern
#!/usr/bin/env bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }

process() {
    local input="$1"
    log "Processing: $input"
    # ...
}

main() {
    local target="${1:?target required}"
    log "Starting"
    process "$target"
    log "Done"
}

main "$@"
```

```bash
# WRONG: Top-level code without main()
#!/usr/bin/env bash
set -euo pipefail

target="${1:?target required}"
echo "Processing $target"
# This code runs if the file is sourced, which may not be intended
```

### Resolve SCRIPT_DIR Reliably

Every script that references relative paths must resolve its own directory first.

```bash
# CORRECT: Reliable script directory resolution (bash)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CORRECT: Source libraries relative to script directory
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
```

```sh
# CORRECT: POSIX sh script directory (less reliable with symlinks)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

```bash
# WRONG: Assumes working directory is script directory
source ./lib/utils.sh           # Fails if run from another directory
config=$(cat config.yaml)       # Fails if run from another directory
```

### Source with Include Guards

Library files that may be sourced multiple times should use include guards to prevent re-execution.

```bash
# CORRECT: Include guard in library file
# lib/logging.sh
[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return 0
_LOGGING_SH_LOADED=1

log() { printf '%s\n' "$*" >&2; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
```

```sh
# CORRECT: POSIX sh include guard
# lib/logging.sh
if [ "${_LOGGING_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || true
fi
_LOGGING_SH_LOADED=1

log() { printf '%s\n' "$*" >&2; }
```

```bash
# WRONG: No include guard
# lib/logging.sh
log() { printf '%s\n' "$*" >&2; }    # Redefined if sourced twice
```

### Stderr for Diagnostics, Stdout for Data

Diagnostic messages (logs, warnings, errors) go to stderr. Data output goes to stdout so it can be
piped.

```bash
# CORRECT: Logs to stderr, data to stdout
find_large_files() {
    local dir="$1"
    log "Searching $dir..."             # stderr (diagnostic)
    find "$dir" -size +10M -print       # stdout (data)
    log "Search complete"               # stderr (diagnostic)
}

# This works correctly with pipes:
find_large_files /var/log | head -5
```

```bash
# WRONG: Everything to stdout
find_large_files() {
    local dir="$1"
    echo "Searching $dir..."            # Mixes with data output
    find "$dir" -size +10M -print
    echo "Search complete"              # Also mixes with data
}

# Broken: "Searching..." and "Search complete" appear in piped output
find_large_files /var/log | head -5
```

### Use Temporary Files Safely

```bash
# CORRECT: mktemp with cleanup trap
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

tmpfile="$tmpdir/output.json"
curl -sf "$url" > "$tmpfile"
jq '.data' "$tmpfile"
```

```bash
# WRONG: Predictable temp file names (security risk)
tmpfile="/tmp/myapp_output"       # Race condition (symlink attack)
tmpfile="/tmp/myapp_$$"           # PID is predictable
echo "data" > "$tmpfile"
```

```bash
# WRONG: No cleanup
tmpfile=$(mktemp)
echo "data" > "$tmpfile"
# temp file accumulates on disk forever
```

### Use readonly for Constants

```bash
# CORRECT: Mark constants as readonly
readonly VERSION="1.2.3"
readonly CONFIG_DIR="/etc/myapp"
readonly MAX_RETRIES=5
```

```bash
# WRONG: Mutable constants
VERSION="1.2.3"                # Can be accidentally overwritten
CONFIG_DIR="/etc/myapp"        # No protection against modification
```

## Input Handling Rules

### Validate All User Input

Never trust user input. Always validate before use.

```bash
# CORRECT: Validate before use
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        die "Invalid port: $port (must be 1-65535)"
    fi
}

validate_environment() {
    case "$1" in
        development|staging|production) ;;
        *) die "Invalid environment: $1 (must be development, staging, or production)" ;;
    esac
}
```

```bash
# WRONG: Using input directly without validation
port="$1"
curl "http://localhost:$port/api"     # What if port is "8080; rm -rf /"?
```

### Handle Missing Arguments Gracefully

```bash
# CORRECT: Check argument count with helpful error
if (( $# < 2 )); then
    echo "Usage: $(basename "$0") <source> <destination>" >&2
    echo "  source       Source directory to backup" >&2
    echo "  destination  Backup target location" >&2
    exit 1
fi
source_dir="$1"
dest_dir="$2"
```

```bash
# WRONG: Just let set -u catch it (unhelpful error message)
source_dir="$1"    # "bash: $1: unbound variable" -- not user friendly
dest_dir="$2"
```

## Iteration and Looping Rules

### Iterate Files Safely

```bash
# CORRECT: Glob with null guard
for file in *.txt; do
    [[ -e "$file" ]] || continue    # Guard against no-match (nullglob)
    process "$file"
done

# CORRECT: find with null delimiter for complex searches
while IFS= read -r -d '' file; do
    process "$file"
done < <(find . -name "*.sh" -type f -print0)
```

```bash
# WRONG: Parsing ls output
for file in $(ls *.txt); do        # Breaks on spaces, glob chars
    process "$file"
done

# WRONG: Unguarded glob (if no .txt files, literal "*.txt" is processed)
for file in *.txt; do
    process "$file"                 # Processes literal "*.txt" if no matches
done
```

### Read Lines Correctly

```bash
# CORRECT: Read lines preserving whitespace
while IFS= read -r line; do
    printf '%s\n' "$line"
done < "$input_file"

# CORRECT: Read from command output (process substitution avoids subshell)
while IFS= read -r line; do
    (( count++ ))
done < <(grep "pattern" "$file")
echo "$count"    # Correct: loop ran in current shell
```

```bash
# WRONG: for loop splits on whitespace, not newlines
for line in $(cat "$input_file"); do
    echo "$line"                    # Each word is a separate "line"
done

# WRONG: Pipe creates subshell (variables are lost)
count=0
grep "pattern" "$file" | while IFS= read -r line; do
    (( count++ ))
done
echo "$count"    # Always 0: loop ran in subshell
```

## Error Handling Rules

### Check cd and Critical Commands

```bash
# CORRECT: Check cd or use subshell
cd "$dir" || die "Cannot change to directory: $dir"

# CORRECT: Subshell to avoid polluting working directory
(cd "$build_dir" && make clean && make all)

# CORRECT: Use pushd/popd for temporary directory changes
pushd "$dir" > /dev/null || die "Cannot pushd to $dir"
# ... work in $dir ...
popd > /dev/null
```

```bash
# WRONG: Unchecked cd
cd "$dir"
rm -rf ./*              # Deletes wrong files if cd failed!
```

### Use Arithmetic Properly

```bash
# CORRECT: (( )) for arithmetic
if (( count > max_retries )); then
    die "Too many retries"
fi
(( attempts++ )) || true    # || true because (( 0 )) returns non-zero

# CORRECT: $(( )) for arithmetic expansion
total=$(( width * height ))
next_page=$(( page + 1 ))
```

```bash
# WRONG: [ ] for arithmetic comparison
if [ "$count" -gt "$max_retries" ]; then   # Works but less readable in bash
    die "Too many retries"
fi

# WRONG: expr for arithmetic (slow, external process)
total=$(expr "$width" \* "$height")
```

## Summary Checklist

When writing shell scripts, ensure:

- [ ] `set -euo pipefail` (bash) or `set -eu` (sh) at the top
- [ ] All variables double-quoted
- [ ] `trap cleanup EXIT` for temporary resources
- [ ] `main()` pattern with `main "$@"` at the bottom
- [ ] `SCRIPT_DIR` resolved for relative path references
- [ ] `printf` instead of `echo` for formatted output
- [ ] `[[ ]]` in bash, `[ ]` in POSIX sh
- [ ] `command -v` instead of `which` for command detection
- [ ] `local` for all function variables (bash)
- [ ] Separate `local` declaration and assignment
- [ ] `mktemp` for temporary files (never hardcoded paths)
- [ ] `readonly` for constants
- [ ] `snake_case` for variables and functions, `UPPER_SNAKE_CASE` for constants
- [ ] stderr for diagnostics, stdout for data
- [ ] Input validation before use
- [ ] Passes `shellcheck -x` without warnings
- [ ] Passes `shfmt -d` without changes
- [ ] No bashisms in POSIX sh scripts
- [ ] Include guards in library files
- [ ] `# shellcheck source=` hints for sourced files

These conventions ensure shell scripts are safe, portable, and maintainable across teams and
environments.
