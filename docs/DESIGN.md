# ccfg Design Document

> Canonical source of truth for the ccfg plugin marketplace architecture. A fresh Claude session
> should read this file first.

## Purpose

`ccfg` is a custom Claude Code plugin marketplace — a collection of plugins that encode workflow
preferences discovered across 275 sessions and 2,322 messages. Instead of a custom CLI that composes
configuration layers, we use Claude Code's native plugin system: one git repo, one marketplace,
multiple installable plugins.

The system solves recurring friction: Claude taking wrong approaches (42 instances), producing buggy
code that fails pre-commit (34), and being rejected for shortcuts like nolint directives (27). All
preventable with front-loaded configuration.

## Architecture

### Delivery Mechanism

This repository is a **Claude Code plugin marketplace**. Users install it with:

```bash
claude plugin marketplace add jsamuelsen11/claude-config
claude plugin install ccfg-core@claude-config
claude plugin install ccfg-python@claude-config   # optional, per-language
```

No custom CLI. No layer composition engine. Claude Code's native plugin system handles discovery,
installation, caching, and component loading.

A **bootstrap script** handles the few things plugins cannot: `permissions.allow`,
`alwaysThinkingEnabled`, and initial `enabledPlugins` in settings.json.

### Repository Layout

```text
claude-config/
├── .claude-plugin/
│   └── marketplace.json              # Marketplace registry (17 plugins)
├── plugins/
│   ├── ccfg-core/                    # Foundation plugin
│   ├── ccfg-python/                  # Python language plugin
│   ├── ccfg-golang/                  # Go language plugin
│   ├── ccfg-typescript/              # TypeScript language plugin
│   ├── ccfg-java/                    # Java language plugin
│   ├── ccfg-rust/                    # Rust language plugin
│   ├── ccfg-csharp/                  # C#/.NET language plugin
│   ├── ccfg-shell/                   # Shell scripting plugin
│   ├── ccfg-mysql/                   # MySQL data plugin
│   ├── ccfg-postgresql/              # PostgreSQL data plugin
│   ├── ccfg-mongodb/                 # MongoDB data plugin
│   ├── ccfg-redis/                   # Redis data plugin
│   ├── ccfg-sqlite/                  # SQLite data plugin
│   ├── ccfg-docker/                  # Docker infrastructure plugin
│   ├── ccfg-github-actions/          # GitHub Actions infrastructure plugin
│   ├── ccfg-kubernetes/              # Kubernetes/Helm infrastructure plugin
│   └── ccfg-markdown/               # Markdown tooling plugin
├── bootstrap/                        # Bootstrap script for settings.json setup
├── docs/                             # Documentation
│   └── DESIGN.md                     # This file
├── AGENTS.md                         # Beads project instructions
└── .beads/                           # Issue tracking
```

### Plugin Anatomy

Every plugin follows this structure:

```text
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json         # Manifest: name, description, version, hooks
├── agents/                  # Subagent definitions (auto-discovered)
│   └── <agent-name>.md     # YAML frontmatter + system prompt
├── commands/                # Slash commands (user-invoked via /<plugin>:<cmd>)
│   └── <command-name>.md   # YAML frontmatter + instructions
├── skills/                  # Skills (auto-invoked by Claude based on context)
│   └── <skill-name>/
│       └── SKILL.md        # YAML frontmatter + skill definition
└── .mcp.json                # MCP server configs (optional)
```

### What Plugins Can and Cannot Do

| Capability                   | Supported | Mechanism                                        |
| ---------------------------- | --------- | ------------------------------------------------ |
| Define agents                | Yes       | `agents/*.md` auto-discovered when enabled       |
| Define slash commands        | Yes       | `commands/*.md` user-invoked                     |
| Define skills                | Yes       | `skills/*/SKILL.md` auto-invoked by context      |
| Define hooks                 | Yes       | `hooks` field in plugin.json                     |
| Define MCP servers           | Yes       | `.mcp.json` at plugin root                       |
| Set permissions (allow list) | **No**    | Must be in settings.json or CLAUDE.md            |
| Contribute to CLAUDE.md      | **No**    | Workflow rules delivered via broad-trigger skill |
| Set alwaysThinkingEnabled    | **No**    | Must be in settings.json (bootstrap handles)     |
| Depend on other plugins      | **No**    | No plugin-to-plugin dependency mechanism         |

### Plugin Categories

