---
description: Create PR with pre-flight validation gates
argument-hint: [--title "..."] [--base main]
allowed-tools: Bash(git:*), Bash(gh:*), Bash(uv:*), Read, Grep
---

# PR Create

Create a pull request with comprehensive pre-flight validation gates to ensure code quality and
prevent common issues before the PR is opened. All gates must pass before PR creation.

## Usage

```bash
/pr-create [--title "feat: description"] [--base main]
```

**Options:**

- `--title` - PR title (optional, will be inferred from commits if not provided)
- `--base` - Base branch to merge into (default: main)

**Examples:**

```bash
/pr-create
/pr-create --title "feat: add user authentication"
/pr-create --base develop --title "fix: resolve session timeout"
```

## Pre-Flight Validation Gates

All gates must pass before PR creation. If any gate fails, the process stops and reports which gates
failed.

### Gate 1: No Uncommitted Changes

**Check:** Working directory must be clean with no uncommitted changes.

**Command:**

```bash
git status --porcelain
```

**Pass Criteria:** Empty output (no staged, unstaged, or untracked files)

**Failure Message:**

```text
GATE FAILED: Uncommitted Changes

You have uncommitted changes in your working directory.
Please commit or stash them before creating a PR.

Uncommitted files:
<list of files>

To fix:
  git add <files>
  git commit -m "message"
```

### Gate 2: Branch Up to Date with Base

**Check:** Current branch must be up to date with the base branch.

**Commands:**

```bash
# Fetch latest from remote
git fetch origin main

# Check if current branch is up to date
git merge-base --is-ancestor origin/main HEAD
```

**Pass Criteria:** Exit code 0 (base branch is ancestor of current branch)

**Failure Message:**

```text
GATE FAILED: Branch Not Up to Date

Your branch is not up to date with origin/main.
Please rebase or merge the latest changes.

To fix:
  git pull --rebase origin main
  # Resolve any conflicts
  git push --force-with-lease
```

### Gate 3: Tests Pass

**Check:** All tests must pass if test configuration exists.

**Detection:**

```bash
# Check if pytest is configured
uv run pytest --collect-only --quiet 2>/dev/null
```

**Command:**

```bash
uv run pytest
```

**Pass Criteria:** Exit code 0, all tests passing

**Failure Message:**

```text
GATE FAILED: Tests Failing

Test suite is failing. Please fix failing tests before creating PR.

Failed tests:
<test output>

To fix:
  uv run pytest -v
  # Fix failing tests
```

**Skip Condition:** If no pytest configuration exists, skip this gate with note.

### Gate 4: Lint Clean

**Check:** Code must pass linting checks if linter is configured.

**Detection:**

```bash
# Check if ruff is configured
uv run ruff check --version 2>/dev/null
```

**Command:**

```bash
uv run ruff check .
```

**Pass Criteria:** Exit code 0, no linting errors

**Failure Message:**

```text
GATE FAILED: Linting Errors

Code has linting errors. Please fix before creating PR.

Errors:
<linting output>

To fix:
  uv run ruff check --fix .
  # Review and commit fixes
```

**Skip Condition:** If ruff is not configured, skip this gate with note.

### Gate 5: No Secrets in Diff

**Check:** Diff must not contain secrets, API keys, or sensitive data.

**Command:**

```bash
git diff main...HEAD
```

**Patterns to Detect:**

- AWS keys: `AKIA[0-9A-Z]{16}`
- GitHub tokens: `ghp_[a-zA-Z0-9]{36}`, `github_pat_[a-zA-Z0-9_]{82}`
- Slack tokens: `xox[baprs]-[a-zA-Z0-9-]+`
- OpenAI keys: `sk-[a-zA-Z0-9]{48}`
- Stripe keys: `sk_live_[a-zA-Z0-9]{24}`, `pk_live_[a-zA-Z0-9]{24}`
- Private keys: `BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY`
- Generic secrets: `password\s*=\s*["'][^"']+["']`, `api_key\s*=\s*["'][^"']+["']`
- Bearer tokens: `Authorization:\s*Bearer\s+[a-zA-Z0-9\-._~+/]+=*`

