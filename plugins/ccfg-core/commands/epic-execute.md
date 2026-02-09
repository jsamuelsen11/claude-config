---
description: Execute a beads task with structured workflow
argument-hint: <task-id> (e.g. claude-config-abc.1)
allowed-tools: Bash(git:*), Bash(bd:*), Bash(uv:*), Bash(gh:*), Read, Grep, Glob, Edit, Write, Task
---

# Epic Execute

Execute a beads task using a structured 6-phase workflow that ensures proper planning, execution,
validation, and delivery. This command follows the beads task management methodology and enforces
quality gates throughout the development lifecycle.

## Usage

```bash
/epic-execute $ARGUMENTS
```

Where `$ARGUMENTS` is a task ID like `claude-config-abc.1`.

## Workflow Phases

### Phase 0: Context Recovery

Before making any changes, establish complete context and verify prerequisites:

**Required Context Gathering:**

1. Read `docs/DESIGN.md` to understand architectural decisions and patterns
2. Load the task details using `bd show $ARGUMENTS`
3. Verify all blockers are closed (check `blocked_by` field in task metadata)
4. Read `docs/AGENTS.md` to understand agent responsibilities and protocols
5. Check repository and branch state using `git status` and `git branch`

**Validation Gates:**

- Working directory must be clean (no uncommitted changes)
- Must be on `main` branch before creating feature branch
- All blocking tasks must have status `closed`
- Task must have status `open` or `ready`

**If any validation fails:** STOP immediately and report the issue. Do not proceed to Phase 1.

**Context Recovery Checklist:**

- [ ] DESIGN.md principles loaded
- [ ] Task scope and acceptance criteria understood
- [ ] No unresolved blockers
- [ ] Clean working directory confirmed
- [ ] Currently on main branch
- [ ] Agent protocols reviewed

### Phase 1: Branch Creation and Task Claiming

Prepare the development environment and claim the task:

**Git Operations:**

```bash
# Sync with remote main
git pull --rebase origin main

# Create feature branch with task ID
git checkout -b $ARGUMENTS
```

**Task Management:**

```bash
# Claim the task
bd update $ARGUMENTS --status in_progress

# Sync task state
bd sync
```

**Branch Naming Convention:**

- Use exact task ID as branch name (e.g., `claude-config-abc.1`)
- This enables automatic linking between branches and tasks

**Phase 1 Checklist:**

- [ ] Synced with latest main branch
- [ ] Feature branch created with task ID
- [ ] Task status updated to in_progress
- [ ] Changes synced to remote

### Phase 2: Planning Conversation

Engage in structured planning dialogue with the user before implementation:

**Planning Steps:**

1. **Present Task Scope**
   - Summarize task description and acceptance criteria
   - Highlight key deliverables
   - Note any constraints or dependencies

2. **Identify Underspecified Areas**
   - Flag ambiguous requirements
   - Ask clarifying questions about edge cases
   - Confirm architectural approach
   - Validate assumptions about user needs

3. **Wait for User Answers**
   - Do NOT proceed until all questions are answered
   - Request examples or mockups if needed
   - Confirm understanding of responses

4. **Present Implementation Checklist**
   - Break down work into logical units
   - Estimate complexity of each item
   - Identify risks or technical challenges
   - List files that will be created or modified

5. **Get Explicit Approval**
   - Wait for user confirmation: "Proceed with implementation"
   - If user requests changes, update checklist and re-confirm
   - Document any implementation notes or decisions

**Example Planning Output:**

```markdown
## Task Scope: Implement User Authentication

**Deliverables:**

- JWT token generation and validation
- Login and logout endpoints
- Password hashing with bcrypt
- Session management

**Questions:**

1. Should we support refresh tokens? (affects token expiry strategy)
2. What should the session timeout be?
3. Do we need rate limiting on login attempts?

**Implementation Checklist:**

- [ ] Add JWT and bcrypt dependencies
- [ ] Create auth middleware for token validation
- [ ] Implement POST /api/auth/login endpoint
- [ ] Implement POST /api/auth/logout endpoint
- [ ] Add password hashing utilities
- [ ] Write unit tests for auth functions
- [ ] Write integration tests for endpoints
- [ ] Update API documentation

**Estimated Complexity:** Medium (3-4 hours)

Awaiting approval to proceed...
```

**Phase 2 Checklist:**

- [ ] Task scope presented clearly
- [ ] All ambiguities resolved
- [ ] Implementation checklist created
- [ ] User explicitly approved plan

### Phase 3: Implementation

Execute the approved implementation checklist with discipline and attention to quality:

**Implementation Principles:**

1. **Follow DESIGN.md Decisions**
   - Adhere to established patterns and conventions
   - Use approved libraries and frameworks
   - Respect architectural boundaries

2. **One Logical Change at a Time**
   - Complete one checklist item before moving to next
   - Keep changes focused and cohesive
   - Make incremental commits

3. **Python Tooling with uv**
   - Use `uv run pytest` for tests
   - Use `uv run ruff check` for linting
   - Use `uv run mypy` for type checking
   - Use `uv add <package>` for dependencies

4. **Code Quality Standards**
   - NO `# nolint` or `# noqa` comments
   - Fix linting issues properly
   - Address type errors correctly
   - Write clear, self-documenting code

