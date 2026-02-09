---
description: Autonomous per-package test coverage improvement loop
argument-hint: '[--threshold=90] [--package=<path>] [--dry-run] [--no-commit]'
allowed-tools: 'Bash(go *), Bash(git *), Read, Write, Edit, Grep, Glob'
---

# Go Coverage Improvement Command

You are executing the `coverage` command to autonomously improve test coverage across a Go project
by analyzing gaps and generating comprehensive tests.

## Command Arguments

### Optional: --threshold

Minimum coverage percentage to achieve (default: 90).

```bash
claude-code ccfg-golang coverage --threshold=85
```

#### Optional: --package

Target specific package instead of entire project.

```bash
claude-code ccfg-golang coverage --package=./internal/service
```

#### Optional: --dry-run

Report coverage gaps without generating tests.

```bash
claude-code ccfg-golang coverage --dry-run
```

#### Optional: --no-commit

Generate tests but don't auto-commit changes.

```bash
claude-code ccfg-golang coverage --no-commit
```

## Execution Strategy

### Phase 1: Coverage Analysis

Measure current test coverage and identify gaps.

1. Run tests with coverage profile
1. Parse coverage report per package
1. Identify packages below threshold
1. Rank packages by coverage gap
1. Report current state

#### Phase 2: Gap Identification

For each under-threshold package:

1. Read source files to understand structure
1. Identify untested functions and methods
1. Analyze existing test patterns
1. Determine test strategy

#### Phase 3: Test Generation

For each identified gap:

1. Generate table-driven tests
1. Include edge cases and error scenarios
1. Match existing code style
1. Add meaningful assertions

#### Phase 4: Validation

After generating tests:

1. Run tests to verify they pass
1. Check for race conditions
1. Run linter to ensure quality
1. Measure new coverage

#### Phase 5: Commit (unless --no-commit)

Create atomic commits per package:

1. Stage test files for one package
1. Commit with descriptive message
1. Repeat for each package

## Coverage Analysis

### Step 1: Generate Coverage Profile

Run tests with coverage collection:

```bash
go test ./... -coverprofile=coverage.out -covermode=atomic
```

Use atomic mode for accurate coverage with concurrent tests.

Expected output:

```text
ok      github.com/user/project/internal/config     0.123s  coverage: 85.7% of statements
ok      github.com/user/project/internal/handler    0.234s  coverage: 72.3% of statements
ok      github.com/user/project/internal/service    0.145s  coverage: 91.2% of statements
?       github.com/user/project/cmd/server          [no test files]
```

#### Step 2: Parse Coverage Report

Extract per-package coverage:

```bash
go tool cover -func=coverage.out
```

Expected output:

```text
github.com/user/project/internal/config/config.go:15:    Load            85.7%
github.com/user/project/internal/config/config.go:28:    getEnv          100.0%
github.com/user/project/internal/handler/handler.go:23:  New             100.0%
github.com/user/project/internal/handler/handler.go:35:  ServeHTTP       100.0%
github.com/user/project/internal/handler/handler.go:39:  handleHealth    80.0%
github.com/user/project/internal/handler/handler.go:52:  handleReady     60.0%
github.com/user/project/internal/handler/handler.go:67:  handleRoot      75.0%
github.com/user/project/internal/service/service.go:12:  New             100.0%
github.com/user/project/internal/service/service.go:18:  Ready           100.0%
total:                                                    (statements)    82.4%
```

#### Step 3: Rank Packages by Gap

Calculate coverage gap for each package:

```text
Package                                          Current   Gap
github.com/user/project/cmd/server              0.0%      90.0%
github.com/user/project/internal/handler        72.3%     17.7%
github.com/user/project/internal/config         85.7%     4.3%
github.com/user/project/internal/service        91.2%     0.0% ✓
```

#### Step 4: Report Initial State

Provide summary before improvements:

```text
=== Coverage Analysis ===

Project: github.com/user/project
Current Coverage: 82.4%
Target Threshold: 90.0%
Gap: 7.6%

Packages Below Threshold:
  1. cmd/server          0.0%  (gap: 90.0%) - NO TESTS
  2. internal/handler   72.3%  (gap: 17.7%) - 5 functions under-tested
  3. internal/config    85.7%  (gap:  4.3%) - 1 function under-tested

Packages Above Threshold:
  ✓ internal/service    91.2%

Planning to improve 3 packages...
```

