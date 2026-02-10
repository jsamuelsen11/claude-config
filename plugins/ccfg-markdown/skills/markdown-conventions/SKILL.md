---
name: markdown-conventions
description:
  This skill should be used when working with Markdown, writing documentation, formatting markdown
  files, or reviewing markdown content.
version: 0.1.0
---

# Markdown Conventions and Best Practices

This skill defines conventions for writing Markdown files, formatting documentation, and maintaining
consistent style across all projects. Following these conventions ensures readable, maintainable,
and correctly rendered markdown content.

## Existing Repository Compatibility

When working in established repositories, always respect existing markdown conventions and patterns.
If the project uses setext headings, a non-standard line length, or different list indentation,
follow it. If the project has a `.markdownlint.json` or `.markdownlint-cli2.jsonc` config, those
rules take precedence. These preferences apply to new markdown and scaffold output only.

## Heading Style

Use ATX-style headings (`#`) with proper hierarchy. Never skip heading levels.

```markdown
# CORRECT: Proper heading hierarchy

# Title

## Section

### Subsection

### Another Subsection

## Next Section
```

```markdown
# WRONG: Skipped heading levels

# Title

### Subsection (skipped ##)

## Section

#### Deep (skipped ###)
```

### Heading Rules

- Use ATX headings (`#`), not setext (underlines) — unless project convention dictates otherwise
- Never skip levels: `##` after `#`, never `###` after `#`
- Blank line before and after every heading
- Only one H1 (`#`) per file — the document title
- Headings should be meaningful scan targets — not generic ("Overview" → "Authentication Overview")

## Code Fences

Always specify a language tag on fenced code blocks. Use triple backticks and maintain consistent
fence style throughout the project.

````markdown
```python
# CORRECT: Language tag specified
def hello():
    print("Hello, world!")
```

```bash
# CORRECT: Shell commands
npm install
npm run build
```

```text
# CORRECT: Plain output
CORRECT for non-code output
```

```json
{
  "CORRECT": "structured data"
}
```
````

### Code Fence Rules

- Always specify language: `python`, `bash`, `json`, `text`, `yaml`, `dockerfile`, etc.
- Use `text` for plain output with no syntax highlighting
- Use consistent fence style (triple backtick preferred over tilde)
- Ensure all fences are properly closed
- When fences appear inside list items, indent to the list content level

## Links

Prefer relative paths for internal links. Use descriptive link text in narrative documentation.

```markdown
<!-- CORRECT: Relative internal links -->

See the [setup guide](./docs/setup.md) for installation instructions.

Refer to the [API reference](../api/README.md) for endpoint details.
```

```markdown
<!-- CORRECT: Reference-style for repeated links -->

The [API docs][api] describe all endpoints. See the [API reference][api] for more.

[api]: ./docs/api/README.md
```

```markdown
<!-- WRONG: Bare URL in prose -->

Visit https://example.com/docs for documentation.

<!-- WRONG: Meaningless link text -->

[Click here](./docs/setup.md) for the setup guide.
```

### Link Rules

- Use relative paths for internal links (`./docs/setup.md`)
- Prefer reference-style `[text][ref]` for links used more than once
- Use meaningful link text — never "click here" or "this page"
- Bare `<url>` syntax is acceptable in dedicated "References" or "Links" sections
- Bare URLs should not appear inline in explanatory prose

## Lists

Use consistent indentation and blank lines around lists.

```markdown
<!-- CORRECT: Consistent 2-space indentation -->

- Item one
  - Nested item
  - Another nested item
    - Deeply nested
- Item two

<!-- CORRECT: Blank lines around lists -->

Some paragraph text.

- Item one
- Item two
- Item three

Next paragraph text.
```

### List Rules

- Consistent indentation: 2 or 4 spaces — match project convention
- Blank lines before and after lists
- Limit nesting to 3 levels maximum
- Use `-` for unordered lists (consistent marker)
- Use `1.` for ordered lists (let the renderer handle numbering)

## Line Length

Default maximum line length is 100 characters. Respect the project's markdownlint config if present.

**Exceptions** (lines that may exceed the limit):

- URLs and links
- Code blocks (content inside fences)
- Tables
- Headings

## Frontmatter

YAML frontmatter appears between `---` markers at the very start of the file.

```yaml
---
title: Setup Guide
description: How to set up the development environment
author: team
date: 2026-01-15
tags:
  - setup
  - development
---
```

### Frontmatter Rules

- Must be at the very start of the file (no content before it)
- Use lowercase keys
- Consistent field ordering across files in the same project
- Valid YAML syntax

## Tables

Align pipes for readability and include proper header separator rows.

```markdown
<!-- CORRECT: Aligned table -->

| Name    | Type   | Required | Description       |
| ------- | ------ | -------- | ----------------- |
| `id`    | string | yes      | Unique identifier |
| `name`  | string | yes      | Display name      |
| `email` | string | no       | Contact email     |

<!-- CORRECT: Column alignment markers -->

| Left | Center | Right |
| :--- | :----: | ----: |
| text |  text  |  text |
```

### Table Rules

- Align pipes for readability
- Always include header separator row
- Use consistent column alignment markers (`:---`, `:---:`, `---:`)
- Keep tables simple — if a table exceeds 4-5 columns, consider restructuring

## Emphasis

Use consistent emphasis markers throughout a file.

```markdown
<!-- CORRECT: Consistent markers -->

This is _italic_ text and **bold** text.
```

```markdown
<!-- WRONG: Mixed emphasis markers -->

This is _italic_ text and **bold** text.
```

### Emphasis Rules

- Use `*` for italic and `**` for bold (not `_` and `__`)
- Be consistent within a file
- Match the project's existing convention if different

This comprehensive guide covers markdown conventions that ensure consistent, readable, and correctly
rendered documentation across all projects.
