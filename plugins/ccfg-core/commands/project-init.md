---
description: Initialize project CLAUDE.md with language-specific conventions
argument-hint: '[--auto] [--dry-run] [--update] [--project-dir <path>]'
allowed-tools: Bash(*/ccfg-project-init.sh:*), Bash(*/ccfg-project-init:*), Read, Glob, Grep
---

# Project Init

Initialize a project's `CLAUDE.md` with managed convention sections based on automatic language and
technology detection. Detects Python, Go, TypeScript, Java, Rust, C#, Shell, Docker, Kubernetes,
GitHub Actions, MySQL, PostgreSQL, MongoDB, Redis, SQLite, and Markdown.

## Usage

```bash
/project-init
/project-init --auto
/project-init --project-dir ~/other-project
/project-init --update
/project-init --dry-run
```

**Options:**

- `--project-dir <path>` — Target a specific project directory (default: current directory)
- `--auto` — Skip confirmation prompts, apply all detected sections
- `--local` — Scope detected plugins to project-local `.claude/settings.local.json`
- `--local-plugins <list>` — Comma-separated plugins to scope locally
- `--dry-run` — Preview changes without writing anything
- `--update` — Update existing managed sections to latest template versions
- `--quiet` — Errors and final summary only
- `--verbose` — Show detailed operations

## Process

### Step 1: Locate the Bootstrap Script

The `ccfg-project-init.sh` script is part of the claude-config bootstrap family. Find it relative to
this plugin's repository:

```bash
# Check common locations
ls ~/claude-config/bootstrap/ccfg-project-init.sh 2>/dev/null
ls ~/.local/bin/ccfg-project-init 2>/dev/null
```

If neither exists, search for it:

```bash
# Find in typical install locations
find ~ -maxdepth 4 -name "ccfg-project-init.sh" -type f 2>/dev/null | head -1
```

### Step 2: Run the Script

Execute the bootstrap script with the user's arguments. Always pass `--auto` when running from a
Claude Code session (stdin is not a tty):

```bash
# Default: auto mode for current project directory
~/claude-config/bootstrap/ccfg-project-init.sh --auto

# With user-provided flags
~/claude-config/bootstrap/ccfg-project-init.sh --auto --dry-run
~/claude-config/bootstrap/ccfg-project-init.sh --auto --project-dir /path/to/project
~/claude-config/bootstrap/ccfg-project-init.sh --auto --update
~/claude-config/bootstrap/ccfg-project-init.sh --auto --local
```

### Step 3: Report Results

After the script completes, summarize what happened:

1. Which sections were added, updated, or skipped
2. Path to the created/updated `CLAUDE.md`
3. If `--local` was used, show `settings.local.json` changes
4. Report any errors or warnings

### Step 4: Verify CLAUDE.md

After script completion, verify the managed sections are well-formed:

```bash
# Marker balance check (begin count should equal end count)
grep -c "ccfg:begin:" ./CLAUDE.md
grep -c "ccfg:end:" ./CLAUDE.md
```

## What Gets Created

The script generates a `./CLAUDE.md` with managed sections like:

```markdown
<!-- ccfg:begin:python v0.1.0 -->

## Python Conventions

- Toolchain: uv (packaging), ruff (lint+format), mypy (types), pytest (test) ...

<!-- ccfg:end:python -->

## User Customizations

Add your project-specific conventions below.
```

Each section is 8-15 lines of concise conventions. Deep detail is provided by the corresponding
plugin skill (e.g., ccfg-python's python-conventions skill triggers automatically when working with
Python files).

## Behavior

- **First run:** Creates `./CLAUDE.md` with sections for all detected technologies
- **Subsequent runs:** Only adds sections for newly detected technologies (skips existing)
- **With --update:** Also refreshes existing sections to latest template versions
- **Idempotent:** Running with same template version produces zero changes

## Safety

- Creates a backup before any modification (`~/.claude/backups/`)
- Never modifies content outside `<!-- ccfg:begin/end -->` markers
- `--dry-run` previews all changes without writing
- User content in `## User Customizations` is never touched

## Requirements

- bash 4+, jq, coreutils
- The claude-config repository must be cloned locally
