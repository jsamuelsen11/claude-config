# ccfg Design Document

> Canonical source of truth for all design decisions, merge rules, layering
> semantics, and conventions. A fresh Claude session should read this file first.

## Purpose

`ccfg` is a portable, version-controlled Claude Code configuration distribution.
It encodes workflow preferences discovered across 275 sessions and 2,322 messages
into a layered configuration system that can be installed on multiple development
machines via a single command.

The system solves recurring friction: Claude taking wrong approaches (42 instances),
producing buggy code that fails pre-commit (34), and being rejected for shortcuts
like nolint directives (27). All preventable with front-loaded configuration.

## Design Decisions

These decisions were made through discussion and are locked in. Do not revisit
without explicit user request.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Python CLI via uv + Typer** | Testable with pytest, proper error handling, uv is already standard. Replaces all shell libs. |
| D2 | **bin/ccfg is a thin shell wrapper** (`exec uv run ccfg "$@"`) | Convenience entry point. Actual logic lives in Python. |
| D3 | **Merge engine tested with pytest from day 1** | compose.py is critical path. Three distinct merge strategies need fixture-based validation. |
| D4 | **settings.json is COPIED, not symlinked** | Claude Code writes runtime state (feedbackSurveyState) to it. Symlink would cause git diffs. Hash tracking detects drift. |
| D5 | **Agents are SYMLINKED** | Agent .md files are read-only. Symlinks mean `git pull` instantly updates everywhere. |
| D6 | **Plugins directory NOT managed** | Claude Code's own marketplace system handles plugin install/update. We only control `enabledPlugins` in settings.json. |
| D7 | **Machine overlays are gitignored, identified by hostname** | `hostname -s` is universal. CCFG_MACHINE env var as override. Templates committed, actuals not. |
| D8 | **Overlays are composable JSON fragments** | Stackable profiles (e.g., `python` + `full-stack`). Each overlay only specifies keys it cares about. |
| D9 | **Target platforms: Linux + macOS** | Both x86_64 and arm64. No WSL. |
| D10 | **Agent tiering: core (~15) + language/infra/specialty bundles** | Overlays activate bundles. Not all 128 agents installed by default. |
| D11 | **No shell testing harness** | Rely on ccfg verify as integration test. Python code tested with pytest. |
| D12 | **Directory scaffold includes purpose READMEs** | Each major dir gets a short README explaining what belongs there. |
| D13 | **MCP servers tracked via manifest** | Versioned registry with status (active/candidate/deferred), requirements, failure modes. |

## Repository Layout

```
claude-config/
├── AGENTS.md                         # Beads project instructions
├── .beads/                           # Issue tracking
├── bin/
│   └── ccfg                          # Shell wrapper: exec uv run ccfg "$@"
├── src/ccfg/                         # Python CLI package (uv-managed, Typer)
│   ├── __init__.py
│   ├── cli.py                        # Typer app with all subcommands
│   ├── compose.py                    # Layer merge engine
│   ├── detect.py                     # OS/arch/runtime detection
│   ├── symlink.py                    # Symlink CRUD + tracking
│   └── backup.py                     # Backup/restore of ~/.claude/ state
├── tests/                            # Pytest test suite
├── layers/                           # Configuration layers (merged in order)
│   ├── 00-base/                      # Universal baseline
│   ├── 10-plugins/                   # Plugin enablement declarations
│   ├── 20-agents/                    # Agent definitions (symlinked)
│   │   ├── core/                     # Always installed (~15 agents)
│   │   ├── python/                   # Python specialists
│   │   ├── go/                       # Go specialists
│   │   ├── typescript/               # TypeScript specialists
│   │   ├── java/                     # Java specialists
│   │   ├── infra/                    # DevOps, K8s, cloud, DB
│   │   └── specialty/               # Security, data, ML, etc.
│   ├── 30-hooks/                     # Hook definitions
│   └── 40-machine/                   # Machine-specific (gitignored)
├── overlays/                         # Named profiles (composable, stackable)
├── project-templates/                # Drop-in templates for target repos
├── skills/                           # Custom skills/commands
│   ├── global/                       # Always-available skills
│   ├── python/                       # Python-specific skills
│   └── go/                           # Go-specific skills
├── secrets/                          # NEVER committed (gitignored)
├── eval/                             # Evaluation harness
└── docs/                             # Documentation
```

