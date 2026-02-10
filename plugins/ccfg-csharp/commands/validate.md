---
description: Run restore, build, format check, tests, and Roslyn analyzers for .NET projects
argument-hint: '[--quick]'
allowed-tools: Bash(dotnet *), Bash(git *), Read, Grep, Glob
---

# .NET Validation Command

You are executing the `validate` command for a .NET project. This command runs a comprehensive suite
of quality gates to ensure code meets production standards before commit or merge.

## Command Modes

### Full Mode (default)

Runs all quality gates in sequence:

1. `dotnet restore` - Restore NuGet packages
2. `dotnet build -warnaserror` - Compile with warnings as errors and Roslyn analyzers
3. `dotnet format --verify-no-changes` - Verify code formatting
4. `dotnet test` - Execute the full test suite

#### Quick Mode (--quick flag)

Runs only fast checks for inner-loop development:

1. `dotnet build -warnaserror --no-restore` - Compile with warnings as errors

Quick mode skips restore, format check, and tests to provide rapid feedback during active
development. Use full mode before committing or opening a pull request.

## Execution Strategy

### Project Detection

Detect the project structure in the following priority order:

1. Check for `.sln` files (solution-level build)
2. Check for `Directory.Build.props` (multi-project repository)
3. Check for individual `.csproj` files (single project)

```bash
# Solution file detection
ls *.sln 2>/dev/null

# Directory.Build.props detection
ls Directory.Build.props 2>/dev/null

# Fall back to individual project files
find . -name "*.csproj" -maxdepth 3 2>/dev/null
```

#### SDK Version Detection

Check for `global.json` to understand the pinned SDK version:

```bash
# Check global.json
cat global.json 2>/dev/null

# Verify installed SDK version
dotnet --version
```

#### Environment Summary

After detection, report the configuration:

```text
Solution: CatalogService.sln
SDK version: 8.0.404 (from global.json)
Projects: 4 source, 4 test
Mode: Full validation
```

### Gate 1: Restore

Restore NuGet packages to ensure all dependencies are available. This step is skipped in quick mode.

```bash
dotnet restore
```

If restore fails, report the error and stop. Common failures include:

- Missing NuGet sources in `nuget.config`
- Version conflicts when using Central Package Management
- Authentication failures for private feeds

#### Restore Diagnostics

If restore fails, check for common issues:

```bash
# Check for nuget.config
ls nuget.config 2>/dev/null

# Check for Directory.Packages.props (CPM)
ls Directory.Packages.props 2>/dev/null

# List configured NuGet sources
dotnet nuget list source
```

### Gate 2: Build with Warnings as Errors

Build the entire solution with `-warnaserror` to enforce zero warnings. Roslyn analyzers configured
in `Directory.Build.props` or individual `.csproj` files run as part of the build, so there is no
separate analyzer gate.

```bash
# Full mode: build after restore
dotnet build -warnaserror --no-restore

# Quick mode: build is the only gate
dotnet build -warnaserror
```

#### Build Failure Diagnostics

If the build fails due to warnings-as-errors:

1. Read the error output to identify the warning codes (e.g., CS8602, CA1062, IDE0005)
2. Fix the code to resolve the warning
3. Never suggest `#pragma warning disable` as a fix
4. Never suggest adding warning codes to `<NoWarn>` in the project file
5. If the warning comes from a Roslyn analyzer, fix the underlying code issue

Common warning categories:

- **CS8600-CS8610**: Nullable reference type warnings (fix null handling)
- **CA1062**: Validate arguments of public methods (add null checks)
- **CA2007**: ConfigureAwait (remove or add based on project type)
- **IDE0005**: Unnecessary using directive (remove the using)
- **IDE0090**: Use simplified `new` expression (use target-typed new)

### Gate 3: Format Check

Verify code formatting matches the `.editorconfig` rules without modifying any files. This gate is
skipped in quick mode.

```bash
dotnet format --verify-no-changes --no-restore --exclude obj/ --exclude Migrations/
```

The `--exclude` flags prevent formatting checks on:

- `obj/` - Build output directories
- `Migrations/` - EF Core generated migration files

#### Format Failure Diagnostics

If format check fails:

1. Run `dotnet format` to see what would change
2. The output shows which files need formatting
3. Fix by running `dotnet format --exclude obj/ --exclude Migrations/`
4. Do NOT auto-fix and commit; report the needed changes instead

```bash
# Show what would change (dry run with diagnostics)
dotnet format --verify-no-changes --no-restore \
    --exclude obj/ --exclude Migrations/ \
    --verbosity diagnostic 2>&1 | head -50
```

#### Format Fix for Local Development

If the user requests a fix, run the formatter:

```bash
dotnet format --no-restore --exclude obj/ --exclude Migrations/
```

### Gate 4: Test Suite

Run the full test suite. This gate is skipped in quick mode.

```bash
dotnet test --no-build --verbosity normal
```

#### Test Failure Diagnostics

If tests fail:

