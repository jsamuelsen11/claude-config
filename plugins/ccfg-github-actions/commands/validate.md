---
description: >
  Run GitHub Actions workflow quality gate suite (syntax validation, action pinning, token
  permissions, secret hygiene, antipattern detection)
argument-hint: '[--quick]'
allowed-tools: Bash(actionlint *), Bash(git *), Read, Grep, Glob
---

# validate

Comprehensive quality gate validation for GitHub Actions workflows. Analyzes workflow files in
`.github/workflows/` for syntax correctness, security vulnerabilities, permission hygiene, secret
handling, and common antipatterns. Provides actionable feedback with pass/fail status for each gate.

## Usage

Full validation suite:

```bash
/ccfg-github-actions validate
```

Quick validation (syntax + action pinning only):

```bash
/ccfg-github-actions validate --quick
```

## Overview

The validate command implements a multi-gate quality assurance system for GitHub Actions workflows:

### Full Mode Gates

1. **Workflow Syntax Validation**
   - Uses `actionlint` if available (detect and use)
   - Falls back to YAML structure validation
   - Validates triggers, job/step naming, expression syntax
   - Checks runner specifications and job dependencies
   - Verifies step command structure

2. **Action Pinning Enforcement**
   - Third-party actions must use SHA pinning (owner/action@{40-char-sha})
   - First-party actions (actions/\*) may use version tags (@v4)
   - Detects unpinned or tag-only third-party actions
   - Flags security risk of mutable references

3. **Token Permissions Hardening**
   - Verifies explicit `permissions:` blocks exist
   - Detects overly broad permissions (write-all)
   - Flags GITHUB_TOKEN in echo/print statements
   - Ensures least privilege principle
   - Checks both workflow and job-level permissions

4. **Secret Hygiene Validation**
   - No secrets in run: echo/print/cat commands
   - No secrets as direct CLI arguments
   - Proper environment: gating for deployment workflows
   - Validates secret reference patterns

5. **Antipattern Detection**
   - Uses `zizmor` if available (detect and use)
   - continue-on-error without justification comments
   - Missing timeout-minutes on jobs
   - pull_request_target with PR head checkout (code injection risk)
   - Hardcoded runner versions
   - Missing concurrency controls on PR workflows
   - Secrets in artifact uploads
   - Missing if: checks on dangerous operations

### Quick Mode Gates

- Workflow Syntax Validation only
- Action Pinning Enforcement only

Quick mode is useful for rapid pre-commit checks or CI environments where full validation would be
too slow.

## Key Rules

### Source of Truth

- Analyze `.github/workflows/*.yml` and `.github/workflows/*.yaml` files only
- Do NOT query GitHub API by default (repository files are authoritative)
- Only suggest API queries if workflows directory is missing or empty

### Tool Detection

- Detect `actionlint` availability with `command -v actionlint`
- Detect `zizmor` availability with `command -v zizmor`
- Gracefully degrade if tools unavailable
- Never fail validation due to missing optional tools
- Report tool availability in validation output

### Safety Requirements

- Never suggest disabling security checks
- Never recommend ignoring security warnings
- Always flag security issues as FAIL, not WARN
- Provide remediation guidance for each failure

### Convention Support

- Check for conventions document at `docs/infra/github-actions-conventions.md`
- If found, incorporate documented standards into validation
- Cross-reference convention violations in output
- Suggest creating conventions doc if missing

### Exclusion Comments

Support inline exclusion for specific checks:

```yaml
# ccfg-validate: ignore action-pinning
uses: actions/checkout@v4

# ccfg-validate: ignore continue-on-error
continue-on-error: true # Required for optional test suite
```

## Step-by-Step Process

### Phase 1: Environment Setup

#### Step 1.1: Verify Git Repository

```bash
git rev-parse --git-dir
```

If not a git repository, report and exit with guidance.

#### Step 1.2: Parse Arguments

Check for `--quick` flag:

- Present: Enable quick mode (gates 1-2 only)
- Absent: Enable full mode (gates 1-5)

#### Step 1.3: Detect Available Tools

Check for actionlint:

```bash
command -v actionlint >/dev/null 2>&1 && echo "available" || echo "unavailable"
```

Check for zizmor:

```bash
command -v zizmor >/dev/null 2>&1 && echo "available" || echo "unavailable"
```

Store tool availability state for later use.

#### Step 1.4: Discover Workflows Directory

Use Glob to find workflow files:

```text
pattern: .github/workflows/*.yml
pattern: .github/workflows/*.yaml
```

If no workflows found:

- Check if `.github/workflows/` exists
- Report finding (empty directory vs. missing directory)
- Exit with appropriate message

#### Step 1.5: Check for Conventions Document

Use Glob to check:

```text
pattern: docs/infra/github-actions-conventions.md
```

If found, read and parse conventions for:

- Required permissions patterns
- Approved action versions
- Organization-specific rules
- Timeout defaults

### Phase 2: Workflow Discovery and Preparation

#### Step 2.1: List All Workflow Files

Use Glob result from Step 1.4 to enumerate workflows.

#### Step 2.2: Read Workflow Contents

For each workflow file, use Read tool to load full content.

#### Step 2.3: Initialize Results Structure

Create per-workflow and aggregate tracking:

```json
{
  "workflow_name": {
    "path": ".github/workflows/ci.yml",
    "gates": {
      "syntax": { "status": "pending", "issues": [] },
      "action_pinning": { "status": "pending", "issues": [] },
      "token_permissions": { "status": "pending", "issues": [] },
      "secret_hygiene": { "status": "pending", "issues": [] },
      "antipatterns": { "status": "pending", "issues": [] }
    }
  }
}
```

### Phase 3: Gate 1 - Workflow Syntax Validation

#### Step 3.1: Choose Validation Method

If actionlint available:

- Use actionlint for comprehensive validation
- Parse structured output

If actionlint unavailable:

- Use manual YAML validation
- Implement common checks

#### Step 3.2a: ActionLint Validation (if available)

Run actionlint on each workflow:

```bash
actionlint -format '{{json .}}' .github/workflows/ci.yml
```

Parse JSON output for:

- Error messages
- Line numbers
- Severity levels
- Check categories

Convert to standardized issue format:

```json
{
  "line": 15,
  "column": 3,
  "severity": "error",
  "message": "property \"job\" not defined",
  "check": "syntax"
}
```

#### Step 3.2b: Manual YAML Validation (if actionlint unavailable)

Perform basic structure checks using Grep and Read:

Check for valid trigger definitions:

```bash
grep -E "^on:" .github/workflows/ci.yml
```

Validate job structure:

```bash
grep -E "^jobs:" .github/workflows/ci.yml
```

Check for runner specifications:

```text
pattern: runs-on:
```

Look for common syntax errors:

- Missing colons after keys
- Invalid indentation (non-multiple of 2 spaces)
- Unclosed quotes in expressions
- Invalid expression syntax: `${{ }}` structure

Check runner specifications:

```text
pattern: runs-on:\s*$
```

Flag empty runs-on as error.

Validate runner names:

```text
pattern: runs-on:\s+(ubuntu-latest|windows-latest|macos-latest|macos-13|macos-14|self-hosted|\[)
```

Check job dependencies:

```text
pattern: needs:\s+\[.*\]
pattern: needs:\s+\w+
```

Validate referenced jobs exist in workflow.

Check for GitHub expression syntax errors:

```text
pattern: \$\{\{\s*[^}]*\}\}
```

Validate expressions don't have:

- Unmatched braces
- Invalid operators
- Undefined contexts (except secrets, vars, inputs which are dynamic)

#### Step 3.3: Validate Trigger Configuration

Check for valid trigger types:

```text
pattern: ^on:\s*$
```

Next line should be trigger name or inline trigger.

Common triggers to validate:

- push, pull_request, workflow_dispatch
- schedule (must have cron syntax)
- release, pull_request_target (flag for review)

Validate pull_request trigger paths:

```yaml
on:
  pull_request:
    paths:
      - '**.js'
      - '!docs/**'
```

Check glob patterns are valid.

#### Step 3.4: Validate Step Structure

