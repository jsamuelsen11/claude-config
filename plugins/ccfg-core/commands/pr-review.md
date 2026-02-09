---
description: Structured pull request review
argument-hint: <pr-number-or-url>
allowed-tools: Bash(gh:*), Bash(git:*), Read, Grep, Glob, Task
---

# PR Review

Conduct a structured, comprehensive pull request review using a 5-part rubric that evaluates
correctness, security, performance, maintainability, and conventions. Produces actionable feedback
with severity ratings.

## Usage

```bash
/pr-review <pr-number-or-url>
```

Examples:

- `/pr-review 42` - Review PR #42 in current repository
- `/pr-review https://github.com/owner/repo/pull/123` - Review by URL

## Review Process

### Step 1: Fetch PR Details

Retrieve PR metadata and changed files:

```bash
# Get PR information
gh pr view <pr-number> --json title,body,author,commits,files

# Get detailed diff
gh pr diff <pr-number>
```

**Information to Extract:**

- PR title and description
- Author and reviewers
- List of changed files
- Number of additions/deletions
- Linked issues or tasks
- CI/CD status

### Step 2: Check Out Branch

Fetch the PR branch locally for deeper inspection:

```bash
# Check out the PR branch
gh pr checkout <pr-number>

# Verify branch is up to date
git fetch origin
git log --oneline main..HEAD
```

### Step 3: Read Changed Files

Systematically read all modified files to understand the changes:

**File Analysis Strategy:**

1. Start with core logic changes (business logic, algorithms)
2. Review API/interface changes (endpoints, function signatures)
3. Examine tests (coverage, quality, edge cases)
4. Check documentation updates
5. Review configuration changes

Use Glob and Read tools to efficiently navigate changed files.

### Step 4: Apply Review Rubric

Evaluate the PR against 5 quality dimensions:

## Review Rubric

### 1. Correctness

**Does the code do what it claims? Are edge cases handled? Any logic errors?**

**Evaluate:**

- Logic flow matches stated requirements
- Edge cases properly handled (null, empty, boundary values)
- Error handling is comprehensive
- Return values and side effects are correct
- Conditionals and loops terminate correctly
- Off-by-one errors absent

**Common Issues:**

- Incorrect boolean logic
- Missing null/undefined checks
- Race conditions in async code
- Incorrect algorithm implementation
- Missing error propagation

### 2. Security

**Are there injection vectors, auth issues, secret exposure, or OWASP top 10 vulnerabilities?**

**Evaluate:**

- Input validation and sanitization
- Authentication and authorization checks
- SQL injection prevention (parameterized queries)
- XSS prevention (output encoding)
- CSRF protection present
- Secrets not hardcoded
- Dependency vulnerabilities
- Rate limiting on sensitive endpoints
- Proper session management
- File upload restrictions

**Common Issues:**

- User input used in queries without sanitization
- Missing authentication checks
- API keys or tokens in code
- Insecure random number generation
- Unvalidated redirects
- Missing access control checks

### 3. Performance

**Are there N+1 queries, unnecessary allocations, missing indexes, or O(n²) algorithms?**

**Evaluate:**

- Database query efficiency (N+1 problems, missing indexes)
- Algorithm complexity (prefer O(n) over O(n²))
- Unnecessary loops or iterations
- Memory allocations and garbage collection pressure
- Caching opportunities
- Lazy loading vs eager loading decisions
- Bundle size impact (frontend)
- Network request batching

**Common Issues:**

- Queries inside loops (N+1)
- Missing database indexes
- Loading entire collections when pagination needed
- Inefficient sorting or searching
- Unnecessary re-renders (frontend)
- Large bundle imports when tree-shaking possible

### 4. Maintainability

**Is the code clear, well-abstracted, tested, and DRY?**

**Evaluate:**

- Variable and function names are descriptive
- Functions have single, clear purpose
- Code is DRY (no duplication)
- Appropriate abstractions (not over-engineered)
- Test coverage is comprehensive
- Comments explain "why" not "what"
- Module organization is logical
- Dependencies are minimal and justified

