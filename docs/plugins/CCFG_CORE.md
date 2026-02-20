# Plugin: ccfg-core

The foundation plugin. Should be installed by everyone. Contains cross-cutting workflow rules, core
agents, utility commands, security hooks, and GitHub MCP integration.

## Directory Structure

```text
plugins/ccfg-core/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── architect-reviewer.md
│   ├── backend-developer.md
│   ├── build-engineer.md
│   ├── cloud-architect.md
│   ├── code-reviewer.md
│   ├── debugger.md
│   ├── error-detective.md
│   ├── event-driven-api-designer.md
│   ├── frontend-developer.md
│   ├── fullstack-developer.md
│   ├── git-workflow-manager.md
│   ├── graphql-api-designer.md
│   ├── grpc-api-designer.md
│   ├── performance-engineer.md
│   ├── project-planner.md
│   ├── prompt-engineer.md
│   ├── qa-expert.md
│   ├── refactoring-specialist.md
│   ├── requirements-analyst.md
│   ├── rest-api-designer.md
│   ├── technical-writer.md
│   └── test-automator.md
├── commands/
│   ├── epic-execute.md
│   ├── pr-review.md
│   ├── pr-create.md
│   ├── project-init.md
│   ├── repo-pack.md
│   └── security-check.md
├── skills/
│   ├── workflow-rules/
│   │   └── SKILL.md
│   ├── memory-conventions/
│   │   └── SKILL.md
│   └── browser-testing/
│       └── SKILL.md
└── .mcp.json
```

## plugin.json

```json
{
  "name": "ccfg-core",
  "description": "Foundation plugin: workflow rules, core agents, commands, security hooks, and GitHub MCP for consistent Claude Code behavior across all projects",
  "version": "0.1.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["workflow", "agents", "security", "mcp", "configuration"],
  "suggestedPermissions": {
    "allow": ["Bash(bd:*)", "Bash(git:*)", "Bash(wc:*)", "Bash(lefthook:*)"]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/secret-scan.sh $CLAUDE_TOOL_OUTPUT_FILE"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/dangerous-command-check.sh $CLAUDE_TOOL_INPUT_FILE"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime"
          }
        ]
      }
    ]
  }
}
```

## Agents (22)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                       | Role                                                                                        | Model  |
| --------------------------- | ------------------------------------------------------------------------------------------- | ------ |
| `code-reviewer`             | Code quality, security vulnerabilities, best practices across languages                     | sonnet |
| `debugger`                  | Issue diagnosis, root cause analysis, systematic problem-solving                            | sonnet |
| `refactoring-specialist`    | Safe code transformations, design pattern application                                       | sonnet |
| `fullstack-developer`       | End-to-end feature delivery from database to UI                                             | sonnet |
| `backend-developer`         | APIs, services, server-side logic, data modeling                                            | sonnet |
| `frontend-developer`        | UI components, web standards, accessibility, responsive design                              | sonnet |
| `event-driven-api-designer` | AsyncAPI specs, event schemas, CloudEvents, saga patterns, topic naming                     | sonnet |
| `graphql-api-designer`      | GraphQL schema design, Relay spec, federation, subscriptions, type system                   | sonnet |
| `grpc-api-designer`         | gRPC service design, proto3 schemas, streaming, schema evolution, health checking           | sonnet |
| `rest-api-designer`         | REST API architecture, resource modeling, OpenAPI, caching, versioning                      | sonnet |
| `architect-reviewer`        | System design validation, scalability analysis, tech stack evaluation                       | sonnet |
| `test-automator`            | Test frameworks, CI/CD integration, coverage strategies                                     | sonnet |
| `build-engineer`            | Build systems, compilation, caching, dependency management                                  | sonnet |
| `git-workflow-manager`      | Branching strategies, merge conflict resolution, repo management                            | sonnet |
| `technical-writer`          | Documentation, API docs, user guides, clear technical writing                               | sonnet |
| `performance-engineer`      | Profiling, bottleneck identification, optimization strategies                               | sonnet |
| `qa-expert`                 | Test strategy, quality processes, manual and automated testing                              | sonnet |
| `prompt-engineer`           | LLM prompt design, evaluation frameworks, prompt optimization                               | sonnet |
| `error-detective`           | Error pattern analysis, distributed debugging, anomaly detection                            | sonnet |
| `project-planner`           | Epic decomposition, task sequencing, dependency mapping, scope estimation                   | sonnet |
| `cloud-architect`           | AWS/Azure/GCP architecture, multi-cloud patterns, cost optimization, IAM                    | sonnet |
| `requirements-analyst`      | Requirements elicitation, user stories, acceptance criteria, scope definition, traceability | sonnet |

