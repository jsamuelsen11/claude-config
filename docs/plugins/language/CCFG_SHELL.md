# Plugin: ccfg-shell

The shell scripting plugin. Provides agents for shell scripting and automation, project scaffolding,
quality validation, and opinionated conventions for consistent shell development with shellcheck and
shfmt. Intentionally leaner than other language plugins — shell scripts lack meaningful test
frameworks, coverage tooling, and package managers.

## Directory Structure

```text
plugins/ccfg-shell/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── shell-pro.md
│   └── automation-engineer.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── shell-conventions/
    │   └── SKILL.md
    └── script-patterns/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-shell",
  "description": "Shell scripting plugin: shell and automation agents, script scaffolding, and conventions for consistent development with shellcheck and shfmt",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["shell", "bash", "sh", "shellcheck", "shfmt", "automation"],
  "suggestedPermissions": {
    "allow": ["Bash(shellcheck:*)", "Bash(shfmt:*)"]
  }
}
```

## Agents (2)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                 | Role                                                                                         | Model  |
| --------------------- | -------------------------------------------------------------------------------------------- | ------ |
| `shell-pro`           | Bash 4+ (3.2 compatible when targeting macOS), POSIX sh, scripting patterns, error handling, | sonnet |
|                       | portability, shellcheck rules                                                                |        |
| `automation-engineer` | CI/CD scripts, deployment automation, Docker entrypoints, cron jobs, Makefiles               | sonnet |

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

No coverage command — shell scripts lack meaningful coverage tooling. No `--quick` mode — both
shellcheck and shfmt complete in under 2 seconds for typical projects, so there is no meaningful
gate to skip. This is intentional and differs from other ccfg language plugins where full validation
includes slower steps like test suites and compilation.

### /ccfg-shell:validate

**Purpose**: Run the full shell script quality gate suite in one command.

**Trigger**: User invokes before committing or shipping shell scripts.

**Allowed tools**: `Bash(shellcheck *), Bash(shfmt *), Bash(git *), Bash(bats *), Read, Grep, Glob`

**Argument**: `[--exclude=<glob>]`

**Behavior**:

1. **Discover**: Find shell scripts using git-tracked files as the baseline:
   - Files with `.sh` or `.bash` extensions
   - Extensionless files in `bin/`, `scripts/`, `libexec/`, or project-root-level directories that
     have a `#!/bin/bash`, `#!/bin/sh`, or `#!/usr/bin/env bash` shebang
   - Excludes paths matching `.gitignore` automatically (only git-tracked or
     untracked-but-not-ignored files are scanned)
   - Excludes `vendor/`, `node_modules/`, `third_party/`, `.git/` unconditionally
   - Honours `--exclude=<glob>` for additional exclusions (e.g., `--exclude="generated/**"`)
2. **Lint**: `shellcheck -x <files>` (follow sourced files with `-x`)
3. **Format check**: `shfmt -d <files>` (diff mode, uses `.editorconfig` or project's shfmt config
   if present, falls back to `-i 2 -ci -bn`)
4. **Test** (optional): If `bats` is installed and a `test/` or `tests/` directory contains `.bats`
   files, run `bats test/`. Skip with notice if bats is not installed or no `.bats` files exist
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

**Key rules**:

- Discovery uses git-tracked files as the baseline to automatically skip vendored and ignored paths.
  Shebang scanning is scoped to known script directories (`bin/`, `scripts/`, `libexec/`) to avoid
  full-repo file reads
- Uses `shellcheck -x` to follow `source`/`.` directives
- shfmt respects `.editorconfig` when present — do not hardcode formatting flags if the project
  already has an `.editorconfig` with shell settings
- Fix the root cause instead of adding `# shellcheck disable`. If a disable is genuinely necessary
  (false positive, intentional pattern), require `# shellcheck disable=SC#### # reason` with the
  specific code and explanation. Never add bare `# shellcheck disable` without a code
- Reports all gate results, not just the first failure
- Detect-and-skip: if shellcheck, shfmt, or bats is not installed, skip that gate and report it as
  SKIPPED. Never fail because a tool is missing

### /ccfg-shell:scaffold

**Purpose**: Initialize a new shell script or shell project with production-ready defaults.

**Trigger**: User invokes when starting a new shell script or scripting project.