**Common Issues:**

- Unclear or misleading names
- God functions doing too much
- Copy-pasted code blocks
- Over-abstraction or premature optimization
- Missing tests for critical paths
- Commented-out code
- Deep nesting (> 3 levels)

### 5. Conventions

**Does it follow project rules? Lint clean? Commit style?**

**Evaluate:**

- Linting rules followed
- Code style matches project
- Commit messages follow convention
- Branch naming correct
- PR description complete
- Breaking changes documented
- Migration scripts included if needed
- Documentation updated

**Common Issues:**

- Linting errors present
- Inconsistent formatting
- Poor commit messages
- Missing documentation updates
- Breaking changes not flagged
- Missing schema migrations

## Output Format

Produce a structured markdown report with findings organized by severity:

```markdown
# PR Review: <PR Title>

**PR:** #<number> **Author:** @<username> **Files Changed:** <count>
**Lines:** +<additions> -<deletions>

## Summary

<1-2 sentence overall assessment>

## Findings

### BLOCKER Issues (Must fix before merge)

#### [BLOCKER] <Category>: <Brief Title>

**File:** `path/to/file.ts:42`

**Issue:** <Clear description of the problem>

**Impact:** <What could go wrong if not fixed>

**Remediation:** <Specific steps to fix>

---

### WARNING Issues (Should fix, creates risk)

#### [WARNING] <Category>: <Brief Title>

**File:** `path/to/file.ts:78`

**Issue:** <Description>

**Impact:** <Potential consequences>

**Remediation:** <How to address>

---

### NIT Issues (Suggestions, non-blocking)

#### [NIT] <Category>: <Brief Title>

**File:** `path/to/file.ts:120`

**Suggestion:** <Improvement recommendation>

---

## Positive Observations

- <Well-done aspect 1>
- <Well-done aspect 2>
- <Well-done aspect 3>

## Recommendation

- [ ] **APPROVE** - Ready to merge
- [ ] **APPROVE with NITS** - Can merge, address suggestions in follow-up
- [ ] **REQUEST CHANGES** - Must address warnings/blockers before merge
- [ ] **NEEDS DISCUSSION** - Architectural concerns require team input

## Additional Notes

<Any context, questions, or discussion points>
```

### Severity Definitions

**BLOCKER:**

- Security vulnerabilities
- Data loss or corruption risks
- Critical logic errors
- Breaking changes without migration path
- Must be fixed before merge

**WARNING:**

- Performance issues affecting user experience
- Missing important test coverage
- Code maintainability concerns
- Incomplete error handling
- Should be fixed but not blocking

**NIT:**

- Style inconsistencies
- Minor refactoring opportunities
- Documentation improvements
- Variable naming suggestions
- Nice to have but not required

## Best Practices

### Review Thoroughly But Kindly

- Focus on the code, not the person
- Provide specific, actionable feedback
- Acknowledge good work and improvements
- Ask questions rather than making demands
- Offer to pair if issues are complex

### Prioritize Issues

- Flag security issues immediately
- Separate critical from nice-to-have
- Consider impact vs effort for each finding
- Don't bikeshed minor style issues

### Provide Context

- Explain why something is a problem
- Link to documentation or examples
- Suggest specific alternatives
- Reference project conventions

### Use the Right Severity

- Don't mark everything as BLOCKER
- Reserve BLOCKER for true merge-blockers
- Use NIT for subjective preferences
- Escalate to team discussion when uncertain

## Automation Checks

Before completing review, verify automated checks:

```bash
# Check CI status
gh pr checks <pr-number>

# View test results
gh pr view <pr-number> --json statusCheckRollup
```

If CI is failing, include status in review report.

## Notes

- Review should be completed within 24 hours when possible
- For large PRs (>500 lines), consider requesting split into smaller PRs
- Use Task tool for complex reviews requiring multiple analysis rounds
- Always check out the branch locally for thorough review
- Test critical changes manually when possible
