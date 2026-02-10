---
description: >
  Generate or update a living documentation index for the repository
argument-hint: '[--update]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob, Grep
---

# docs-map

Generate or update a living documentation index that serves as a navigable entry point for the
repository's documentation. Discovers all markdown files and creates a structured index at the
documentation root.

## Usage

```bash
ccfg markdown docs-map                  # Generate new documentation index
ccfg markdown docs-map --update         # Update existing index (preserve hand-written sections)
```

## Overview

The docs-map command creates a single entry point for navigating all documentation in the
repository. It discovers markdown files, categorizes them, and generates an index with quick links
and a table of contents.

## Behavior

### Generate Mode (default)

1. Detect the repo's documentation root — check for `docs/`, `doc/`, `documentation/` in order; fall
   back to repo root if none exists
2. Generate an index file at the detected doc root (e.g., `docs/README.md`)
3. Index contents:
   - "Start here" section: 1-2 sentence project summary + link to root README
   - Table of contents listing all markdown files in the doc tree
   - Quick links to key documents (README, setup/getting-started, architecture/design, ADR index,
     API docs, CONTRIBUTING, CHANGELOG) — omit any that don't exist
4. Use marker comments to delimit the managed section:

   ```markdown
   <!-- docs-map:start -->

   ... generated content ...

   <!-- docs-map:end -->
   ```

### Update Mode (`--update`)

1. If the index already exists, update the table of contents section in-place
2. Preserve any hand-written sections outside the `<!-- docs-map:start -->` /
   `<!-- docs-map:end -->` markers
3. If the index file exists without markers, skip with guidance:

   ```text
   docs/README.md exists but has no docs-map markers.
   Add the following markers to enable managed updates:

     <!-- docs-map:start -->
     <!-- docs-map:end -->

   Content between these markers will be managed by docs-map.
   Content outside the markers will be preserved.
   ```

## Generated Index Format

```markdown
# Documentation

Welcome to the project documentation. Start with the [project README](../README.md) for an overview.

<!-- docs-map:start -->

## Quick Links

- [README](../README.md) — Project overview and quickstart
- [Getting Started](./getting-started.md) — Setup and first steps
- [Architecture](./architecture.md) — System design overview
- [ADR Index](./adr/README.md) — Architecture Decision Records
- [API Documentation](./api/README.md) — API reference
- [Contributing](../CONTRIBUTING.md) — How to contribute
- [Changelog](../CHANGELOG.md) — Version history

## All Documentation

| Document                                | Description                   |
| --------------------------------------- | ----------------------------- |
| [Getting Started](./getting-started.md) | Setup and first steps         |
| [Architecture](./architecture.md)       | System design overview        |
| [Configuration](./configuration.md)     | Configuration options         |
| [ADR 0001](./adr/0001-decision.md)      | Use PostgreSQL for database   |
| [API Overview](./api/README.md)         | API documentation entry point |
| [Endpoints](./api/endpoints.md)         | API endpoint reference        |

<!-- docs-map:end -->
```

## Key Rules

### Never Overwrite Hand-Written Content

Managed sections use HTML comment markers. Only content between `<!-- docs-map:start -->` and
`<!-- docs-map:end -->` is modified. Everything outside the markers is preserved.

### No Network Access

All file discovery uses `Glob` — deterministic, no external tools required. Never make network
requests.

### Skip Gracefully

If the index file exists without markers and `--update` is used, skip with guidance on how to add
markers. Never overwrite an entire hand-written documentation index.

### Doc Root Detection

Check for documentation directories in order:

1. `docs/`
2. `doc/`
3. `documentation/`
4. Repository root (fallback)

Use the first match as the location for the generated index.

### Quick Links Are Context-Aware

Only include quick links for documents that actually exist in the repository. Omit links to missing
files rather than generating broken references.