## Commands (6)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-core:epic-execute

**Purpose**: Execute a beads task with a consistent 6-phase workflow.

**Phases**: Context Recovery -> Branch -> Planning Conversation -> Implementation -> Validation ->
PR & Close

**Trigger**: User invokes with a task ID (e.g., `/ccfg-core:epic-execute claude-config-abc.1`)

**Allowed tools**:
`Bash(git *), Bash(bd *), Bash(uv *), Bash(gh pr create *), Read, Grep, Glob, Edit, Write, Task`

**Key behavior**:

- Reads docs/DESIGN.md for context recovery
- Loads task details via `bd show`
- Verifies blockers are closed before proceeding
- Creates feature branch from clean main
- Conducts interactive planning conversation (asks questions, gets approval)
- Implements with incremental commits
- Runs full validation (tests, lint, type check)
- Creates PR via `gh pr create` and closes beads task

### /ccfg-core:pr-review

**Purpose**: Structured pull request review with consistent rubric.

**Trigger**: User invokes with a PR number or URL.

**Allowed tools**: `Bash(gh *), Bash(git *), Read, Grep, Glob, Task`

**Review rubric**:

1. **Correctness**: Does the code do what it claims? Edge cases handled?
2. **Security**: Injection vectors, auth issues, secret exposure?
3. **Performance**: N+1 queries, unnecessary allocations, missing indexes?
4. **Maintainability**: Clear naming, appropriate abstractions, test coverage?
5. **Conventions**: Follows project CLAUDE.md rules? Lint clean?

**Output format**: Structured markdown with severity levels (blocker/warning/nit).

### /ccfg-core:pr-create

**Purpose**: Create a pull request with pre-flight validation gates.

**Trigger**: User invokes when ready to ship.

**Allowed tools**: `Bash(git *), Bash(gh *), Bash(uv *), Read, Grep`

**Pre-flight gates** (all must pass before PR creation):

1. Tests pass
2. Lint clean
3. No uncommitted changes
4. Branch is up to date with main
5. No secrets detected in diff

**Output**: Creates PR with structured body (summary, changes, validation checklist).

### /ccfg-core:project-init

**Purpose**: Initialize a project's `CLAUDE.md` with language-specific convention sections.

**Trigger**: User invokes to set up or update managed convention sections for a project.

**Allowed tools**: `Bash(*/ccfg-project-init.sh:*), Bash(*/ccfg-project-init:*), Read, Glob, Grep`

**Behavior**:

- Auto-detects languages and technologies in the project directory
- Creates `./CLAUDE.md` with one managed section per detected technology (8-15 lines each)
- Supports `--auto`, `--dry-run`, `--update`, `--project-dir`, `--local` flags
- Idempotent: re-running with same template version produces zero changes
- Creates backup before any modification

### /ccfg-core:repo-pack

**Purpose**: Generate a repomix-style context bundle for large repos.

**Trigger**: User invokes when Claude needs broader repo context.

**Allowed tools**: `Bash(repomix *), Bash(npx *), Read, Glob, Grep`

**Behavior**:

- Runs repomix (or equivalent) to generate a packed context file
- Respects .gitignore and custom exclusion patterns
- Outputs summary of what was packed (file count, total size)
- Feeds packed context back to Claude for analysis

### /ccfg-core:security-check

**Purpose**: Scan workspace for secrets, credentials, and vulnerable patterns.

**Trigger**: User invokes for pre-commit or ad-hoc security review.

**Allowed tools**: `Bash(git *), Bash(grep *), Read, Grep, Glob`

**Checks**:

- API keys, tokens, passwords in source files
- .env files with real values committed to git
- Private keys, certificates in repo
- Hardcoded credentials in config files
- Known vulnerable dependency patterns

**Output**: List of findings with file, line, severity, and remediation.

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### workflow-rules

**Trigger description**: "This skill should be used for ALL coding tasks, code reviews, planning,
git operations, and development work. It defines mandatory workflow rules."

**This is the CLAUDE.md equivalent.** Contains all workflow rules derived from the Insights Report
friction analysis:

**Code Quality Rules**:

- Always run pre-commit/lefthook checks before considering any task complete
- Never propose `nolint` directives, `noqa` comments, lint rule exclusions, or ignoring lint errors
  as a solution. Fix the root cause instead
- For markdown files: validate with markdownlint before committing. Watch for line length (MD013),
  missing code fence languages (MD040), list indentation
- Never use magic numbers. Define constants
- Always handle errors explicitly. No `_ = err` in Go, no bare `except` in Python

**Git Workflow Rules**:

- Never push to `main` directly. Always create a feature branch and open a PR
- Ask which branch to target if unclear
- One task = one commit. Do not batch unrelated changes
- Commit before closing/completing any task

**Task Management Rules (Beads)**:

- Use `--parent` (not `--epic`) for sub-tasks
- Add tasks as children, not blockers, unless explicitly asked
- Always commit before closing/completing a task
- Work on one task at a time unless explicitly told to parallelize
- Complete each task fully (implement -> test -> lint -> commit) before the next

**Workflow Discipline Rules**:

- When planning, be concise and action-oriented. Do not spend excessive time exploring files before
  producing a plan. Present what you have within 5 minutes
- Do not modify code when asked to update documentation only, and vice versa
- If scope is unclear, ask before expanding beyond the stated request

### memory-conventions

**Trigger description**: "This skill should be used when persisting context between sessions, saving
project state, loading previous session context, or managing longitudinal memory beyond beads issue
tracking."

**Contents**:

- When to write Serena memories vs beads notes vs git commits
- Memory file naming conventions (descriptive, kebab-case)
- What to persist: design decisions, API contracts, architecture choices, discovered constraints
- What NOT to persist: session-specific temp data, file listings, search results
- How to check for existing memories at session start
- When to update vs create new memories

### browser-testing

**Trigger description**: "This skill should be used when testing web UIs, browser automation,
end-to-end testing with Playwright or Puppeteer, Chrome DevTools debugging, or visual regression
testing."

**Contents**:

- Playwright test patterns and best practices
- Page object model conventions
- Screenshot comparison for visual regression
- Chrome DevTools Protocol usage patterns
- Network request interception and mocking
- Accessibility testing automation
- Mobile viewport testing

## Hooks (4)

Defined in plugin.json (see above). The hook scripts live in a `scripts/` directory within the
plugin.

### PostToolUse: secret-scan.sh

**Fires on**: Write, Edit tool usage

**Purpose**: Scans file content after write/edit for leaked secrets.

**Detection patterns**:

- API keys: `AKIA[0-9A-Z]{16}`, `sk-[a-zA-Z0-9]{32,}`, etc.
- Generic secrets: `password\s*=\s*['"][^'"]+`, `secret\s*=\s*['"][^'"]+`
- Private keys: `-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----`
- Connection strings with embedded credentials

**Behavior**: Returns non-zero exit code with warning message if secrets detected. Claude sees the
warning and can remediate before proceeding.

### PreToolUse: dangerous-command-check.sh

**Fires on**: Bash tool usage

**Purpose**: Warns before destructive or dangerous shell commands.

**Detection patterns**:

- `rm -rf /` or `rm -rf ~` (catastrophic deletion)
- `git push --force` to main/master
- `git reset --hard` (data loss)
- `DROP TABLE`, `DROP DATABASE` (data destruction)
- `chmod 777` (insecure permissions)
- `curl | sh` or `wget | bash` (untrusted execution)

**Behavior**: Returns non-zero with warning. User must approve to proceed.

### SessionStart: bd prime

**Fires on**: Every session start

**Purpose**: Recovers beads context for issue tracking continuity.

### PreCompact: bd prime

**Fires on**: Before context compaction

**Purpose**: Preserves beads context through compaction events.

## MCP Servers (.mcp.json)

The core plugin defines MCP server configurations that enhance cross-cutting workflows. Cloud-based
MCP servers (Context7, Serena, Greptile) remain as their own official plugins — not redefined here.

| Server | Purpose                                              | Status |
| ------ | ---------------------------------------------------- | ------ |
| github | GitHub API access for PRs, issues, reviews, and code | Active |

The `.mcp.json` file at plugin root configures this server for use by all core commands and agents.

## Scripts

```text
plugins/ccfg-core/
└── scripts/
    ├── secret-scan.sh               # PostToolUse hook: secret detection
    └── dangerous-command-check.sh    # PreToolUse hook: dangerous command warning
```
