# Plugin: ccfg-markdown

The Markdown tooling plugin. Provides markdown syntax and documentation architecture agents,
markdown validation, documentation scaffolding, and opinionated conventions for consistent
documentation across projects. Focuses on markdown formatting, link integrity, documentation
structure patterns (README, ADR, changelog), and technical writing quality. Safety is
straightforward — operates on repo files only, never makes network requests without explicit user
confirmation.

## Directory Structure

```text
plugins/ccfg-markdown/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── markdown-specialist.md
│   └── documentation-architect.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── docs-map.md
└── skills/
    ├── markdown-conventions/
    │   └── SKILL.md
    ├── documentation-patterns/
    │   └── SKILL.md
    └── writing-quality/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-markdown",
  "description": "Markdown tooling plugin: syntax and documentation architecture agents, markdown validation, documentation scaffolding, and conventions for consistent documentation",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["markdown", "documentation", "readme", "adr", "changelog", "technical-writing"],
  "suggestedPermissions": {
    "allow": ["Bash(npx markdownlint:*)"]
  }
}
```

## Agents (2)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                     | Role                                                                          | Model  |
| ------------------------- | ----------------------------------------------------------------------------- | ------ |
| `markdown-specialist`     | Markdown/GFM syntax, frontmatter, linting rules, formatting, link validation  | sonnet |
| `documentation-architect` | Doc structure, README patterns, ADR templates, API docs, changelog, info arch | sonnet |

No coverage command — documentation doesn't have a meaningful coverage concept. This is intentional
and differs from language plugins.

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-markdown:validate

**Purpose**: Run the full Markdown quality gate suite in one command.

**Trigger**: User invokes before committing documentation changes or reviewing markdown files.

**Allowed tools**: `Bash(markdownlint *), Bash(lychee *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Markdown lint**: markdownlint-aware if available; otherwise heuristic checks — heading
   hierarchy (no skipped levels), line length (MD013), code fence language tags (MD040), consistent
   list indentation, no trailing whitespace, proper blank lines around headings/lists/code blocks
2. **Link validation**: check for broken internal links (relative paths to files that don't exist),
   anchor references to headings that don't exist. External link checking requires `--live` flag and
   explicit user confirmation. Always print a status line:
   `External links: SKIPPED (requires --live and explicit confirmation)` when not running live, or
   `External links: PASSED` / `External links: FAILED` when running with `--live`
3. **Frontmatter validation**: if frontmatter detected (YAML between `---` markers), validate YAML
   syntax. Check for required fields if project conventions define them
4. **Structure checks**: consistent heading style (ATX preferred), table formatting, consistent
   emphasis style, image alt text presence, no bare URLs (use `[text](url)` or `<url>`)
5. **Duplicate anchors**: detect duplicate headings within a file that would produce identical
   anchors in GitHub-flavored markdown rendering. WARN level — duplicate headings are syntactically
   valid and common in structured docs (e.g., repeated "Usage" subsections under different parents);
   the real breakage is explicit anchor links to `#heading` that become ambiguous, which is caught
   compositionally by the internal link gate. Report duplicates with file path and line numbers
6. **Code fence integrity**: check for unclosed code fences (odd number of triple-backtick lines),
   code fences indented inside list items where indentation breaks rendering (fence must be indented
   to list content level), and optionally WARN on mixing shell prompts (`$` prefixed lines) with
   bare commands in the same fenced block (copy-paste hazard). All checks are local and
   deterministic — no external tools required
7. **Doc freshness** (optional): if a markdown file contains a `Last updated:` line
   (case-insensitive), validate that the date is in ISO 8601 format (`YYYY-MM-DD`). If no such line
   is present, report SKIPPED for that file — never fails repos that don't use this convention.
   Advisory only
8. Report pass/fail for each gate with output
9. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Markdown lint**: Heading hierarchy + code fence language tags + line length only
2. **External links**: Print `External links: SKIPPED (requires --live and explicit confirmation)` —
   always visible in quick output summary