5. **Commit Strategy**
   - Commit after each logical unit
   - Use conventional commit messages
   - Reference task ID in commits
   - Keep commits atomic and revertible

**Implementation Loop:**

For each checklist item:

1. Implement the change
2. Run relevant tests
3. Fix any issues
4. Commit with descriptive message
5. Update checklist progress
6. Move to next item

**Example Commit Messages:**

```text
feat(auth): add JWT token generation utility

Implements token creation with configurable expiry and payload
signing using HS256 algorithm.

Related: claude-config-abc.1
```

```text
test(auth): add integration tests for login endpoint

Covers successful login, invalid credentials, and rate limiting
scenarios.

Related: claude-config-abc.1
```

**Phase 3 Checklist:**

- [ ] All checklist items completed
- [ ] Code follows DESIGN.md patterns
- [ ] No linting bypasses added
- [ ] Incremental commits made
- [ ] Each commit is atomic and logical

### Phase 4: Validation

Verify the implementation meets all quality and completeness requirements:

**Automated Checks:**

1. **Test Suite**

   ```bash
   uv run pytest
   ```

   - All tests must pass
   - No skipped tests without justification
   - Coverage should meet project standards

2. **Linting**

   ```bash
   uv run ruff check
   ```

   - Zero linting errors
   - Zero linting warnings
   - No suppressions added

3. **Type Checking**

   ```bash
   uv run mypy
   ```

   - Zero type errors
   - Proper type hints added
   - No `type: ignore` without justification

**Manual Verification:**

1. **Task Completeness Checklist**

   Review each acceptance criterion from the original task:
   - [ ] Feature works as specified
   - [ ] Edge cases handled
   - [ ] Error messages are clear
   - [ ] Documentation updated
   - [ ] Examples provided if applicable

2. **Code Review Self-Check**
   - [ ] Clear variable and function names
   - [ ] No duplicated code
   - [ ] Appropriate abstractions
   - [ ] Security considerations addressed
   - [ ] Performance is acceptable

**Final Status Decision:**

- **PASS:** All checks green, ready for PR
- **FAIL:** Document issues and return to Phase 3

If validation fails, fix issues and re-run validation before proceeding to Phase 5.

**Phase 4 Checklist:**

- [ ] All tests passing
- [ ] Linting clean
- [ ] Type checking clean
- [ ] Acceptance criteria met
- [ ] Self-review completed

### Phase 5: PR Creation and Task Closure

Deliver the completed work through a pull request and close the task:

**Push Branch:**

```bash
git push -u origin $ARGUMENTS
```

**Create Pull Request:**

```bash
gh pr create --title "feat: <brief description>" --body "$(cat <<'EOF'
## Summary

<1-3 sentence summary of changes>

## Task Reference

Closes: $ARGUMENTS

## Changes

- <bullet list of key changes>
- <organized by logical area>

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist

- [ ] Tests passing
- [ ] Linting clean
- [ ] Type checking clean
- [ ] Documentation updated

## Related

- Task: $ARGUMENTS
- Design: docs/DESIGN.md

Generated with Claude Code
EOF
)"
```

**Close Task:**

```bash
# Mark task as closed
bd close $ARGUMENTS

# Sync state to remote
bd sync
```

**PR Body Template Guidelines:**

- Keep summary concise and clear
- Link to the task explicitly
- List all significant changes
- Include testing evidence
- Check all quality gates

**Phase 5 Checklist:**

- [ ] Branch pushed to remote
- [ ] PR created with structured body
- [ ] Task closed in beads
- [ ] Changes synced
- [ ] PR URL shared with user

## Abort Protocol

If you need to abort the workflow at any phase:

**Before Branch Creation (Phase 0-1):**

- Simply stop and report the issue
- No cleanup needed

**After Branch Creation (Phase 1+):**

1. **Abandon Changes:**

   ```bash
   git checkout main
   git branch -D $ARGUMENTS
   ```

2. **Release Task:**

   ```bash
   bd update $ARGUMENTS --status open
   bd sync
   ```

3. **Report Reason:**
   - Clearly state why the task was abandoned
   - Document any findings or blockers
   - Update task notes if needed

**Common Abort Scenarios:**

- Discovered blocking dependency during planning
- Technical approach not feasible
- User requested scope change requiring re-planning
- Unresolved architectural questions

## Best Practices

1. **Never Skip Phases**
   - Each phase builds on previous phases
   - Skipping creates quality and process debt
   - If a phase seems unnecessary, discuss with user

2. **Document Decisions**
   - Record important implementation decisions in comments
   - Update docs/DESIGN.md if establishing new patterns
   - Leave clear commit messages for future reference

3. **Communicate Progress**
   - Update user at each phase transition
   - Flag blockers immediately
   - Ask for help when uncertain

4. **Respect Quality Gates**
   - Do not bypass linting or type checking
   - Write tests first for complex logic
   - Validate edge cases thoroughly

5. **Keep Scope Focused**
   - Resist scope creep during implementation
   - Create new tasks for discovered work
   - Link related tasks in comments

## Notes

- This command is designed for beads task management workflow
- Requires `bd` CLI tool to be installed and configured
- Assumes `uv` for Python project tooling
- Requires `gh` CLI for GitHub operations
- All paths should be absolute when interacting with files
