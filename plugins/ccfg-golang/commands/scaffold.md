---
description: Initialize new Go project with opinionated production-ready defaults
argument-hint: '<module-path> [--type=service|library|cli]'
allowed-tools: 'Bash(go *), Bash(git *), Read, Write, Edit, Glob'
---

# Go Project Scaffolding Command

You are executing the `scaffold` command to create a new Go project with production-ready defaults
and best practices baked in.

## Command Arguments

### Required: module-path

The Go module path (e.g., `github.com/user/project` or `company.com/team/service`).

Examples:

```bash
claude-code ccfg-golang scaffold github.com/acme/userservice
claude-code ccfg-golang scaffold gitlab.com/team/inventory-api --type=service
claude-code ccfg-golang scaffold github.com/user/mathlib --type=library
```

#### Optional: --type

Project type determines the scaffold structure:

1. `service` (default) - HTTP/gRPC microservice with health endpoints
1. `library` - Reusable library with public API
1. `cli` - Command-line tool with Cobra framework

## Project Layouts

### Service Layout

```text
project/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── handler/
│   │   ├── handler.go
│   │   └── handler_test.go
│   └── service/
│       ├── service.go
│       └── service_test.go
├── pkg/
│   └── api/
│       └── api.go
├── .gitignore
├── .golangci.yml
├── go.mod
├── go.sum
├── README.md
└── Taskfile.yml
```

#### Library Layout

```text
project/
├── examples/
│   └── basic/
│       └── main.go
├── internal/
│   ├── parser/
│   │   └── parser.go
│   └── validator/
│       └── validator.go
├── pkg/
│   └── mathlib/
│       ├── mathlib.go
│       ├── mathlib_test.go
│       └── doc.go
├── .gitignore
├── .golangci.yml
├── go.mod
├── README.md
└── Taskfile.yml
```

#### CLI Layout

```text
project/
├── cmd/
│   └── root.go
│   └── version.go
├── internal/
│   ├── config/
│   │   └── config.go
│   └── commands/
│       ├── create.go
│       └── list.go
├── main.go
├── .gitignore
├── .golangci.yml
├── go.mod
├── README.md
└── Taskfile.yml
```

## Scaffolding Execution

### Step 1: Validate Arguments

1. Check that module-path is provided
1. Validate module-path format (contains domain/path)
1. Parse --type flag (default: service)
1. Determine project name from module-path (last component)
1. Check if directory already exists

```bash
# Extract project name
PROJECT_NAME=$(basename "$MODULE_PATH")

# Check for existing directory
if [ -d "$PROJECT_NAME" ]; then
  echo "Error: Directory $PROJECT_NAME already exists"
  exit 1
fi
```

#### Step 2: Create Directory Structure

Create base directories according to project type:

```bash
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Service structure
mkdir -p cmd/server internal/config internal/handler internal/service pkg/api

# Library structure
mkdir -p examples/basic internal pkg/${PROJECT_NAME}

# CLI structure
mkdir -p cmd internal/config internal/commands
```

#### Step 3: Initialize Go Module

```bash
go mod init "$MODULE_PATH"
```

This creates go.mod with the correct module path.

#### Step 4: Generate Project Files

Create all necessary files based on project type.

## Service Type Files

### cmd/server/main.go

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"{{.ModulePath}}/internal/config"
	"{{.ModulePath}}/internal/handler"
	"{{.ModulePath}}/internal/service"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Initialize service
	svc := service.New(cfg)

	// Initialize HTTP handler
	h := handler.New(svc)

	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      h,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	serverErrors := make(chan error, 1)
	go func() {
		fmt.Printf("Server starting on port %d\n", cfg.Port)
		serverErrors <- srv.ListenAndServe()
	}()

	// Wait for interrupt signal
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// Block until error or shutdown signal
	select {
	case err := <-serverErrors:
		return fmt.Errorf("server error: %w", err)
	case sig := <-shutdown:
		fmt.Printf("\nReceived signal %v, starting graceful shutdown\n", sig)

		// Give outstanding requests 30 seconds to complete
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			if err := srv.Close(); err != nil {
				return fmt.Errorf("failed to stop server: %w", err)
			}
			return fmt.Errorf("shutdown timeout exceeded: %w", err)
		}
	}

	return nil
}
```

#### Service Configuration Package

```go
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds application configuration.
type Config struct {
	Port        int
	Environment string
	LogLevel    string
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	cfg := &Config{
		Port:        8080,
		Environment: getEnv("ENVIRONMENT", "development"),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
	}

	if portStr := os.Getenv("PORT"); portStr != "" {
		port, err := strconv.Atoi(portStr)
		if err != nil {
			return nil, fmt.Errorf("invalid PORT value: %w", err)
		}
		cfg.Port = port
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
```

#### internal/handler/handler.go

```go
package handler

import (
	"encoding/json"
	"net/http"

	"{{.ModulePath}}/internal/service"
)

// Handler handles HTTP requests.
type Handler struct {
	service *service.Service
	mux     *http.ServeMux
}

// New creates a new HTTP handler.
func New(svc *service.Service) *Handler {
	h := &Handler{
		service: svc,
		mux:     http.NewServeMux(),
	}

	// Register routes
	h.mux.HandleFunc("/health", h.handleHealth)
	h.mux.HandleFunc("/ready", h.handleReady)
	h.mux.HandleFunc("/", h.handleRoot)

	return h
}

// ServeHTTP implements http.Handler.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.mux.ServeHTTP(w, r)
}

// handleHealth returns service health status.
func (h *Handler) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := map[string]string{
		"status": "healthy",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(response)
}

// handleReady returns service readiness status.
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

// handleRoot handles the root endpoint.
func (h *Handler) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	response := map[string]string{
		"message": "{{.ProjectName}} service",
		"version": "0.1.0",
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response)
}
```

#### internal/handler/handler_test.go

```go
package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"{{.ModulePath}}/internal/config"
	"{{.ModulePath}}/internal/service"
)

