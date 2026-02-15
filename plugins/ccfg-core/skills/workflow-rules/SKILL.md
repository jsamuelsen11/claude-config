---
name: workflow-rules
description:
  This skill should be used for ALL coding tasks, code reviews, planning, git operations, and
  development work. It defines mandatory workflow rules that must be followed in every session.
version: 0.1.0
---

# Workflow Rules

This skill defines mandatory workflow rules that must be followed in every development session.
These rules prevent recurring friction patterns discovered across 275 sessions: 42 wrong approaches,
34 buggy code incidents, 27 rejected actions.

## Code Quality Rules

### Linting and Pre-commit Checks

**Always run pre-commit/lefthook checks before considering any task complete.** If the project has
pre-commit hooks, lefthook, or other automated checks configured, they must pass before you can
close a task or create a commit.

**Do not suppress linter warnings, formatter checks, or static analysis findings.** Always attempt
to fix the root cause first. Suppression hides problems and creates technical debt.

**Inline suppression patterns (do not use without exhausting alternatives):**

- **JavaScript/TypeScript**: `eslint-disable`, `eslint-disable-next-line`, `@ts-ignore`,
  `@ts-expect-error`, `@ts-nocheck`, `// prettier-ignore`
- **Python**: `# noqa`, `# type: ignore`, `# pylint: disable`, `# nosec`
- **Rust**: `#[allow(...)]` (blanket forms like `dead_code`, `clippy::all`, `unused`)
- **Go**: `//nolint`, `_ = err` (silencing errors is suppression)
- **Java**: `@SuppressWarnings`, `@SuppressFBWarnings`
- **C#/.NET**: `#pragma warning disable`, `[SuppressMessage]`, adding to `<NoWarn>`
- **Shell**: `# shellcheck disable=SC####`
- **Coverage/quality**: `# pragma: no cover`, `/* istanbul ignore */`, `skipcq`

**Config-level bypasses are equally prohibited.** Do not work around findings by:

- Adding rules to ignore or disable lists in config files (`.eslintrc`, `ruff.toml`,
  `.golangci.yml`, `pyproject.toml`, etc.)
- Raising thresholds to make violations pass (e.g., increasing max complexity)
- Removing linter plugins or rulesets to eliminate categories of findings
- Switching formatters or linters to avoid specific checks

**Fix root causes — examples:**

```python
# WRONG: Suppress complexity warning
def process(items):  # noqa: C901
    if a:
        if b:
            if c:
                ...

# RIGHT: Refactor to reduce complexity
def process(items):
    if not _should_process(items):
        return
    validated = _validate(items)
    return _apply(validated)
```

```typescript
// WRONG: Ignore the type error
// @ts-ignore
const result: number = fetchData();

// RIGHT: Handle the type properly
const data: unknown = fetchData();
const result = typeof data === 'number' ? data : 0;
```

```go
// WRONG: Silence the error
result, _ := doSomething()

// RIGHT: Handle or propagate
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doSomething: %w", err)
}
```

**Common fixes by violation type:**

- **Complexity**: Extract helper functions, use early returns, simplify conditionals
- **Line length**: Break at logical points, extract to named variables
- **Unused imports/variables**: Remove them
- **Naming conventions**: Rename to match the project style
- **Missing error handling**: Add proper handling or propagation
- **Type errors**: Add correct types, use type guards, validate at boundaries

**When suppression is acceptable:** If you have genuinely attempted to fix the root cause and the
finding is a false positive, a tooling bug, or a third-party code boundary that cannot be changed,
targeted suppression is acceptable under these conditions:

1. Use the most specific suppression possible (single line, single rule — never file-level or
   blanket suppressions)
2. Add a comment explaining WHY the finding is a false positive or unfixable
3. Reference a linter issue tracker link if it is a known tooling bug

### Markdown Files

**Validate markdown files with markdownlint before committing.** Common issues to watch for:

- **MD013** (line length): Wrap prose at 100 characters unless explicitly disabled
- **MD040** (fenced code language): Always specify language for code blocks
- **MD033** (inline HTML): Avoid when possible; use markdown alternatives
- **MD034** (bare URLs): Use link syntax `[text](url)` instead of bare URLs
- **MD041** (first line heading): Ensure documents start with a level 1 heading
- **MD022/MD023/MD024/MD025** (heading spacing and uniqueness)
- **MD029** (ordered list prefixes): Use consistent numbering style
- **MD030** (list marker spacing): Consistent spacing after list markers