3. Report pass/fail — skips link validation, frontmatter validation, structure checks, duplicate
   anchors, code fence integrity, and doc freshness for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full documentation tree.

**Key rules**:

- Source of truth: repo artifacts only — markdown files in the repository. External link validation
  requires the `--live` flag and explicit user confirmation before any network request
- Never suggests disabling lint rules as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available, skip that gate and report it as
  SKIPPED. Suggest installing the missing tool
- markdownlint detection: if available, invoke and parse output; if missing, use built-in heuristic
  checks and suggest installing markdownlint-cli2
- Optional tooling (detect-and-skip): markdownlint-cli2 (markdown lint), lychee or
  markdown-link-check (link validation). If not installed, use heuristic checks for the
  corresponding gate and suggest the missing tool in output
- Checks for presence of conventions document (`docs/markdown-conventions.md` or similar). Reports
  SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-markdown:scaffold

**Purpose**: Initialize documentation structure and templates for projects.

**Trigger**: User invokes when setting up documentation in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=readme|adr|api-docs|changelog|contributing]`

**Behavior**:

**readme** (default):

1. Detect project type from project files (language, framework, CLI vs library vs service)
2. Generate structured README.md: title, badges placeholder, description, prerequisites,
   installation, usage, configuration, development, testing, contributing reference, license
3. Sections ordered by reader need (what is this → how to use it → how to contribute)
4. Include table of contents for documents with > 4 sections

**adr**:

1. Generate ADR directory and template in `<doc-root>/adr/` (or existing ADR directory if present)
2. Template follows MADR format: title, status, context, decision, consequences, alternatives
3. Include ADR index file (`docs/adr/README.md`) linking all decision records

**api-docs**:

1. Detect API framework from project files (Express, FastAPI, Spring, Gin, etc.)
2. Generate API documentation structure: authentication, endpoints, request/response formats, error
   codes, rate limiting
3. Include example request/response blocks with placeholder data

**changelog**:

1. Generate CHANGELOG.md following Keep a Changelog format
2. Include category headers: Added, Changed, Deprecated, Removed, Fixed, Security
3. Include Unreleased section and version template with dates

**contributing**:

1. Generate CONTRIBUTING.md: getting started, development setup, coding standards reference, PR
   process, issue reporting, code of conduct reference
2. Detect project tooling to include relevant setup commands (npm install, pip install, etc.)

**Key rules**:

- Project type detection is best-effort — never prescribe a stack, respect what the project already
  uses
- Never overwrites existing files — check first, skip with notice if present
- Generated docs use project-specific names and paths where detectable
- Docs root detection: check for `docs/`, `doc/`, `documentation/` (in that order); use the first
  match as the doc root for all generated output. If none exists, use `docs/` as the default for new
  projects. All scaffold types respect this detected root (e.g., ADR goes to `<doc-root>/adr/`, not
  hardcoded `docs/adr/`)
- Scaffold recommends creating conventions at `<doc-root>/markdown-conventions.md`. If the doc root
  directory exists, scaffold offers to create it. If no doc root structure exists, skip and note in
  output

### /ccfg-markdown:docs-map

**Purpose**: Generate or update a living documentation index for the repository.

**Trigger**: User invokes when documentation has grown organically and needs a navigable entry
point.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob, Grep`

**Argument**: `[--update]`

**Behavior**:

1. Detect the repo's documentation root — check for `docs/`, `doc/`, `documentation/` in order; fall
   back to repo root if none exists
2. Generate (or update) an index file at the detected doc root (e.g., `docs/README.md`)
3. Index contents: "Start here" section (1-2 sentence project summary + link to root README), table
   of contents listing all markdown files in the doc tree, quick links to key documents (README,
   setup/getting-started, architecture/design, ADR index, API docs, CONTRIBUTING, CHANGELOG) — omit
   any that don't exist
4. `--update` mode: if the index already exists, update the table of contents section in-place
   (preserving any hand-written sections outside the generated block). Use marker comments
   (`<!-- docs-map:start -->` / `<!-- docs-map:end -->`) to delimit the managed section