1. Parse the test output for failed test names and error messages
2. Read the failing test files to understand the test intent
3. Read the source code being tested to identify the bug
4. Suggest a targeted fix

```bash
# Run with detailed output to see individual test results
dotnet test --no-build --verbosity normal --logger "console;verbosity=detailed"
```

#### Running Specific Tests

If a specific test or test class is failing, run it in isolation:

```bash
# Run a specific test class
dotnet test --no-build --filter "FullyQualifiedName~ProductServiceTests"

# Run a specific test method
dotnet test --no-build --filter "FullyQualifiedName~ProductServiceTests.GetByIdAsync_WhenProductExists_ReturnsProductResponse"

# Run tests in a specific project
dotnet test tests/Catalog.Application.Tests/Catalog.Application.Tests.csproj --no-build
```

## Output and Reporting

### Success Report

When all gates pass, report a summary:

```text
Validation Summary (Full Mode)
==============================
Restore:      PASS (3.2s)
Build:        PASS (8.1s, 0 warnings)
Format:       PASS (2.4s)
Tests:        PASS (15.7s, 142 passed, 0 failed, 0 skipped)
-------------------------------
Total:        29.4s - ALL GATES PASSED
```

#### Failure Report

When a gate fails, stop execution and report:

```text
Validation Summary (Full Mode)
==============================
Restore:      PASS (3.2s)
Build:        FAIL (6.8s)

Build failed with 3 errors:
  src/Catalog.Api/Endpoints/ProductEndpoints.cs(42): error CS8602: Dereference of a possibly null reference
  src/Catalog.Application/Services/ProductService.cs(18): error IDE0005: Using directive is unnecessary
  src/Catalog.Domain/Models/Product.cs(7): error CA1051: Do not declare visible instance fields

Fix these issues and run validate again.
```

## Warning Suppression Policy

### Rules for Warning Handling

These rules are absolute and must never be violated:

1. **Never suggest `#pragma warning disable`** for any warning. Always fix the underlying code.
2. **Never suggest adding warnings to `<NoWarn>`** in project files. Fix the code instead.
3. **Never suggest `[SuppressMessage]`** attributes. Fix the code.
4. The only acceptable suppression location is `.editorconfig` for project-wide policy decisions,
   and those decisions are made by the team, not during validation.

### How to Fix Common Warnings

Instead of suppressing, fix the code:

```csharp
// CS8602: Dereference of a possibly null reference
// WRONG: #pragma warning disable CS8602
var name = user.Name.ToUpper();
// CORRECT: Add null check
var name = user?.Name?.ToUpper() ?? string.Empty;
```

```csharp
// CA1062: Validate arguments of public methods
// WRONG: [SuppressMessage("CA1062")]
public void Process(Order order) { }
// CORRECT: Add ArgumentNullException guard
public void Process(Order order)
{
    ArgumentNullException.ThrowIfNull(order);
}
```

```csharp
// IDE0005: Unnecessary using directive
// WRONG: Adding to <NoWarn>
// CORRECT: Remove the unused using statement
```

## Roslyn Analyzer Integration

### How Analyzers Are Enforced

Roslyn analyzers are enforced through the build, not as a separate gate. They are configured via:

1. **Directory.Build.props**: Analyzer packages added as `PrivateAssets="all"` references
2. **.editorconfig**: Severity levels for individual diagnostic IDs
3. **TreatWarningsAsErrors**: All analyzer warnings become build errors

This means `dotnet build -warnaserror` is the single gate that enforces both compilation correctness
and analyzer rules.

#### Checking Analyzer Configuration

Verify which analyzers are active:

```bash
# Check Directory.Build.props for analyzer packages
grep -i "analyzer" Directory.Build.props 2>/dev/null

# Check .editorconfig for severity overrides
grep "dotnet_diagnostic" .editorconfig 2>/dev/null

# Check project files for TreatWarningsAsErrors
grep "TreatWarningsAsErrors" Directory.Build.props *.csproj 2>/dev/null
```

## Edge Cases

### Multi-Target Framework Projects

For projects targeting multiple frameworks (e.g., `net8.0;net9.0`), all targets must pass:

```bash
# Build targets all frameworks by default
dotnet build -warnaserror

# Test targets the first framework by default; test all:
dotnet test --no-build --framework net8.0
dotnet test --no-build --framework net9.0
```

### Projects Without Test Projects

If no test projects are found (no `.csproj` with `<IsTestProject>true</IsTestProject>`), skip Gate 4
and report:

```text
Tests:        SKIP (no test projects found)
```

Detect test projects:

```bash
# Find test projects
grep -rl "<IsTestProject>true</IsTestProject>" --include="*.csproj" . 2>/dev/null
```

### Projects Without .editorconfig

If no `.editorconfig` is found, skip Gate 3 (format check) because `dotnet format` without an
`.editorconfig` will use default rules which may not match the team's intent:

```text
Format:       SKIP (no .editorconfig found)
```