**Allowed tools**: `Bash(chmod *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<name> [--type=script|project] [--shell=bash|sh]`

**Behavior**:

Scaffold differs by type and shell target:

**Script** (single file):

1. Create `<name>.sh` with:

   For `--shell=bash` (default):

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # <name> - <description>
   # Usage: <name>.sh [options]

   SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
   readonly SCRIPT_DIR
   readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

   usage() { ... }
   log() { ... }
   err() { ... }
   cleanup() { ... }
   main() { ... }

   trap cleanup EXIT
   main "$@"
   ```

   For `--shell=sh`:

   ```sh
   #!/bin/sh
   set -eu

   # <name> - <description>
   # Usage: <name>.sh [options]

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   readonly SCRIPT_DIR

   usage() { ... }
   log() { ... }
   err() { ... }
   cleanup() { ... }
   main() { ... }

   trap cleanup EXIT
   main "$@"
   ```

2. Create `.shellcheckrc` alongside the script (or in the project root if inside a repo) with
   `shell=bash` or `shell=sh` directive
3. Set executable permissions: `chmod +x <name>.sh`

**Project** (multi-file scripting project):

1. Create directory structure:

   ```text
   <name>/
   ├── bin/
   │   └── <name>
   ├── lib/
   │   └── utils.sh
   ├── test/
   │   └── .gitkeep
   ├── Makefile
   ├── .shellcheckrc
   ├── .editorconfig
   ├── .gitignore
   └── README.md
   ```

2. Generate `bin/<name>` with full argument parsing (getopts for sh, getopts or while+case for
   bash), sourced lib/ dependencies
3. Generate `lib/utils.sh` with logging, error handling, and color output functions
4. Generate `Makefile` with targets: lint, fmt, check, test, install
5. Generate `.shellcheckrc` with project-wide shellcheck configuration matching `--shell` choice
6. Generate `.editorconfig` with shell formatting settings (indent size, end of line)
7. Set executable permissions on `bin/<name>`

**Key rules**:

- Default `--shell=bash` uses `#!/usr/bin/env bash` and `set -euo pipefail`
- `--shell=sh` uses `#!/bin/sh`, `set -eu` (no `pipefail` in POSIX sh), `[ ]` instead of `[[ ]]`, no
  arrays, no `local` keyword, no `${BASH_SOURCE[0]}`
- `SCRIPT_DIR` computation handles symlinks via `readlink -f` with fallback for macOS (where
  `readlink -f` requires coreutils). The sh variant uses `$0` which is correct for direct invocation
- Script template includes `main()` function pattern — never top-level procedural code
- Project template uses `bin/` + `lib/` + `test/` layout with Makefile as build runner
- Includes `trap cleanup EXIT` for resource cleanup
- `.shellcheckrc` is included in both script and project templates for consistent tooling

## Skills (2)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### shell-conventions

**Trigger description**: "This skill should be used when working on shell scripts, writing bash
code, creating automation scripts, or reviewing shell code."

**Existing repo compatibility**: For existing projects, respect the established style. If the
project uses 4-space indentation, follow it. If the project uses a different shebang pattern or
doesn't use `set -euo pipefail`, follow the established convention. If the project uses `bats-core`
for testing, follow its test directory conventions and helper patterns. These preferences apply to
new scripts and scaffold output only.

**Safety rules**:

- Always `set -euo pipefail` at the top of every bash script (`set -eu` for POSIX sh — `pipefail` is
  not POSIX)
  - `set -e`: Exit on error
  - `set -u`: Error on unset variables
  - `set -o pipefail`: Propagate pipe failures (bash only)
- Always quote variables: `"$var"`, never bare `$var`. The only exception is inside `[[ ]]` where
  word splitting doesn't apply, but quoting is still preferred for consistency
- Use `[[ ]]` for conditionals in bash, `[ ]` in POSIX sh. `[[ ]]` handles empty strings and glob
  patterns safely but is not portable
- Use `"${var:-default}"` for default values, `"${var:?error message}"` for required variables
- Never use `eval`. If you think you need `eval`, you don't — use arrays, `printf %q`, or other safe
  alternatives

**Style rules**:

- Use `shellcheck` for linting — follow all SC rules
- Use `shfmt` for formatting. Respect `.editorconfig` or project shfmt config when present; default
  to 2-space indent, case indent, binary ops on next line for new projects