## Gap Identification

For each package below threshold, analyze what needs testing.

### Identify Untested Functions

Parse the coverage report to find functions with low coverage:

```bash
go tool cover -func=coverage.out | grep "internal/handler"
```

Extract functions with coverage below threshold:

```text
handleHealth    80.0%  - needs edge case testing
handleReady     60.0%  - missing error scenarios
handleRoot      75.0%  - incomplete method coverage
```

#### Analyze Source Code

Read source files to understand function signatures and logic:

```go
func (h *Handler) handleReady(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    if !h.service.Ready() {
        http.Error(w, "Service not ready", http.StatusServiceUnavailable)
        return
    }

    response := map[string]string{
        "status": "ready",
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    _ = json.NewEncoder(w).Encode(response)
}
```

Identify untested paths:

1. POST/PUT/DELETE methods (line 2-5)
1. Service not ready scenario (line 7-10)
1. JSON encoding success (line 17-18)

#### Analyze Existing Tests

Read existing test files to match style and patterns:

```bash
# Find test files in package
find ./internal/handler -name "*_test.go"
```

Read test files to understand:

1. Table-driven test structure
1. Test helper functions
1. Mock/stub patterns
1. Assertion style
1. Subtest naming conventions

#### Determine Test Strategy

For each untested path, plan test cases:

```text
handleReady function:
  ✓ GET request with ready service (existing)
  ✗ POST request (needs test)
  ✗ Service not ready (needs test)
  ✗ JSON encoding (covered by existing)

New tests needed:
  1. TestReadyEndpoint_MethodNotAllowed
  2. TestReadyEndpoint_ServiceNotReady
```

## Test Generation

Generate comprehensive, table-driven tests for identified gaps.

### Test Template Structure

Use this structure for all generated tests:

```go
func TestFunctionName(t *testing.T) {
    tests := []struct {
        name    string
        // input fields
        want    expectedType
        wantErr bool
    }{
        {
            name: "descriptive test case name",
            // input values
            want: expectedValue,
            wantErr: false,
        },
        // more test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // test execution
            // assertions
        })
    }
}
```

#### Example: Handler Test Generation

For the handleReady function, generate:

```go
func TestReadyEndpoint_MethodNotAllowed(t *testing.T) {
    tests := []struct {
        name       string
        method     string
        wantStatus int
    }{
        {
            name:       "POST method",
            method:     http.MethodPost,
            wantStatus: http.StatusMethodNotAllowed,
        },
        {
            name:       "PUT method",
            method:     http.MethodPut,
            wantStatus: http.StatusMethodNotAllowed,
        },
        {
            name:       "DELETE method",
            method:     http.MethodDelete,
            wantStatus: http.StatusMethodNotAllowed,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            cfg := &config.Config{
                Port:        8080,
                Environment: "test",
                LogLevel:    "debug",
            }
            svc := service.New(cfg)
            h := New(svc)

            req := httptest.NewRequest(tt.method, "/ready", nil)
            w := httptest.NewRecorder()

            h.ServeHTTP(w, req)

            if w.Code != tt.wantStatus {
                t.Errorf("Expected status %d, got %d", tt.wantStatus, w.Code)
            }
        })
    }
}

func TestReadyEndpoint_ServiceNotReady(t *testing.T) {
    // Create mock service that returns not ready
    cfg := &config.Config{
        Port:        8080,
        Environment: "test",
        LogLevel:    "debug",
    }
    svc := &mockService{ready: false}
    h := New(svc)

    req := httptest.NewRequest(http.MethodGet, "/ready", nil)
    w := httptest.NewRecorder()

    h.ServeHTTP(w, req)

    if w.Code != http.StatusServiceUnavailable {
        t.Errorf("Expected status 503, got %d", w.Code)
    }

    body := w.Body.String()
    if !strings.Contains(body, "Service not ready") {
        t.Errorf("Expected 'Service not ready' in body, got %s", body)
    }
}

// mockService implements a test double for Service
type mockService struct {
    ready bool
}

func (m *mockService) Ready() bool {
    return m.ready
}
```