Check the project's `.markdownlint.json` or `.markdownlintrc` for specific rule configurations.

### Code Clarity

**Never use magic numbers.** Define constants with descriptive names:

```python
# Bad
if user.age >= 18:
    grant_access()

# Good
MINIMUM_AGE_FOR_ACCESS = 18
if user.age >= MINIMUM_AGE_FOR_ACCESS:
    grant_access()
```

**Always handle errors explicitly.** No shortcuts:

- Go: No `_ = err` — always handle or propagate errors
- Python: No bare `except:` — catch specific exceptions
- Java/TypeScript: No empty catch blocks — log or re-throw
- Rust: No unwrapping without panic messages

```go
// Bad
result, _ := doSomething()

// Good
result, err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}
```

**Prefer descriptive variable names over abbreviations:**

- `userRepository` over `ur`
- `maxConnectionTimeout` over `mct`
- `customerList` over `cl`

Exceptions: well-known abbreviations (i, j, k in loops; err for errors; ctx for context)

### Comments and Documentation

**Write self-documenting code; only add comments where logic isn't self-evident.** Good code reads
like prose. Comments should explain "why", not "what":

```javascript
// Bad
// Increment counter
counter++;

// Good
// Skip first iteration to avoid off-by-one error in legacy API
counter++;
```

**Don't add docstrings, comments, or type annotations to code you didn't change.** If you're fixing
a bug in a function, don't add docstrings as "while you're there" work unless explicitly asked. Stay
focused on the task.

### Scope Discipline

**Avoid over-engineering: only make changes directly requested or clearly necessary.** Don't add
features "just in case" or "for future extensibility" unless the user explicitly asks for it.

**Don't add error handling for scenarios that can't happen:**

```python
# Bad - file is already validated before this function
def process_user(user_id: int):
    if user_id is None:  # Can't happen - type system prevents it
        raise ValueError("user_id cannot be None")
```

**Don't create abstractions for one-time operations.** If something is used once, inline it. Only
abstract when you have 2-3 concrete examples showing the pattern.

## Git Workflow Rules

### Branching Strategy

**Never push to `main` directly. Always create a feature branch and open a PR.** This applies even
for documentation changes, typo fixes, or "quick" changes. The PR process exists for a reason.

**Ask which branch to target if unclear.** Different projects use different conventions:

- Some use `main` or `master` for production
- Some use `develop` for integration
- Some use `staging` for pre-production

Never assume. Ask: "Which branch should I target for this PR?"

### Commit Discipline

**One task = one commit. Do not batch unrelated changes.** If you're working on multiple tasks,
commit each one separately:

- ✅ "feat(auth): add password reset endpoint" (one feature)
- ❌ "feat(auth): add password reset endpoint and fix login bug and update docs" (three changes)

**Commit before closing/completing any task.** Work is not done until it's committed. The sequence
must always be:

1. Implement the change
2. Test the change (manual or automated)
3. Run linters/pre-commit checks
4. Stage specific files with `git add <file1> <file2>`
5. Commit with descriptive message
6. Push to remote
7. Close/complete the task in beads

