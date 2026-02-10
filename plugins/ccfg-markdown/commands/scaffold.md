---
description: >
  Initialize documentation structure and templates (README, ADR, API docs, changelog, contributing)
argument-hint: '[--type=readme|adr|api-docs|changelog|contributing]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize documentation structure and templates for projects. Generates well-structured
documentation files based on project type detection and standard patterns.

## Usage

```bash
ccfg markdown scaffold                          # Default: scaffold README
ccfg markdown scaffold --type=readme            # Generate structured README
ccfg markdown scaffold --type=adr               # Generate ADR directory and template
ccfg markdown scaffold --type=api-docs          # Generate API documentation structure
ccfg markdown scaffold --type=changelog         # Generate CHANGELOG.md
ccfg markdown scaffold --type=contributing      # Generate CONTRIBUTING.md
```

## Scaffold Types

### readme (default)

Generate a structured README.md for the project.

**Steps**:

1. Detect project type from project files (language, framework, CLI vs library vs service)
2. Generate structured README.md: title, badges placeholder, description, prerequisites,
   installation, usage, configuration, development, testing, contributing reference, license
3. Sections ordered by reader need (what is this → how to use it → how to contribute)
4. Include table of contents for documents with more than 4 sections

**Project type detection**:

```text
package.json         -> Node.js project (check for framework: express, next, react, etc.)
requirements.txt     -> Python project (check for framework: django, flask, fastapi, etc.)
go.mod               -> Go project
Cargo.toml           -> Rust project
pom.xml / build.gradle -> Java project
Gemfile              -> Ruby project
composer.json        -> PHP project
```

**Generated sections**:

```markdown
# Project Name

<!-- badges -->

One-sentence description.

## Table of Contents

## Prerequisites

## Installation

## Usage

## Configuration

## Development

## Testing

## Contributing

## License
```

### adr

Generate an Architecture Decision Records directory and template.

**Steps**:

1. Detect existing ADR directory or create `<doc-root>/adr/`
2. Generate ADR template file following MADR format: title, status, context, decision, consequences,
   alternatives
3. Generate ADR index file (`<doc-root>/adr/README.md`) linking all decision records

**Generated files**:

```text
<doc-root>/adr/
├── README.md              (ADR index)
└── template.md            (blank ADR template)
```

### api-docs

Generate API documentation structure.

**Steps**:

1. Detect API framework from project files (Express, FastAPI, Spring, Gin, etc.)
2. Generate API documentation structure: authentication, endpoints, request/response formats, error
   codes, rate limiting
3. Include example request/response blocks with placeholder data

**Generated files**:

```text
<doc-root>/api/
├── README.md              (API overview)
├── authentication.md      (auth methods and tokens)
└── endpoints.md           (endpoint reference)
```

### changelog

Generate a CHANGELOG.md following Keep a Changelog format.

**Steps**:

1. Generate CHANGELOG.md at the repository root
2. Include category headers: Added, Changed, Deprecated, Removed, Fixed, Security
3. Include Unreleased section and version template with dates

**Generated structure**:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed
```

### contributing

Generate a CONTRIBUTING.md for the project.

**Steps**:

1. Generate CONTRIBUTING.md at the repository root: getting started, development setup, coding
   standards reference, PR process, issue reporting, code of conduct reference
2. Detect project tooling to include relevant setup commands (npm install, pip install, go mod
   download, etc.)

## Key Rules

### Never Overwrite Existing Files

Always check if a file exists before creating it. If the target file already exists, skip with a
notice. Never silently overwrite documentation.

```text
README.md already exists. Skipping scaffold.
To regenerate, rename or remove the existing file first.
```

### Project Type Detection

Detection is best-effort. Never prescribe a stack — respect what the project already uses. Use
project files to detect language, framework, and tooling.

### Doc Root Detection

Check for existing documentation directories in this order:

1. `docs/` (preferred)
2. `doc/`
3. `documentation/`

Use the first match as the doc root for all generated output. If none exists, use `docs/` as the
default for new projects.

All scaffold types respect this detected root:

- ADR goes to `<doc-root>/adr/`, not hardcoded `docs/adr/`
- API docs go to `<doc-root>/api/`, not hardcoded `docs/api/`

### Conventions Recommendation

Scaffold recommends creating a conventions document at `<doc-root>/markdown-conventions.md`. If the
doc root directory exists, scaffold offers to create it. If no doc root structure exists, skip and
note in output.

### Generated Content Uses Project Context

- Project name detected from package.json, Cargo.toml, go.mod, or directory name
- Installation commands match detected package manager
- Test commands match detected test framework
- Placeholder sections use project-appropriate examples
