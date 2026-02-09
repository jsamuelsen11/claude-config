---
description: Autonomous per-file test coverage improvement
argument-hint: [--threshold=90] [--file=<path>] [--dry-run] [--no-commit]
allowed-tools: Bash(uv *), Bash(git *), Read, Write, Edit, Grep, Glob
---

# coverage

Autonomously analyze test coverage and generate targeted tests to improve coverage metrics. This
command identifies untested code paths, writes meaningful tests following project patterns, and
optionally commits each improvement incrementally.

## Usage

```bash
ccfg python coverage                              # Target 90% coverage, auto-commit
ccfg python coverage --threshold=95               # Custom threshold
ccfg python coverage --file=src/api/handlers.py   # Target specific file
ccfg python coverage --dry-run                    # Report gaps, no changes
ccfg python coverage --no-commit                  # Write tests but don't commit
```

## Overview

The coverage command operates autonomously to improve test coverage by:

1. **Measuring** current coverage with pytest-cov
1. **Identifying** files and code paths below threshold
1. **Analyzing** untested branches, functions, and edge cases
1. **Generating** meaningful tests matching project patterns
1. **Validating** tests pass and meet quality standards
1. **Committing** improvements incrementally per file

This is not just line coverage. The command analyzes:

- Untested functions and methods
- Uncovered conditional branches
- Exception handling paths
- Edge cases and boundary conditions
- Error scenarios and validation logic

## Execution Modes

### Default Mode

Full autonomous operation with incremental commits.

**Behavior**:

1. Measure coverage across entire project
1. Identify files below threshold (default 90%)
1. For each file, generate and commit tests
1. Stop when threshold reached or all files processed

**Use when**:

- Ready to commit coverage improvements
- Trust automated test generation
- Want incremental git history

### Dry Run Mode

Report coverage gaps and describe what would be tested, without writing any code.

**Behavior**:

1. Measure coverage
1. Identify untested code paths
1. Display detailed report of what tests would be generated
1. Exit without modifying files

**Use when**:

- Auditing test coverage
- Planning test strategy
- Understanding coverage gaps
- Verifying command behavior

### No Commit Mode

Generate tests but leave them uncommitted for manual review.

**Behavior**:

1. Measure coverage
1. Generate and write tests
1. Run validation (pytest, ruff)
1. Leave changes staged for user review

**Use when**:

- Want to review tests before committing
- Integrating into manual workflow
- Need to adjust generated tests
- Testing in CI/CD pipeline

### File-Specific Mode

Target a single file for coverage improvement.

**Behavior**:

1. Measure coverage for specified file only
1. Generate tests if below threshold
1. Commit improvement (unless --no-commit)

**Use when**:

- Focusing on specific module
- Incremental coverage improvement
- Responding to code review feedback

## Step-by-Step Process

### 1. Measure Current Coverage

Run pytest with coverage reporting:

```bash
uv run pytest --cov=src --cov-report=term-missing --cov-report=json
```

**Coverage report format**:

```text
Name                    Stmts   Miss  Cover   Missing
-----------------------------------------------------
src/api/handlers.py        45      8    82%   23-25, 45-48, 67
src/core/processor.py      89      3    97%   102-104
src/models/user.py         34     15    56%   12-18, 34-42
-----------------------------------------------------
TOTAL                     168     26    85%
```

**Parse coverage data**:

- Extract file-level coverage percentages
- Identify specific uncovered line numbers
- Note branch coverage if available
- Capture total project coverage

### 2. Identify Coverage Gaps

Prioritize files for improvement based on:

1. **Coverage delta**: Files furthest below threshold
1. **Code importance**: Core functionality before utilities
1. **Test complexity**: Easier wins first (simple functions before complex state machines)
1. **Dependencies**: Test foundations before dependents

**Ranking example**:

```text
Priority | File                    | Coverage | Gap  | Lines Missing
---------|-------------------------|----------|------|---------------
1        | src/models/user.py      | 56%      | 34%  | 15 lines
2        | src/api/handlers.py     | 82%      | 8%   | 8 lines
3        | src/core/processor.py   | 97%      | 0%   | (above threshold)
```

### 3. Analyze Untested Code

For each under-threshold file, perform deep analysis:

#### Read Source File

```python
# Read the implementation
source_path = Path("src/models/user.py")
source_code = source_path.read_text()
```

#### Identify Untested Elements

Analyze AST and coverage data to find:

**Untested functions**:

```python
def validate_email(email: str) -> bool:  # Line 12 - UNCOVERED
    if not email or "@" not in email:
        return False
    return True
```

**Untested branches**:

