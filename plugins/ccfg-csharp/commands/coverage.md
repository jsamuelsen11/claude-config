---
description: Autonomously improve .NET test coverage using Cobertura analysis
argument-hint: '[--threshold=90] [--project=<path>] [--dry-run] [--no-commit]'
allowed-tools: Bash(dotnet *), Bash(git *), Read, Write, Edit, Grep, Glob
---

# .NET Coverage Improvement Command

You are executing the `coverage` command to autonomously improve test coverage across a .NET project
by analyzing Cobertura coverage reports, identifying gaps, and generating comprehensive tests.

## Command Arguments

### Optional: --threshold

Minimum coverage percentage to achieve per class (default: 90).

```bash
ccfg csharp coverage --threshold=85
```

#### Optional: --project

Target a specific project or namespace instead of the entire solution.

```bash
ccfg csharp coverage --project=src/Catalog.Application
```

#### Optional: --dry-run

Report coverage gaps without generating any tests.

```bash
ccfg csharp coverage --dry-run
```

#### Optional: --no-commit

Generate tests but do not auto-commit changes.

```bash
ccfg csharp coverage --no-commit
```

## Execution Strategy

### Phase 1: Coverage Baseline

Measure current test coverage and establish the baseline.

1. Discover test projects
2. Run tests with Coverlet coverage collection
3. Parse the Cobertura XML report
4. Calculate per-class line coverage
5. Identify classes below threshold
6. Rank classes by uncovered line count
7. Report the current state

#### Phase 2: Gap Analysis

For each under-threshold class:

1. Read the source file to understand its structure
2. Read existing test files to match patterns and style
3. Identify untested methods and branches
4. Determine what test patterns the project uses
5. Plan targeted test cases

#### Phase 3: Test Generation

For each identified gap:

1. Write targeted tests matching project patterns
2. Use FluentAssertions for assertion chains
3. Use NSubstitute for dependency isolation
4. Follow the Arrange-Act-Assert pattern
5. Follow the project's existing test naming conventions

#### Phase 4: Validation

After generating tests for each class:

1. Run tests to verify they pass
2. Run format check to ensure style compliance
3. Measure new coverage for the class
4. Report the improvement

#### Phase 5: Commit (unless --no-commit or --dry-run)

Create one commit per improved class:

1. Stage only the test files for that class
2. Commit with a descriptive message including coverage delta
3. Move to the next class

## Discovering Test Projects

### Finding Test Projects by Metadata

Discover test projects by checking `.csproj` files for test project indicators:

```bash
# Find projects marked as test projects
grep -rl "<IsTestProject>true</IsTestProject>" --include="*.csproj" . 2>/dev/null
```

Map each test project to its corresponding source project by examining `ProjectReference` entries:

```bash
# Check project references in a test project
grep "ProjectReference" tests/Catalog.Application.Tests/Catalog.Application.Tests.csproj
```

### Test Project Convention Mapping

Test projects typically follow naming conventions:

- `Catalog.Application.Tests` tests `Catalog.Application`
- `Catalog.Api.Tests` tests `Catalog.Api`
- `Catalog.Infrastructure.Tests` tests `Catalog.Infrastructure`

## Coverage Baseline Analysis

### Step 1: Run Tests with Coverlet

Run all tests with the Coverlet collector to generate Cobertura XML reports.

```bash
dotnet test \
    --collect:"XPlat Code Coverage" \
    --results-directory ./TestResults \
    -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
```

This produces one `coverage.cobertura.xml` file per test project under `TestResults/`.

#### Step 2: Locate Coverage Reports

```bash
# Find all Cobertura XML files
find ./TestResults -name "coverage.cobertura.xml" -type f 2>/dev/null
```

#### Step 3: Parse Cobertura XML

Read each Cobertura XML file and extract per-class coverage data. The Cobertura XML format contains
`<class>` elements with `line-rate` attributes.

```xml
<package name="Catalog.Application.Services">
  <classes>
    <class name="Catalog.Application.Services.ProductService"
           filename="src/Catalog.Application/Services/ProductService.cs"
           line-rate="0.75" branch-rate="0.60" complexity="12">
      <lines>
        <line number="15" hits="3" />
        <line number="16" hits="3" />
        <line number="20" hits="0" />
        <line number="21" hits="0" />
      </lines>
    </class>
  </classes>
</package>
```