#### Example: Business Logic Test Generation

For a business logic function:

```go
// Source function
func (s *Service) ValidateUser(user *User) error {
    if user == nil {
        return errors.New("user cannot be nil")
    }
    if user.Email == "" {
        return errors.New("email is required")
    }
    if !strings.Contains(user.Email, "@") {
        return errors.New("invalid email format")
    }
    return nil
}

// Generated test
func TestValidateUser(t *testing.T) {
    tests := []struct {
        name    string
        user    *User
        wantErr bool
        errMsg  string
    }{
        {
            name: "valid user",
            user: &User{
                Email: "user@example.com",
            },
            wantErr: false,
        },
        {
            name:    "nil user",
            user:    nil,
            wantErr: true,
            errMsg:  "user cannot be nil",
        },
        {
            name: "empty email",
            user: &User{
                Email: "",
            },
            wantErr: true,
            errMsg:  "email is required",
        },
        {
            name: "invalid email format",
            user: &User{
                Email: "notanemail",
            },
            wantErr: true,
            errMsg:  "invalid email format",
        },
        {
            name: "email with multiple @",
            user: &User{
                Email: "user@@example.com",
            },
            wantErr: false, // Contains @, so passes basic check
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            s := &Service{}
            err := s.ValidateUser(tt.user)

            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateUser() error = %v, wantErr %v", err, tt.wantErr)
                return
            }

            if tt.wantErr && err.Error() != tt.errMsg {
                t.Errorf("ValidateUser() error message = %v, want %v", err.Error(), tt.errMsg)
            }
        })
    }
}
```

#### Test Generation Guidelines

1. Generate table-driven tests for all functions
1. Include happy path and error cases
1. Test edge cases: nil, empty, zero values
1. Test boundary conditions
1. Add descriptive test names
1. Include error message validation
1. Use subtests for clarity
1. Match existing test patterns in the package
1. Create test helpers if needed
1. Add mock implementations when necessary

#### Mock Generation

When functions depend on interfaces, generate minimal mocks:

```go
// If source uses this interface
type UserRepository interface {
    Get(id string) (*User, error)
    Create(user *User) error
}

// Generate this mock
type mockUserRepository struct {
    getFunc    func(id string) (*User, error)
    createFunc func(user *User) error
}

func (m *mockUserRepository) Get(id string) (*User, error) {
    if m.getFunc != nil {
        return m.getFunc(id)
    }
    return nil, errors.New("not implemented")
}

func (m *mockUserRepository) Create(user *User) error {
    if m.createFunc != nil {
        return m.createFunc(user)
    }
    return errors.New("not implemented")
}
```

## Validation Phase

After generating tests, validate they work correctly.

### Run Generated Tests

Execute tests for the specific package:

```bash
go test ./internal/handler -v -race
```

Expected successful output:

```text
=== RUN   TestReadyEndpoint_MethodNotAllowed
=== RUN   TestReadyEndpoint_MethodNotAllowed/POST_method
=== RUN   TestReadyEndpoint_MethodNotAllowed/PUT_method
=== RUN   TestReadyEndpoint_MethodNotAllowed/DELETE_method
--- PASS: TestReadyEndpoint_MethodNotAllowed (0.00s)
    --- PASS: TestReadyEndpoint_MethodNotAllowed/POST_method (0.00s)
    --- PASS: TestReadyEndpoint_MethodNotAllowed/PUT_method (0.00s)
    --- PASS: TestReadyEndpoint_MethodNotAllowed/DELETE_method (0.00s)
=== RUN   TestReadyEndpoint_ServiceNotReady
--- PASS: TestReadyEndpoint_ServiceNotReady (0.00s)
PASS
ok      github.com/user/project/internal/handler    0.234s
```

#### Handle Test Failures

If generated tests fail:

1. Analyze the failure message
1. Check if assumptions about code behavior were wrong
1. Fix the test logic (not the source code)
1. Re-run tests
1. If persistent failures, report and skip package

Example failure handling:

```text
Test failure in internal/handler:
  TestReadyEndpoint_ServiceNotReady
  Expected status 503, got 200

Analysis: Mock service not properly integrated with handler.
Action: Updating handler instantiation to accept interface.
```