```python
def process_user(user: User) -> Result:
    if user.is_active:  # True branch COVERED
        return activate(user)
    else:  # False branch UNCOVERED
        return deactivate(user)
```

**Untested exception paths**:

```python
def fetch_data(url: str) -> dict:  # Line 45 - UNCOVERED exception path
    try:
        response = requests.get(url)
        return response.json()
    except requests.RequestException:  # UNCOVERED
        return {}
```

**Untested edge cases**:

```python
def calculate_discount(price: float, code: str) -> float:
    # COVERED: normal case (price=100, code="SAVE10")
    # UNCOVERED: boundary cases (price=0, empty code, invalid code)
    # UNCOVERED: edge cases (negative price, None values)
```

#### Read Existing Tests

```python
# Find corresponding test file
test_path = Path("tests/test_user.py")
if test_path.exists():
    existing_tests = test_path.read_text()
else:
    existing_tests = None
```

**Learn from existing tests**:

- Naming conventions (test*\*, test*_*with*_, test*\*\_raises*\*)
- Fixture usage patterns
- Assertion style
- Test organization (grouped by class/function)
- Mocking patterns
- Parametrization usage

### 4. Generate Targeted Tests

Create tests that address specific coverage gaps.

#### Principles

1. **Test behavior, not implementation**: Focus on observable outcomes
1. **Meaningful assertions**: Verify actual functionality, not just execution
1. **Real scenarios**: Avoid tests that just call functions and assert True
1. **Edge cases matter**: Test boundaries, empty inputs, None values
1. **Exception handling**: Verify errors are raised correctly
1. **Follow patterns**: Match existing test style and structure

#### Test Generation Examples

**For untested function**:

Source code:

```python
def calculate_total(items: list[float], tax_rate: float = 0.1) -> float:
    """Calculate total with tax."""
    subtotal = sum(items)
    return subtotal * (1 + tax_rate)
```

Generated test:

```python
def test_calculate_total_with_items() -> None:
    """Test total calculation with multiple items."""
    items = [10.0, 20.0, 30.0]
    result = calculate_total(items)
    assert result == 66.0  # (10 + 20 + 30) * 1.1


def test_calculate_total_empty_list() -> None:
    """Test total calculation with empty items."""
    result = calculate_total([])
    assert result == 0.0


def test_calculate_total_custom_tax_rate() -> None:
    """Test total calculation with custom tax rate."""
    items = [100.0]
    result = calculate_total(items, tax_rate=0.2)
    assert result == 120.0
```

**For untested branch**:

Source code:

```python
def process_payment(amount: float, method: str) -> bool:
    """Process payment using specified method."""
    if method == "card":
        return process_card_payment(amount)
    elif method == "cash":
        return process_cash_payment(amount)
    else:
        raise ValueError(f"Unknown payment method: {method}")
```

Generated test (if card path covered but cash path not):

```python
def test_process_payment_with_cash(mock_cash_processor: Mock) -> None:
    """Test payment processing with cash method."""
    mock_cash_processor.return_value = True
    result = process_payment(100.0, "cash")
    assert result is True
    mock_cash_processor.assert_called_once_with(100.0)


def test_process_payment_invalid_method() -> None:
    """Test payment processing with invalid method raises error."""
    with pytest.raises(ValueError, match="Unknown payment method: bitcoin"):
        process_payment(100.0, "bitcoin")
```

**For untested exception handling**:

Source code:

```python
def load_config(path: str) -> dict:
    """Load configuration from file."""
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError:
        raise ValueError(f"Invalid JSON in {path}")
```

Generated test:

```python
def test_load_config_missing_file() -> None:
    """Test loading config when file doesn't exist."""
    result = load_config("nonexistent.json")
    assert result == {}


def test_load_config_invalid_json(tmp_path: Path) -> None:
    """Test loading config with invalid JSON raises error."""
    config_file = tmp_path / "bad.json"
    config_file.write_text("{invalid json}")

    with pytest.raises(ValueError, match="Invalid JSON in"):
        load_config(str(config_file))
```

#### Integration with Fixtures

Use existing fixtures from conftest.py:

```python
# conftest.py has:
@pytest.fixture
def sample_user() -> User:
    return User(id=1, name="Test", email="test@example.com")

# Generated test uses it:
def test_user_validation(sample_user: User) -> None:
    """Test user validation with fixture."""
    assert sample_user.is_valid()
```

If needed fixtures don't exist, add them to conftest.py:

```python
@pytest.fixture
def mock_database() -> Iterator[Mock]:
    """Mock database connection for testing."""
    db = Mock()
    db.execute.return_value = []
    yield db
    db.close()
```