**Use conventional commit format:** `type(scope): description`

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Formatting, missing semicolons, etc (no code change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD pipeline changes
- `build`: Build system or external dependency changes

Scope: The affected component, module, or area (e.g., `auth`, `api`, `ui`, `db`)

Description: Imperative mood, lowercase, no period at end

Examples:

- `feat(api): add user profile endpoint`
- `fix(auth): prevent token expiry race condition`
- `docs(readme): update installation instructions`
- `refactor(db): extract query builder to separate module`

### Git Safety

**Never use `git push --force` to main/master.** Force pushing overwrites history and can destroy
other people's work. If you need to force push to a feature branch, use `--force-with-lease` which
is safer.

**Never use `git reset --hard` without explicit user approval.** This destroys uncommitted work
permanently. Always ask first.

**Never skip hooks (--no-verify) unless the user explicitly requests it.** Pre-commit hooks exist to
catch problems before they enter the history. Bypassing them defeats the purpose.

**Always create NEW commits rather than amending, unless explicitly requested.** When a pre-commit
hook fails, the commit did NOT happen — so `--amend` would modify the PREVIOUS commit, which may
result in destroying work or losing previous changes. Instead, after hook failure:

1. Fix the issue identified by the hook
2. Re-stage the fixed files
3. Create a NEW commit

**When staging files, prefer adding specific files by name rather than `git add -A`.** This prevents
accidentally committing:

- Sensitive files (.env, credentials.json, private keys)
- Large binaries (build artifacts, node_modules)
- Debug files (.log, .tmp)
- Editor configs (.vscode, .idea) that shouldn't be shared

Example:

```bash
# Bad
git add -A

# Good
git add src/auth/login.ts src/auth/login.test.ts docs/auth.md
```

## Task Management Rules (Beads)

### Task Hierarchy

**Use `--parent` (not `--epic`) for sub-tasks.** The correct flag for creating child tasks is
`--parent`:

```bash
# Correct
bd add "Implement user login" --parent 42

# Incorrect
bd add "Implement user login" --epic 42
```

**Add tasks as children, not blockers, unless explicitly asked.** If task B depends on task A, make
B a child of A. Only use blockers when the relationship is cross-epic or explicitly requested.

### Task Workflow

**Always commit before closing/completing a task.** The sequence must be:

1. Complete the work (implement, test, lint)
2. Create git commit
3. Push to remote
4. Close task with `bd close <id> --reason="..."`

**Work on one task at a time unless explicitly told to parallelize.** Complete each task fully
before moving to the next:

1. Implement the change
2. Test the change (manual or automated)
3. Run linters/pre-commit checks
4. Create git commit
5. Push to remote
6. Close the task

**Complete each task fully before the next.** "Fully" means:

- Code implemented and working
- Tests written and passing (if project has test coverage requirements)
- Linters passing
- Committed to git
- Pushed to remote

Don't leave tasks in a half-done state to move to something else unless blocked.

### Task Documentation

**Use `bd close <id> --reason="..."` to document what was done.** The reason should be a concise
summary of what was accomplished, not just "done" or "completed":

```bash
# Bad
bd close 42 --reason="done"

# Good
bd close 42 --reason="implemented JWT auth with refresh tokens, added tests, updated API docs"
```

### Session Management

**Run `bd sync` at end of every session.** This ensures your local beads state is synchronized with
the remote issue tracker (GitHub, Jira, Linear, etc.).

**Check `bd ready` for available work, not `bd list`.** The `bd ready` command shows tasks that are
actually ready to work on (not blocked, in correct status). Use `bd list` only when you need to see
all tasks regardless of status.

## Workflow Discipline Rules

### Planning and Communication

**When planning, be concise and action-oriented. Present what you have promptly.** Don't spend
paragraphs explaining what you're about to do. Instead:

- Quick summary (1-2 sentences)
- Bulleted action items
- Execute

Users prefer seeing progress over reading lengthy explanations.

**Do not modify code when asked to update documentation only, and vice versa.** Respect the scope:

- "Update the README" = touch only documentation files
- "Fix the login bug" = touch only code files (and tests if needed)

Don't bundle unrelated changes without asking first.

**If scope is unclear, ask before expanding beyond the stated request.** When a user says "fix the
auth bug", don't also refactor the auth module, update dependencies, and add new features. Fix the
bug. Then ask if they want additional improvements.

### Decision Making

**Present options when multiple valid approaches exist; don't assume.** If there are trade-offs,
present them:

"There are two approaches:

1. **Option A**: Faster to implement (2 hours), but requires manual testing
2. **Option B**: More robust (4 hours), includes automated tests

Which would you prefer?"

Don't pick one silently and hope it's what they wanted.

### Handling Blockers

**If blocked, explain why and suggest alternatives rather than silently giving up.** When you
encounter a blocker:

1. Clearly state what you're blocked on
2. Explain why it's blocking you
3. Suggest 2-3 alternatives or workarounds
4. Ask for guidance

Example: "I can't proceed with the database migration because the production credentials aren't in
the .env file. Options: 1) You provide the credentials, 2) I create a mock environment for
testing, 3) I document the migration steps for you to run manually. Which would you prefer?"

### Completion Discipline

**Never say "ready to push when you are" — YOU must push.** The AI agent is responsible for
completing the git workflow. Saying "ready to push" is passing the buck. Just push.