| Category       | Plugins                                               | Purpose                                                |
| -------------- | ----------------------------------------------------- | ------------------------------------------------------ |
| Foundation     | ccfg-core                                             | Workflow rules, core agents, commands, hooks, MCP      |
| Language       | python, golang, typescript, java, rust, csharp, shell | Language-specific agents, conventions, test commands   |
| Data           | mysql, postgresql, mongodb, redis, sqlite             | Database agents, query conventions, migration patterns |
| Infrastructure | docker, github-actions, kubernetes                    | Container, CI/CD, orchestration conventions            |
| Tooling        | markdown                                              | Documentation conventions                              |

---

## Plugin Summary (all 17)

| #   | Plugin              | Agents | Commands | Skills | Hooks | MCP            |
| --- | ------------------- | ------ | -------- | ------ | ----- | -------------- |
| 1   | ccfg-core           | 19     | 5        | 3      | 4     | github-mcp     |
| 2   | ccfg-python         | 7      | 3        | 3      | -     | -              |
| 3   | ccfg-golang         | 5      | 3        | 3      | -     | -              |
| 4   | ccfg-typescript     | 9      | 3        | 3      | -     | playwright-mcp |
| 5   | ccfg-java           | 5      | 3        | 3      | -     | -              |
| 6   | ccfg-rust           | 4      | 3        | 3      | -     | -              |
| 7   | ccfg-csharp         | 5      | 3        | 3      | -     | -              |
| 8   | ccfg-shell          | 2      | 2        | 2      | -     | -              |
| 9   | ccfg-mysql          | 3      | 2        | 3      | -     | -              |
| 10  | ccfg-postgresql     | 4      | 2        | 3      | -     | -              |
| 11  | ccfg-mongodb        | 3      | 2        | 3      | -     | -              |
| 12  | ccfg-redis          | 2      | 2        | 2      | -     | -              |
| 13  | ccfg-sqlite         | 2      | 2        | 2      | -     | sqlite-mcp     |
| 14  | ccfg-docker         | 3      | 2        | 3      | -     | -              |
| 15  | ccfg-github-actions | 3      | 2        | 3      | -     | -              |
| 16  | ccfg-kubernetes     | 3      | 2        | 3      | -     | -              |
| 17  | ccfg-markdown       | 2      | 3        | 3      | -     | -              |

---

## Design Decisions

| #   | Decision                                       | Rationale                                                                                                                               |
| --- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | **Native plugin marketplace, not custom CLI**  | Claude Code's plugin system handles discovery, install, caching, and component loading. No composition engine to maintain.              |
| D2  | **Monorepo with marketplace.json**             | Matches official Anthropic marketplace pattern. All plugins in `plugins/` referenced via `"source": "./plugins/<name>"`.                |
| D3  | **Workflow rules as broad-trigger skill**      | Plugins can't contribute to CLAUDE.md. A skill with a very broad trigger description is the closest equivalent.                         |
| D4  | **Bootstrap script for settings.json**         | Plugins can't set `permissions.allow`, `alwaysThinkingEnabled`, or initial `enabledPlugins`. A one-time bootstrap script handles these. |
| D5  | **Cloud MCP servers stay as official plugins** | Context7, Serena, Greptile are already in claude-plugins-official. No need to redefine them.                                            |
| D6  | **GitHub MCP in core plugin**                  | GitHub API access enhances PRs, reviews, and epic workflows — cross-cutting, not language-specific.                                     |
| D7  | **Security hooks in core plugin**              | Secret scanning (PostToolUse) and dangerous command blocking (PreToolUse) are universal safety nets.                                    |
| D8  | **One plugin per language/technology**         | Clean separation. Enable only what you need. No bloat.                                                                                  |
| D9  | **Target platforms: Linux + macOS**            | Both x86_64 and arm64. No WSL.                                                                                                          |

## Insights Report Reference

These plugins encode rules derived from documented friction patterns across 275 sessions:

- **42 wrong approaches**: Prevented by workflow-rules skill (planning discipline, scope control)
- **34 buggy code incidents**: Prevented by pre-commit enforcement, test-before-ship commands
- **27 rejected actions**: Prevented by no-nolint rules, git workflow rules, beads conventions

Key user style traits encoded:

- Methodical, epic-driven planner
- Trusting but corrective
- Prefers planning conversations before implementation
- Expects one task at a time, fully complete before moving on
