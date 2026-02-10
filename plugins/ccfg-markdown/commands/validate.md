---
description: >
  Run Markdown quality gate suite (lint, link validation, frontmatter, structure, code fence
  integrity, doc freshness)
argument-hint: '[--quick]'
allowed-tools: Bash(markdownlint *), Bash(lychee *), Bash(git *), Read, Grep, Glob
---

# validate

Run a comprehensive Markdown quality gate suite to ensure documentation files meet formatting,
linking, and structural standards. This command analyzes repository markdown artifacts to verify
syntax correctness, link integrity, and documentation consistency.

## Usage

```bash
ccfg markdown validate                  # Full validation (all gates)
ccfg markdown validate --quick          # Quick mode (lint subset only)
```

## Overview

The validate command runs multiple quality gates in sequence:

1. **Markdown lint**: Heading hierarchy, code fence language tags, line length, list indentation,
   trailing whitespace, blank lines around block elements
2. **Link validation**: Broken internal links (relative paths), anchor references to non-existent
   headings
3. **Frontmatter validation**: YAML syntax between `---` markers, required field checks if project
   conventions define them
4. **Structure checks**: Consistent heading style (ATX preferred), table formatting, emphasis
   consistency, image alt text, no bare URLs
5. **Duplicate anchors**: Detect duplicate headings that produce identical GitHub anchors (WARN
   level)
6. **Code fence integrity**: Unclosed fences, misindented fences in lists, mixed shell prompt styles
7. **Doc freshness** (advisory): Validate ISO 8601 format for `Last updated:` lines
8. Report pass/fail for each gate with output

All gates must pass for validation to succeed. Quick mode runs a reduced subset for fast iteration.

## Quick Mode (`--quick`)

Quick mode runs only the highest-signal checks:

1. **Markdown lint**: Heading hierarchy + code fence language tags + line length only
2. **External links**: Print `External links: SKIPPED (requires --live and explicit confirmation)`
3. Report pass/fail — skips link validation, frontmatter, structure, duplicate anchors, code fence
   integrity, and doc freshness

Quick mode completes in seconds rather than scanning the full documentation tree.

## Key Rules

### Repository-Only by Default

Validation operates exclusively on repository artifacts — markdown files in the repository. External
link validation requires the `--live` flag and explicit user confirmation before any network
request.

```text
DEFAULT behavior:
  - Scan markdown files in the repository
  - Check internal links and anchors
  - Verify formatting and structure
  - NEVER make network requests without --live flag and user confirmation
```

When external links are not checked, always print:

```text
External links: SKIPPED (requires --live and explicit confirmation)
```

### Detect and Skip

If no markdown files are detected in the repository, skip validation gracefully. Never fail
validation on a project with no markdown content.

If a check requires a tool that is not available (markdownlint-cli2, lychee), skip that gate and
report it as SKIPPED. Suggest installing the missing tool.

### Never Suggest Disabling Lint Rules

When a check fails, suggest how to fix the root cause. Never suggest disabling or skipping a lint
rule as a fix.

### Conventions Document

Check for markdown conventions documentation at standard locations:

```text
docs/markdown-conventions.md
docs/writing-guide.md
.markdownlint.json
.markdownlint-cli2.jsonc
```

If a markdownlint config is found, those rules take precedence over defaults. Reports SKIPPED if no
`docs/` directory exists — never fails on missing documentation structure.

## Step-by-Step Process

### 0. Markdown File Discovery

Before running any gates, discover markdown files in the repository.

```bash
git ls-files --cached --others --exclude-standard -- '*.md' '**/*.md' | head -100
```

If no markdown files are found, report and skip:

```text
No markdown files detected in repository.
Skipping markdown validation.
```

### 1. Markdown Lint Gate

Verify all markdown files follow formatting best practices.

**Tool detection**: Check if `markdownlint-cli2` or `markdownlint` is available:

```bash
command -v markdownlint-cli2 >/dev/null 2>&1 || command -v markdownlint >/dev/null 2>&1
```

If available, invoke and parse output. If missing, use heuristic checks and suggest installing
markdownlint-cli2.

**Heuristic checks** (always available):

- Heading hierarchy: no skipped levels (`###` after `#` is a violation)
- Code fence language tags: all fenced code blocks must specify a language
- Line length: 100 characters default (configurable via markdownlint config)
- Consistent list indentation
- No trailing whitespace
- Blank lines around headings, lists, code blocks, and tables

**Quick mode**: Heading hierarchy + code fence language tags + line length only.

**Success output**:

```text
[1/8] Markdown Lint
  -> Scanning: 15 markdown files
  OK: Heading hierarchy correct in all files
  OK: All code fences specify language tags
  OK: Line length within limits (100 chars)
  OK: Consistent list indentation
  OK: No trailing whitespace
  OK: Blank lines around block elements
  PASS
```

**Failure output**:

```text
[1/8] Markdown Lint
  -> Scanning: 15 markdown files
  FAIL: 2 files have heading hierarchy violations
    - docs/setup.md:15 ### after # (skipped ##)
    - README.md:42 #### after ## (skipped ###)
  WARN: 3 code fences missing language tags
    - docs/api.md:25
    - docs/api.md:58
    - CONTRIBUTING.md:12
  FAIL (2 errors, 3 warnings)
```

### 2. Link Validation Gate

Check for broken internal links and anchor references.

**Skip in quick mode**: This gate only runs in full mode.

**Internal links**: Check that relative paths point to files that exist:

```bash
# Extract markdown links from files
grep -rn '\[.*\](\.\.*/.*\.md)' docs/ README.md CONTRIBUTING.md 2>/dev/null
```

**Anchor references**: Check that `#heading` anchors match actual headings in the target file.

**External links**: Always print the status line:

```text
External links: SKIPPED (requires --live and explicit confirmation)
```

With `--live` flag and user confirmation:

```text
External links: PASSED (42 links checked)
```

or:

```text
External links: FAILED (3 broken links)
  - docs/setup.md:10 https://example.com/old-page (404 Not Found)
```

**Success output**:

```text
[2/8] Link Validation
  -> Checking: 28 internal links, 15 anchor references
  OK: All internal links resolve to existing files
  OK: All anchor references match existing headings
  External links: SKIPPED (requires --live and explicit confirmation)
  PASS
```

### 3. Frontmatter Validation Gate

If frontmatter is detected (YAML between `---` markers), validate YAML syntax.

**Skip in quick mode**: This gate only runs in full mode.

```text
[3/8] Frontmatter Validation
  -> Scanning: 5 files with frontmatter
  OK: Valid YAML syntax in all frontmatter blocks
  OK: Required fields present (if project conventions define them)
  PASS
```

### 4. Structure Checks Gate

Check for consistent formatting patterns across all markdown files.

**Skip in quick mode**: This gate only runs in full mode.

**Checks**:

- Consistent heading style (ATX `#` preferred over setext)
- Table formatting (aligned pipes, header separator row)
- Consistent emphasis style (`*italic*` and `**bold**` not mixed with `_` and `__`)
- Image alt text presence
- No bare URLs in prose (use `[text](url)` or `<url>`)

```text
[4/8] Structure Checks
  -> Scanning: 15 markdown files
  OK: Consistent ATX heading style
  OK: Tables properly formatted
  OK: Consistent emphasis style
  OK: All images have alt text
  OK: No bare URLs in prose
  PASS
```

### 5. Duplicate Anchors Gate

Detect duplicate headings that produce identical GitHub-flavored markdown anchors.

**Skip in quick mode**: This gate only runs in full mode.

This is a WARN-level gate — duplicate headings are syntactically valid and common in structured
docs. The real breakage is explicit anchor links to ambiguous anchors, which is caught
compositionally by the link validation gate.

```text
[5/8] Duplicate Anchors
  -> Scanning: 15 markdown files
  WARN: 2 files have duplicate headings
    - docs/api.md: "Usage" at lines 25, 58
    - docs/config.md: "Examples" at lines 30, 72
  Note: Duplicate headings are valid but produce ambiguous #anchors
  PASS (warnings only)
```

### 6. Code Fence Integrity Gate

Check for code fence rendering issues.

**Skip in quick mode**: This gate only runs in full mode.

**Checks**:

1. Unclosed code fences (odd number of triple-backtick lines)
2. Code fences indented inside list items where indentation breaks rendering
3. Mixed shell prompts (`$` prefixed lines with bare commands in the same block)

All checks are local and deterministic — no external tools required.

```text
[6/8] Code Fence Integrity
  -> Scanning: 15 markdown files
  OK: All code fences properly closed
  OK: Code fences in lists correctly indented
  WARN: 1 code block mixes shell prompts with bare commands
    - docs/setup.md:45 (copy-paste hazard)
  PASS (warnings only)
```

### 7. Doc Freshness Gate (Advisory)

If a markdown file contains a `Last updated:` line (case-insensitive), validate the date format.

**Skip in quick mode**: This gate only runs in full mode.

```text
[7/8] Doc Freshness
  -> Scanning: 15 markdown files
  OK: docs/setup.md — Last updated: 2026-01-15
  FAIL: docs/api.md — Last updated: January 15, 2026 (use YYYY-MM-DD format)
  SKIP: README.md — No "Last updated" line found
  SKIP: 12 files — No "Last updated" line found
  FAIL (1 error)
```

### 8. Report

Compile results from all gates into a final report.

## Final Report Format

### Full Mode Report

```text
Markdown Validation Report
==========================

Project: my-application
Mode: Full
Date: 2026-01-15T14:30:00Z
Files scanned: 15 markdown files

[1/8] Markdown Lint .................. PASS
[2/8] Link Validation ............... PASS
[3/8] Frontmatter Validation ........ PASS
[4/8] Structure Checks .............. PASS
[5/8] Duplicate Anchors ............. PASS (warnings only)
[6/8] Code Fence Integrity .......... PASS
[7/8] Doc Freshness ................. SKIP (no files use this convention)
[8/8] Report ........................ COMPLETE

Summary:
  Errors:   0
  Warnings: 2
  Status:   PASS

All markdown quality gates passed!
```

### Quick Mode Report

```text
Markdown Validation Report
==========================

Project: my-application
Mode: Quick
Date: 2026-01-15T14:30:00Z
Files scanned: 15 markdown files

[1/3] Markdown Lint (quick) ......... PASS
[2/3] External Links ................ SKIPPED (requires --live and explicit confirmation)
[3/3] Report ........................ COMPLETE

Summary:
  Errors:   0
  Warnings: 0
  Status:   PASS

Quick mode validates essential formatting only.
Run 'ccfg markdown validate' (full mode) for comprehensive checks.
```

## Exit Behavior

```text
All gates pass:              Exit with success message, no errors
Any gate has warnings only:  Exit with success message, list warnings
Any gate has errors:         Exit with failure message, list all errors and warnings
No markdown files detected:  Exit with informational message, no errors
```