func TestHealthEndpoint(t *testing.T) {
	cfg := &config.Config{
		Port:        8080,
		Environment: "test",
		LogLevel:    "debug",
	}
	svc := service.New(cfg)
	h := New(svc)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	h.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]string
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got '%s'", response["status"])
	}
}

func TestReadyEndpoint(t *testing.T) {
	cfg := &config.Config{
		Port:        8080,
		Environment: "test",
		LogLevel:    "debug",
	}
	svc := service.New(cfg)
	h := New(svc)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()

	h.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestRootEndpoint(t *testing.T) {
	cfg := &config.Config{
		Port:        8080,
		Environment: "test",
		LogLevel:    "debug",
	}
	svc := service.New(cfg)
	h := New(svc)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	h.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]string
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["version"] != "0.1.0" {
		t.Errorf("Expected version '0.1.0', got '%s'", response["version"])
	}
}
```

#### internal/service/service.go

```go
package service

import "{{.ModulePath}}/internal/config"

// Service contains business logic.
type Service struct {
	cfg *config.Config
}

// New creates a new service instance.
func New(cfg *config.Config) *Service {
	return &Service{
		cfg: cfg,
	}
}

// Ready returns true if the service is ready to handle requests.
func (s *Service) Ready() bool {
	// Add readiness checks here (database connections, etc.)
	return true
}
```

#### internal/service/service_test.go

```go
package service

import (
	"testing"

	"{{.ModulePath}}/internal/config"
)

func TestNew(t *testing.T) {
	cfg := &config.Config{
		Port:        8080,
		Environment: "test",
		LogLevel:    "debug",
	}

	svc := New(cfg)
	if svc == nil {
		t.Fatal("Expected service to be created")
	}

	if !svc.Ready() {
		t.Error("Expected service to be ready")
	}
}
```

#### pkg/api/api.go

```go
// Package api provides public API types for {{.ProjectName}}.
package api

// Version is the current API version.
const Version = "v1"
```

## Library Type Files

### pkg/{{.ProjectName}}/{{.ProjectName}}.go

```go
// Package {{.ProjectName}} provides [brief description].
package {{.ProjectName}}

// Example is a placeholder type.
type Example struct {
	Value string
}

// New creates a new Example instance.
func New(value string) *Example {
	return &Example{
		Value: value,
	}
}

// Process performs an example operation.
func (e *Example) Process() string {
	return e.Value
}
```

#### pkg/{{.ProjectName}}/{{.ProjectName}}\_test.go

```go
package {{.ProjectName}}

import "testing"

func TestNew(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  string
	}{
		{
			name:  "basic value",
			value: "test",
			want:  "test",
		},
		{
			name:  "empty value",
			value: "",
			want:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ex := New(tt.value)
			if ex.Value != tt.want {
				t.Errorf("New() = %v, want %v", ex.Value, tt.want)
			}
		})
	}
}

func TestProcess(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  string
	}{
		{
			name:  "returns value",
			value: "hello",
			want:  "hello",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ex := New(tt.value)
			got := ex.Process()
			if got != tt.want {
				t.Errorf("Process() = %v, want %v", got, tt.want)
			}
		})
	}
}
```

#### pkg/{{.ProjectName}}/doc.go

```go
/*
Package {{.ProjectName}} provides [detailed description].

# Usage

Basic usage example:

	ex := {{.ProjectName}}.New("value")
	result := ex.Process()

# Features

- Feature 1
- Feature 2
- Feature 3

For more examples, see the examples/ directory.
*/
package {{.ProjectName}}
```

#### examples/basic/main.go

```go
package main

import (
	"fmt"

	"{{.ModulePath}}/pkg/{{.ProjectName}}"
)