Check for steps without name or run/uses:

```text
pattern: ^\s+- name:
pattern: ^\s+- uses:
pattern: ^\s+- run:
```

Every step should have at least name + (run|uses).

Check for invalid step combinations:

```text
pattern: ^\s+uses:.*\n\s+run:
```

A step cannot have both uses and run.

#### Step 3.5: Record Syntax Results

Mark gate as PASS if no errors, FAIL if any error found.

Store all issues with line numbers and descriptions.

### Phase 4: Gate 2 - Action Pinning Enforcement

#### Step 4.1: Extract All Action References

Use Grep to find all action uses:

```text
pattern: uses:\s+(.+)
output_mode: content
```

Parse each match to extract:

- Owner/repo: `owner/action@ref`
- Reference type: SHA, tag, or branch
- Line number

#### Step 4.2: Categorize Actions

For each action:

First-party actions (allowed version tags):

```text
pattern: uses:\s+actions/[^@]+@
```

These may use `@v4`, `@v3`, etc.

Third-party actions (must use SHA):

```text
pattern: uses:\s+(?!actions/)[^/]+/[^@]+@
```

These must use `@{40-hex-char-sha}`.

Local actions (allowed relative paths):

```text
pattern: uses:\s+\./.+
```

#### Step 4.3: Validate Third-Party Action Pinning

For each third-party action, check reference format:

SHA pinning (valid):

```text
pattern: uses:\s+[^/]+/[^@]+@[0-9a-f]{40}
```

Tag or branch reference (invalid):

```text
pattern: uses:\s+(?!actions/)[^/]+/[^@]+@v?\d+
pattern: uses:\s+(?!actions/)[^/]+/[^@]+@main
pattern: uses:\s+(?!actions/)[^/]+/[^@]+@master
```

#### Step 4.4: Check for Exclusion Comments

For each flagged action, check preceding lines for:

```text
pattern: ccfg-validate:\s*ignore\s+action-pinning
```

If found, skip this violation.

#### Step 4.5: Generate Action Pinning Issues

For each unpinned third-party action:

```json
{
  "line": 23,
  "action": "docker/setup-buildx-action@v3",
  "issue": "Third-party action must use SHA pinning, not version tag",
  "remediation": "Pin to commit SHA: docker/setup-buildx-action@8c0edd44fd9d2d25d1f32147d34faabc28ce1b7d",
  "severity": "error"
}
```

Optionally, if git available and network accessible, resolve tag to SHA:

```bash
git ls-remote https://github.com/docker/setup-buildx-action.git refs/tags/v3
```

Parse output to suggest specific SHA.

#### Step 4.6: Record Action Pinning Results

Mark gate as:

- PASS: All third-party actions use SHA pinning
- FAIL: Any third-party action uses tag/branch reference

### Phase 5: Gate 3 - Token Permissions Hardening

#### Step 5.1: Check for Permissions Block

Search for workflow-level permissions:

```text
pattern: ^permissions:
```

Search for job-level permissions:

```text
pattern: ^\s{2}\w+:\s*$\n\s{4}permissions:
```

#### Step 5.2: Validate Permissions Existence

If no permissions block found at workflow or any job level:

```json
{
  "issue": "No explicit permissions: block found",
  "severity": "error",
  "remediation": "Add 'permissions:' block at workflow or job level"
}
```

#### Step 5.3: Check for Overly Broad Permissions

Search for write-all:

```text
pattern: permissions:\s+write-all
```

This is a FAIL condition.

Search for missing read-only default:

```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

Without explicit scoping to needed permissions only.

#### Step 5.4: Validate Permission Scopes

Valid permission scopes:

- actions, checks, contents, deployments, discussions
- id-token, issues, packages, pages, pull-requests
- repository-projects, security-events, statuses

Valid values: read, write, none

Check for invalid scopes:

```text
pattern: permissions:.*\n(\s+\w+:\s+(read|write|none))+
```

Flag any unknown scopes.

#### Step 5.5: Check for GITHUB_TOKEN in Output

Search for token leakage:

```text
pattern: echo.*GITHUB_TOKEN
pattern: print.*GITHUB_TOKEN
pattern: cat.*GITHUB_TOKEN
```

Also check for secrets in echo:

```text
pattern: echo.*\$\{\{\s*secrets\.
```

#### Step 5.6: Validate Context-Appropriate Permissions

For workflows with deployment jobs:

```text
pattern: environment:
```

These should have minimal permissions, id-token for OIDC.

For workflows that create releases:

```text
pattern: release
```

Should have `contents: write` scoped to release job only.

#### Step 5.7: Check for Exclusion Comments

Look for:

```text
pattern: ccfg-validate:\s*ignore\s+permissions
```

#### Step 5.8: Record Token Permissions Results

Mark gate as:

- PASS: Explicit permissions, no write-all, no token leakage
- FAIL: Missing permissions, write-all, or token in output

### Phase 6: Gate 4 - Secret Hygiene Validation

#### Step 6.1: Check for Secrets in Echo/Print

Search for secret exposure:

```text
pattern: run:.*\n.*echo.*\$\{\{\s*secrets\.
pattern: run:.*\n.*print.*\$\{\{\s*secrets\.
pattern: run:.*\n.*printf.*\$\{\{\s*secrets\.
```

Each match is a FAIL.

#### Step 6.2: Check for Secrets as CLI Arguments

Look for patterns like:

```text
pattern: --password\s+\$\{\{\s*secrets\.
pattern: --token\s+\$\{\{\s*secrets\.
pattern: --api-key\s+\$\{\{\s*secrets\.
```

Flag as security risk - prefer environment variables.

#### Step 6.3: Validate Environment Variable Usage

Preferred secret usage:

```yaml
env:
  API_TOKEN: ${{ secrets.API_TOKEN }}
run: |
  ./script.sh
```

Not:

```yaml
run: |
  ./script.sh --token ${{ secrets.API_TOKEN }}
```

#### Step 6.4: Check Deployment Secret Gating

For workflows using deployment secrets:

```text
pattern: environment:
```

Verify secrets are scoped to environment jobs only:

```yaml
jobs:
  deploy:
    environment: production
    steps:
      - env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
```

Not at workflow level.

#### Step 6.5: Check for Secrets in Artifacts

Search for:

```text
pattern: actions/upload-artifact
```

Check subsequent run: steps don't include secret files:

```text
pattern: run:.*\n.*\.env
pattern: run:.*\n.*credentials
```

#### Step 6.6: Check for Exclusion Comments

Look for:

```text
pattern: ccfg-validate:\s*ignore\s+secret-hygiene
```

#### Step 6.7: Record Secret Hygiene Results

Mark gate as:

- PASS: No secret exposure detected
- FAIL: Secrets in output, CLI args, or artifacts

### Phase 7: Gate 5 - Antipattern Detection

#### Step 7.1: Run Zizmor if Available

If zizmor detected in Step 1.3:

```bash
zizmor --format json .github/workflows/
```

Parse JSON output for antipatterns:

- Code injection risks
- Dangerous trigger combinations
- OIDC misconfigurations

Add findings to antipattern results.

#### Step 7.2: Check continue-on-error Usage

Find all continue-on-error:

```text
pattern: continue-on-error:\s*true
```

For each, check for justification comment:

```text
pattern: #.*continue-on-error|#.*optional|#.*allowed to fail
```

Within 2 lines before the continue-on-error.

If no comment, flag as antipattern.

#### Step 7.3: Check for Missing Timeouts

Search for jobs without timeout-minutes:

```text
pattern: ^\s{2}\w+:\s*$\n(?:(?!\s{2}\w+:|\s{4}timeout-minutes:).)*$
```

This regex finds job definitions without timeout-minutes.

Flag each job missing timeout as antipattern:

```json
{
  "job": "test",
  "issue": "Missing timeout-minutes",
  "remediation": "Add 'timeout-minutes: 30' to job definition",
  "severity": "warning"
}
```

#### Step 7.4: Check pull_request_target Safety

Search for pull_request_target:

```text
pattern: pull_request_target:
```

If found, check for dangerous checkout patterns:

```text
pattern: uses:\s+actions/checkout@.*\n.*ref:.*github\.event\.pull_request\.head
```

This is code injection risk - FAIL condition.

Safe pattern should use default or base ref:

```yaml
- uses: actions/checkout@SHA
  # Defaults to base branch - safe
```

#### Step 7.5: Check for Hardcoded Runner Versions

Search for specific Ubuntu versions:

```text
pattern: runs-on:\s+ubuntu-\d{2}\.\d{2}
```

Suggest using ubuntu-latest unless specific version required.

Similarly for:

```text
pattern: runs-on:\s+macos-\d{2}
pattern: runs-on:\s+windows-\d{4}
```

#### Step 7.6: Check Concurrency on PR Workflows

For workflows triggered by pull_request:

```text
pattern: on:.*pull_request
```

Check for concurrency configuration:

```text
pattern: concurrency:
```

If missing, flag as antipattern:

```json
{
  "issue": "PR workflow missing concurrency control",
  "remediation": "Add concurrency group to cancel outdated runs",
  "example": "concurrency:\n  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}\n  cancel-in-progress: true"
}
```

#### Step 7.7: Check for Dangerous Operations Without Conditions

Search for destructive operations:

```text
pattern: run:.*rm -rf
pattern: run:.*drop database
pattern: run:.*terraform destroy
```

Check for if: condition:

```text
pattern: if:\s+github\.event_name\s+==
```

If dangerous operation without condition, flag as antipattern.

#### Step 7.8: Check for Missing Matrix Fail-Fast

For matrix strategies:

```text
pattern: strategy:\s*\n\s+matrix:
```

Check for fail-fast configuration:

```text
pattern: fail-fast:
```

Suggest explicit setting (default is true).

#### Step 7.9: Check for Exclusion Comments

Look for:

```text
pattern: ccfg-validate:\s*ignore\s+antipatterns
```

#### Step 7.10: Record Antipattern Results

Mark gate as:

- PASS: No critical antipatterns detected
- WARN: Minor antipatterns that should be addressed
- FAIL: Critical security antipatterns detected

### Phase 8: Results Aggregation and Reporting

#### Step 8.1: Aggregate Per-Workflow Results

For each workflow, calculate:

- Total issues count
- Critical/error count
- Warning count
- Pass/fail status per gate
- Overall workflow status

#### Step 8.2: Calculate Suite-Level Metrics

Aggregate across all workflows:

- Total workflows analyzed
- Workflows passing all gates
- Workflows with errors
- Workflows with warnings only
- Most common issues

#### Step 8.3: Generate Recommendations

Based on findings, generate:

- Top 3 priority fixes
- Quick wins (easy fixes with high impact)
- Reference to conventions document
- Links to GitHub Actions security best practices

#### Step 8.4: Format Final Report

Use Final Report Format (see section below).

#### Step 8.5: Write Report to Output

Display complete report with:

- Executive summary
- Per-workflow details
- Per-gate details
- Recommendations
- Tool information

### Phase 9: Edge Cases and Special Handling

#### Step 9.1: Reusable Workflows

For workflows with workflow_call:

```text
pattern: on:\s+workflow_call
```

- Validate typed inputs and secrets
- Check for proper output definitions
- Verify caller contracts

#### Step 9.2: Composite Actions

Check for composite action definitions:

```text
pattern: runs:\s+using:\s+composite
```

In `.github/actions/` directory:

- Validate action.yml structure
- Check for shell specifications on run steps
- Verify input/output definitions

#### Step 9.3: Matrix Strategies

For workflows with matrix:

```text
pattern: strategy:\s+matrix:
```

- Validate matrix variable usage
- Check for include/exclude correctness
- Verify matrix variables in expressions

#### Step 9.4: Conditional Execution

For steps/jobs with if:

```text
pattern: if:\s+\$\{\{
```

- Validate expression syntax
- Check for common mistakes (status functions)
- Verify context availability

#### Step 9.5: Service Containers

For jobs with services:

```text
pattern: services:
```

- Validate service definitions
- Check port mappings
- Verify credential handling

#### Step 9.6: Environment Protection

For jobs with environment:

```text
pattern: environment:
```

- Validate environment name
- Check for appropriate permissions
- Verify secret scoping

## Final Report Format

### Success Example (All Gates Pass)

```text
GitHub Actions Validation Report
================================

Suite: PASS
Analyzed: 3 workflows
Duration: 2.3s

Tools Used:
  actionlint: v1.6.27 (available)
  zizmor: v1.2.0 (available)

Workflows:
----------

1. .github/workflows/ci.yml
   Status: PASS

   [PASS] Workflow Syntax (actionlint)
   [PASS] Action Pinning (6 actions checked)
   [PASS] Token Permissions (contents: read)
   [PASS] Secret Hygiene (0 issues)
   [PASS] Antipatterns (zizmor)

2. .github/workflows/release.yml
   Status: PASS

   [PASS] Workflow Syntax (actionlint)
   [PASS] Action Pinning (4 actions checked)
   [PASS] Token Permissions (contents: write - release job only)
   [PASS] Secret Hygiene (0 issues)
   [PASS] Antipatterns (zizmor)

3. .github/workflows/deploy.yml
   Status: PASS

   [PASS] Workflow Syntax (actionlint)
   [PASS] Action Pinning (5 actions checked)
   [PASS] Token Permissions (id-token: write - OIDC)
   [PASS] Secret Hygiene (0 issues)
   [PASS] Antipatterns (zizmor)

Summary:
--------
All workflows passed validation.

Recommendations:
- Consider documenting workflow standards in docs/infra/github-actions-conventions.md
- Keep actionlint and zizmor updated for latest security checks
```

### Failure Example (Multiple Issues)

```text
GitHub Actions Validation Report
================================

Suite: FAIL
Analyzed: 2 workflows
Duration: 1.8s
Errors: 5
Warnings: 3

Tools Used:
  actionlint: not available (install: go install github.com/rhysd/actionlint/cmd/actionlint@latest)
  zizmor: v1.2.0 (available)

Workflows:
----------

1. .github/workflows/ci.yml
   Status: FAIL (3 errors, 2 warnings)

   [FAIL] Workflow Syntax
     Line 15: Invalid expression syntax: ${{ github.event.pull_request.number) }}
              Missing opening brace

     Line 23: Unknown runner: ubuntu-20.04-custom
              Use: ubuntu-latest, ubuntu-22.04, or self-hosted

   [FAIL] Action Pinning (8 actions checked)
     Line 18: docker/setup-buildx-action@v3
              Third-party action must use SHA pinning
              Fix: docker/setup-buildx-action@8c0edd44fd9d2d25d1f32147d34faabc28ce1b7d

     Line 34: aws-actions/configure-aws-credentials@v4
              Third-party action must use SHA pinning
              Fix: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502

   [PASS] Token Permissions
     contents: read (appropriate for CI)

   [WARN] Secret Hygiene
     Line 45: run: echo "Token: ${{ secrets.API_TOKEN }}"
              Never echo secrets to logs
              Fix: Use environment variable and mask in application

   [WARN] Antipatterns
     Line 52: continue-on-error: true
              Missing justification comment
              Add: # ccfg-validate: ignore continue-on-error - optional integration tests

     Missing: concurrency control for PR workflow
              Add: concurrency:
                     group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
                     cancel-in-progress: true

2. .github/workflows/deploy.yml
   Status: FAIL (2 errors, 1 warning)

   [PASS] Workflow Syntax (manual validation)
     Note: Install actionlint for comprehensive checks

   [PASS] Action Pinning (4 actions checked)

   [FAIL] Token Permissions
     Line 10: permissions: write-all
              Overly broad permissions
              Fix: Specify only required permissions:
                   permissions:
                     contents: read
                     id-token: write

   [FAIL] Secret Hygiene
     Line 67: run: aws deploy --secret-key ${{ secrets.AWS_SECRET }}
              Secret passed as CLI argument (visible in process list)
              Fix: Use environment variable:
                   env:
                     AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }}
                   run: aws deploy

   [WARN] Antipatterns (zizmor)
     Line 34: Missing timeout-minutes on deploy job
              Long-running jobs should have timeout
              Add: timeout-minutes: 30

Summary:
--------
5 errors must be fixed before workflows are production-ready.
3 warnings should be addressed to follow best practices.

Priority Fixes:
1. Pin third-party actions to SHA (2 occurrences)
2. Replace write-all with scoped permissions
3. Move secrets from CLI args to environment variables

Quick Wins:
- Add concurrency control to cancel outdated PR runs
- Add justification comments for continue-on-error
- Fix expression syntax in line 15

Conventions:
No conventions document found. Consider creating:
  docs/infra/github-actions-conventions.md

Resources:
- GitHub Actions Security Hardening: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
- Action Pinning: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions
```

### Quick Mode Example

```text
GitHub Actions Validation Report (Quick Mode)
=============================================

Suite: FAIL
Analyzed: 2 workflows
Duration: 0.5s

Note: Quick mode runs syntax and action pinning checks only.
      Run full validation for comprehensive security analysis.

Tools Used:
  actionlint: v1.6.27 (available)

Workflows:
----------

1. .github/workflows/ci.yml
   Status: PASS

   [PASS] Workflow Syntax (actionlint)
   [PASS] Action Pinning (6 actions checked)

2. .github/workflows/deploy.yml
   Status: FAIL (1 error)

   [PASS] Workflow Syntax (actionlint)

   [FAIL] Action Pinning (4 actions checked)
     Line 23: docker/setup-buildx-action@v3
              Third-party action must use SHA pinning

Summary:
--------
1 error found in quick validation.
Run full validation for complete analysis: /ccfg-github-actions validate
```

### No Workflows Example

```text
GitHub Actions Validation Report
================================

Status: NO WORKFLOWS FOUND

The .github/workflows/ directory is empty or does not exist.

To create your first workflow:
  /ccfg-github-actions scaffold --type=ci

Or manually create:
  .github/workflows/ci.yml

Resources:
- GitHub Actions Quickstart: https://docs.github.com/en/actions/quickstart
```

## Implementation Notes

### Performance Considerations

- Use Glob instead of recursive find for file discovery
- Parallelize per-workflow analysis when possible
- Cache Read results if re-reading same file
- Quick mode should complete in < 1 second for typical repos
- Full mode should complete in < 5 seconds for typical repos

### Error Handling

- Gracefully handle malformed YAML (report as syntax error)
- Continue validation if one gate fails
- Aggregate all issues before failing
- Provide specific line numbers for all issues
- Include remediation guidance with every error

### Extensibility

- Support for custom rules via conventions document
- Exclusion comment syntax for exceptions
- Configurable severity levels
- Optional output formats (JSON, SARIF for CI integration)

### Testing Strategy

Validate against known-good and known-bad workflows:

- Valid workflow with all best practices
- Workflow with unpinned actions
- Workflow with write-all permissions
- Workflow with secret leakage
- Workflow with pull_request_target + head checkout
- Reusable workflow
- Composite action definition

## Common Validation Scenarios

### Scenario: Monorepo with Multiple Workflows

Handle large numbers of workflows efficiently:

- Process workflows in batches
- Provide progress indication
- Summarize common issues across workflows
- Suggest shared reusable workflows for common patterns

### Scenario: Migration from Another CI System

When validating newly migrated workflows:

- Check for CI system-specific syntax that needs conversion
- Validate secret references match GitHub format
- Ensure runner labels are GitHub-compatible
- Check for Docker-in-Docker patterns that need adjustment

### Scenario: Fork Repository with Untrusted PRs

Extra scrutiny for workflows accepting PRs:

- Enforce pull_request vs pull_request_target best practices
- Validate all PR-triggered workflows have concurrency
- Check for script injection vulnerabilities
- Ensure no write permissions on PR validation

### Scenario: Organization-Wide Policy Enforcement

Support enterprise requirements:

- Load organization conventions from well-known location
- Enforce required actions (e.g., security scanning)
- Validate OIDC configuration for AWS/Azure/GCP
- Check for required code owners approval on workflow changes
