# Plugin: ccfg-github-actions

The GitHub Actions infrastructure plugin. Provides workflow design, deployment architecture, and
supply chain security agents, workflow validation, CI/CD scaffolding, and opinionated conventions
for consistent GitHub Actions development. Focuses on workflow structure, action pinning, token
permissions, and deployment patterns. Safety is paramount — never triggers workflows or interacts
with the GitHub API without explicit user confirmation.

## Directory Structure

```text
plugins/ccfg-github-actions/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── workflow-specialist.md
│   ├── deployment-architect.md
│   └── actions-security.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── actions-conventions/
    │   └── SKILL.md
    ├── ci-patterns/
    │   └── SKILL.md
    └── deployment-patterns/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-github-actions",
  "description": "GitHub Actions infrastructure plugin: workflow design, deployment architecture, and supply chain security agents, workflow validation, CI/CD scaffolding, and conventions for consistent GitHub Actions development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["github-actions", "ci", "cd", "workflows", "pipelines", "deployment", "actions"]
}
```

## Agents (3)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                  | Role                                                                                                | Model  |
| ---------------------- | --------------------------------------------------------------------------------------------------- | ------ |
| `workflow-specialist`  | GitHub Actions YAML, triggers, events, matrix builds, concurrency groups, caching strategies        | sonnet |
| `deployment-architect` | CD strategies, environments, approval gates, reusable workflows, OIDC auth, rollback                | sonnet |
| `actions-security`     | Supply chain security (pinned actions, Sigstore), GITHUB_TOKEN permissions, secret management, OIDC | sonnet |

No coverage command — coverage is a code concept, not an infrastructure concept. This is intentional
and differs from language plugins.

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-github-actions:validate

**Purpose**: Run the full GitHub Actions workflow quality gate suite in one command.

**Trigger**: User invokes before merging workflow changes or reviewing CI/CD configuration.