- Use `snake_case` for variables and functions. Use `UPPER_SNAKE_CASE` for constants and environment
  variables
- Use `local` for all function-scoped variables (bash). In POSIX sh, use naming conventions like
  `_var` for function-local intent
- Use `readonly` for constants: `readonly MY_CONST="value"`
- Prefer `$(command)` over backticks for command substitution
- Use `printf` over `echo` for portable output (especially with `-n` or special characters)
- Declare functions with `name() { }` syntax (no `function` keyword — POSIX compatible)

**Portability rules**:

- Use `#!/usr/bin/env bash` for bash scripts, `#!/bin/sh` for POSIX sh scripts
- If targeting POSIX sh: no arrays, no `[[ ]]`, no `local`, no `pipefail`, no
  `${var//pattern/replacement}`, no `${BASH_SOURCE[0]}`
- Bash 4+ recommended for new scripts. When targeting macOS without Homebrew bash (bash 3.2): avoid
  associative arrays (`declare -A`), `readarray`/`mapfile`, `&>>` redirection, and `${var,,}` /
  `${var^^}` case conversion
- Test on both Linux and macOS when portability matters
- Use `command -v <tool>` to check for tool availability, not `which`

**Structure rules**:

- Use `main()` function pattern — all logic inside functions, `main "$@"` at the bottom
- Use `trap cleanup EXIT` for resource cleanup (temp files, background processes)
- Source library files with `source "${SCRIPT_DIR}/lib/utils.sh"` using `SCRIPT_DIR`
- One function per responsibility. Functions should be small and composable

**Testing rules**:

- For projects using `bats-core`, follow the `test/` directory convention with `.bats` files
- Use `bats-assert` and `bats-support` helpers for structured assertions
- Test functions should be named descriptively: `@test "script exits with error when no args"`
- Not all shell projects need a test framework — for simple scripts, manual validation during
  development and shellcheck in CI is sufficient

### script-patterns

**Trigger description**: "This skill should be used when writing argument parsing, logging
functions, trap handlers, temp file management, or portable shell patterns."

**Contents**:

- **Argument parsing**: Use `getopts` for simple POSIX-compatible option parsing. For long options,
  use a `while` + `case` loop over `"$@"`. Always include `--help`/`-h` handler. Use `shift` to
  consume processed arguments. Validate required arguments after parsing
- **Logging functions**: Define `log()`, `warn()`, `err()`, and `die()` functions. Send log messages
  to stderr (`>&2`). Include timestamps in log output for long-running scripts. Use color codes only
  when connected to a terminal (`[[ -t 2 ]]` in bash, test with `[ -t 2 ]` in POSIX sh)
- **Trap cleanup**: Use `trap cleanup EXIT` (not `trap cleanup ERR`). Clean up temp files, kill
  background processes, restore terminal state. Use `mktemp` for temp files: `tmp_dir=$(mktemp -d)`
  with cleanup in trap handler
- **Temp files**: Always use `mktemp` — never hardcoded paths in `/tmp`. Use `mktemp -d` for temp
  directories. Clean up in trap handler, not at end of script (trap fires on error exit too)
- **Script directory resolution**: Use `readlink -f` with fallback for resolving symlinks:
  `SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"`.
  On macOS without coreutils, `readlink -f` is unavailable; the fallback handles this gracefully.
  For POSIX sh, use `$(cd "$(dirname "$0")" && pwd)` which does not resolve symlinks but is
  universally portable
- **Input validation**: Validate all user inputs before using them. Check file existence with
  `[[ -f "$file" ]]`, directory with `[[ -d "$dir" ]]`. Validate numeric input:
  `[[ "$var" =~ ^[0-9]+$ ]]`. Fail early with descriptive error messages
- **Process management**: Use `wait` for background processes. Capture PIDs: `command & pid=$!`. Use
  `kill -- -$$` in cleanup to terminate child processes. Prefer `xargs -P` or GNU `parallel` over
  manual background process management
- **Portability between bash/zsh/sh**: Avoid zsh-only features in portable scripts. Test with
  `bash --posix` for POSIX compliance. Use `shellcheck -s sh` for POSIX sh scripts,
  `shellcheck -s bash` for bash scripts. Document shell requirements in script header
