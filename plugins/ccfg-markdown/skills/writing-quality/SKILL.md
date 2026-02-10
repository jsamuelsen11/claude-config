---
name: writing-quality
description:
  This skill should be used when improving documentation clarity, reviewing technical writing
  quality, or ensuring documentation is complete and readable.
version: 0.1.0
---

# Writing Quality Standards

This skill defines standards for technical writing quality, clarity, and completeness. Following
these standards ensures documentation is clear, accurate, and serves its intended audience
effectively.

## Clarity

Write clear, concise prose that communicates efficiently.

### Sentence Structure

```markdown
<!-- CORRECT: Short, direct sentences -->

Run the install command. This creates the project directory and installs dependencies.

<!-- WRONG: Long, convoluted sentence -->

In order to proceed with the installation process, you should run the install command which will
then create the project directory structure and subsequently install all of the required
dependencies that are needed for the application to function properly.
```

### Voice and Tense

```markdown
<!-- CORRECT: Active voice, present tense for instructions -->

Run `npm install` to install dependencies. Create a `.env` file with your configuration. Start the
server with `npm start`.

<!-- WRONG: Passive voice, future tense -->

Dependencies will be installed by running `npm install`. A `.env` file should be created by the
user. The server can be started by using `npm start`.
```

### Clarity Rules

- **Short sentences**: One idea per sentence, one idea per paragraph
- **Active voice**: "Run the command" not "The command should be run"
- **Present tense**: "Run" not "You should run" for instructions
- **Concrete over abstract**: "Returns a JSON object with `id` and `name` fields" not "Returns the
  relevant data"
- **Avoid jargon without definition**: If you must use a technical term, define it on first use or
  link to a glossary
- **Avoid weasel words**: "fast" → "responds in under 100ms", "easy" → "requires 3 commands"

## Technical Accuracy

Ensure all technical content is correct and verifiable.

### Code Examples

**CORRECT** — runnable code with context:

```bash
# Install dependencies
npm install

# Start the development server
npm run dev
# The server starts on http://localhost:3000
```

**WRONG** — vague instructions without runnable commands:

```text
Just install it and run the thing.
```

### Technical Accuracy Rules

- **Code examples must be runnable** — or clearly marked as pseudocode
- **Version numbers must be current** — outdated versions mislead readers
- **Command examples must work** on documented platforms
- **Output examples must match** what the command actually produces
- **Configuration examples must be valid** syntax for the format (YAML, JSON, TOML)
- **File paths must be correct** relative to the documented working directory

## Audience Awareness

Match detail level and tone to the intended audience.

### Documentation Types by Audience

```text
User Guide:
  - Task-oriented ("How to deploy your first app")
  - Minimal internals — focus on what to do, not how it works
  - Prerequisites stated explicitly
  - Step-by-step with expected output at each step

Contributor Guide:
  - Development setup + workflow
  - Architecture overview sufficient to make changes
  - Testing strategy and how to run tests
  - PR process and review expectations

API Reference:
  - Complete and precise — every parameter, every response code
  - Runnable examples for every endpoint
  - Error handling documented exhaustively
  - Machine-readable where possible (OpenAPI spec)

Internal Design Doc:
  - Context and rationale ("why" over "what")
  - Trade-offs discussed explicitly
  - Alternatives considered and rejected
  - Links to ADRs for key decisions
```

### Audience Rules

- **State prerequisites explicitly** — never assume knowledge
- **Match detail to audience** — user guides skip internals, API refs include everything
- **Don't mix audiences** — a getting-started guide shouldn't include architecture deep-dives
- **Provide escape hatches** — link to deeper content for readers who want more detail

## Structure

Organize content for progressive disclosure and scannability.

### Progressive Disclosure

```markdown
<!-- CORRECT: Overview → Quickstart → Detailed Reference -->

## Overview

One-paragraph summary of the feature.

## Quickstart

Minimal steps to get started (3-5 steps maximum).

## Configuration

All options with defaults and descriptions.

## Advanced Usage

Complex scenarios, edge cases, customization.

## Troubleshooting

Common errors and their solutions.
```

### Scannable Content

```markdown
<!-- CORRECT: Bullets for lists, tables for comparisons -->

Supported databases:

- PostgreSQL 14+
- MySQL 8.0+
- SQLite 3.35+

| Database   | Transactions | JSON Support | Full-Text Search |
| ---------- | ------------ | ------------ | ---------------- |
| PostgreSQL | Yes          | Native JSONB | Built-in         |
| MySQL      | Yes          | JSON type    | Plugin           |
| SQLite     | Yes          | JSON1 ext    | FTS5             |
```

```markdown
<!-- WRONG: Wall of text for structured information -->

We support PostgreSQL 14 and above which has transactions and native JSONB support and built-in
full-text search. We also support MySQL 8.0 and above which has transactions and a JSON type and
full-text search via a plugin. We also support SQLite 3.35 and above which has transactions and JSON
support via the JSON1 extension and full-text search via FTS5.
```

### Structure Rules

- **Progressive disclosure**: overview → quickstart → detailed reference
- **Meaningful headings**: Headings should work as scan targets — specific over generic
- **Bullets over paragraphs**: For lists of items, use bullet points
- **Tables for comparisons**: Structured data belongs in tables
- **Code blocks for commands**: Never put commands in prose paragraphs

## Completeness

Ensure documentation covers the full user journey without gaps.

### Completeness Checklist

```text
Prerequisites:
  [ ] All required software listed with versions
  [ ] System requirements documented
  [ ] Account/access requirements stated

Setup:
  [ ] Every step included (no "then just..." gaps)
  [ ] Expected output shown for verification steps
  [ ] Common setup errors documented with solutions

Usage:
  [ ] Basic example that works immediately
  [ ] Common use cases covered with examples
  [ ] Edge cases and non-obvious behavior documented

Error Handling:
  [ ] Common errors documented with causes and fixes
  [ ] Error message → solution mapping provided
  [ ] Debugging steps included

Navigation:
  [ ] Links to related docs from every page
  [ ] No dead-end pages (every page links forward)
  [ ] Table of contents for long documents
```

### Completeness Rules

- **Prerequisites listed**: Every required tool, account, and version
- **All steps included**: No "then just..." gaps — every step explicit
- **Error cases covered**: Common errors with causes and solutions
- **Examples for non-obvious behavior**: Don't rely on readers guessing
- **Links to related docs**: Every page connects to the next logical page
- **No dead-end pages**: Every page links forward to related content or next steps

This comprehensive guide covers writing quality standards that ensure clear, accurate, and complete
technical documentation.
