---
name: module-conventions
description:
  This skill should be used when creating or editing go.mod, managing Go dependencies, configuring
  Go modules, or organizing Go packages and module boundaries.
version: 0.1.0
---

# Go Module Conventions and Dependency Management

This skill defines best practices for Go module management, dependency handling, package
organization, and versioning following the Go modules system.

## Module Path Configuration

### Use Full Repository Path

The module path in go.mod must be the full import path, typically matching the repository URL.

```go
// CORRECT: Full repository path
module github.com/username/myproject

go 1.21

require (
    github.com/pkg/errors v0.9.1
)
```

```go
// WRONG: Incomplete or incorrect module path
module myproject  // Missing domain and path

module example.com/myproject  // Don't use example.com for real projects
```

#### Module Path for Private Repositories

For private repositories, use the full Git hosting path with authentication configured.

```go
// CORRECT: Private repository module path
module github.com/mycompany/private-repo

go 1.21
```

```bash
# Configure Git for private repos
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Or use GOPRIVATE environment variable
export GOPRIVATE=github.com/mycompany/*
```

```bash
# .netrc for private repos with HTTPS
machine github.com
login USERNAME
password TOKEN
```

## Go Version Management

### Specify Minimum Go Version in go.mod

Always specify the minimum Go version required by your module in go.mod.

```go
// CORRECT: Explicit Go version
module github.com/username/myproject

go 1.21  // Minimum version required

require (
    github.com/stretchr/testify v1.8.4
)
```

```go
// WRONG: Missing or vague version
module github.com/username/myproject

// No go version specified - bad practice
```

#### Use .go-version for Toolchain Pinning

Use .go-version file to pin the exact Go toolchain version for development.

```text
# CORRECT: .go-version file
1.21.5
```

```bash
# Tools like goenv or asdf read .go-version
asdf install golang
goenv install
```

```go
// go.mod specifies minimum
go 1.21

// .go-version specifies exact version for dev
// 1.21.5
```

#### Toolchain Directive for Go 1.21+

Use the toolchain directive to specify the Go toolchain version.

```go
// CORRECT: Toolchain directive
module github.com/username/myproject

go 1.21

toolchain go1.21.5
```

## Dependency Management

### Run go mod tidy Regularly

Always run go mod tidy to clean up dependencies and ensure go.mod and go.sum are in sync.

```bash
# CORRECT: Regular go mod tidy workflow
go mod tidy        # Remove unused and add missing dependencies
go mod verify      # Verify checksums
```

```bash
# In CI, verify go.mod is tidy
go mod tidy
git diff --exit-code go.mod go.sum || (echo "go.mod is not tidy" && exit 1)
```

```bash
# Taskfile.yml task
tasks:
  tidy:
    desc: Tidy and verify dependencies
    cmds:
      - go mod tidy
      - go mod verify
      - go mod download
```

#### Use go mod verify for Security

Verify dependency checksums to ensure integrity.

```bash
# CORRECT: Verify dependencies
go mod verify
```

```bash
# WRONG: Skipping verification
go build  # Builds without verification
```

```bash
# In CI pipeline
- name: Verify dependencies
  run: |
    go mod download
    go mod verify
```

#### Use go mod why to Understand Dependencies

Use go mod why to understand why a dependency is required.

```bash
# CORRECT: Understanding dependency tree
go mod why github.com/pkg/errors

# Output shows dependency chain:
# github.com/username/myproject
# github.com/username/myproject/internal/service
# github.com/pkg/errors
```

```bash
# Find all dependencies of a package
go mod graph | grep github.com/pkg/errors

# Show dependency tree
go mod graph
```

#### Upgrade Dependencies Carefully

Use go get to upgrade dependencies with version constraints.

```bash
# CORRECT: Controlled dependency upgrades
go get github.com/stretchr/testify@latest       # Latest version
go get github.com/stretchr/testify@v1.8.4       # Specific version
go get github.com/stretchr/testify@v1           # Latest v1.x.x
go get -u ./...                                  # Upgrade all dependencies
go get -u=patch ./...                            # Upgrade to latest patch versions
```

