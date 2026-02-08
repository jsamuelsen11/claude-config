---
description:
  Execute a beads epic task with branch, planning conversation, implementation, validation, and PR
argument-hint: <task-id> (e.g. claude-config-9re.1)
allowed-tools:
  Bash(git *), Bash(bd *), Bash(uv *), Bash(gh pr create *), Bash(gh pr view *), Read, Grep, Glob,
  Edit, Write, Task
---

# Epic Task Execution

You are executing a beads task in an independent session. Follow every phase in order. Do not skip
phases. Do not combine phases. Confirm with the user before moving between major phases (Planning ->
Implementation -> Validation -> PR).

**Target task**: $ARGUMENTS

---

## Phase 0: Context Recovery

**Goal**: Load all context needed to work cold.

1. Read the project design doc:
   ```
   Read docs/DESIGN.md
   ```
2. Load the task details:
   ```bash
   bd show $ARGUMENTS
   ```
3. Check what blocks this task and confirm all blockers are closed:
   ```bash
   bd show $ARGUMENTS   # check blockedBy field
   ```
   If blockers are open, **STOP** and tell the user. Do not proceed with blocked work.
4. Read AGENTS.md for session protocol rules.
5. Check current branch and repo state:
   - Current branch: !`git branch --show-current`
   - Repo status: !`git status --short`
   - Recent commits: !`git log --oneline -5`

If the repo is dirty or not on `main`, **STOP** and ask the user how to proceed.

---

## Phase 1: Branch

**Goal**: Create an isolated feature branch from a clean main.

1. Ensure main is up to date:
   ```bash
   git pull --rebase origin main
   ```
2. Create and switch to a feature branch:
   ```bash
   git checkout -b <task-id>    # e.g. claude-config-9re.1
   ```
3. Claim the task:
   ```bash
   bd update <task-id> --status in_progress
   ```

---

## Phase 2: Planning Conversation

**Goal**: Lock in every implementation detail before writing code. This is the most important phase.
Do not rush it.

**Actions**:

1. Present the task scope to the user in your own words. Include:
   - What this task produces (files, functions, tests)
   - What it does NOT touch (explicit boundaries)
   - Design decisions that apply (reference DESIGN.md by number, e.g. D1, D4)
   - Any open questions or ambiguities you see

2. Identify and ask about anything underspecified:
   - File locations and naming
   - Function signatures and return types
   - Edge cases and error handling
   - Test coverage expectations
   - Integration points with other tasks

3. **Wait for user answers before proceeding.** Do not guess. Do not assume. If the user says
   "whatever you think is best", state your recommendation and get explicit confirmation.

4. Once all questions are resolved, present a concrete implementation checklist:
   - Files to create/modify (with paths)
   - Functions/classes to implement
   - Tests to write
   - Validation steps

5. **Get explicit user approval** of the checklist before moving to Phase 3.

---

## Phase 3: Implementation

**Goal**: Build exactly what was agreed in Phase 2.

**Rules**:

- Follow docs/DESIGN.md decisions strictly
- Follow project conventions (see AGENTS.md and any CLAUDE.md)
- One logical change at a time, committed incrementally
- Use `uv` for all Python operations (never bare `python`, `pip`, or `pytest`)
- No `nolint`, `noqa`, or lint suppressions -- fix the root cause
- No magic numbers -- define constants
- Handle errors explicitly

**Actions**:

1. Implement the agreed checklist item by item
2. After each logical unit, run relevant checks:
   ```bash
   uv run pytest tests/ -x      # if Python tests exist
   ```
3. Commit after each meaningful milestone:
   ```bash
   git add <specific-files>
   git commit -m "<descriptive message>"
   ```
4. Keep the user informed of progress. Summarize what was done after each commit.

---

## Phase 4: Validation

**Goal**: Prove the work is correct and complete before PR.

Run every applicable check. Do NOT skip any.

### 4a. Tests

```bash
uv run pytest tests/ -v          # full test suite
```

If tests fail, fix them before proceeding. Never disable or skip tests.

### 4b. Lint & Format

```bash
uv run ruff check .              # if ruff is configured
uv run ruff format --check .     # format check
```

If lint fails, fix the code. Never add lint suppressions.

### 4c. Type Check (if applicable)

```bash
uv run mypy src/                 # if mypy is configured
```

### 4d. Verify Task Completeness

Review the Phase 2 checklist item by item:

- [ ] Every file listed was created/modified
- [ ] Every function/class listed was implemented
- [ ] Every test listed passes
- [ ] No untracked files that should be committed
- [ ] No debug code, TODOs, or print statements left behind

### 4e. Final Status

```bash
git status
git log --oneline main..HEAD     # all commits on this branch
```

Present the validation results to the user. If anything is incomplete, fix it.

---

## Phase 5: PR & Close

**Goal**: Ship the work back to main.

1. Push the branch:

   ```bash
   git push -u origin HEAD
   ```

2. Create a pull request:

   ```bash
   gh pr create --title "<task-id>: <short description>" --body "$(cat <<'EOF'
   ## Summary
   <1-3 bullet points of what was done>

   ## Task
   Closes beads task `<task-id>`: <task title>

   ## Changes
   <list of files changed with brief descriptions>

   ## Validation
   - [ ] All tests pass
   - [ ] Lint clean
   - [ ] Type check clean (if applicable)
   - [ ] Manual review of implementation checklist

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

3. Close the beads task:

   ```bash
   bd close <task-id> --reason="PR created: <pr-url>"
   ```

4. Sync beads:

   ```bash
   bd sync
   ```

5. Present the PR URL to the user.

---

## Abort Protocol

If at any point you cannot proceed (blocked task, failing tests you can't fix, unclear requirements
the user can't clarify):

1. Commit any work in progress:
   ```bash
   git add -A && git commit -m "WIP: <what was done so far>"
   ```
2. Push the branch:
   ```bash
   git push -u origin HEAD
   ```
3. Update the task with notes:
   ```bash
   bd update <task-id> --notes "Blocked: <reason>. WIP on branch <branch-name>."
   ```
4. Create follow-up issues for discovered work:
   ```bash
   bd create --parent <epic-id> --title="<discovered work>" --type=task
   ```
5. Tell the user what happened and what needs to happen next.