func main() {
	ex := {{.ProjectName}}.New("Hello, World!")
	result := ex.Process()
	fmt.Println(result)
}
```

## CLI Type Files

### main.go

```go
package main

import (
	"{{.ModulePath}}/cmd"
)

func main() {
	cmd.Execute()
}
```

#### cmd/root.go

```go
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "{{.ProjectName}}",
	Short: "A brief description of {{.ProjectName}}",
	Long: `A longer description that spans multiple lines and explains
what {{.ProjectName}} does and how to use it.`,
}

// Execute runs the root command.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	// Global flags
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "verbose output")
}
```

#### cmd/version.go

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	version = "0.1.0"
	commit  = "none"
	date    = "unknown"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("{{.ProjectName}} version %s\n", version)
		fmt.Printf("commit: %s\n", commit)
		fmt.Printf("built at: %s\n", date)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
```

#### CLI Configuration Package

```go
package config

import (
	"fmt"
	"os"
)

// Config holds CLI configuration.
type Config struct {
	Verbose bool
}

// Load reads configuration from environment and flags.
func Load(verbose bool) (*Config, error) {
	cfg := &Config{
		Verbose: verbose,
	}

	// Add additional config loading logic here

	return cfg, nil
}
```

## Common Files (All Types)

### Taskfile.yml

```yaml
version: '3'

vars:
  BINARY_NAME: { { .ProjectName } }
  MAIN_PATH: ./cmd/server # Adjust based on type
  COVERAGE_OUT: coverage.out

tasks:
  default:
    desc: Show available tasks
    cmds:
      - task --list

  build:
    desc: Build the application
    cmds:
      - go build -o bin/{{.BINARY_NAME}} {{.MAIN_PATH}}
    sources:
      - '**/*.go'
      - go.mod
      - go.sum
    generates:
      - bin/{{.BINARY_NAME}}

  run:
    desc: Run the application
    deps: [build]
    cmds:
      - ./bin/{{.BINARY_NAME}}

  test:
    desc: Run tests
    cmds:
      - go test ./... -v -race -timeout=5m

  test:coverage:
    desc: Run tests with coverage
    cmds:
      - go test ./... -coverprofile={{.COVERAGE_OUT}} -covermode=atomic
      - go tool cover -html={{.COVERAGE_OUT}} -o coverage.html
      - echo "Coverage report generated: coverage.html"

  bench:
    desc: Run benchmarks
    cmds:
      - go test ./... -bench=. -benchmem

  vet:
    desc: Run go vet
    cmds:
      - go vet ./...

  fmt:
    desc: Format code
    cmds:
      - gofumpt -l -w .

  fmt:check:
    desc: Check code formatting
    cmds:
      - gofumpt -l .

  lint:
    desc: Run golangci-lint
    cmds:
      - golangci-lint run ./...

  vuln:
    desc: Check for vulnerabilities
    cmds:
      - govulncheck ./...

  validate:
    desc: Run all quality checks
    deps: [vet, fmt:check, test, lint]

  tidy:
    desc: Tidy go modules
    cmds:
      - go mod tidy
      - go mod verify

  clean:
    desc: Clean build artifacts
    cmds:
      - rm -rf bin/
      - rm -f {{.COVERAGE_OUT}} coverage.html

  install:
    desc: Install binary to $GOPATH/bin
    cmds:
      - go install {{.MAIN_PATH}}
```

#### .golangci.yml

```yaml
run:
  timeout: 5m
  tests: true
  skip-dirs:
    - vendor

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - revive
    - stylecheck
    - gosec
    - gofmt
    - goimports
    - misspell
    - unconvert
    - unparam
    - goconst
    - gocritic
    - gocyclo
    - dupl

linters-settings:
  errcheck:
    check-type-assertions: true
    check-blank: true

  govet:
    check-shadowing: true
    enable-all: true

  revive:
    rules:
      - name: exported
        severity: warning
      - name: package-comments
        severity: warning
      - name: var-naming
        severity: warning

  stylecheck:
    checks: ['all']

  gosec:
    excludes:
      - G104 # Audit errors not checked (covered by errcheck)

  gocyclo:
    min-complexity: 15

  goconst:
    min-len: 3
    min-occurrences: 3

issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0

output:
  format: colored-line-number
  print-issued-lines: true
  print-linter-name: true
```

#### .gitignore

```text
# Binaries
bin/
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool
*.out
coverage.html

# Dependency directories
vendor/

# Go workspace file
go.work

# Environment files
.env
.env.local

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Build artifacts
dist/
tmp/
```

### README.md Template (Service)

````markdown
# {{.ProjectName}}

Brief description of the service.

## Features

- HTTP API with health and readiness endpoints
- Graceful shutdown handling
- Configuration via environment variables
- Comprehensive test coverage
- Production-ready defaults