#### Run Race Detector

Always check for race conditions:

```bash
go test ./internal/handler -race
```

If races detected, fix the test setup:

1. Ensure proper synchronization in mocks
1. Avoid shared state between subtests
1. Use test-scoped variables

#### Run Linter

Ensure generated tests pass linting:

```bash
golangci-lint run ./internal/handler/...
```

Fix any issues:

1. Add missing comments for test helpers
1. Fix naming conventions
1. Remove unused variables
1. Address complexity warnings

#### Measure New Coverage

Re-run coverage analysis for the package:

```bash
go test ./internal/handler -coverprofile=coverage.out -covermode=atomic
go tool cover -func=coverage.out | grep "internal/handler"
```

Verify coverage improvement:

```text
Before: 72.3%
After:  94.2%
Improvement: +21.9%
```

## Commit Strategy

Create atomic commits per package (unless --no-commit).

### Commit Per Package

After successfully improving a package:

1. Stage only test files for that package
1. Create descriptive commit message
1. Include coverage improvement in message

```bash
git add internal/handler/handler_test.go
git commit -m "$(cat <<'EOF'
test(handler): improve coverage from 72.3% to 94.2%

Add table-driven tests for:
- HTTP method validation (POST, PUT, DELETE)
- Service not ready scenarios
- Error response formatting

Coverage improvement: +21.9%

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

#### Commit Message Format

Use this format for all commits:

```text
test(<package>): improve coverage from X% to Y%

Add tests for:
- Specific feature 1
- Specific feature 2
- Specific feature 3

Coverage improvement: +Z%

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

#### Handle Commit Failures

If commit fails (e.g., pre-commit hooks):

1. Run the failing check
1. Fix any issues in generated tests
1. Re-stage and commit
1. Don't use --no-verify

## Reporting

Provide comprehensive reports throughout execution.

### Initial Analysis Report

```text
=== Coverage Improvement Plan ===

Current State:
  Project coverage: 82.4%
  Target threshold: 90.0%
  Packages analyzed: 4
  Packages below threshold: 3

Improvement Plan:
  1. cmd/server (0.0% → 90.0%)
     - Create initial test suite
     - Test main() error paths
     - Test signal handling

  2. internal/handler (72.3% → 92.0%)
     - Add HTTP method tests
     - Test error scenarios
     - Improve response validation

  3. internal/config (85.7% → 90.0%)
     - Test invalid port parsing
     - Add environment variable tests

Estimated new tests: 24
Estimated time: 5-10 minutes
```

#### Progress Updates

Report after each package:

```text
[1/3] Processing cmd/server...
  ✓ Analyzed 3 functions
  ✓ Generated 12 test cases
  ✓ Tests pass (race-free)
  ✓ Linting clean
  ✓ Coverage: 0.0% → 91.2% (+91.2%)
  ✓ Committed: 8a3f2b1

[2/3] Processing internal/handler...
  ✓ Analyzed 5 functions
  ✓ Generated 8 test cases
  ✓ Tests pass (race-free)
  ✓ Linting clean
  ✓ Coverage: 72.3% → 94.2% (+21.9%)
  ✓ Committed: 7c2d9e4

[3/3] Processing internal/config...
  ✓ Analyzed 2 functions
  ✓ Generated 4 test cases
  ✓ Tests pass (race-free)
  ✓ Linting clean
  ✓ Coverage: 85.7% → 92.1% (+6.4%)
  ✓ Committed: 5f8a1c3
```

#### Final Summary

```text
=== Coverage Improvement Complete ===

Before:
  Project coverage: 82.4%
  Packages below threshold: 3

After:
  Project coverage: 92.3% ✓
  Packages below threshold: 0

Improvements:
  cmd/server:        0.0% → 91.2% (+91.2%)
  internal/handler: 72.3% → 94.2% (+21.9%)
  internal/config:  85.7% → 92.1% (+6.4%)

Tests Added: 24
Commits Created: 3
Time Taken: 6m 23s

All packages now meet the 90% coverage threshold.
```

#### Dry-Run Report

If --dry-run flag is used:

```text
=== Coverage Analysis (Dry Run) ===

Current coverage: 82.4%
Target threshold: 90.0%

Recommended improvements:

1. cmd/server (0.0%)
   Missing tests for:
   - main() function error handling
   - Signal handling and graceful shutdown
   - Configuration loading
   Estimated tests needed: 12

2. internal/handler (72.3%)
   Missing tests for:
   - handleReady() with POST/PUT/DELETE methods
   - handleReady() when service not ready
   - handleRoot() with invalid paths
   Estimated tests needed: 8

3. internal/config (85.7%)
   Missing tests for:
   - Load() with invalid PORT value
   - Environment variable combinations
   Estimated tests needed: 4

Total estimated tests: 24
Projected coverage: ~92%

Run without --dry-run to generate tests.
```

## Edge Cases and Error Handling

### No Test Files Exist

If a package has no tests:

1. Create new test file with appropriate name
1. Add package declaration
1. Add necessary imports
1. Generate complete test suite

#### Package Has Build Tags

Respect build tags in test generation:

```go
//go:build integration

package service_test
```

#### Unexported Functions

Focus on exported functions by default. For unexported functions with low coverage:

1. Test them indirectly through exported functions
1. Consider if they should be tested directly
1. Don't change export status just for testing

#### External Dependencies

When functions depend on external services:

1. Create interface wrappers if they don't exist
1. Generate mocks for the interfaces
1. Test with mocked dependencies

#### Context-Based Functions

For functions using context.Context:

```go
func TestWithContext(t *testing.T) {
    tests := []struct {
        name    string
        ctx     context.Context
        wantErr bool
    }{
        {
            name:    "valid context",
            ctx:     context.Background(),
            wantErr: false,
        },
        {
            name:    "canceled context",
            ctx:     canceledContext(),
            wantErr: true,
        },
        {
            name:    "timeout context",
            ctx:     timeoutContext(),
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := FunctionWithContext(tt.ctx)
            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}

func canceledContext() context.Context {
    ctx, cancel := context.WithCancel(context.Background())
    cancel()
    return ctx
}

func timeoutContext() context.Context {
    ctx, cancel := context.WithTimeout(context.Background(), 0)
    defer cancel()
    return ctx
}
```

## Best Practices

### Test Quality Standards

1. Every test must have a clear, descriptive name
1. Use table-driven tests for multiple scenarios
1. Include both success and failure cases
1. Test edge cases: nil, empty, zero, max values
1. Validate error messages, not just error existence
1. Use subtests for organization
1. Avoid test interdependence
1. Make tests deterministic (no random values)

#### Code Style Matching

1. Match existing import grouping
1. Use same assertion patterns
1. Follow existing naming conventions
1. Respect package testing style
1. Use same test helper patterns

#### Coverage Goals

1. Aim for meaningful coverage, not just high numbers
1. Don't test trivial getters/setters
1. Focus on business logic and error paths
1. Test public APIs thoroughly
1. Test error conditions comprehensively

## Cleanup

After completion, clean up temporary files:

```bash
rm -f coverage.out
```

Keep coverage.html if generated, as it's useful for review.

## Exit Codes

1. `0` - Coverage improvement successful or already above threshold
1. `1` - Failed to improve coverage (test failures, etc.)
1. `2` - Command error (invalid arguments, no go.mod)

## Integration with Validate Command

This command complements the validate command:

1. Run `coverage` to improve test coverage
1. Run `validate` to ensure quality gates pass
1. Both work together for high-quality code

Suggested workflow:

```bash
# Improve coverage
claude-code ccfg-golang coverage --threshold=90

# Validate everything
claude-code ccfg-golang validate
```

## Performance Considerations

For large projects:

1. Process packages in parallel when possible
1. Cache coverage analysis results
1. Skip packages already above threshold
1. Provide progress updates for long operations
1. Allow interruption with cleanup

## Final Notes

The coverage command is autonomous but transparent:

1. Shows what it plans to do before acting
1. Reports progress continuously
1. Explains decisions (which tests to generate)
1. Creates atomic commits for easy review
1. Allows dry-run mode for safety
1. Fails safe (doesn't break existing code)

Always prioritize test quality over coverage percentage. A well-tested codebase at 85% is better
than a poorly-tested one at 95%.
