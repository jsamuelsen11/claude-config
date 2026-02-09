---
description: Generate repomix context bundle for repo
argument-hint: [--include "src/**"] [--exclude "node_modules"]
allowed-tools: Bash(npx:*), Read, Glob, Grep
---

# Repo Pack

Generate a comprehensive context bundle of the repository using repomix, making it easy to share the
entire codebase context with Claude for analysis, documentation, or architectural review.

## Usage

```bash
/repo-pack [--include "pattern"] [--exclude "pattern"]
```

**Options:**

- `--include` - Glob pattern for files to include (default: all files)
- `--exclude` - Glob pattern for files to exclude (default: respects .gitignore)

**Examples:**

```bash
/repo-pack
/repo-pack --include "src/**/*.py"
/repo-pack --exclude "tests/**"
/repo-pack --include "src/**" --exclude "node_modules,*.log"
```

## Process

### Step 1: Verify Repomix Availability

Check if repomix is available via npx:

```bash
npx repomix --version
```

**Expected Output:** Version number (e.g., `v2.3.1`)

**If Not Available:**

```text
Repomix not found. Installing via npx...

This is a one-time operation. Future runs will use cached version.
```

### Step 2: Run Repomix

Execute repomix with appropriate options based on user arguments:

**Default Command:**

```bash
npx repomix
```

**With Include Pattern:**

```bash
npx repomix --include "src/**/*.py"
```

**With Exclude Pattern:**

```bash
npx repomix --exclude "node_modules,dist,*.log"
```

**With Both:**

```bash
npx repomix --include "src/**" --exclude "tests/**,*.test.js"
```

**Additional Flags:**

- Automatically respects `.gitignore` patterns
- Excludes binary files by default
- Generates XML format for optimal Claude parsing
- Output location: `repomix-output.xml` in project root

### Step 3: Collect Summary Statistics

After repomix completes, gather metadata:

```bash
# Count files included
grep -c "<file " repomix-output.xml

# Calculate total size
wc -c repomix-output.xml
```

**Statistics to Report:**

- Total files included
- Total size of bundle (in KB/MB)
- Output file location
- Timestamp of generation

### Step 4: Present Bundle Summary

Display summary before reading the packed content:

```text
REPO PACK COMPLETE

Output: /absolute/path/to/repomix-output.xml
Files: 247
Size: 1.8 MB
Generated: 2026-02-08 14:23:45 UTC

Included patterns:
  - src/**/*.py
  - src/**/*.ts

Excluded patterns:
  - node_modules/**
  - tests/**
  - .git/**

Respecting .gitignore: Yes
```

### Step 5: Read and Present Context

Read the generated XML bundle and present it to Claude for analysis:

```markdown
Repository context bundle loaded successfully.

The bundle contains the full source code and structure of the project. I can now help you with:

- Code review and analysis
- Architecture documentation
- Refactoring suggestions
- Dependency mapping
- Security audit
- Performance analysis
- Migration planning
- API documentation generation

What would you like me to analyze or help with?
```

## Repomix Configuration

### Default Behavior

Repomix uses these defaults:

- Respects `.gitignore` automatically
- Excludes common directories: `node_modules`, `.git`, `dist`, `build`
- Excludes binary files (images, executables, archives)
- Includes metadata (file paths, sizes, line counts)
- Generates XML format optimized for LLM consumption

### Customization

For advanced use cases, you can create a `repomix.config.json`:

```json
{
  "output": {
    "filePath": "repomix-output.xml",
    "style": "xml"
  },
  "include": ["src/**", "docs/**"],
  "ignore": {
    "useGitignore": true,
    "customPatterns": ["*.log", "*.tmp", "secrets/"]
  }
}
```

If this file exists, repomix will automatically use it.

## Use Cases

### Full Codebase Analysis

```bash
/repo-pack
```

Generate complete repository context for comprehensive analysis.

### Documentation Generation

```bash
/repo-pack --include "src/**/*.py" --exclude "tests/**"
```

Focus on source code, exclude tests for documentation.

### Security Audit

```bash
/repo-pack --include "src/**,package.json,requirements.txt"
```

Include source and dependency files for security review.

### Architecture Review

```bash
/repo-pack --exclude "tests/**,*.test.*,*.spec.*"
```

Exclude test files to focus on production architecture.

### Migration Planning

```bash
/repo-pack --include "src/**/*.js,package.json"
```

Pack JavaScript files for TypeScript migration analysis.

## Best Practices

### Size Management

- For large repos (>10MB packed), consider using include/exclude filters
- Exclude test files if focusing on production code
- Exclude generated files (build output, compiled assets)
- Exclude large data files or fixtures

### Pattern Tips

- Use `**` for recursive matching: `src/**/*.py`
- Separate multiple patterns with commas: `*.js,*.ts`
- More specific patterns = smaller, faster bundles
- Check `.gitignore` first to avoid redundant exclusions

### Performance

- First run downloads repomix (30-60 seconds)
- Subsequent runs use cached version (instant)
- Large repos (1000+ files) may take 10-30 seconds to pack
- Bundle size typically 10-50% of actual repo size

### Privacy

- Review bundle before sharing externally
- Ensure no secrets in tracked files
- Repomix respects `.gitignore` but verify output
- Consider encrypting bundle if sharing sensitive code

## Output Format

Repomix generates XML with this structure:

```xml
<file_summary>
  <purpose>Repository context bundle</purpose>
  <file_count>247</file_count>
  <total_size>1834592</total_size>
</file_summary>

<files>
  <file path="src/main.py">
    <content>
      <!-- File contents here -->
    </content>
  </file>
  <!-- More files -->
</files>
```

This format is optimized for Claude to parse and understand repository structure.

## Troubleshooting

### Repomix Not Found

```text
Error: Command failed: npx repomix --version

Solution:
  Ensure Node.js and npx are installed:
    node --version
    npx --version

  If not installed, install Node.js from nodejs.org
```

### Bundle Too Large

```text
Warning: Bundle size exceeds 5MB (current: 12.4 MB)

This may be difficult to process in a single context window.

Suggestions:
  1. Use --include to focus on specific directories
  2. Use --exclude to remove large files
  3. Split into multiple targeted bundles
  4. Check for accidentally included build artifacts
```

### No Files Included

```text
Error: Bundle contains 0 files

Possible causes:
  1. Include pattern too restrictive
  2. All files matched by exclude pattern
  3. All files ignored by .gitignore

Solution:
  Review patterns and try:
    /repo-pack --include "**/*"
```

## Notes

- Repomix output file (`repomix-output.xml`) is automatically gitignored
- Bundle generation is read-only, never modifies source files
- Multiple bundles can be generated with different filters
- Use Glob and Grep tools to preview what will be included before packing
- Consider committing `repomix.config.json` for team consistency
