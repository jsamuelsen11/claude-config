# Bootstrap Script Family — Design Document

> Comprehensive architecture for the ccfg bootstrap scripts. These scripts handle the things Claude
> Code plugins cannot: `permissions.allow`, `alwaysThinkingEnabled`, `enabledPlugins` in
> settings.json, and `CLAUDE.md` management at both user and project levels.
>
> See also: [DESIGN.md](./DESIGN.md) decision D4.

---

## Table of Contents

- [Purpose](#purpose)
- [Script Family Structure](#script-family-structure)
- [Shared Libraries](#shared-libraries)
- [Script 1: ccfg-bootstrap.sh](#script-1-ccfg-bootstrapsh)
- [Script 2: ccfg-project-init.sh](#script-2-ccfg-project-initsh)
- [Script 3: ccfg-plugins.sh](#script-3-ccfg-pluginssh)
- [Permissions Strategy](#permissions-strategy)
- [CLAUDE.md Management](#claudemd-management)
- [Global vs Local Scope](#global-vs-local-scope)
- [Terminal Output Styling](#terminal-output-styling)
- [Safety Mechanisms](#safety-mechanisms)
- [Shell Conventions](#shell-conventions)
- [User Journey](#user-journey)

---

## Purpose

Claude Code plugins can define agents, commands, skills, hooks, and MCP servers. They **cannot**:

- Set `permissions.allow` (must be in settings.json)
- Set `alwaysThinkingEnabled` (must be in settings.json)
- Set initial `enabledPlugins` (must be in settings.json)
- Contribute to `CLAUDE.md` (delivered via broad-trigger skill instead)

A family of three scripts fills this gap. Each script has a single responsibility and shares common
libraries for consistency and maintainability.

### Design Principles

1. **Non-destructive** — never overwrite, never remove. Append and maintain only.
2. **Idempotent** — safe to run multiple times. Second run produces zero changes.
3. **Preserve customization** — user additions are never touched. Scripts only manage their own
   sections.
4. **One job per script** — small, focused scripts over one monolithic bootstrap.

---

## Script Family Structure

```text
bootstrap/
├── lib/                        # Shared libraries (sourced by all scripts)
│   ├── common.sh               # Logging, colors, unicode, platform, preflight
│   ├── settings.sh             # settings.json / settings.local.json merge operations
│   ├── claude-md.sh            # CLAUDE.md managed-section operations
│   ├── backup.sh               # Timestamped backup/restore/rollback
│   └── detect.sh               # Language/tech-stack detection
├── ccfg-bootstrap.sh           # First-time global setup
├── ccfg-project-init.sh        # Per-project CLAUDE.md + local settings
├── ccfg-plugins.sh             # Third-party plugin recommendations/install
└── templates/
    ├── user-claude.md           # Template for ~/.claude/CLAUDE.md managed content
    └── sections/                # Per-language project CLAUDE.md sections
        ├── python.md
        ├── golang.md
        ├── typescript.md
        ├── java.md
        ├── rust.md
        ├── csharp.md
        ├── shell.md
        ├── docker.md
        ├── kubernetes.md
        ├── github-actions.md
        ├── mysql.md
        ├── postgresql.md
        ├── mongodb.md
        ├── redis.md
        ├── sqlite.md
        └── markdown.md
```

---

## Shared Libraries

### `lib/common.sh`

Sourced by all scripts. Provides:

- **Logging**: `log_info`, `log_warn`, `log_error` with `[INFO]`, `[WARN]`, `[ERROR]` prefixes
- **Colors**: ANSI color variables (`GREEN`, `YELLOW`, `RED`, `CYAN`, `BOLD`, `DIM`, `RESET`),
  auto-disabled when stdout is not a tty (`[[ -t 1 ]]`)
- **Unicode symbols**: `CHECK="✓"`, `CROSS="✗"`, `ARROW="→"`, `DOT="·"`, `WARN_SYM="⚠"`
- **Platform detection**: OS (`linux`/`darwin`), architecture (`x86_64`/`arm64`)
- **Preflight checks**: Verify bash 4+, jq installed, write permissions to target directories
- **Version**: `CCFG_VERSION="0.1.0"` constant

### `lib/settings.sh`

JSON manipulation for `settings.json` and `settings.local.json` via `jq`.

**Core functions:**

- `settings_read <file>` — Read and validate settings JSON
- `settings_merge_permissions <file> <permissions_array>` — Union merge into `permissions.allow`
  (add new entries, never remove existing)
- `settings_merge_plugins <file> <plugin_entries>` — Add `enabledPlugins` keys (never set existing
  to `false`, never remove)
- `settings_set_thinking <file>` — Set `alwaysThinkingEnabled=true` only if key is absent
- `settings_write <file> <json>` — Write to temp file, validate with `jq empty`, atomic `mv`

**Merge strategy:**

```bash
# permissions.allow — union of arrays, deduplicate
jq '.permissions.allow = ((.permissions.allow // []) + $new | unique)' \
  --argjson new "$new_perms" "$settings_file"

# enabledPlugins — add keys, never overwrite existing
jq '.enabledPlugins += $new' \
  --argjson new "$new_plugins" "$settings_file"

# alwaysThinkingEnabled — set only if absent
jq '.alwaysThinkingEnabled //= true' "$settings_file"
```

### `lib/claude-md.sh`

Managed section operations for CLAUDE.md files.

**Marker format:**

```markdown
<!-- ccfg:begin:section-name v0.1.0 -->

... managed content (replaced on re-run) ...

<!-- ccfg:end:section-name -->
```

**Core functions:**

- `claude_md_has_section <file> <section>` — Check if managed section exists
- `claude_md_get_version <file> <section>` — Extract version from marker
- `claude_md_update_section <file> <section> <content> <version>` — Replace content between markers
  (create section if missing, update if version changed)
- `claude_md_create <file> <sections[]>` — Create new CLAUDE.md with managed sections and a
  user-customization footer
- `claude_md_validate <file>` — Verify marker balance (equal start/end counts)

**Behavior on re-run:**

1. If section doesn't exist → append section at end (before user customization footer)
2. If section exists with same version → skip (no changes)
3. If section exists with older version → replace content between markers
4. Content outside markers → never touched

### `lib/backup.sh`

Timestamped backup and restore.

**Core functions:**

- `backup_create <file>` — Copy to `~/.claude/backups/<name>_<YYYYMMDD_HHMMSS>.<ext>`
- `backup_list <file>` — List available backups sorted by date
- `backup_restore <file> [timestamp]` — Restore specific backup (latest if no timestamp)
- `backup_rollback <file>` — Create safety backup of current, then restore previous
- `backup_prune <file> <keep>` — Retain only N most recent backups (default: 10)

**Storage:** `~/.claude/backups/` directory.

### `lib/detect.sh`

Language and technology detection from project files.

**Detection signals:**

| Language/Tech  | Detection files                                                          |
| -------------- | ------------------------------------------------------------------------ |
| Python         | `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `Pipfile` |
| Go             | `go.mod`                                                                 |
| TypeScript     | `package.json` (with typescript dep or tsconfig.json present)            |
| JavaScript     | `package.json` (without TypeScript signals)                              |
| Java           | `pom.xml`, `build.gradle`, `build.gradle.kts`                            |
| Rust           | `Cargo.toml`                                                             |
| C#             | `*.csproj`, `*.sln` (searched to depth 2)                                |
| Shell          | `*.sh` files in root or `scripts/` directory                             |
| Docker         | `Dockerfile`, `docker-compose.yml`, `docker-compose.yaml`, `compose.yml` |
| Kubernetes     | `k8s/` or `kubernetes/` directory, YAML with `kind:` field               |
| GitHub Actions | `.github/workflows/` directory                                           |
| MySQL          | `docker-compose.yml` with mysql image, `.sql` files                      |
| PostgreSQL     | `docker-compose.yml` with postgres image, `.sql` files                   |
| MongoDB        | `docker-compose.yml` with mongo image                                    |
| Redis          | `docker-compose.yml` with redis image                                    |
| SQLite         | `*.db`, `*.sqlite`, `*.sqlite3` files                                    |
| Markdown       | `docs/` directory, `README.md`                                           |

**Core functions:**

- `detect_languages <dir>` — Return array of detected language identifiers
- `detect_has <dir> <language>` — Check if specific language is detected
- `detect_summary <dir>` — Print formatted detection results

---

## Script 1: `ccfg-bootstrap.sh`

First-time global setup. Configures `~/.claude/settings.json` and creates `~/.claude/CLAUDE.md`.

### Responsibilities

1. Merge `permissions.allow` from selected plugins' `suggestedPermissions`
2. Merge `enabledPlugins` for selected ccfg plugins
3. Set `alwaysThinkingEnabled` if not present
4. Create `~/.claude/CLAUDE.md` with user-level best practices
5. Offer symlink to `~/.local/bin/ccfg-bootstrap`

### CLI

```bash
ccfg-bootstrap.sh                     # Interactive mode (default)
ccfg-bootstrap.sh --auto              # Auto-detect, apply defaults, no prompts
ccfg-bootstrap.sh --plugins core,python,docker  # Select specific plugins
ccfg-bootstrap.sh --skip-settings     # Only manage CLAUDE.md
ccfg-bootstrap.sh --skip-claude-md    # Only manage settings.json
ccfg-bootstrap.sh --dry-run           # Preview all changes, apply nothing
ccfg-bootstrap.sh --diff              # Show diff of what would change
ccfg-bootstrap.sh --rollback          # Restore from most recent backup
ccfg-bootstrap.sh --update            # Update managed sections to latest version
ccfg-bootstrap.sh --status            # Show what's currently managed
ccfg-bootstrap.sh --quiet             # Errors and final summary only
ccfg-bootstrap.sh --verbose           # Show jq commands and diff output
```

### Interactive Flow

```text
  ccfg bootstrap v0.1.0
  ══════════════════════

  Preflight
    ✓ bash 5.2     ✓ jq 1.7     ✓ linux x86_64
    ✓ ~/.claude/settings.json found

  Plugin Selection
    ✓ ccfg-core            (always included)
    ✓ ccfg-python          (pyproject.toml detected)
    ✓ ccfg-docker          (Dockerfile detected)
    · ccfg-golang           ccfg-typescript    ccfg-java
    · ccfg-rust             ccfg-csharp        ccfg-shell
    · ccfg-kubernetes       ccfg-github-actions
    · ccfg-markdown         ccfg-mysql         ccfg-postgresql
    · ccfg-mongodb          ccfg-redis         ccfg-sqlite

    Enable additional? [comma-separated or Enter to skip]:

  Settings  ~/.claude/settings.json
    + enabledPlugins  ccfg-core@claude-config
    + enabledPlugins  ccfg-python@claude-config
    + enabledPlugins  ccfg-docker@claude-config
    + permissions     Bash(uvx ruff:*)  Bash(uvx mypy:*)  +4 more
    ~ alwaysThinkingEnabled  already true

  CLAUDE.md  ~/.claude/CLAUDE.md
    + created  best-practices section (v0.1.0)

  Backup
    → ~/.claude/backups/settings_20260210_143000.json

  ──────────────────────
  Done. 2 files updated, 0 errors.
```

### Plugin Discovery

The script reads `suggestedPermissions` from each plugin's `plugin.json`:

```bash
# For each selected plugin
plugin_dir="plugins/$plugin_name/.claude-plugin/plugin.json"
perms=$(jq -r '.suggestedPermissions.allow[]?' "$plugin_dir" 2>/dev/null)
```

This field is added to every `plugin.json` as part of implementation. Claude Code ignores unknown
fields in plugin.json, so this does not break plugin installation.

---

## Script 2: `ccfg-project-init.sh`

Per-project setup. Detects languages and creates project-level `./CLAUDE.md`.

**What it does:**

1. Detect languages in target project directory
2. Create/update `./CLAUDE.md` with language-specific managed sections
3. Optionally update `./.claude/settings.local.json` for locally-scoped plugins

### Three Invocation Modes

```bash
# Mode 1: Run from within the project directory
cd ~/my-project
~/claude-config/bootstrap/ccfg-project-init.sh

# Mode 2: Pass project directory as argument
~/claude-config/bootstrap/ccfg-project-init.sh --project-dir ~/my-project

# Mode 3: Claude Code command (wraps this script)
# /ccfg-core:project-init
```

### Project-Init CLI

```bash
ccfg-project-init.sh                           # Interactive, current dir
ccfg-project-init.sh --project-dir <path>      # Target specific project
ccfg-project-init.sh --auto                    # Auto-detect, no prompts
ccfg-project-init.sh --local                   # Scope plugins to project-local settings
ccfg-project-init.sh --local-plugins python,docker  # Mix: specific plugins local
ccfg-project-init.sh --dry-run                 # Preview only
ccfg-project-init.sh --update                  # Update existing managed sections
```

### Project-Init Interactive Flow

```text
  ccfg project-init v0.1.0
  ═════════════════════════

  Project  ~/my-project

  Detection
    ✓ Python       pyproject.toml
    ✓ Docker       Dockerfile, docker-compose.yml
    ✓ Markdown     docs/, README.md

  CLAUDE.md  ./CLAUDE.md
    + python section (v0.1.0)
    + docker section (v0.1.0)
    + markdown section (v0.1.0)

  ──────────────────────
  Done. 1 file created, 3 sections added.
```

---

## Script 3: `ccfg-plugins.sh`

Third-party plugin recommendations and installation.

**What it does:**

1. Recommend third-party plugins based on detected languages/tech stack
2. Present curated list for user selection
3. Run `claude plugin install` for selected plugins
4. Update `enabledPlugins` in appropriate settings file

### Curated Registry

The script reads its plugin data from `bootstrap/lib/registry.sh` — a bash-sourceable file with 78
plugin entries across 5 marketplaces. See [REGISTRY.md](./REGISTRY.md) for the complete reference.

**Registry summary:**

| Tier        | Count | `--auto` behavior       | Interactive behavior     |
| ----------- | ----- | ----------------------- | ------------------------ |
| **auto**    | 14    | Installed automatically | Pre-selected (checkmark) |
| **suggest** | 30    | Shown, not installed    | Available (dot symbol)   |
| **info**    | 34    | Hidden                  | Only via `--list`        |

**Categories:** 33 LSP plugins (22 languages), 20 general, 20 integration, 2 style, 2 skills, 1
issue tracking.

**LSP overlap handling:** For 11 languages with plugins in both `claude-plugins-official` and
`claude-code-lsps`, both options are presented and the user picks one. In `--auto` mode, overlapping
LSPs are skipped (user must choose interactively).

### Plugins CLI

```bash
ccfg-plugins.sh                        # Interactive, detect and recommend
ccfg-plugins.sh --auto                 # Install all recommended, no prompts
ccfg-plugins.sh --list                 # Show recommendations without installing
ccfg-plugins.sh --category lsp         # Only LSP plugins
ccfg-plugins.sh --category general     # Only general-purpose plugins
ccfg-plugins.sh --dry-run              # Preview only
```

---

## Permissions Strategy

### Dynamic from Plugin Manifests

Each plugin declares permissions in `plugin.json` via `suggestedPermissions`:

```json
{
  "name": "ccfg-python",
  "version": "1.0.0",
  "suggestedPermissions": {
    "allow": [
      "Bash(uvx ruff:*)",
      "Bash(uvx mypy:*)",
      "Bash(uv run pytest:*)",
      "Bash(uv add:*)",
      "Bash(uv sync:*)",
      "Bash(pip install:*)"
    ]
  }
}
```

The bootstrap reads these at runtime and merges into `permissions.allow`.

### Permission Philosophy

Auto-allow **read/analysis, formatting, installation, and build commands**. Only require user
approval for commands that **deploy to external systems** or perform **irreversible destructive
operations**.

| Plugin              | Auto-allowed                                                                                                                | Requires user approval                                    |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| ccfg-core           | `Bash(bd:*)`, `Bash(git:*)`, `Bash(wc:*)`, `Bash(lefthook:*)`                                                               | git push --force to main (blocked by hook)                |
| ccfg-python         | `Bash(uvx ruff:*)`, `Bash(uvx mypy:*)`, `Bash(uv run pytest:*)`, `Bash(uv add:*)`, `Bash(uv sync:*)`, `Bash(pip install:*)` | —                                                         |
| ccfg-golang         | `Bash(go:*)`, `Bash(golangci-lint:*)`                                                                                       | —                                                         |
| ccfg-typescript     | `Bash(npx prettier:*)`, `Bash(npx eslint:*)`, `Bash(npx tsc:*)`, `Bash(npm install:*)`, `Bash(npm run:*)`                   | npm publish                                               |
| ccfg-java           | `Bash(mvn:*)`, `Bash(gradle:*)`                                                                                             | mvn deploy                                                |
| ccfg-rust           | `Bash(cargo:*)`                                                                                                             | cargo publish                                             |
| ccfg-csharp         | `Bash(dotnet:*)`                                                                                                            | nuget push                                                |
| ccfg-shell          | `Bash(shellcheck:*)`, `Bash(shfmt:*)`                                                                                       | —                                                         |
| ccfg-docker         | `Bash(docker build:*)`, `Bash(docker compose:*)`, `Bash(docker ps:*)`, `Bash(docker images:*)`                              | docker push                                               |
| ccfg-kubernetes     | `Bash(kubectl get:*)`, `Bash(kubectl describe:*)`, `Bash(kubectl logs:*)`, `Bash(helm list:*)`, `Bash(helm template:*)`     | kubectl apply, kubectl delete, helm install, helm upgrade |
| ccfg-github-actions | `Bash(gh run list:*)`, `Bash(gh run view:*)`                                                                                | gh run rerun                                              |
| ccfg-markdown       | `Bash(npx markdownlint:*)`                                                                                                  | —                                                         |
| Data plugins        | MCP server tools (in `suggestedPermissions`)                                                                                | —                                                         |

---

## CLAUDE.md Management

### Managed Section Format

```markdown
<!-- ccfg:begin:section-name v0.1.0 -->

... managed content ...

<!-- ccfg:end:section-name -->
```

- **Versioned**: Marker includes version for update detection
- **Idempotent**: Same version = no changes on re-run
- **Non-destructive**: Everything outside markers is untouched

### User-Level Content (`~/.claude/CLAUDE.md`)

Single managed section with condensed, always-on best practices extracted from the workflow-rules
skill. This is always loaded into Claude's context, so brevity matters.

```markdown
<!-- ccfg:begin:best-practices v0.1.0 -->

# Best Practices

## Code Quality

- Fix linter/formatter errors — never bypass with nolint, noqa, or eslint-disable
- No magic numbers — use named constants
- Handle errors explicitly — no empty catch blocks or swallowed exceptions
- Type-annotate function signatures in typed languages

## Git Workflow

- Never push to main directly — use feature branches
- Stage specific files (not `git add -A`)
- Conventional commits: type(scope): description
- Never skip hooks (--no-verify) unless explicitly requested
- After hook failure, create a NEW commit (never amend the previous one)

## Security

- Never commit secrets (.env, credentials, private keys)
- Never use chmod 777
- Never pipe remote content to shell (curl | sh)

## Task Discipline

- Complete one task fully before starting the next
- Work is not done until git push succeeds
- When multiple approaches exist, present options before implementing
<!-- ccfg:end:best-practices -->

## User Customizations

Add your personal preferences below.
```

### Project-Level Content (`./CLAUDE.md`)

One managed section per detected language/technology. Each section is intentionally concise (8-15
lines) since CLAUDE.md is always loaded into context. Deep detail stays in plugin skills which
trigger contextually.

Example for a Python + Docker project:

```markdown
<!-- ccfg:begin:python v0.1.0 -->

## Python Conventions

- Toolchain: uv (packaging), ruff (lint+format), mypy (types), pytest (test)
- Always: `from __future__ import annotations`
- Union types: `X | Y` (not Optional[X])
- Paths: pathlib.Path (not os.path)
- Data: dataclasses or Pydantic (not raw dicts)
- Logging: `logging` module (not print())
- Imports: stdlib, third-party, local (one per line)
- Test files: `test_<module>.py`, functions: `test_<behavior>()`
<!-- ccfg:end:python -->

<!-- ccfg:begin:docker v0.1.0 -->

## Docker Conventions

- Multi-stage builds for production images
- Pin base image versions (no :latest)
- Use .dockerignore to exclude build artifacts
- One process per container
- COPY before RUN for layer caching
- Non-root USER in final stage
<!-- ccfg:end:docker -->

## Project-Specific Notes

Add project-specific conventions below.
```

---

## Global vs Local Scope

Claude Code has a layered settings model:

| File                            | Scope                 | Gitignored      |
| ------------------------------- | --------------------- | --------------- |
| `~/.claude/settings.json`       | Global (all projects) | N/A (user home) |
| `./.claude/settings.local.json` | Project-local         | Yes             |

### Decision Matrix

| Plugin type            | Default scope | Override       |
| ---------------------- | ------------- | -------------- |
| ccfg-core              | Always global | —              |
| Language plugins       | Global        | `--local` flag |
| Data plugins           | Global        | `--local` flag |
| Infrastructure plugins | Global        | `--local` flag |

### What Gets Written Where

| Action                  | Global plugin                    | Local plugin                    |
| ----------------------- | -------------------------------- | ------------------------------- |
| `enabledPlugins`        | `~/.claude/settings.json`        | `./.claude/settings.local.json` |
| `permissions.allow`     | `~/.claude/settings.json`        | `./.claude/settings.local.json` |
| `alwaysThinkingEnabled` | Always `~/.claude/settings.json` | —                               |
| User-level CLAUDE.md    | Always `~/.claude/CLAUDE.md`     | —                               |
| Project-level CLAUDE.md | —                                | Always `./CLAUDE.md`            |

### Interactive Scope Selection

```text
  Plugin Scope
    Global (applies to all projects):
      ✓ ccfg-core              (always global)
      ✓ ccfg-python            (selected)
      ✓ ccfg-shell             (selected)

    Local to ~/my-project only:
      ✓ ccfg-docker            (selected)
      ✓ ccfg-kubernetes        (selected)
```

---

## Terminal Output Styling

### Color Palette

```bash
BOLD='\033[1m'
GREEN='\033[0;32m'    # Success, created, added
YELLOW='\033[0;33m'   # Warning, skipped, already exists
RED='\033[0;31m'      # Error, failed
CYAN='\033[0;36m'     # Info, file paths, section names
DIM='\033[2m'         # Secondary info, timestamps
RESET='\033[0m'
```

### Unicode Symbols

```bash
CHECK="✓"    # Success
CROSS="✗"    # Failure
ARROW="→"    # Action/result
DOT="·"      # List item
WARN_SYM="⚠" # Warning
```

### Behavior

- **No color when piped**: Detect `[[ -t 1 ]]` and strip ANSI when stdout is not a tty
- **Quiet mode** (`--quiet`): Only errors and final summary
- **Verbose mode** (`--verbose`): Show jq commands, diff output, file contents
- **Diff output**: Unified diff format with color highlighting
- **Interactive prompts**: Default answers in brackets, Enter to accept: `[Y/n]`
- **Progress**: Each phase has a header, each action gets a status symbol immediately

---

## Safety Mechanisms

### Backups

- **Location**: `~/.claude/backups/`
- **Format**: `settings_20260210_143000.json`, `CLAUDE_user_20260210_143000.md`
- **Retention**: 10 most recent per file type
- **Created**: Automatically before any file modification

### Dry-Run (`--dry-run`)

Computes all changes, prints diffs, writes nothing. Uses `diff -u` (or `delta` if available).

### Rollback (`--rollback`)

Lists available backups with timestamps. Restores selected backup. Creates a safety backup of
current state before rollback.

### Validation

- JSON syntax validation via `jq empty` after every settings.json write
- CLAUDE.md marker balance check (equal start/end counts per section)
- Preflight: bash version, jq exists, write permissions, settings.json parseable

### Error Handling

```bash
set -euo pipefail

trap cleanup EXIT ERR

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Bootstrap failed. Your original files are preserved."
        log_error "Backup at: $BACKUP_FILE"
    fi
}
```

---

## Shell Conventions

- **Shebang**: `#!/usr/bin/env bash`
- **Strict mode**: `set -euo pipefail`
- **Minimum version**: bash 4+ (arrays, associative arrays, `[[ ]]`)
- **Style**: shellcheck-clean, shfmt-formatted (matching project lefthook config)
- **Dependencies**: bash 4+, jq, coreutils only. No python, no npm, no ruby.
- **Platform**: Linux + macOS, x86_64 + arm64
- **Portability**: Handle `date`, `sed`, `mktemp` differences between GNU and BSD coreutils

---

## User Journey

### First-Time Setup

```bash
# 1. Clone the repo
git clone https://github.com/jsamuelsen11/claude-config.git ~/claude-config

# 2. Add as marketplace
claude plugin marketplace add jsamuelsen11/claude-config

# 3. Run bootstrap (one-time global setup)
~/claude-config/bootstrap/ccfg-bootstrap.sh
```

### Per-Project Setup

```bash
# Option A: Run from project directory
cd ~/my-project
~/claude-config/bootstrap/ccfg-project-init.sh

# Option B: Pass project directory
~/claude-config/bootstrap/ccfg-project-init.sh --project-dir ~/my-project

# Option C: Claude Code command (after ccfg-core is installed)
# /ccfg-core:project-init
```

### Convenience Symlink

```bash
# Offered during first-time setup
ln -s ~/claude-config/bootstrap/ccfg-bootstrap.sh ~/.local/bin/ccfg-bootstrap
ln -s ~/claude-config/bootstrap/ccfg-project-init.sh ~/.local/bin/ccfg-project-init
ln -s ~/claude-config/bootstrap/ccfg-plugins.sh ~/.local/bin/ccfg-plugins
```

### Third-Party Plugins

```bash
# Recommend and install third-party plugins
~/claude-config/bootstrap/ccfg-plugins.sh

# Or with convenience symlink
ccfg-plugins
```

### Updating

```bash
# Update managed sections to latest template versions
ccfg-bootstrap --update
ccfg-project-init --update
```