#### Parametrized Tests

Use parametrization for multiple similar cases:

```python
@pytest.mark.parametrize(
    "input_value,expected",
    [
        (0, False),
        (1, True),
        (100, True),
        (-1, False),
        (None, False),
    ],
)
def test_is_positive(input_value: int | None, expected: bool) -> None:
    """Test positive number validation with various inputs."""
    result = is_positive(input_value)
    assert result == expected
```

### 5. Validate Generated Tests

Before committing, ensure tests meet quality standards:

#### Run Tests

```bash
uv run pytest tests/test_user.py -v
```

**Verification**:

- All new tests pass
- No test failures or errors
- Execution time reasonable (< 1s per test typically)
- No warnings about deprecated features

#### Lint Tests

```bash
uv run ruff check tests/test_user.py
```

**Verification**:

- No style violations
- Proper imports
- Consistent formatting
- Type hints present

#### Measure Coverage Improvement

```bash
uv run pytest --cov=src/models/user.py --cov-report=term-missing
```

**Verification**:

- Coverage increased toward threshold
- Previously missing lines now covered
- No regression in other files

### 6. Commit Improvement

For each file improved, create a focused commit:

```bash
git add tests/test_user.py
git commit -m "$(cat <<'EOF'
test: add coverage for user model

- Test email validation edge cases
- Cover inactive user branch
- Add error handling tests

Coverage: 56% -> 92%

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

**Commit message format**:

- **Subject**: `test: add coverage for <module>`
- **Body**: Bullet list of what was tested
- **Footer**: Coverage improvement and co-author tag

**One commit per file**:

- Makes review easier
- Allows selective revert
- Creates clear history
- Enables bisecting if issues arise

### 7. Report Progress

After each file, show progress:

```text
[1/3] src/models/user.py
  Before: 56% coverage (15 lines missing)
  After:  92% coverage (3 lines missing)
  Tests added: 8
  ✓ Committed: test: add coverage for user model

[2/3] src/api/handlers.py
  Before: 82% coverage (8 lines missing)
  After:  94% coverage (2 lines missing)
  Tests added: 4
  ✓ Committed: test: add coverage for api handlers

[3/3] src/core/processor.py
  Before: 97% coverage (3 lines missing)
  Status: Above threshold, skipped

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Coverage Improvement Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total coverage: 85% -> 93%
Files improved: 2
Tests added: 12
Commits created: 2

Files still below threshold:
  (none)

✓ Target coverage achieved!
```

## Key Rules and Requirements

### Test Quality Standards

1. **No trivial tests**: Never write tests like `assert True` or tests that just verify function
   execution without checking outcomes

1. **Real behavior**: Tests must verify actual functionality, not just that code runs

1. **Meaningful assertions**: Assert on specific values, types, and states - not just "something was
   returned"

1. **Edge cases**: Test boundaries, empty inputs, None values, maximum sizes, etc.

1. **Error paths**: Verify exceptions are raised with correct types and messages

1. **No over-mocking**: Mock external dependencies, but test real logic

### Pattern Matching

Generated tests must follow project conventions:

**Naming**:

- Match existing test name patterns
- Use descriptive names that explain what's tested
- Follow `test_` or `_test.py` convention

**Structure**:

- Group tests logically (by class or module section)
- Use same fixture patterns as existing tests
- Follow AAA pattern (Arrange, Act, Assert)

**Style**:

- Match docstring format
- Use same assertion style
- Follow type hint conventions
- Respect line length and formatting

### Commit Discipline

1. **One commit per file**: Never combine multiple files in one commit

1. **Descriptive messages**: Explain what was tested, not just "add tests"

1. **Include metrics**: Show coverage improvement in commit message

1. **Co-author tag**: Always include Claude co-author line

1. **Never amend**: Create new commits, don't modify existing ones

### Coverage Metrics

1. **Line coverage primary**: Focus on covering uncovered lines first

1. **Branch coverage secondary**: Ensure all conditional paths tested

1. **Realistic targets**: 90% is standard, 100% often impractical

1. **Exclude when appropriate**: Some code (debug helpers, typing stubs) can be excluded

### Error Handling

**If test generation fails**:

- Report which file failed
- Continue with next file
- Don't leave partial changes

**If tests don't pass**:

- Fix the test, don't commit failing tests
- If unfixable, skip file and report issue
- Never commit broken tests

**If coverage doesn't improve**:

- Analyze why (maybe wrong lines targeted)
- Adjust test strategy
- Report if file is untestable

## Dry Run Mode Details

When running with `--dry-run`, provide detailed report:

```text
Coverage Analysis Report
========================

