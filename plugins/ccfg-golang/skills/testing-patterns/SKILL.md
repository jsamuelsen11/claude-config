---
name: testing-patterns
description:
  This skill should be used when writing Go tests, creating test fixtures, benchmarks, table-driven
  tests, mocking dependencies, or improving test coverage.
version: 0.1.0
---

# Go Testing Patterns and Best Practices

This skill defines comprehensive testing patterns for Go, covering unit tests, integration tests,
benchmarks, mocking, and test organization.

## Table-Driven Tests

### Default Testing Pattern

Table-driven tests are the standard pattern for Go testing. They reduce duplication and make it easy
to add new test cases.

```go
// CORRECT: Table-driven test pattern
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a        int
        b        int
        expected int
    }{
        {name: "positive numbers", a: 2, b: 3, expected: 5},
        {name: "negative numbers", a: -2, b: -3, expected: -5},
        {name: "mixed signs", a: -2, b: 3, expected: 1},
        {name: "zero values", a: 0, b: 0, expected: 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d, expected %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

```go
// WRONG: Repetitive individual tests
func TestAddPositive(t *testing.T) {
    got := Add(2, 3)
    if got != 5 {
        t.Errorf("expected 5, got %d", got)
    }
}

func TestAddNegative(t *testing.T) {
    got := Add(-2, -3)
    if got != -5 {
        t.Errorf("expected -5, got %d", got)
    }
}
// More duplication...
```

#### Use tt Loop Variable

Use tt as the conventional name for the table test variable.

```go
// CORRECT: Use tt for test case variable
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {name: "valid input", input: "test@example.com", wantErr: false},
        {name: "invalid input", input: "not-an-email", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := Validate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

```go
// WRONG: Inconsistent variable naming
for _, tc := range tests {  // Use tt, not tc or testCase
    t.Run(tc.name, func(t *testing.T) {
        // ...
    })
}
```

#### Descriptive Test Names

Use clear, descriptive names for test cases that explain what is being tested.

```go
// CORRECT: Descriptive test case names
tests := []struct {
    name string
    // ...
}{
    {name: "empty input returns error"},
    {name: "valid email passes validation"},
    {name: "email without @ symbol fails"},
    {name: "concurrent access is thread-safe"},
}
```

```go
// WRONG: Unclear test case names
tests := []struct {
    name string
    // ...
}{
    {name: "test1"},
    {name: "case2"},
    {name: "good"},
    {name: "bad"},
}
```

#### Always Use t.Run for Subtests

Use t.Run to create subtests for better test organization and parallel execution.

```go
// CORRECT: t.Run for subtests
func TestUserService(t *testing.T) {
    tests := []struct {
        name string
        id   string
        want *User
    }{
        {name: "existing user", id: "123", want: &User{ID: "123", Name: "Alice"}},
        {name: "non-existent user", id: "999", want: nil},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := service.GetUser(tt.id)
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("GetUser() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

```go
// WRONG: No subtests, harder to identify failures
func TestUserService(t *testing.T) {
    tests := []struct {
        id   string
        want *User
    }{
        {id: "123", want: &User{ID: "123"}},
        {id: "999", want: nil},
    }

    for _, tt := range tests {
        got := service.GetUser(tt.id)  // Can't tell which case failed
        if !reflect.DeepEqual(got, tt.want) {
            t.Errorf("failed for %s", tt.id)
        }
    }
}
```

## Test File Naming and Organization

### Use \_test.go Suffix

Test files must end with \_test.go and be in the same package or \_test package.

```go
// user.go
package user

type User struct {
    ID   string
    Name string
}
```

```go
// CORRECT: user_test.go (same package)
package user

import "testing"

func TestNewUser(t *testing.T) {
    u := NewUser("1", "Alice")
    if u.ID != "1" {
        t.Errorf("expected ID 1, got %s", u.ID)
    }
}
```

```go
// CORRECT: user_test.go (external test package)
package user_test

import (
    "testing"
    "myapp/user"
)

func TestUserAPI(t *testing.T) {
    u := user.NewUser("1", "Alice")
    // Test exported API only
}
```

#### Test Function Naming Convention

Test functions must start with Test, benchmarks with Benchmark, examples with Example.

```go
// CORRECT: Test function naming
func TestUserValidation(t *testing.T) {}
func TestUser_SetName(t *testing.T) {}
func TestUserService_GetUser_NotFound(t *testing.T) {}

func BenchmarkUserValidation(b *testing.B) {}
func BenchmarkUser_SetName(b *testing.B) {}

func ExampleUser_SetName() {}
```

```go
// WRONG: Invalid function names
func userValidation(t *testing.T) {}      // Must start with Test
func Test_user_validation(t *testing.T) {} // Use TestUserValidation
func testUserValidation(t *testing.T) {}   // Must start with capital T
```

## testify Package Usage

### require vs assert

Use require for critical assertions that should stop the test immediately. Use assert for
non-critical checks.

```go
// CORRECT: require for critical setup, assert for checks
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserService(t *testing.T) {
    db, err := setupTestDB()
    require.NoError(t, err, "failed to setup test DB")  // Stop if setup fails
    require.NotNil(t, db)

    svc := NewService(db)
    user, err := svc.GetUser("123")
    require.NoError(t, err)

    assert.Equal(t, "123", user.ID)          // Continue even if fails
    assert.Equal(t, "Alice", user.Name)      // Can check multiple fields
    assert.True(t, user.Active)
}
```

```go
// WRONG: Using assert for critical setup
func TestUserService(t *testing.T) {
    db, err := setupTestDB()
    assert.NoError(t, err)  // Test continues even if DB setup failed!

    svc := NewService(db)   // nil pointer panic if db is nil
    user, err := svc.GetUser("123")
}
```

#### require.NoError for Error Checks

Use require.NoError for clear error checking in tests.

```go
// CORRECT: require.NoError
func TestLoadConfig(t *testing.T) {
    cfg, err := LoadConfig("config.json")
    require.NoError(t, err, "LoadConfig should not return error")
    require.NotNil(t, cfg)

    assert.Equal(t, "localhost", cfg.Host)
    assert.Equal(t, 8080, cfg.Port)
}
```

```go
// WRONG: Manual error checking in tests
func TestLoadConfig(t *testing.T) {
    cfg, err := LoadConfig("config.json")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)  // Verbose
    }
    if cfg == nil {
        t.Fatal("cfg should not be nil")
    }
}
```

#### testify Table Tests

Combine table-driven tests with testify assertions.

```go
// CORRECT: Table tests with testify
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
        errMsg  string
    }{
        {
            name:    "valid email",
            email:   "user@example.com",
            wantErr: false,
        },
        {
            name:    "missing @ symbol",
            email:   "userexample.com",
            wantErr: true,
            errMsg:  "invalid email format",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

## HTTP Testing

### Use httptest.NewServer for Integration Tests

Use httptest.NewServer to create a test HTTP server for integration testing.

```go
// CORRECT: httptest.NewServer for integration tests
func TestAPIClient_GetUser(t *testing.T) {
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        assert.Equal(t, "/users/123", r.URL.Path)
        assert.Equal(t, "GET", r.Method)

        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{
            "id":   "123",
            "name": "Alice",
        })
    }))
    defer server.Close()

    client := NewClient(server.URL)
    user, err := client.GetUser("123")
    require.NoError(t, err)
    assert.Equal(t, "123", user.ID)
    assert.Equal(t, "Alice", user.Name)
}
```

#### Use httptest.NewRecorder for Unit Tests

Use httptest.NewRecorder to test HTTP handlers without starting a server.

```go
// CORRECT: httptest.NewRecorder for handler unit tests
func TestGetUserHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/123", nil)
    rec := httptest.NewRecorder()

    handler := GetUserHandler(mockUserService)
    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)

    var response map[string]string
    err := json.NewDecoder(rec.Body).Decode(&response)
    require.NoError(t, err)
    assert.Equal(t, "123", response["id"])
}
```

```go
// WRONG: Creating actual server for unit tests
func TestGetUserHandler(t *testing.T) {
    server := httptest.NewServer(GetUserHandler(mockUserService))  // Overkill
    defer server.Close()

    resp, err := http.Get(server.URL + "/users/123")
    // Unnecessary complexity for unit test
}
```

## Mocking with gomock

### Generate Mocks with mockgen

Use mockgen to generate mocks for interfaces. Store mocks in internal/mocks or package_test.go.

```bash
# Install mockgen
go install go.uber.org/mock/mockgen@latest

# Generate mocks
mockgen -source=user.go -destination=internal/mocks/user_mock.go -package=mocks
```

```go
// user.go - Interface to mock
package user

import "context"

type Repository interface {
    GetUser(ctx context.Context, id string) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}
```

```go
// CORRECT: Using generated mocks
package user_test

import (
    "context"
    "testing"
    "myapp/internal/mocks"
    "myapp/user"
    "go.uber.org/mock/gomock"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserService_GetUser(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := mocks.NewMockRepository(ctrl)
    mockRepo.EXPECT().
        GetUser(gomock.Any(), "123").
        Return(&user.User{ID: "123", Name: "Alice"}, nil)

    svc := user.NewService(mockRepo)
    u, err := svc.GetUser(context.Background(), "123")

    require.NoError(t, err)
    assert.Equal(t, "123", u.ID)
}
```

#### Store Mocks in internal/mocks Directory

Keep generated mocks organized in internal/mocks/ directory.

```text
myapp/
  internal/
    mocks/
      user_mock.go
      payment_mock.go
  user/
    user.go
    user_test.go
```

```go
// go:generate directive in source file
//go:generate mockgen -source=user.go -destination=../internal/mocks/user_mock.go -package=mocks
package user
```

#### Use gomock.InOrder for Sequential Expectations

Use gomock.InOrder when the order of method calls matters.

```go
// CORRECT: InOrder for sequential calls
func TestUserService_CreateAndNotify(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := mocks.NewMockRepository(ctrl)
    mockNotifier := mocks.NewMockNotifier(ctrl)

    gomock.InOrder(
        mockRepo.EXPECT().SaveUser(gomock.Any(), gomock.Any()).Return(nil),
        mockNotifier.EXPECT().SendWelcome(gomock.Any(), gomock.Any()).Return(nil),
    )

    svc := user.NewService(mockRepo, mockNotifier)
    err := svc.CreateUser(context.Background(), &user.User{Name: "Alice"})
    require.NoError(t, err)
}
```

## Test Helpers

### Mark Test Helpers with t.Helper

Use t.Helper() in test helper functions to report errors at the caller location.

```go
// CORRECT: Test helper with t.Helper()
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()  // Errors reported in calling test, not here

    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("failed to open test DB: %v", err)
    }

    if err := runMigrations(db); err != nil {
        t.Fatalf("failed to run migrations: %v", err)
    }

    return db
}

func TestUserRepository(t *testing.T) {
    db := setupTestDB(t)  // Error reported here if setup fails
    defer db.Close()

    // Test implementation
}
```

```go
// WRONG: Helper without t.Helper()
func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("failed: %v", err)  // Error line points here, not caller
    }
    return db
}
```

#### Cleanup with t.Cleanup

Use t.Cleanup for test cleanup instead of defer when cleanup depends on test context.

```go
// CORRECT: Using t.Cleanup
func TestWithTempFile(t *testing.T) {
    tmpfile, err := os.CreateTemp("", "test")
    require.NoError(t, err)

    t.Cleanup(func() {
        os.Remove(tmpfile.Name())
    })

    // Test using tmpfile
    // Cleanup runs even if test fails
}
```

## Benchmarks

### Benchmark Function Naming

Benchmark functions must start with Benchmark and take \*testing.B parameter.

```go
// CORRECT: Benchmark naming
func BenchmarkAdd(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Add(2, 3)
    }
}

func BenchmarkUserValidation(b *testing.B) {
    user := &User{ID: "123", Email: "test@example.com"}
    b.ResetTimer()  // Reset after setup

    for i := 0; i < b.N; i++ {
        user.Validate()
    }
}
```

```go
// WRONG: Invalid benchmark naming
func benchmarkAdd(b *testing.B) {}     // Must start with capital B
func TestBenchmarkAdd(b *testing.B) {} // Don't mix Test and Benchmark
```

#### Use b.ResetTimer After Setup

Call b.ResetTimer() after expensive setup to exclude setup time from benchmark.

```go
// CORRECT: ResetTimer after setup
func BenchmarkDatabaseQuery(b *testing.B) {
    db := setupTestDB(b)
    defer db.Close()

    b.ResetTimer()  // Don't include setup time

    for i := 0; i < b.N; i++ {
        db.Query("SELECT * FROM users WHERE id = ?", i)
    }
}
```

```go
// WRONG: Including setup in benchmark
func BenchmarkDatabaseQuery(b *testing.B) {
    for i := 0; i < b.N; i++ {
        db := setupTestDB(b)  // Setup repeated b.N times!
        db.Query("SELECT * FROM users WHERE id = ?", i)
        db.Close()
    }
}
```

#### Report Allocations with b.ReportAllocs

Use b.ReportAllocs() to track memory allocations in benchmarks.

```go
// CORRECT: Report allocations
func BenchmarkStringConcat(b *testing.B) {
    b.ReportAllocs()  // Shows allocs/op in results

    for i := 0; i < b.N; i++ {
        s := ""
        for j := 0; j < 100; j++ {
            s += "a"
        }
    }
}

func BenchmarkStringBuilder(b *testing.B) {
    b.ReportAllocs()

    for i := 0; i < b.N; i++ {
        var sb strings.Builder
        for j := 0; j < 100; j++ {
            sb.WriteString("a")
        }
        _ = sb.String()
    }
}
```

```bash
# Run benchmarks with memory stats
go test -bench=. -benchmem

# Compare benchmarks
go test -bench=. -benchmem -count=5 | tee old.txt
# Make changes
go test -bench=. -benchmem -count=5 | tee new.txt
benchstat old.txt new.txt
```

#### Table-Driven Benchmarks

Use table-driven pattern for benchmarks with multiple scenarios.

```go
// CORRECT: Table-driven benchmarks
func BenchmarkValidation(b *testing.B) {
    benchmarks := []struct {
        name  string
        input string
    }{
        {name: "short email", input: "a@b.c"},
        {name: "normal email", input: "user@example.com"},
        {name: "long email", input: "very.long.email.address@subdomain.example.com"},
    }

    for _, bm := range benchmarks {
        b.Run(bm.name, func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                ValidateEmail(bm.input)
            }
        })
    }
}
```

## Fuzzing

### Use f.Fuzz for Fuzz Testing

Use Go's built-in fuzzing to discover edge cases.

```go
// CORRECT: Fuzz test
func FuzzParseEmail(f *testing.F) {
    // Seed corpus
    f.Add("user@example.com")
    f.Add("test@test.org")
    f.Add("invalid")

    f.Fuzz(func(t *testing.T, email string) {
        result, err := ParseEmail(email)

        // Invariants that should always hold
        if err == nil {
            require.NotEmpty(t, result.User)
            require.NotEmpty(t, result.Domain)
            require.Contains(t, email, "@")
        }
    })
}
```

```bash
# Run fuzz tests
go test -fuzz=FuzzParseEmail -fuzztime=30s

# Run with seed corpus only
go test -fuzz=FuzzParseEmail -fuzztime=0s
```

#### Seed Corpus for Fuzzing

Provide good seed inputs to guide fuzzing toward interesting cases.

```go
// CORRECT: Good seed corpus
func FuzzJSONParse(f *testing.F) {
    f.Add(`{"name":"Alice","age":30}`)
    f.Add(`{"name":"Bob"}`)
    f.Add(`{}`)
    f.Add(`{"nested":{"value":true}}`)
    f.Add(`[]`)  // Invalid but interesting

    f.Fuzz(func(t *testing.T, data string) {
        var v interface{}
        _ = json.Unmarshal([]byte(data), &v)
        // Should not panic
    })
}
```

## Parallel Tests

### Use t.Parallel for Independent Tests

Mark independent tests as parallel to speed up test execution.

```go
// CORRECT: Parallel tests
func TestUserValidation(t *testing.T) {
    t.Parallel()  // Can run in parallel with other tests

    tests := []struct {
        name string
        user *User
        want error
    }{
        {name: "valid user", user: &User{ID: "1", Email: "a@b.c"}, want: nil},
        {name: "missing email", user: &User{ID: "1"}, want: ErrInvalidEmail},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // Subtests also parallel
            got := tt.user.Validate()
            assert.Equal(t, tt.want, got)
        })
    }
}
```

```go
// WRONG: t.Parallel() on tests that share state
func TestSharedState(t *testing.T) {
    t.Parallel()  // Don't use if test modifies global state

    globalCounter = 0  // Race condition!
    globalCounter++
}
```

## Golden Files

### Use testdata Directory for Test Fixtures

Store test fixtures and golden files in testdata/ directory.

```text
myapp/
  parser/
    parser.go
    parser_test.go
    testdata/
      valid_input.json
      invalid_input.json
      expected_output.golden
```

```go
// CORRECT: Using golden files
func TestParser(t *testing.T) {
    input, err := os.ReadFile("testdata/valid_input.json")
    require.NoError(t, err)

    got, err := Parse(input)
    require.NoError(t, err)

    golden, err := os.ReadFile("testdata/expected_output.golden")
    require.NoError(t, err)

    assert.Equal(t, string(golden), got.String())
}
```

#### Update Golden Files with Flag

Provide a flag to update golden files when output changes intentionally.

```go
// CORRECT: Golden file update flag
var update = flag.Bool("update", false, "update golden files")

func TestRender(t *testing.T) {
    got := Render(data)
    goldenPath := "testdata/output.golden"

    if *update {
        err := os.WriteFile(goldenPath, []byte(got), 0644)
        require.NoError(t, err)
    }

    golden, err := os.ReadFile(goldenPath)
    require.NoError(t, err)
    assert.Equal(t, string(golden), got)
}
```

```bash
# Update golden files
go test -update

# Normal test run
go test
```

## Coverage

### Run Tests with Coverage

Always measure test coverage and aim for meaningful coverage.

```bash
# Run tests with coverage
go test -v -race -coverprofile=coverage.out ./...

# View coverage in terminal
go tool cover -func=coverage.out

# View coverage in browser
go tool cover -html=coverage.out

# Coverage by package
go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out | grep total
```

```bash
# Minimum coverage check in CI
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//' | \
    awk '{if ($1 < 80) exit 1}'
```

#### Focus on Meaningful Coverage

Aim for high coverage of business logic, not just line coverage.

```go
// CORRECT: Test important paths and edge cases
func TestProcessPayment(t *testing.T) {
    tests := []struct {
        name    string
        amount  float64
        balance float64
        wantErr error
    }{
        {name: "sufficient balance", amount: 50, balance: 100, wantErr: nil},
        {name: "insufficient balance", amount: 150, balance: 100, wantErr: ErrInsufficientFunds},
        {name: "zero amount", amount: 0, balance: 100, wantErr: ErrInvalidAmount},
        {name: "negative amount", amount: -50, balance: 100, wantErr: ErrInvalidAmount},
    }
    // Test all important scenarios
}
```

This skill ensures comprehensive testing coverage following Go community best practices. Apply these
patterns consistently to maintain high-quality, reliable code.