**Work is NOT complete until `git push` succeeds.** A local commit is not done. The sequence must
be:

1. `git commit -m "..."`
2. `git push`
3. Verify push succeeded
4. Only then close the task

**Always verify: git status should show "up to date with origin" at session end.** Before ending any
session, run `git status` and confirm:

- Working tree is clean (or intentionally has uncommitted changes)
- Branch is up to date with remote
- No unpushed commits

If there are unpushed commits, push them unless explicitly told not to.

## Security Rules

### Secrets Management

**Never commit files containing secrets (.env, credentials.json, private keys).** Before every
commit, scan staged files for:

- Environment files (.env, .env.local, .env.production)
- Credential files (credentials.json, service-account.json)
- Private keys (.pem, .key, id_rsa)
- API keys in config files
- Database connection strings with passwords

If you need to commit example configurations, use placeholder values:

```bash
# .env.example (safe to commit)
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
API_KEY=your_api_key_here

# .env (NEVER commit)
DATABASE_URL=postgresql://prod_user:actual_password@prod.example.com:5432/production_db
API_KEY=sk_live_actual_key_12345
```

**Scan for hardcoded credentials before every commit.** Use regex or manual review to catch:

- Password literals: `password = "actual_password"`
- API keys: `api_key = "sk_live_..."`
- Tokens: `token = "ghp_..."`
- Connection strings with credentials

### Permissions

**Never add `chmod 777` or world-writable permissions.** This makes files readable, writable, and
executable by everyone, which is a security risk. Instead:

- `chmod 644` for regular files (owner can write, others can read)
- `chmod 755` for executables (owner can write, everyone can execute)
- `chmod 600` for sensitive files (owner only)

**Never pipe remote content to shell (curl|sh, wget|bash).** This pattern downloads and immediately
executes remote code without inspection:

```bash
# Dangerous
curl https://example.com/install.sh | sh

# Safe
curl -O https://example.com/install.sh
# Inspect install.sh
sh install.sh
```

### Input Validation

**Validate all user input at system boundaries.** Any data entering the system from:

- HTTP request parameters
- Database queries (prevent SQL injection)
- File uploads
- Command-line arguments
- Environment variables

Must be validated, sanitized, or parameterized before use:

```python
# Bad - SQL injection risk
query = f"SELECT * FROM users WHERE username = '{username}'"

# Good - parameterized query
query = "SELECT * FROM users WHERE username = ?"
cursor.execute(query, (username,))
```

## Code Review Rules

### Review Process

When reviewing code (either your own before committing, or someone else's PR), use severity levels
to categorize feedback:

- **BLOCKER**: Must fix before merging (security issues, data corruption, broken functionality)
- **WARNING**: Should fix before merging (performance issues, maintainability problems, convention
  violations)
- **NIT**: Suggestion for improvement (style preferences, minor optimizations, bikeshedding)

### Review Checklist

**Correctness:**

- Does the code do what it's supposed to do?
- Are edge cases handled?
- Are errors handled appropriately?
- Are there race conditions or concurrency issues?

**Security:**

- Are user inputs validated?
- Are secrets properly managed?
- Are there injection vulnerabilities (SQL, XSS, command)?
- Are authentication and authorization correct?

**Performance:**

- Are there obvious inefficiencies (N+1 queries, unnecessary loops)?
- Are large datasets handled efficiently?
- Are resources properly released (connections, file handles)?

**Maintainability:**

- Is the code readable and well-organized?
- Are names descriptive?
- Is complexity appropriate for the problem?
- Are there sufficient tests?

**Conventions:**

- Does the code follow the project's style guide?
- Are commit messages following the conventional format?
- Are files in the correct locations?

### Focus on Substance

**Focus on substance over style for things the linter handles.** If the project has automated
linting for formatting, don't comment on:

- Indentation
- Quote style
- Trailing commas
- Spacing around operators

The linter will catch these. Focus your review on logic, architecture, and maintainability.

## Summary

These workflow rules exist because they solve real problems that occurred in hundreds of sessions.
Following them prevents:

- Broken commits that don't pass CI
- Lost work from improper git operations
- Security vulnerabilities from credential leaks
- Scope creep and over-engineering
- Incomplete tasks and confused state

Every rule has a reason. Trust the process.