```bash
# WRONG: Uncontrolled upgrades
go get -u  # Upgrades everything, can break builds
```

```bash
# Best practice: Test after upgrade
go get -u=patch ./...
go mod tidy
go test ./...
```

## Replace Directives

### Replace Only for Local Development

Use replace directives only for local development, never commit local filesystem paths.

```go
// CORRECT: Replace for local development (don't commit)
module github.com/username/myproject

go 1.21

require (
    github.com/username/library v1.2.3
)

// Uncomment for local development only
// replace github.com/username/library => ../library
```

```go
// WRONG: Committed local replace directive
module github.com/username/myproject

go 1.21

replace github.com/username/library => /Users/john/projects/library  // Never commit this!
```

#### Replace for Forked Dependencies

Use replace to use a fork or specific commit of a dependency.

```go
// CORRECT: Replace with fork
module github.com/username/myproject

go 1.21

require (
    github.com/original/library v1.2.3
)

// Use fork with bug fix
replace github.com/original/library => github.com/username/library-fork v1.2.4-fix
```

```bash
# Replace with specific commit
go mod edit -replace=github.com/original/library=github.com/username/library-fork@commit-hash
```

#### Document Replace Directives

Always document why a replace directive exists.

```go
// CORRECT: Documented replace
module github.com/username/myproject

go 1.21

require (
    github.com/problematic/library v1.0.0
)

// Replace with fork that fixes critical security issue CVE-2024-1234
// TODO: Remove when upstream merges fix (tracking issue: #123)
replace github.com/problematic/library => github.com/username/library-fixed v1.0.1-patched
```

## Package Organization

### Use cmd Directory for Entry Points

Place all executable entry points in cmd/ directory with subdirectories for each binary.

```text
# CORRECT: cmd structure for multiple binaries
myproject/
  cmd/
    server/
      main.go
    worker/
      main.go
    migrate/
      main.go
  internal/
    service/
      user.go
  pkg/
    client/
      client.go
  go.mod
```

```go
// CORRECT: cmd/server/main.go
package main

import (
    "log"
    "myproject/internal/service"
)

func main() {
    svc := service.New()
    log.Fatal(svc.Start())
}
```

```text
# WRONG: Binaries in root or mixed structure
myproject/
  main.go           # Don't put main in root for libraries
  server.go
  worker.go
```

#### Use internal for Private Code

Use internal/ directory for code that should not be importable by external modules.

```text
# CORRECT: internal directory structure
myproject/
  internal/
    service/
      user.go       # Cannot be imported by external modules
    repository/
      postgres.go
    middleware/
      auth.go
  pkg/
    client/
      client.go     # Public API
  go.mod
```

```go
// CORRECT: Internal package
package service  // In internal/service/user.go

// This package cannot be imported by modules outside myproject
type UserService struct {
    repo Repository
}
```

```go
// WRONG: Putting private code in pkg/
// pkg/internals/service.go
package internals  // Don't use "internals" in pkg/

// Still importable by external modules, defeating the purpose
```

#### Use pkg for Public Libraries

Use pkg/ directory for code intended to be imported by external modules.

```text
# CORRECT: pkg for public API
myproject/
  pkg/
    client/
      client.go     # Public client library
    types/
      user.go       # Public types
  internal/
    service/
      impl.go       # Private implementation
  go.mod
```

```go
// CORRECT: pkg/client/client.go
package client

// Client is the public API for external users
type Client struct {
    baseURL string
}

// NewClient creates a new client instance
func NewClient(baseURL string) *Client {
    return &Client{baseURL: baseURL}
}
```

## Versioning and Releases

### Use Semantic Versioning with v Prefix

Follow semantic versioning with v prefix for Git tags.

