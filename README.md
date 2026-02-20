# claude-config

A Claude Code plugin marketplace encoding workflow preferences discovered across 275+ sessions and
2,300+ messages. Prevents wrong approaches, buggy code, and rejected actions through front-loaded
configuration.

## Quick Start

```bash
# Add the marketplace
claude plugin marketplace add jsamuelsen11/claude-config

# Install the foundation plugin (recommended for everyone)
claude plugin install ccfg-core@claude-config

# Install language/data/infra plugins as needed
claude plugin install ccfg-python@claude-config
claude plugin install ccfg-typescript@claude-config
claude plugin install ccfg-postgresql@claude-config
```

## Plugin Catalog

| #   | Plugin              | Category       | Agents | Cmds | Skills | Description                                             |
| --- | ------------------- | -------------- | ------ | ---- | ------ | ------------------------------------------------------- |
| 1   | ccfg-core           | Foundation     | 22     | 5    | 3      | Workflow rules, core agents, security hooks, GitHub MCP |
| 2   | ccfg-python         | Language       | 7      | 3    | 3      | uv, ruff, pytest, mypy conventions                      |
| 3   | ccfg-golang         | Language       | 5      | 3    | 3      | golangci-lint, gofumpt, go modules conventions          |
| 4   | ccfg-typescript     | Language       | 9      | 3    | 3      | ESLint, Vitest, Playwright MCP, strict tsconfig         |
| 5   | ccfg-java           | Language       | 5      | 3    | 3      | Maven/Gradle, JUnit 5, Checkstyle conventions           |
| 6   | ccfg-rust           | Language       | 4      | 3    | 3      | cargo clippy, rustfmt, workspaces conventions           |
| 7   | ccfg-csharp         | Language       | 5      | 3    | 3      | dotnet format, Roslyn, xUnit conventions                |
| 8   | ccfg-shell          | Language       | 2      | 2    | 2      | shellcheck, shfmt conventions                           |
| 9   | ccfg-mysql          | Data           | 3      | 2    | 3      | DBA, query optimization, replication conventions        |
| 10  | ccfg-postgresql     | Data           | 4      | 2    | 3      | DBA, query optimization, extension conventions          |
| 11  | ccfg-mongodb        | Data           | 3      | 2    | 3      | Document modeling, aggregation, sharding conventions    |
| 12  | ccfg-redis          | Data           | 2      | 2    | 2      | Data structures, pub-sub, caching conventions           |
| 13  | ccfg-sqlite         | Data           | 2      | 2    | 2      | WAL mode, PRAGMA tuning, SQLite MCP                     |
| 14  | ccfg-docker         | Infrastructure | 3      | 2    | 3      | Dockerfile optimization, Compose, security conventions  |
| 15  | ccfg-github-actions | Infrastructure | 3      | 2    | 3      | Workflow design, deployment, supply chain security      |
| 16  | ccfg-kubernetes     | Infrastructure | 3      | 2    | 3      | Manifests, Helm charts, deployment strategy conventions |

## Categories

**Foundation** — `ccfg-core` is the base plugin. Install it first. It provides cross-cutting
workflow rules (planning discipline, scope control), 22 general-purpose agents, security hooks
(secret scanning, dangerous command blocking), and GitHub MCP integration.

**Language** — One plugin per language. Each provides framework-specific agents, project scaffolding
commands, coverage automation, and conventions for the language's standard toolchain. Enable only
what you use.

**Data** — Database-specific agents and conventions. Each plugin covers schema design, query
optimization, migration patterns, and the database's operational best practices.

**Infrastructure** — Container, CI/CD, and orchestration plugins. Dockerfile optimization, GitHub
Actions workflow design, and Kubernetes manifest/Helm chart conventions.

## Bootstrap

Some settings can't be configured through plugins (permissions allow-lists, `alwaysThinkingEnabled`,
initial `enabledPlugins`). A bootstrap script handles these one-time settings.json updates.

> The bootstrap script is under development. See the [design doc](docs/DESIGN.md) for details on
> what it will configure (decision D4).

## Ecosystem

This marketplace focuses on coding conventions and workflow rules. For complementary capabilities
(documentation retrieval, semantic code navigation, code review, browser testing), see the
[Third-Party Recommendations](docs/THIRD_PARTY.md).

## Design

Architecture decisions, plugin anatomy, and the insights report that informed these plugins are
documented in [docs/DESIGN.md](docs/DESIGN.md).

## License

MIT