**Pass Criteria:** No secret patterns detected in diff

**Failure Message:**

```text
GATE FAILED: Secrets Detected

Found potential secrets in your changes:

File: path/to/file.py, Line 42
Pattern: AWS Access Key
Content: AKIAIOSFODNN7EXAMPLE

File: path/to/config.js, Line 18
Pattern: API Key
Content: api_key = "sk-abc123..."

CRITICAL: Do not commit secrets to git!

To fix:
  1. Remove secrets from code
  2. Use environment variables or secret management
  3. Add files to .gitignore if needed
  4. Rotate exposed credentials immediately
```

## PR Creation Process

If all gates pass, proceed with PR creation:

### Step 1: Extract Commit Information

Analyze commits since base branch to generate PR content:

```bash
# Get commit messages
git log --pretty=format:"%s" main..HEAD

# Get detailed diff stats
git diff --stat main...HEAD
```

### Step 2: Generate PR Title

**If --title provided:** Use the provided title

**If --title not provided:**

- If single commit: Use commit message
- If multiple commits: Generate title from common theme
- Follow conventional commit format: `type(scope): description`
- Keep under 70 characters

### Step 3: Generate PR Body

Use structured template:

```bash
gh pr create --title "<title>" --base "<base>" --body "$(cat <<'EOF'
## Summary

<1-3 sentence summary of changes>

## Changes

- <bullet list of key changes>
- <organized by area or file>

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests passing

## Pre-Flight Gates

- [x] No uncommitted changes
- [x] Branch up to date with base
- [x] Tests passing
- [x] Linting clean
- [x] No secrets in diff

## Checklist

- [ ] Documentation updated
- [ ] Breaking changes documented
- [ ] Migration guide included (if needed)

Generated with Claude Code
EOF
)"
```

### Step 4: Output PR URL

After successful creation:

```text
PR CREATED SUCCESSFULLY

PR: https://github.com/owner/repo/pull/123
Title: feat: add user authentication
Base: main <- feature-branch

All pre-flight gates passed:
  ✓ No uncommitted changes
  ✓ Branch up to date
  ✓ Tests passing
  ✓ Linting clean
  ✓ No secrets detected

Next steps:
  - Request reviewers
  - Monitor CI/CD checks
  - Address review feedback
```

## Gate Failure Handling

When one or more gates fail:

### Stop Immediately

Do not create the PR. Report all failed gates clearly.

### Provide Clear Remediation

For each failed gate, provide:

- What failed
- Why it matters
- Specific commands to fix
- Links to documentation if applicable

### Report Summary

```text
PR CREATION ABORTED

Failed gates (2/5):
  ✗ Gate 2: Branch not up to date with main
  ✗ Gate 4: Linting errors present

Passed gates (3/5):
  ✓ Gate 1: No uncommitted changes
  ✓ Gate 3: Tests passing
  ✓ Gate 5: No secrets detected

Please address failed gates and try again.
```

## Best Practices

### Always Run Pre-Flight

- Never skip gates to "save time"
- Gates prevent common PR rejection reasons
- Faster to fix issues locally than in review

### Keep PRs Focused

- Single logical change per PR
- Split large features into multiple PRs
- Easier to review, faster to merge

### Write Clear Descriptions

- Explain the "why" not just the "what"
- Link to related issues or tasks
- Include screenshots for UI changes
- Document breaking changes prominently

### Update Tests First

- Write tests before creating PR
- Ensure coverage for new code paths
- Update tests for modified behavior

## Advanced Usage

### Custom Base Branch

For feature branch workflows:

```bash
/pr-create --base develop --title "feat: new feature"
```

### Draft PRs

To create a draft PR (for work in progress):

Modify the `gh pr create` command to include `--draft` flag after gates pass.

### Auto-Assign Reviewers

Configure default reviewers in repository settings or use:

```bash
gh pr create ... --reviewer @user1,@user2
```

## Notes

- Requires `gh` CLI authenticated with GitHub
- Requires `uv` for Python projects with tests/linting
- Secret detection patterns should be updated regularly
- Gates can be customized per project needs
- Consider adding type checking gate (`mypy`) for Python projects