```bash
# CORRECT: Semantic versioning tags
git tag v1.0.0
git tag v1.1.0
git tag v1.1.1
git tag v2.0.0

git push origin v1.0.0
```

```bash
# WRONG: Missing v prefix or non-semver
git tag 1.0.0      # Missing 'v' prefix
git tag release-1  # Not semantic versioning
```

```bash
# Create and push version tag
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3

# List all version tags
git tag -l "v*"
```

#### Major Version v2+ Module Path Suffix

For v2 and higher, add version suffix to module path.

```go
// CORRECT: v2 module path
module github.com/username/myproject/v2

go 1.21

require (
    github.com/stretchr/testify v1.8.4
)
```

```go
// Import v2 module
import "github.com/username/myproject/v2/pkg/client"
```

```bash
# Create v2 tag
git tag v2.0.0
git push origin v2.0.0
```

```go
// WRONG: v2 without path suffix
module github.com/username/myproject  // Should be /v2

go 1.21
```

#### Pre-release Versions

Use pre-release suffixes for unstable versions.

```bash
# CORRECT: Pre-release versions
git tag v1.0.0-alpha.1
git tag v1.0.0-beta.1
git tag v1.0.0-rc.1
git tag v1.0.0  # Final release
```

```bash
# Use pre-release in go.mod
require github.com/username/library v1.0.0-beta.1
```

## Vendoring

### Prefer Module Proxy Over Vendoring

Use Go module proxy instead of vendoring when possible.

```bash
# CORRECT: Configure module proxy
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
```

```bash
# Private modules bypass proxy
export GOPRIVATE=github.com/mycompany/*
```

#### Vendor Only for Reproducibility

Use vendoring only when necessary for hermetic builds.

```bash
# CORRECT: Vendor when needed
go mod vendor

# Verify vendor is up to date
go mod vendor
git diff --exit-code vendor/
```

```gitignore
# Usually don't commit vendor/
vendor/

# But commit vendor/ if required for build reproducibility
```

```bash
# Build with vendor
go build -mod=vendor ./cmd/server
```

```bash
# WRONG: Vendoring by default
go mod vendor  # Don't vendor unless necessary
```

## Multi-Module Repositories

### Avoid Multi-Module Repos When Possible

Prefer single module per repository for simplicity.

```text
# CORRECT: Single module (preferred)
myproject/
  cmd/
  internal/
  pkg/
  go.mod
```

```text
# Use multi-module only with clear separation
monorepo/
  service-a/
    go.mod
    cmd/
    internal/
  service-b/
    go.mod
    cmd/
    internal/
```

#### Use Go Workspaces for Multi-Module Development

Use go.work for local development of multiple modules.

```bash
# CORRECT: Initialize workspace
go work init ./service-a ./service-b
```

```go
// go.work (don't commit to version control)
go 1.21

use (
    ./service-a
    ./service-b
)
```

```gitignore
# CORRECT: Ignore workspace file
go.work
go.work.sum
```

```bash
# Work with modules in workspace
cd service-a
go test ./...  # Uses workspace configuration

# Sync workspace
go work sync
```

## Indirect Dependencies

### Understand Indirect Dependencies

Indirect dependencies appear in go.mod when required by direct dependencies.

```go
// CORRECT: Indirect dependencies marked
module github.com/username/myproject

go 1.21

require (
    github.com/direct/dependency v1.2.3
)

require (
    github.com/indirect/dependency v2.1.0 // indirect
)
```

```bash
# View all dependencies
go list -m all

# View dependency tree
go mod graph
```

#### Clean Up Unused Indirect Dependencies

Run go mod tidy to remove unused indirect dependencies.

```bash
# CORRECT: Remove unused dependencies
go mod tidy

# Check which module requires a dependency
go mod why github.com/indirect/dependency
```

## Module Download and Caching

### Configure Module Cache

Understand and configure Go module cache location.