Current total coverage: 85%
Target threshold: 90%
Files below threshold: 3

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: src/models/user.py
Coverage: 56% (34% below threshold)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Uncovered lines: 12-18, 34-42

Untested code paths:
  1. Function: validate_email (lines 12-15)
     - Missing test for invalid email format
     - Missing test for empty email

  1. Branch: User.is_active == False (line 34)
     - Missing test for inactive user path

  1. Exception: ValueError in parse_date (line 40)
     - Missing test for invalid date format

Proposed tests (8):
  - test_validate_email_invalid_format()
  - test_validate_email_empty_string()
  - test_validate_email_missing_at_symbol()
  - test_user_process_inactive()
  - test_parse_date_invalid_format()
  - test_parse_date_empty_string()
  - test_user_full_name_with_middle()
  - test_user_age_calculation_boundary()

Estimated coverage after: 92%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Similar reports for other files...]

Summary:
- Would add 23 tests across 3 files
- Estimated total coverage: 93%
- Would create 3 commits

Run without --dry-run to implement these changes.
```

## Advanced Usage

### Custom Threshold per Module

While not a direct flag, you can target different thresholds:

```bash
# Critical modules need 95%+
ccfg python coverage --file=src/core/security.py --threshold=95

# Utilities can be 85%
ccfg python coverage --file=src/utils/helpers.py --threshold=85
```

### Incremental Improvement

Improve coverage gradually over time:

```bash
# Sprint 1: Get to 80%
ccfg python coverage --threshold=80

# Sprint 2: Reach 90%
ccfg python coverage --threshold=90

# Sprint 3: Push to 95%
ccfg python coverage --threshold=95
```

### Focus on Specific Package

```bash
# Only improve API coverage
ccfg python coverage --file=src/api/*.py

# Or target specific module
ccfg python coverage --file=src/models/
```

### Integration with CI/CD

```yaml
# .github/workflows/coverage.yml
name: Coverage Check

on: [pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check coverage
        run: ccfg python coverage --dry-run --threshold=90

      - name: Fail if below threshold
        run: |
          coverage=$(uv run pytest --cov=src --cov-report=json | jq .totals.percent_covered)
          if (( $(echo "$coverage < 90" | bc -l) )); then
            echo "Coverage $coverage% below 90% threshold"
            exit 1
          fi
```

### Exclude Patterns

Some code shouldn't be covered:

```toml
# pyproject.toml
[tool.coverage.run]
omit = [
    "*/tests/*",
    "*/migrations/*",
    "*/__main__.py",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
]
```

## Common Scenarios

### Scenario 1: New Project

Fresh project with minimal tests:

```bash
ccfg python coverage
```

**Expected behavior**:

- Many files below threshold
- Generates comprehensive test suite
- May take 10-15 minutes for large project
- Creates many commits

### Scenario 2: Legacy Codebase

Old code with no tests:

```bash
# Start with dry run to assess scope
ccfg python coverage --dry-run

# Then improve incrementally
ccfg python coverage --threshold=70  # Start low
ccfg python coverage --threshold=80  # Increase gradually
```

### Scenario 3: Pre-Release Quality Gate

Ensure release candidate meets coverage standards:

```bash
ccfg python coverage --threshold=95 --no-commit
# Review generated tests
git diff tests/
# Commit manually if satisfied
git add tests/
git commit -m "test: achieve 95% coverage for v1.0 release"
```

### Scenario 4: File-Specific Review Feedback

Code review asks for more tests on specific file:

```bash
ccfg python coverage --file=src/api/handlers.py --threshold=95
```

### Scenario 5: CI Integration

Automated coverage enforcement:

```bash
# In CI pipeline
ccfg python coverage --dry-run
if [ $? -ne 0 ]; then
  echo "Coverage below threshold, see report above"
  exit 1
fi
```

## Troubleshooting

### Coverage doesn't increase

**Possible causes**:

- Tests generated but don't exercise target code
- Incorrect file paths in coverage report
- Code is actually unreachable

**Solutions**:

- Review generated tests manually
- Check coverage report with `--cov-report=html`
- Consider if uncovered code is dead code

### Generated tests fail

**Possible causes**:

- Misunderstood code behavior
- Missing dependencies or fixtures
- Incorrect mocking

**Solutions**:

- Command should fix and retry
- May skip file if unfixable
- Report issue for manual resolution

### Tests too slow

**Possible causes**:

- Testing actual external services
- Large data generation
- Complex setup/teardown

**Solutions**:

- Mock external dependencies
- Use smaller test data
- Optimize fixture scope

### Coverage report missing files

**Possible causes**:

- Files not in src/ directory
- Import errors prevent measurement
- Coverage config excludes them

**Solutions**:

- Check pyproject.toml coverage config
- Verify imports work
- Adjust --cov paths

## Best Practices

### When to Use Coverage Command

**Good use cases**:

- Pre-release quality gates
- Responding to coverage drops
- Improving new modules
- Systematic test improvement

**Not recommended for**:

- Achieving 100% coverage (diminishing returns)
- Testing code you don't understand
- Replacing manual test design
- Covering dead code

### Reviewing Generated Tests

Even in auto-commit mode, review commits:

```bash
# After coverage command
git log --oneline -n 5
git show HEAD  # Review last commit

