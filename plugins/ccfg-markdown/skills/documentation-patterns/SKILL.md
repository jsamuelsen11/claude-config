---
name: documentation-patterns
description:
  This skill should be used when creating or structuring documentation, writing READMEs, designing
  documentation architecture, or organizing project documentation.
version: 0.1.0
---

# Documentation Patterns and Structure

This skill defines patterns for structuring documentation, organizing files, and maintaining
consistent documentation architecture across projects. Following these patterns ensures navigable,
complete, and maintainable project documentation.

## README Structure

READMEs follow a standard structure ordered by reader need: what is this → how to use it → how to
contribute.

### Required Sections

```markdown
# Project Name

[![Build Status](badge-url)](link)

One-sentence description of what the project does and why it exists.

## Table of Contents

(for documents with > 4 sections)

## Prerequisites

## Installation

## Usage

## Configuration

## Development

## Testing

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

[MIT](./LICENSE)
```

### README Rules

- **Title**: Project name as H1, never repeated elsewhere in the file
- **Badges**: Build status, coverage, version, license — immediately after title
- **Description**: One to two sentences, answering "what does this do and why?"
- **Table of Contents**: Include for documents with more than 4 sections
- **Installation**: Complete steps including prerequisites
- **Usage**: Working code examples starting with the simplest case
- **Order by reader need**: what → how → contribute
- For libraries: include API reference section
- For services: include deployment and configuration sections
- For CLIs: include command reference with examples

## ADR (Architecture Decision Records)

ADRs use MADR (Markdown Any Decision Records) format with sequential numbering and status tracking.

### MADR Format

```markdown
# ADR 0001: Decision Title

## Status

Proposed | Accepted | Deprecated | Superseded by ADR 000X

## Context

What is the issue we are facing? What is the background?

## Decision

What is the change that we are proposing and/or doing?

## Consequences

### Positive

- Benefit one
- Benefit two

### Negative

- Cost one
- Cost two

## Alternatives Considered

### Alternative A

- Pros: ...
- Cons: ...
```

### ADR Conventions

- **Numbering**: Sequential with zero-padding (`0001-*`, `0002-*`)
- **Status lifecycle**: Proposed → Accepted → Deprecated / Superseded
- **Cross-reference**: Link related decisions ("Supersedes ADR 0003")
- **Storage**: `docs/adr/` directory (or existing ADR directory if present)
- **Index**: Maintain `docs/adr/README.md` linking all decision records with status and date

### ADR Directory Structure

```text
docs/adr/
├── README.md              (index of all ADRs)
├── 0001-use-postgresql.md
├── 0002-adopt-rest-api.md
└── template.md            (blank ADR template)
```

## Changelog

Changelogs follow the [Keep a Changelog](https://keepachangelog.com/) format.

### Keep a Changelog Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New feature description

## [1.2.0] - 2026-01-15

### Added

- Feature description

### Changed

- Change description

### Fixed

- Bug fix description

[Unreleased]: https://github.com/org/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/org/repo/compare/v1.1.0...v1.2.0
```

### Changelog Rules

- **Categories**: Added, Changed, Deprecated, Removed, Fixed, Security
- **Version headers**: Include date in ISO 8601 format (`## [1.2.0] - 2026-01-15`)
- **Unreleased section**: Always present at top for upcoming changes
- **Diff links**: Link each version header to the diff between versions at the bottom
- **Entry format**: Past tense, one line per change, grouped by category
- **Location**: `CHANGELOG.md` at the repository root

## API Documentation

API docs follow the endpoint → method → params → response → errors pattern.

### API Documentation Structure

```text
docs/api/
├── README.md              (API overview, base URL, versioning)
├── authentication.md      (auth methods, tokens, examples)
└── endpoints.md           (endpoint reference)
```

### Endpoint Documentation Pattern

Each endpoint documents:

1. **Method and path**: `POST /api/v1/users`
2. **Description**: What the endpoint does
3. **Parameters**: Request body fields with types, required/optional, descriptions
4. **Example request**: Runnable curl/httpie command
5. **Success response**: Status code and response body
6. **Error responses**: Status codes, error codes, descriptions

### API Documentation Rules

- **Authentication first**: Document auth requirements before endpoints
- **Runnable examples**: Include curl/httpie examples that can be copied and run
- **Status code table**: List all possible response codes for each endpoint
- **Error format**: Show the error response structure with field descriptions
- **Rate limiting**: Document limits and relevant response headers
- **Versioning**: Document API version strategy at the top

## File Organization

Documentation follows a standard directory structure.

### Standard Layout

```text
project/
├── README.md                    (project overview, quickstart)
├── CONTRIBUTING.md              (how to contribute)
├── CHANGELOG.md                 (version history)
├── LICENSE                      (license text)
└── docs/
    ├── README.md                (documentation index)
    ├── getting-started.md       (setup and first steps)
    ├── architecture.md          (system design overview)
    ├── configuration.md         (all config options)
    ├── adr/
    │   ├── README.md            (ADR index)
    │   └── template.md
    └── api/
        ├── README.md            (API overview)
        └── endpoints.md
```

### File Organization Rules

- `docs/` for project documentation (prefer over `doc/` or `documentation/`)
- `docs/adr/` for Architecture Decision Records
- `docs/api/` for API documentation
- `CONTRIBUTING.md` and `CHANGELOG.md` at the repository root
- `README.md` at root and in significant subdirectories
- Detect existing doc root: check `docs/`, `doc/`, `documentation/` in order; use first match
- If none exists, default to `docs/` for new projects

This comprehensive guide covers documentation patterns that ensure consistent, navigable, and
complete project documentation.