**Allowed tools**: `Bash(actionlint *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Workflow syntax**: actionlint-aware if available; otherwise YAML structure validation — trigger
   correctness, job/step naming, expression syntax (`${{ }}` patterns), valid runner specifications,
   proper `needs:` dependency chains
2. **Action pinning**: all third-party actions must use SHA pinning (`uses: owner/action@<sha>`) not
   tags. First-party (`actions/*`) may use version tags (`@v4`). Flag unpinned third-party actions
   as FAIL
3. **Token permissions**: verify `permissions:` is set explicitly at workflow or job level (not
   relying on default read-write). Flag overly broad permissions. Check for `GITHUB_TOKEN` being
   printed or logged (potential leak). Specifically flag `permissions: write-all` or absence of any
   `permissions:` key as FAIL (not WARN) — default token permissions are too broad for production
   workflows
4. **Secret hygiene**: no secrets in `run:` echo/print statements, no secrets passed as command-line
   arguments (visible in process list), proper `environment:` gating for deployment secrets
5. **Antipattern detection**: `continue-on-error: true` without justification, missing
   `timeout-minutes` on jobs, `pull_request_target` with checkout of PR head (code injection risk),
   hardcoded runner versions instead of `-latest` or pinned versions, missing `concurrency:` on
   PR-triggered workflows. zizmor-aware for supply chain security if available (detects injection
   risks, unsafe patterns in expressions and contexts)
6. Report pass/fail for each gate with output
7. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Workflow syntax**: Same as full mode (YAML validation)
2. **Action pinning**: Same as full mode (SHA pinning check)
3. Report pass/fail — skips token permissions, secret hygiene, and antipattern detection for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — workflow YAML files in `.github/workflows/`. Does not
  interact with the GitHub API by default. Live checks (workflow run history, secret existence,
  action versions) require the `--live` flag and explicit user confirmation before any API
  interaction
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available (e.g., actionlint not
  installed), skip that gate and report it as SKIPPED. Suggest installing the missing tool
- actionlint detection: if available, invoke and parse output; if missing, use built-in heuristic
  checks and suggest installing actionlint
- Optional tooling (detect-and-skip): actionlint (workflow syntax), zizmor (supply chain security
  scanning). If not installed, use heuristic checks for the corresponding gate and suggest the
  missing tool in output
- Checks for presence of conventions document (`docs/infra/github-actions-conventions.md` or
  similar). Reports SKIPPED if no `docs/` directory exists — never fails on missing documentation
  structure

### /ccfg-github-actions:scaffold

**Purpose**: Initialize CI/CD workflow files for GitHub Actions projects.

**Trigger**: User invokes when setting up GitHub Actions in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=ci|cd|release|pr-checks|reusable-workflow]`

**Behavior**:

**ci** (default):

1. Detect project language/framework and test tooling from project files
2. Generate CI workflow (`.github/workflows/ci.yml`): checkout → setup language → install deps →
   lint → test → build
3. Include language-appropriate caching (setup-node cache, pip cache, Go module cache, Gradle cache)
4. Set `permissions: read-all` minimum, then add specific write permissions as needed
5. Pin all third-party actions to SHA
6. Include `concurrency:` with `cancel-in-progress: true` for PR-triggered workflows
7. Add `timeout-minutes` on all jobs

**cd**:

1. Generate deployment workflow (`.github/workflows/deploy.yml`) with environment gates
2. Include environment protection rules reference
3. OIDC token configuration for cloud provider auth (no long-lived credentials)
4. Blue-green or rolling strategy template with health check verification

**release**:

1. Generate release workflow (`.github/workflows/release.yml`) triggered by tag push or manual
   dispatch
2. Include changelog generation step
3. Asset build and upload to GitHub Release
4. Include version validation (tag matches package version)

**pr-checks**:

1. Generate PR validation workflow (`.github/workflows/pr-checks.yml`): lint, test, build status
2. Include `paths:` filters for monorepo efficiency
3. Include `concurrency:` to cancel outdated runs on same PR
4. Add required status checks suggestion in output

**reusable-workflow**:

1. Generate reusable workflow template (`.github/workflows/reusable-<name>.yml`) with
   `workflow_call:` trigger
2. Include typed `inputs:` and `secrets:` parameters with descriptions
3. Include caller workflow example showing `uses:` syntax with input/secret mapping
4. Set `permissions:` explicitly on the reusable workflow

**Key rules**:

- Language detection is best-effort — never prescribe a toolchain, respect what the project already
  uses
- All generated workflows use SHA-pinned third-party actions
- Never includes real secrets — uses `${{ secrets.EXAMPLE }}` placeholder patterns
- Generated workflows always set explicit `permissions:` (least privilege)
- If inside a git repo, ensure `.github/workflows/` directory exists
- Scaffold recommends creating a conventions document at `docs/infra/github-actions-conventions.md`.
  If the project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure
  exists, skip and note in output

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### actions-conventions

**Trigger description**: "This skill should be used when working with GitHub Actions, writing CI/CD
workflows, configuring workflow triggers, or reviewing GitHub Actions configuration."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses specific workflow patterns, trigger configurations, or action versions, follow them. If
the project uses tag-based action pinning instead of SHA, flag it but don't change without
coordination. These preferences apply to new workflows and scaffold output only.

**Workflow structure rules**:

- File naming: kebab-case (`ci.yml`, `deploy-staging.yml`, `pr-checks.yml`)
- Job naming: descriptive, kebab-case (`build-and-test`, `deploy-staging`, `lint-code`)
- Step naming: use `name:` on every step for readable logs — descriptive imperative form ("Install
  dependencies", "Run unit tests")
- Trigger selection: `push` + `pull_request` for CI, `workflow_dispatch` for manual, `release` for
  releases, avoid `schedule` unless truly needed (wastes minutes)

**YAML style rules**:

- Use `|` for multi-line `run:` blocks, never `>` (folding breaks shell commands)
- Always set `shell: bash` explicitly on `run:` steps (consistent behavior across runners)
- Quote expressions: `"${{ secrets.TOKEN }}"` in shell contexts to prevent injection
- Use `env:` at job level for shared variables, step level for step-specific

**Permissions rules**:

- Always set `permissions:` explicitly — never rely on default token permissions
- Start with `permissions: read-all` at workflow level, add specific write permissions per-job
- Common patterns: `contents: read` (checkout), `pull-requests: write` (PR comments),
  `packages: write` (container registry), `id-token: write` (OIDC)

**Concurrency rules**:

- Use `concurrency:` with `cancel-in-progress: true` on PR-triggered workflows
- Group by `${{ github.workflow }}-${{ github.ref }}` for branch-scoped concurrency
- Do NOT cancel deployment workflows — use queue-based concurrency instead

**Runner rules**:

- Use `ubuntu-latest` for most workloads (faster provisioning, well-maintained)
- Pin to specific version (`ubuntu-22.04`) when reproducibility matters more than freshness
- Use matrix strategy for multi-OS testing when needed

### ci-patterns

**Trigger description**: "This skill should be used when implementing CI pipelines, configuring
caching, setting up matrix builds, creating composite actions, or optimizing workflow performance."

**Contents**:

- **Caching strategies**: use built-in `cache:` parameter on setup actions (setup-node,
  setup-python, setup-go) when available. For custom caches, use `actions/cache` with hash-based
  keys (`hashFiles('**/package-lock.json')`). Separate caches per OS/language version in matrix
  builds. Set `restore-keys:` for partial cache hits