**Key rules**:

- Never overwrites hand-written content — managed sections use HTML comment markers
- If the index file exists without markers, skip with guidance on how to add markers for future
  updates
- No network access
- File discovery via `Glob` — deterministic, no external tools required

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### markdown-conventions

**Trigger description**: "This skill should be used when working with Markdown, writing
documentation, formatting markdown files, or reviewing markdown content."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses setext headings, a non-standard line length, or different list indentation, follow it.
If the project has a `.markdownlint.json` or `.markdownlint-cli2.jsonc` config, those rules take
precedence. These preferences apply to new markdown and scaffold output only.

**GFM syntax rules**:

- Use ATX headings (`#`), proper hierarchy (no skipped levels — `##` after `#`, never `###` after
  `#`)
- Blank lines around block elements: headings, lists, code blocks, tables, blockquotes
- Code fences: always specify language tag (`python`, `bash`, `json`, `text` for plain output), use
  triple backtick, consistent fence style throughout the project
- Links: prefer reference-style `[text][ref]` for links used more than once, relative paths for
  internal links (`./docs/setup.md`), meaningful link text in narrative documentation (never "click
  here", prefer descriptive text over bare URLs). Bare `<url>` syntax is acceptable in dedicated
  "References" or "Links" sections but should not appear inline in explanatory prose
- Lists: consistent indentation (2 or 4 spaces — match project convention), blank lines around
  lists, limit nesting to 3 levels
- Line length: 100 characters default, respect project's markdownlint config if present
- Frontmatter: YAML between `---` markers, lowercase keys, consistent field ordering
- Tables: aligned pipes for readability, header separator row, consistent column alignment markers

### documentation-patterns

**Trigger description**: "This skill should be used when creating or structuring documentation,
writing READMEs, designing documentation architecture, or organizing project documentation."

**Contents**:

- **README structure**: title, badges, one-sentence description, table of contents (for > 4
  sections), installation, usage with examples, API reference (for libraries), contributing link,
  license. Order by reader need: what → how → contribute
- **ADR (Architecture Decision Records)**: MADR format, sequential numbering (`0001-*`, `0002-*`),
  status tracking (proposed → accepted → deprecated/superseded), cross-reference related decisions,
  store in `docs/adr/`
- **Changelog**: Keep a Changelog format, version headers with dates (`## [1.2.0] - 2026-01-15`),
  categorized entries (Added, Changed, Deprecated, Removed, Fixed, Security), link to diff between
  versions, Unreleased section at top
- **API docs**: endpoint → method → params → response → errors pattern, include runnable examples
  with curl/httpie, status code table, authentication section first, rate limiting documented
- **File organization**: `docs/` for project docs, `docs/adr/` for decisions, `docs/api/` for API
  docs, CONTRIBUTING.md and CHANGELOG.md at repo root, README.md at root and in significant
  subdirectories

### writing-quality

**Trigger description**: "This skill should be used when improving documentation clarity, reviewing
technical writing quality, or ensuring documentation is complete and readable."

**Contents**:

- **Clarity**: short sentences, active voice, present tense for instructions ("Run" not "You should
  run"), one idea per paragraph, concrete over abstract, avoid jargon without definition
- **Technical accuracy**: code examples must be runnable (or clearly marked as pseudocode), version
  numbers must be current, command examples must work on documented platforms, screenshots must
  match current UI
- **Audience awareness**: match detail level to audience — user guide (task-oriented, minimal
  internals), contributor guide (setup + workflow), API reference (complete, precise), internal
  design doc (context + rationale). State prerequisites explicitly, don't assume knowledge
- **Structure**: progressive disclosure (overview → quickstart → detailed reference), meaningful
  headings that work as scan targets, scannable content — use bullets over paragraphs for lists of
  items, tables for structured comparisons, code blocks for commands and output
- **Completeness**: prerequisites listed, all steps included (no "then just..." gaps), error cases
  covered, examples for non-obvious behavior, links to related docs, no dead-end pages (every page
  links forward)