## Configuration Layering

### Precedence (lowest to highest)

```
Layer 0: layers/00-base/settings.json        -> Universal defaults
Layer 1: layers/10-plugins/<selected>.json    -> Plugin enablement
Layer 2: layers/30-hooks/base-hooks.json      -> Hook definitions
Layer 3: overlays/<profile>.json              -> Language/role profiles
Layer 4: layers/40-machine/<hostname>.json    -> Machine-specific overrides
```

### Merge Strategies

Three distinct merge strategies, implemented in `src/ccfg/compose.py`:

| Key | Strategy | Behavior |
|-----|----------|----------|
| `enabledPlugins` | **Union merge** | Keys merged across layers. `false` in higher layer disables a plugin. |
| `hooks` | **Deep merge** | Merge by event name. Arrays concatenated, duplicates removed by command string. |
| Scalars (`alwaysThinkingEnabled`, etc.) | **Last-writer-wins** | Higher layer value overwrites lower. |
| `feedbackSurveyState` | **Preserved** | Kept from installed copy only. Never overridden by layers. |

### CLAUDE.md Composition

Concatenated with `---` separators (not JSON merged):

```
layers/00-base/CLAUDE.md                      -> Universal rules
+ overlays/<profile>.claude.md                -> Language-specific (if exists)
+ layers/40-machine/<hostname>.claude.md      -> Machine-specific (gitignored)
```

### Agent Resolution

Agents are selected by overlay, not merged:

- `core/` agents: always installed
- `python/`, `go/`, etc.: activated when the matching overlay is selected
- Selection stored in `~/.claude/.ccfg-agent-manifest` for verification

### settings.json: Copy, Not Symlink

Claude Code writes runtime state (`feedbackSurveyState.lastShownTime`) to
`settings.json`. A symlink would pollute the repo with git diffs.

Flow: compose layers -> copy to `~/.claude/settings.json` -> store hash in
`~/.claude/.ccfg-settings-hash` for drift detection.