```bash
# Default cache location
go env GOMODCACHE
# Output: /home/user/go/pkg/mod

# Set custom cache location
export GOMODCACHE=/custom/path
```

```bash
# Download all dependencies
go mod download

# Download specific module
go mod download github.com/stretchr/testify
```

```bash
# Clear module cache
go clean -modcache
```

#### Use Module Cache in CI

Configure CI to cache module downloads for faster builds.

```yaml
# CORRECT: GitHub Actions module caching
- name: Setup Go
  uses: actions/setup-go@v4
  with:
    go-version: '1.21'
    cache: true # Automatically caches modules

- name: Download dependencies
  run: go mod download
```

```yaml
# GitLab CI module caching
cache:
  paths:
    - .go/pkg/mod

before_script:
  - export GOMODCACHE=$CI_PROJECT_DIR/.go/pkg/mod
  - go mod download
```

## Module Checksums and Security

### Commit go.sum to Version Control

Always commit go.sum for dependency verification.

```gitignore
# CORRECT: Don't ignore go.sum
# go.mod and go.sum should be committed

# WRONG: Ignoring go.sum
go.sum  # Never add this to .gitignore!
```

```bash
# Verify go.sum is committed
git add go.mod go.sum
git commit -m "chore: update dependencies"
```

#### Use GOSUMDB for Verification

Configure checksum database for security.

```bash
# CORRECT: Use public checksum database
export GOSUMDB=sum.golang.org

# Disable for private modules
export GONOSUMDB=github.com/mycompany/*
```

```bash
# Verify all dependencies
go mod verify
```

## Module-Aware Commands

### Use Module-Aware go get

Understand go get behavior in module mode.

```bash
# CORRECT: Module-aware go get
go get github.com/stretchr/testify@latest      # Add or upgrade
go get github.com/stretchr/testify@v1.8.4      # Specific version
go get github.com/stretchr/testify@none        # Remove dependency
```

```bash
# WRONG: Old GOPATH-style go get
export GO111MODULE=off  # Don't disable modules
go get github.com/stretchr/testify  # Unclear semantics
```

#### Use go install for Tools

Use go install for installing command-line tools.

```bash
# CORRECT: Install tools with go install
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install mvdan.cc/gofumpt@latest
go install go.uber.org/mock/mockgen@latest
```

```bash
# WRONG: Using go get for tools
go get github.com/golangci/golangci-lint/cmd/golangci-lint  # Old way
```

```go
// Track tool dependencies in tools.go
//go:build tools

package tools

import (
    _ "github.com/golangci/golangci-lint/cmd/golangci-lint"
    _ "mvdan.cc/gofumpt"
    _ "go.uber.org/mock/mockgen"
)
```

## Best Practices Summary

### Module Initialization Checklist

When creating a new Go module, follow this checklist.

```bash
# CORRECT: Initialize new module
mkdir myproject
cd myproject

# Initialize module
go mod init github.com/username/myproject

# Set Go version
go mod edit -go=1.21

# Create basic structure
mkdir -p cmd/myapp internal pkg

# Create .go-version
echo "1.21.5" > .go-version

# Create .gitignore
cat > .gitignore <<EOF
# Binaries
bin/
*.exe

# Go workspace
go.work
go.work.sum

# IDE
.idea/
.vscode/
*.swp
EOF

# Initialize git
git init
git add .
git commit -m "chore: initialize Go module"
```

#### Dependency Update Workflow

Regular dependency maintenance workflow.

```bash
# CORRECT: Dependency update process
# 1. Check for updates
go list -u -m all

# 2. Update patch versions
go get -u=patch ./...

# 3. Test changes
go test ./...

# 4. Tidy dependencies
go mod tidy

# 5. Verify checksums
go mod verify

# 6. Check for vulnerabilities
govulncheck ./...

# 7. Commit changes
git add go.mod go.sum
git commit -m "chore: update dependencies"
```

This skill ensures proper Go module management, dependency handling, and package organization
following the Go team's recommendations and community best practices.