## Getting Started

### Prerequisites

- Go 1.21 or later
- Task (optional, for task automation)

### Installation

```bash
go mod download
```

### Running

```bash
# Using Task
task run

# Or directly
go run cmd/server/main.go
```

The service will start on port 8080 (configurable via PORT env var).

### Configuration

Environment variables:

- `PORT` - Server port (default: 8080)
- `ENVIRONMENT` - Environment name (default: development)
- `LOG_LEVEL` - Logging level (default: info)

### Development

```bash
# Run tests
task test

# Run tests with coverage
task test:coverage

# Format code
task fmt

# Run linter
task lint

# Run all quality checks
task validate
```

### API Endpoints

- `GET /health` - Health check endpoint
- `GET /ready` - Readiness check endpoint
- `GET /` - Service information

### Project Structure

```text
cmd/server/      - Application entrypoint
internal/        - Private application code
  config/        - Configuration management
  handler/       - HTTP handlers
  service/       - Business logic
pkg/             - Public API and types
```

## Testing

```bash
go test ./... -v -race
```

## Building

```bash
task build
```

Binary will be created in `bin/{{.ProjectName}}`.

## License

[Your License]
````

### README.md Template (Library)

````markdown
# {{.ProjectName}}

Brief description of the library.

## Installation

```bash
go get {{.ModulePath}}
```

## Usage

```go
package main

import (
    "fmt"
    "{{.ModulePath}}/pkg/{{.ProjectName}}"
)

func main() {
    ex := {{.ProjectName}}.New("Hello")
    result := ex.Process()
    fmt.Println(result)
}
```

## Examples

See the `examples/` directory for more usage examples.

## Development

```bash
# Run tests
task test

# Run tests with coverage
task test:coverage

# Format code
task fmt

# Run linter
task lint
```

## Documentation

Full documentation available at [pkg.go.dev](https://pkg.go.dev/{{.ModulePath}}).

## License

[Your License]
````

### README.md Template (CLI)

````markdown
# {{.ProjectName}}

Brief description of the CLI tool.

## Installation

```bash
go install {{.ModulePath}}@latest
```

## Usage

```bash
# Show help
{{.ProjectName}} --help

# Show version
{{.ProjectName}} version
```

## Commands

- `version` - Display version information

## Development

```bash
# Run tests
task test

# Build binary
task build

# Install locally
task install
```

## License

[Your License]
````

## Post-Scaffold Steps

After creating all files:

### Step 5: Install Dependencies

For CLI projects, install Cobra:

```bash
go get -u github.com/spf13/cobra
```

Run go mod tidy:

```bash
go mod tidy
```

#### Step 6: Initialize Git Repository

```bash
git init
git add .
git commit -m "Initial commit: scaffold {{.ProjectName}}"
```

#### Step 7: Verify Build

```bash
go build ./...
```

#### Step 8: Run Tests

```bash
go test ./...
```

## Template Variable Substitution

When generating files, replace template variables:

1. `{{.ModulePath}}` - The provided module path
1. `{{.ProjectName}}` - Extracted project name (last path component)

Use string replacement or simple templating to substitute these values in all generated files.

## Success Report

After successful scaffolding, provide a summary:

```text
=== Project Scaffolded Successfully ===

Project: {{.ProjectName}}
Module: {{.ModulePath}}
Type: service
Location: ./{{.ProjectName}}

Created:
  ✓ Go module initialized
  ✓ Project structure created
  ✓ 12 files generated
  ✓ Git repository initialized

Next steps:
  1. cd {{.ProjectName}}
  2. task test          # Run tests
  3. task run           # Start the service
  4. task validate      # Run quality checks

Documentation: ./{{.ProjectName}}/README.md
```

## Customization Guidelines

The scaffold creates opinionated defaults. Users can customize:

1. Change port in internal/config/config.go
1. Add routes in internal/handler/handler.go
1. Add business logic in internal/service/service.go
1. Modify linter rules in .golangci.yml
1. Add tasks to Taskfile.yml

## Best Practices Implemented

1. cmd/internal/pkg layout for clear boundaries
1. Graceful shutdown for services
1. Health and readiness endpoints
1. Context propagation ready
1. Table-driven tests
1. Comprehensive .gitignore
1. Strict linting configuration
1. Task automation with Taskfile
1. Environment-based configuration
1. Proper error handling patterns

## Error Handling

Handle these error cases:

1. Module path not provided - show usage
1. Directory already exists - prompt or fail
1. Invalid module path format - validate
1. go mod init fails - report and exit
1. File creation fails - cleanup and report

## Final Validation

Before completing:

1. Verify all files were created
1. Check go.mod exists and is valid
1. Ensure go build succeeds
1. Confirm go test runs (even if no tests initially)
1. Verify .gitignore includes common patterns
1. Check README has correct module path