Key attributes to extract:

- `class/@name`: Fully qualified class name
- `class/@filename`: Source file path
- `class/@line-rate`: Line coverage as a decimal (0.75 = 75%)
- `line/@number`: Line number
- `line/@hits`: Number of times the line was executed (0 = uncovered)

#### Step 4: Calculate Coverage Summary

For each class, compute:

- **Line coverage**: `lines with hits > 0 / total lines` (from `line-rate`)
- **Uncovered lines**: Lines where `hits == 0`
- **Branch coverage**: From `branch-rate` if available

Generate a sorted table of classes below threshold:

```text
Coverage Baseline (threshold: 90%)
==================================

Class                                           Lines   Covered  %     Gap
Catalog.Application.Services.ProductService     48      36       75.0  12
Catalog.Application.Services.CategoryService    32      20       62.5  12
Catalog.Infrastructure.Data.ProductRepository   64      54       84.4  10
Catalog.Api.Middleware.GlobalExceptionHandler    22      10       45.5  12

Total classes below 90%: 4
Total uncovered lines: 46
```

## Gap Analysis

### Identifying Uncovered Code

For each under-threshold class:

1. Read the source file
2. Cross-reference with the Cobertura line data
3. Identify which methods contain uncovered lines
4. Categorize the gap type

Gap types:

- **Untested method**: Entire method has zero hits
- **Untested branch**: Conditional paths (if/else, switch cases) without coverage
- **Untested error path**: Exception handling or error conditions
- **Untested edge case**: Boundary conditions, null checks, validation

### Reading Existing Test Patterns

Before generating new tests, study the existing test codebase:

1. Find existing test files for the class or related classes
2. Note the testing framework conventions (xUnit + NSubstitute + FluentAssertions)
3. Note the naming convention (e.g., `MethodName_Condition_Expected`)
4. Note the setup pattern (constructor injection, IDisposable, IAsyncLifetime)
5. Note the assertion style (FluentAssertions chains)

```bash
# Find existing test files for a service
find tests/ -name "*ProductService*" -o -name "*CategoryService*" 2>/dev/null

# Find test base classes or shared fixtures
find tests/ -name "*Fixture*" -o -name "*Base*" -o -name "*Helper*" 2>/dev/null
```

## Test Generation

### Test Code Quality Standards

Generated tests must follow these rules:

1. **One assertion concept per test** - Each test verifies one behavior
2. **Arrange-Act-Assert pattern** - Clearly separated sections
3. **Descriptive test names** - `MethodName_StateOrCondition_ExpectedBehavior`
4. **FluentAssertions** - Use `.Should()` chains, not `Assert.Equal`
5. **NSubstitute** - Use `Substitute.For<T>()` for mocking, not manual fakes
6. **No test interdependence** - Each test must be independently runnable
7. **Match existing patterns** - Follow the project's established conventions

### Test Generation for a Service Class

Given an uncovered `ProductService.DeleteAsync` method:

```csharp
public async Task<bool> DeleteAsync(Guid id, CancellationToken ct)
{
    var product = await _unitOfWork.Products.GetByIdAsync(id, ct)
        ?? throw new ProductNotFoundException(id);

    product.IsDeleted = true;
    product.DeletedAt = DateTimeOffset.UtcNow;

    await _unitOfWork.SaveChangesAsync(ct);
    _logger.LogInformation("Deleted product {ProductId}", id);

    return true;
}
```

Generate test cases:

```csharp
[Fact]
public async Task DeleteAsync_WhenProductExists_ReturnsTrue()
{
    // Arrange
    var productId = Guid.NewGuid();
    var product = CreateTestProduct(productId);
    _repository.GetByIdAsync(productId, Arg.Any<CancellationToken>())
        .Returns(product);

    // Act
    var result = await _sut.DeleteAsync(productId, CancellationToken.None);

    // Assert
    result.Should().BeTrue();
}

[Fact]
public async Task DeleteAsync_WhenProductExists_SetsIsDeleted()
{
    // Arrange
    var productId = Guid.NewGuid();
    var product = CreateTestProduct(productId);
    _repository.GetByIdAsync(productId, Arg.Any<CancellationToken>())
        .Returns(product);

    // Act
    await _sut.DeleteAsync(productId, CancellationToken.None);

    // Assert
    product.IsDeleted.Should().BeTrue();
    product.DeletedAt.Should().BeCloseTo(
        DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
}

[Fact]
public async Task DeleteAsync_WhenProductExists_SavesChanges()
{
    // Arrange
    var productId = Guid.NewGuid();
    var product = CreateTestProduct(productId);
    _repository.GetByIdAsync(productId, Arg.Any<CancellationToken>())
        .Returns(product);

    // Act
    await _sut.DeleteAsync(productId, CancellationToken.None);

    // Assert
    await _unitOfWork.Received(1)
        .SaveChangesAsync(Arg.Any<CancellationToken>());
}

[Fact]
public async Task DeleteAsync_WhenProductNotFound_ThrowsNotFoundException()
{
    // Arrange
    var productId = Guid.NewGuid();
    _repository.GetByIdAsync(productId, Arg.Any<CancellationToken>())
        .Returns((Product?)null);

    // Act
    var act = () => _sut.DeleteAsync(productId, CancellationToken.None);

    // Assert
    await act.Should()
        .ThrowAsync<ProductNotFoundException>()
        .Where(ex => ex.ProductId == productId);
}
```

## Validation After Generation

### Step 1: Run Tests

After generating tests for a class, verify they pass:

```bash
dotnet test --no-build --filter "FullyQualifiedName~ProductServiceTests"
```

If tests fail, diagnose and fix the generated tests. Do not modify source code to make tests pass.

### Step 2: Run Format Check

Ensure generated test code matches the project's formatting rules:

```bash
dotnet format --verify-no-changes --no-restore --exclude obj/ --exclude Migrations/
```

If formatting fails, run `dotnet format` on the new test files only.

### Step 3: Measure New Coverage

Re-run coverage collection to verify the improvement:

```bash
dotnet test \
    --collect:"XPlat Code Coverage" \
    --results-directory ./TestResults \
    -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
```

Parse the new report and compare with the baseline.

### Step 4: Report Improvement

```text
Coverage Improvement for ProductService
=======================================
Before: 75.0% (36/48 lines)
After:  93.8% (45/48 lines)
Delta:  +18.8% (+9 lines covered)
Remaining uncovered: 3 lines (unreachable error paths)
```

## Commit Strategy

### One Commit per Class

After validating tests for each class, create a focused commit:

```bash
# Stage only the test file(s) for this class
git add tests/Catalog.Application.Tests/Services/ProductServiceTests.cs

# Commit with coverage delta in message
git commit -m "test(ProductService): improve coverage from 75% to 94%

Add tests for DeleteAsync, UpdatePriceAsync, and error handling paths.
Coverage delta: +18.8% (9 additional lines covered)."
```

### Commit Message Format

Follow this pattern for each commit:

```text
test(<ClassName>): improve coverage from <before>% to <after>%

Add tests for <methods>. Coverage delta: +<delta>% (<N> additional lines covered).
```

## Cleanup

### Remove TestResults Directory

After all classes are processed, clean up the TestResults directory:

```bash
rm -rf ./TestResults
```

This prevents stale coverage data from interfering with future runs.

## Edge Cases

### Classes Without Testable Logic

Some classes may have low coverage but are not worth testing:

- **Auto-generated code**: Migrations, designer files
- **Pure configuration**: DI registration classes that only call `.AddScoped()`
- **Thin wrappers**: Classes that delegate entirely to another service

Report these as "skipped" with a reason rather than generating meaningless tests.

### Classes with External Dependencies

For classes that depend on external systems (HTTP clients, message queues):

1. Test the logic around the external call, not the call itself
2. Use NSubstitute to mock the external dependency
3. Verify the correct arguments are passed to the dependency

### Concurrency and Async Edge Cases

When testing async code:

1. Always use `async Task` test methods, not `async void`
2. Test cancellation by passing a cancelled `CancellationToken`
3. Test exception propagation from async methods
4. Use `FluentActions.Invoking()` for async exception assertions

## Coverage Thresholds by Layer

Recommended coverage thresholds vary by architectural layer:

- **Domain models**: 95%+ (pure logic, easy to test)
- **Application services**: 90%+ (business rules, mock dependencies)
- **Infrastructure**: 70%+ (often requires integration tests)
- **API layer**: 80%+ (endpoint routing and validation)

Report which layer each class belongs to for context in the coverage report.