# If issues found
git reset --soft HEAD~1  # Undo commit, keep changes
# Fix tests
git commit --amend
```

### Combining with Manual Testing

Use coverage command to:

1. Identify gaps
1. Generate baseline tests
1. Then add manual tests for:
   - Complex business logic
   - Integration scenarios
   - Performance characteristics

### Maintaining Coverage

After using coverage command:

- Add pre-commit hook for coverage check
- Enforce threshold in CI/CD
- Review coverage reports regularly
- Don't let coverage drop

## Integration with Other Commands

### Before Coverage

```bash
ccfg python validate        # Ensure baseline quality
```

### After Coverage

```bash
ccfg python validate        # Verify all tests pass
git push                    # Push coverage improvements
```

### With Scaffold

```bash
ccfg python scaffold mylib
cd mylib
ccfg python coverage --threshold=100  # Start with perfect coverage
```

## Output Format Examples

### Success Output

```text
Running coverage analysis...

Current coverage: 85%
Target threshold: 90%
Files to improve: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/2] Improving src/models/user.py

  Analyzing uncovered code...
  - 3 untested functions
  - 2 untested branches
  - 1 untested exception handler

  Generating tests...
  ✓ Generated 8 tests in tests/test_user.py

  Validating...
  ✓ All tests pass (8/8)
  ✓ Ruff check passed
  ✓ Coverage: 56% -> 92%

  Committing...
  ✓ Committed: test: add coverage for user model

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[2/2] Improving src/api/handlers.py

  Analyzing uncovered code...
  - 1 untested function
  - 1 untested exception handler

  Generating tests...
  ✓ Generated 4 tests in tests/test_handlers.py

  Validating...
  ✓ All tests pass (4/4)
  ✓ Ruff check passed
  ✓ Coverage: 82% -> 94%

  Committing...
  ✓ Committed: test: add coverage for api handlers

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Coverage Improvement Complete!

Summary:
  Files improved: 2
  Tests added: 12
  Commits created: 2

  Before: 85% coverage
  After:  93% coverage
  Change: +8%

✓ Target threshold (90%) achieved!
```

### Failure Output

```text
Running coverage analysis...

Current coverage: 85%
Target threshold: 90%
Files to improve: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/2] Improving src/models/user.py

  Analyzing uncovered code...
  - 3 untested functions

  Generating tests...
  ✓ Generated 8 tests in tests/test_user.py

  Validating...
  ✗ Test failures (2/8 failed)

  Fixing failing tests...
  ✓ Retried and fixed 2 tests

  Re-validating...
  ✓ All tests pass (8/8)
  ✓ Coverage: 56% -> 92%

  Committing...
  ✓ Committed: test: add coverage for user model

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[2/2] Improving src/api/handlers.py

  Analyzing uncovered code...
  - Complex async code with external dependencies

  ⚠ Warning: Unable to generate reliable tests
  Reason: Code requires extensive mocking of external services

  Suggestion: Manually design integration tests for this module
  ⊘ Skipped

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Coverage Improvement Partial

Summary:
  Files improved: 1
  Files skipped: 1
  Tests added: 8
  Commits created: 1

  Before: 85% coverage
  After:  88% coverage
  Change: +3%

⚠ Target threshold (90%) not achieved

Files still below threshold:
  - src/api/handlers.py (82% coverage, needs manual tests)

Consider manually writing tests for complex modules.
```

## Summary

The coverage command provides autonomous test generation to systematically improve code coverage. By
analyzing uncovered code paths, learning from existing test patterns, and generating meaningful
tests, it accelerates the path to comprehensive test suites.

The command prioritizes test quality over mere line coverage, ensuring generated tests verify real
behavior rather than just executing code. With incremental commits and validation at each step, it
maintains code quality while building robust test coverage.

Use coverage command as part of a complete testing strategy, combining automated gap-filling with
thoughtful manual test design for complex business logic and integration scenarios.
