# Third-Party Plugin Registry

> Curated registry of recommended third-party Claude Code plugins for `ccfg-plugins.sh`. Data
> source: `bootstrap/lib/registry.sh` (78 entries, v1.0.0).
>
> See also: [BOOTSTRAP.md](./BOOTSTRAP.md) for script specification,
> [THIRD_PARTY.md](./THIRD_PARTY.md) for MCP server recommendations.

---

## Table of Contents

- [Tier Model](#tier-model)
- [LSP Plugins — Dual Coverage](#lsp-plugins--dual-coverage)
- [LSP Plugins — Community Only](#lsp-plugins--community-only)
- [General Plugins](#general-plugins)
- [Integration Plugins](#integration-plugins)
- [Skills and Issue Tracking](#skills-and-issue-tracking)
- [Detection Signals](#detection-signals)
- [Overlap Analysis](#overlap-analysis)

---

## Tier Model

| Tier        | `--auto` mode           | Interactive mode         | `--list` mode | Count |
| ----------- | ----------------------- | ------------------------ | ------------- | ----- |
| **auto**    | Installed automatically | Pre-selected (checkmark) | Shown         | 14    |
| **suggest** | Shown but not installed | Available (dot symbol)   | Shown         | 30    |
| **info**    | Hidden                  | Hidden                   | Shown         | 34    |

**Design principle:** Robust offering without strong-arming. The auto tier contains only
high-confidence universal plugins and single-source LSPs for detected languages. The suggest tier
presents options that require active selection. The info tier is discoverable via `--list` for users
who want full visibility.

**Overlapping LSPs in `--auto` mode:** Skipped entirely. When two marketplaces offer LSPs for the
same language, neither is auto-installed. The user must choose interactively.

---

## LSP Plugins — Dual Coverage

For 11 languages, both `claude-plugins-official` (official) and `claude-code-lsps` (community)
provide LSP plugins. All are tier=suggest. The user picks one per language.

| Language      | Official Plugin     | Community Plugin      | Preferred     | Rationale                                      |
| ------------- | ------------------- | --------------------- | ------------- | ---------------------------------------------- |
| TypeScript/JS | `typescript-lsp`    | `vtsls`               | official      | Anthropic-maintained                           |
| Python        | `pyright-lsp`       | `pyright`             | official      | Same Pyright engine, official packaging        |
| Go            | `gopls-lsp`         | `gopls`               | official      | Same gopls engine, official packaging          |
| Rust          | `rust-analyzer-lsp` | `rust-analyzer`       | official      | Same engine, official packaging                |
| C/C++         | `clangd-lsp`        | `clangd`              | official      | Same clangd engine, official packaging         |
| Java          | `jdtls-lsp`         | `jdtls`               | official      | Same Eclipse JDT.LS engine, official packaging |
| Swift         | `swift-lsp`         | `sourcekit-lsp`       | official      | Same SourceKit-LSP engine, official packaging  |
| Kotlin        | `kotlin-lsp`        | `kotlin-lsp`          | official      | Same engine, official packaging                |
| Lua           | `lua-lsp`           | `lua-language-server` | official      | Official packaging                             |
| PHP           | `php-lsp`           | `intelephense`        | **community** | Intelephense is the industry-standard PHP LSP  |
| C#            | `csharp-lsp`        | `omnisharp`           | **community** | OmniSharp is the industry-standard C# LSP      |

### Interactive UI for Overlap Choices

```text
  Python LSP (choose one):
    [5] · pyright-lsp                    official (recommended)    claude-plugins-official
    [6] · pyright                        community                 claude-code-lsps
```

---

## LSP Plugins — Community Only

11 languages have LSP plugins only in `claude-code-lsps`. All are tier=auto (installed automatically
when the language is detected).

| Language     | Plugin                 | Marketplace      | Detection Signal |
| ------------ | ---------------------- | ---------------- | ---------------- |
| Bash/Shell   | `bash-language-server` | claude-code-lsps | `shell`          |
| Clojure      | `clojure-lsp`          | claude-code-lsps | `clojure`        |
| Dart/Flutter | `dart-analyzer`        | claude-code-lsps | `dart`           |
| Elixir       | `elixir-ls`            | claude-code-lsps | `elixir`         |
| Gleam        | `gleam`                | claude-code-lsps | `gleam`          |
| Nix          | `nixd`                 | claude-code-lsps | `nix`            |
| OCaml        | `ocaml-lsp`            | claude-code-lsps | `ocaml`          |
| Ruby         | `solargraph`           | claude-code-lsps | `ruby`           |
| Terraform    | `terraform-ls`         | claude-code-lsps | `terraform`      |
| YAML         | `yaml-language-server` | claude-code-lsps | `yaml`           |
| Zig          | `zls`                  | claude-code-lsps | `zig`            |

---

## General Plugins

### Auto Tier

| Plugin            | Marketplace             | Detect | Community Installs | Rationale                                |
| ----------------- | ----------------------- | ------ | ------------------ | ---------------------------------------- |
| `context7`        | claude-plugins-official | always | 71.8k              | Universal documentation retrieval        |
| `commit-commands` | claude-plugins-official | always | —                  | Universal git workflow                   |
| `document-skills` | anthropic-agent-skills  | always | —                  | Office doc handling (xlsx/docx/pptx/pdf) |

### Suggest Tier

| Plugin              | Marketplace             | Detect   | Community Installs | Rationale                                   |
| ------------------- | ----------------------- | -------- | ------------------ | ------------------------------------------- |
| `code-review`       | claude-plugins-official | always   | 50k                | Automated PR review with specialized agents |
| `feature-dev`       | claude-plugins-official | always   | —                  | Feature development workflow                |
| `security-guidance` | claude-plugins-official | always   | 25.5k              | Security scanning on file edits             |
| `serena`            | claude-plugins-official | always   | —                  | Semantic code navigation and memory         |
| `greptile`          | claude-plugins-official | always   | —                  | AI-powered code review and search           |
| `frontend-design`   | claude-plugins-official | frontend | 71.8k              | Production-grade frontend UI                |
| `playwright`        | claude-plugins-official | frontend | 28.1k              | Browser testing and automation              |

### Info Tier

| Plugin                     | Marketplace             | Notes                                      |
| -------------------------- | ----------------------- | ------------------------------------------ |
| `ralph-loop`               | claude-plugins-official | 57k installs, autonomous development loops |
| `firecrawl`                | claude-plugins-official | Web scraping, needs API key                |
| `pr-review-toolkit`        | claude-plugins-official | Overlaps with code-review                  |
| `code-simplifier`          | claude-plugins-official | Code clarity and complexity reduction      |
| `hookify`                  | claude-plugins-official | Custom hook creation                       |
| `plugin-dev`               | claude-plugins-official | Plugin development toolkit                 |
| `claude-code-setup`        | claude-plugins-official | Tailored automation recommendations        |
| `claude-md-management`     | claude-plugins-official | CLAUDE.md maintenance                      |
| `agent-sdk-dev`            | claude-plugins-official | Agent SDK development                      |
| `playground`               | claude-plugins-official | Interactive HTML playgrounds               |
| `superpowers`              | claude-plugins-official | Brainstorming, debugging, TDD techniques   |
| `explanatory-output-style` | claude-plugins-official | Educational output style                   |
| `learning-output-style`    | claude-plugins-official | Interactive learning mode                  |

---

## Integration Plugins

All info tier. Require external service accounts or API keys.

| Plugin               | Marketplace             | Service                                                    |
| -------------------- | ----------------------- | ---------------------------------------------------------- |
| `github`             | claude-plugins-official | GitHub API (note: ccfg-core bundles GitHub MCP separately) |
| `gitlab`             | claude-plugins-official | GitLab API                                                 |
| `linear`             | claude-plugins-official | Linear issue tracking                                      |
| `asana`              | claude-plugins-official | Asana project management                                   |
| `slack`              | claude-plugins-official | Slack messaging                                            |
| `figma`              | claude-plugins-official | Figma design platform                                      |
| `notion`             | claude-plugins-official | Notion workspace                                           |
| `sentry`             | claude-plugins-official | Sentry error monitoring                                    |
| `vercel`             | claude-plugins-official | Vercel deployments                                         |
| `stripe`             | claude-plugins-official | Stripe payments                                            |
| `firebase`           | claude-plugins-official | Google Firebase                                            |
| `supabase`           | claude-plugins-official | Supabase backend                                           |
| `pinecone`           | claude-plugins-official | Pinecone vector database                                   |
| `posthog`            | claude-plugins-official | PostHog analytics                                          |
| `circleback`         | claude-plugins-official | CircleBack meeting intelligence                            |
| `coderabbit`         | claude-plugins-official | CodeRabbit AI code review                                  |
| `huggingface-skills` | claude-plugins-official | HuggingFace model hub                                      |
| `sonatype-guide`     | claude-plugins-official | Sonatype dependency security                               |
| `atlassian`          | claude-plugins-official | Jira and Confluence                                        |
| `laravel-boost`      | claude-plugins-official | Laravel development toolkit                                |

---

## Skills and Issue Tracking

| Plugin            | Marketplace            | Tier    | Detect | Notes                                   |
| ----------------- | ---------------------- | ------- | ------ | --------------------------------------- |
| `document-skills` | anthropic-agent-skills | auto    | always | xlsx, docx, pptx, pdf handling          |
| `example-skills`  | anthropic-agent-skills | info    | —      | Algorithmic art, brand guidelines, etc. |
| `beads`           | beads-marketplace      | suggest | beads  | AI-supervised issue tracker             |

---

## Detection Signals

### Existing (in `bootstrap/lib/detect.sh` today)

| Identifier       | Detection Files/Dirs                                           |
| ---------------- | -------------------------------------------------------------- |
| `python`         | pyproject.toml, setup.py, setup.cfg, requirements.txt, Pipfile |
| `golang`         | go.mod                                                         |
| `typescript`     | package.json + tsconfig.json or typescript dependency          |
| `javascript`     | package.json without TypeScript signals                        |
| `java`           | pom.xml, build.gradle, build.gradle.kts                        |
| `rust`           | Cargo.toml                                                     |
| `csharp`         | \*.csproj, \*.sln (depth 2)                                    |
| `shell`          | \*.sh in root or scripts/                                      |
| `docker`         | Dockerfile, docker-compose.yml, compose.yml                    |
| `kubernetes`     | k8s/ or kubernetes/ directory                                  |
| `github-actions` | .github/workflows/ directory                                   |
| `mysql`          | docker-compose with mysql image                                |
| `postgresql`     | docker-compose with postgres image                             |
| `mongodb`        | docker-compose with mongo image                                |
| `redis`          | docker-compose with redis image                                |
| `sqlite`         | \*.db, \*.sqlite, \*.sqlite3                                   |
| `markdown`       | docs/ directory or README.md                                   |

### New (to be added in task .2)

| Identifier  | Detection Files/Dirs                           | Method          |
| ----------- | ---------------------------------------------- | --------------- |
| `cpp`       | CMakeLists.txt or Makefile + \*.c/cpp/cc/h/hpp | File + glob     |
| `php`       | composer.json, artisan                         | File existence  |
| `ruby`      | Gemfile, \*.gemspec, Rakefile                  | File + glob     |
| `kotlin`    | \*.kt files (depth 2)                          | Glob            |
| `dart`      | pubspec.yaml                                   | File existence  |
| `elixir`    | mix.exs                                        | File existence  |
| `clojure`   | deps.edn, project.clj                          | File existence  |
| `terraform` | \*.tf (depth 2)                                | Glob            |
| `nix`       | flake.nix, \*.nix (depth 1)                    | File + glob     |
| `ocaml`     | dune-project, \*.opam (depth 1)                | File + glob     |
| `gleam`     | gleam.toml                                     | File existence  |
| `zig`       | build.zig                                      | File existence  |
| `swift`     | Package.swift, \*.xcodeproj (depth 1)          | File + glob     |
| `lua`       | \*.lua (depth 2), .luarocks, .luacheckrc       | File + glob     |
| `yaml`      | 5+ YAML files (excluding compose)              | Count heuristic |
| `frontend`  | \*.tsx, \*.vue, \*.svelte, \*.jsx (depth 2)    | Glob            |
| `beads`     | .beads/ directory                              | Dir existence   |

---

## Overlap Analysis

### Why Two Marketplaces for LSP?

- **claude-plugins-official** (Anthropic): 11 LSP plugins. Officially maintained, guaranteed
  compatibility with Claude Code updates, but smaller language set.
- **claude-code-lsps** (boostvolt): 22 LSP plugins. Broader language coverage, community-
  maintained, faster to add new languages.

### Preference Rules

For most languages, both marketplaces wrap the same underlying language server (e.g., both Python
plugins use Microsoft Pyright). The preference is:

1. **Default to official** when the underlying engine is identical — official packaging is more
   likely to stay compatible across Claude Code updates.
2. **Prefer community** when the community plugin uses a more mature/standard LSP:
   - **PHP**: Intelephense (community) is the dominant PHP language server with better type
     inference than the generic official wrapper.
   - **C#**: OmniSharp (community) is Microsoft's own C# language server with deep .NET integration.

### Marketplace Sources

| Marketplace             | Source                                                                                      | Plugins | Focus                               |
| ----------------------- | ------------------------------------------------------------------------------------------- | ------- | ----------------------------------- |
| claude-plugins-official | [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | 53      | LSPs, general tools, integrations   |
| claude-code-lsps        | [boostvolt/claude-code-lsps](https://github.com/boostvolt/claude-code-lsps)                 | 22      | LSP-only, broad language coverage   |
| anthropic-agent-skills  | [anthropics/skills](https://github.com/anthropics/skills)                                   | 2       | Document processing, example skills |
| beads-marketplace       | [steveyegge/beads](https://github.com/steveyegge/beads)                                     | 1       | AI-supervised issue tracking        |

---

## Summary

| Category       | auto   | suggest | info   | Total  |
| -------------- | ------ | ------- | ------ | ------ |
| LSP            | 11     | 22      | 0      | 33     |
| General        | 2      | 7       | 11     | 20     |
| Style          | 0      | 0       | 2      | 2      |
| Integration    | 0      | 0       | 20     | 20     |
| Skills         | 1      | 0       | 1      | 2      |
| Issue tracking | 0      | 1       | 0      | 1      |
| **Total**      | **14** | **30**  | **34** | **78** |