Agents and CLAUDE.md are symlinked (read-only from Claude Code's perspective).

## CLI Commands

All commands are subcommands of `ccfg` (Typer app):

| Command | Purpose |
|---------|---------|
| `ccfg install` | Full install: pre-flight -> backup -> init-machine -> compose -> copy/symlink -> verify |
| `ccfg uninstall` | Remove managed symlinks, restore backup |
| `ccfg update` | Re-compose + refresh without full backup |
| `ccfg verify` | 10-point health check |
| `ccfg compose` | Merge layers -> output composed settings.json |
| `ccfg doctor` | Deep diagnostics (versions, runtimes, disk, plugins) |
| `ccfg diff` | Show delta between composed and installed settings.json |
| `ccfg init-machine` | Generate machine overlay from template |
| `ccfg init-project` | Scaffold project-level config from template |

### Verify Checks (10-point)

1. Repository integrity (git clean, directories exist)
2. Machine overlay exists
3. Composition produces valid JSON
4. settings.json installed (hash matches)
5. CLAUDE.md installed (symlink valid)
6. Agent symlinks valid (no dangling)
7. Credentials present (warn-only)
8. Plugin enablement consistent with installed plugins
9. Runtime availability (LSP binaries exist for enabled LSPs)
10. No secrets in git tracking

## Agent Tiers

### Core (~15, always installed)

code-reviewer, debugger, refactoring-specialist, fullstack-developer,
backend-developer, api-designer, architect-reviewer, test-automator,
build-engineer, git-workflow-manager, technical-writer, performance-engineer,
qa-expert, prompt-engineer, error-detective

### Language Bundles (activated by overlay)

- **python/**: python-pro, django-developer, data-scientist
- **go/**: golang-pro
- **typescript/**: typescript-pro, react-specialist, nextjs-developer, angular-architect
- **java/**: java-architect, spring-boot-engineer, kotlin-specialist

### Infrastructure Bundle

devops-engineer, terraform-engineer, kubernetes-specialist, security-engineer,
database-administrator, sre-engineer

## Plugin Management

### Always enabled (core.json)

beads, context7, serena, greptile

### Workflow plugins (workflow.json)

feature-dev, code-review, commit-commands

### LSP plugins (lsp-all.json, disabled per-machine as needed)

pyright-lsp, gopls-lsp, gopls, vtsls, jdtls-lsp, jdtls, clangd,
rust-analyzer, solargraph, intelephense, kotlin-language-server,
omnisharp, vscode-html-css

### MCP Servers (tracked via manifest)

| Server | Status | Role |
|--------|--------|------|
| Context7 | Active | Documentation lookup |
| Serena | Active | Semantic code analysis via LSP |
| Greptile | Active | AI-powered code review for PRs |

Candidates (deferred): docker-mcp, mcp-sqlite/DBHub, playwright-mcp,
pytest-mcp-server. Each gets an overlay fragment when activated.

## Project Templates

Template variables use `{{VAR}}` syntax:

| Variable | Source |
|----------|--------|
| `{{PROJECT_NAME}}` | Target directory basename |
| `{{TEST_COMMAND}}` | User input or detection |
| `{{LINT_COMMAND}}` | User input or detection |
| `{{PACKAGE_MANAGER}}` | Detection (uv, go mod, npm) |

Available templates: base, python-service, go-service, typescript-app, monorepo.

## Skills

### Global (always available)

| Skill | Purpose |
|-------|---------|
| `/epic-execute` | Execute next beads task with full quality gates |
| `/epic-plan` | Plan beads epic from requirements |
| `/pr-create` | Create PR with lint/test verification |
| `/coverage-push` | Autonomous per-file coverage improvement loop |

### Language-specific

| Skill | Purpose |
|-------|---------|
| `/py-test-coverage` | Python coverage with uv, ruff, pytest, pytestmark |
| `/go-test-coverage` | Go coverage with task, golangci-lint, gofumpt |

## Machine Overlay Convention

- Identified by `hostname -s` (overridable via `CCFG_MACHINE` env var)
- Files: `layers/40-machine/<hostname>.json` + `<hostname>.claude.md`
- Gitignored (templates committed, actuals not)
- Typical use: disable LSPs for missing runtimes, add machine-specific notes

## CLAUDE.md Baseline Rules (from Insights Report)

The global CLAUDE.md at `layers/00-base/CLAUDE.md` encodes rules derived from
documented friction patterns. Key categories:

- **Code Quality**: pre-commit enforcement, no nolint/noqa, no magic numbers, explicit error handling
- **Git Workflow**: never push to main, feature branches + PRs, one task = one commit
- **Task Management**: beads --parent not --epic, one task at a time, commit before close
- **Workflow Discipline**: concise planning, no scope creep, ask before expanding
- **Python**: uv for everything, pytestmark decorators, pytest.raises match params
- **Go**: task for builds, gofumpt formatting, golangci-lint, never ignore errors

## Idempotency Contract

All lifecycle commands check current state before acting. Re-running
`ccfg install` is equivalent to `ccfg update`. No command destroys data
without creating a backup first.

## External Dependencies

| Tool | Version | Required |
|------|---------|----------|
| Python | >= 3.11 | Yes |
| uv | latest | Yes |
| git | >= 2.30 | Yes |
| claude | current | Yes (target application) |