- **Matrix builds**: use `strategy.matrix` for multi-version testing (e.g., node: [18, 20, 22]). Set
  `fail-fast: false` to see all failures, not just the first. Use `include:` for additional
  configurations, `exclude:` for known-bad combinations. Keep matrix dimensions small (< 20 total
  combinations)
- **Composite actions**: extract repeated step sequences (>3 steps used in multiple workflows) into
  `.github/actions/<name>/action.yml`. Use composite actions for org-wide patterns. Prefer composite
  over JavaScript actions for simple step sequences
- **Reusable workflows**: use `workflow_call` for cross-repo workflow sharing. Pass inputs for
  configuration, secrets for credentials. Limit nesting (reusable workflows can't call other
  reusable workflows beyond depth 4)
- **Artifacts**: use `actions/upload-artifact` and `actions/download-artifact` for passing data
  between jobs. Set retention days appropriately (default 90 is often too long). Use artifact names
  that include context (OS, version)
- **Monorepo patterns**: use `paths:` filter on triggers to skip irrelevant workflows. Use
  `dorny/paths-filter` action for job-level conditional execution. Group related services by
  workflow file

### deployment-patterns

**Trigger description**: "This skill should be used when implementing CD pipelines, configuring
deployment environments, setting up OIDC authentication, or designing rollback strategies."

**Contents**:

- **Environments**: use GitHub Environments for staging/production separation. Configure protection
  rules (required reviewers, wait timer, deployment branches). Reference environment in workflow:
  `environment: production`. Environment secrets override repository secrets
- **OIDC authentication**: use OpenID Connect for cloud provider auth — no long-lived credentials
  stored as secrets. Configure trust relationships in AWS (IAM role), Azure (federated credentials),
  or GCP (Workload Identity). Use `permissions: id-token: write` at job level. Each cloud provider
  has an official action for OIDC exchange
- **Deployment strategies**: blue-green (deploy to inactive environment, swap after health check),
  canary (route percentage of traffic to new version), rolling (gradual pod/instance replacement).
  Choose based on risk tolerance and infrastructure capabilities
- **Reusable workflows for deployment**: define deployment logic in a reusable workflow with inputs
  for environment, version, and strategy. Call from environment-specific workflows. Pass secrets via
  `secrets: inherit` or explicit secret mapping
- **Rollback patterns**: manual dispatch workflow with version parameter for emergency rollback.
  Automated rollback: post-deployment health check, trigger rollback workflow on failure. Keep
  previous N deployment artifacts for quick rollback. Document rollback procedures in conventions
  doc
