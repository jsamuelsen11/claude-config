---
description: >
  Scaffold CI/CD workflow files for GitHub Actions projects
argument-hint: '[--type=ci|cd|release|pr-checks|reusable-workflow]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Intelligent workflow scaffolding for GitHub Actions. Generates production-ready CI/CD workflow files
with security best practices, language-specific configurations, and modern DevOps patterns.
Automatically detects project language and structure to create tailored workflows.

## Usage

Scaffold CI workflow (auto-detects language):

```bash
/ccfg-github-actions scaffold
/ccfg-github-actions scaffold --type=ci
```

Scaffold deployment workflow:

```bash
/ccfg-github-actions scaffold --type=cd
```

Scaffold release workflow:

```bash
/ccfg-github-actions scaffold --type=release
```

Scaffold PR validation workflow:

```bash
/ccfg-github-actions scaffold --type=pr-checks
```

Scaffold reusable workflow:

```bash
/ccfg-github-actions scaffold --type=reusable-workflow
```

## Overview

The scaffold command generates GitHub Actions workflow files following security and efficiency best
practices:

### Workflow Types

#### CI (Continuous Integration) - Default

- Language detection and setup
- Dependency caching
- Linting and code quality checks
- Automated testing
- Build verification
- Artifact generation
- Matrix testing across versions/platforms

#### CD (Continuous Deployment)

- Environment-gated deployments
- OIDC authentication (AWS, Azure, GCP)
- Blue-green deployment template
- Rolling deployment template
- Health check validation
- Rollback procedures
- Deployment notifications

#### Release

- Tag-triggered release automation
- Manual workflow dispatch option
- Changelog generation
- Semantic version validation
- Asset compilation and upload
- GitHub Release creation
- Package publication (npm, PyPI, crates.io, etc.)

#### PR Checks

- Pull request validation
- Paths-based filtering
- Concurrency with auto-cancel
- Required status checks
- Code quality gates
- Preview deployments

#### Reusable Workflow

- Parameterized workflow template
- Typed inputs and secrets
- Reusable job definitions
- Caller documentation
- Cross-repository sharing

### Security Features

All scaffolded workflows include:

- SHA-pinned third-party actions
- Explicit permissions blocks (least privilege)
- No hardcoded secrets (placeholder references)
- Timeout configurations
- Concurrency controls where appropriate
- OIDC support for cloud deployments

### Language Support

Auto-detection and configuration for:

- JavaScript/TypeScript (Node.js, npm, yarn, pnpm)
- Python (pip, poetry, pipenv)
- Java (Maven, Gradle)
- Go (go modules)
- Rust (Cargo)
- Ruby (Bundler)
- PHP (Composer)
- .NET (dotnet CLI)
- Swift (SPM)
- Kotlin (Gradle)

## Key Rules

### Language Detection Priority

1. Check for explicit language files (package.json, Cargo.toml, go.mod)
2. Use most specific indicator (Pipfile > requirements.txt)
3. Fall back to generic template if unclear
4. Prompt user for confirmation on ambiguous projects

### Action Pinning Requirements

- Third-party actions: SHA-pinned only

  ```yaml
  uses: docker/setup-buildx-action@8c0edd44fd9d2d25d1f32147d34faabc28ce1b7d
  ```

- First-party actions: Version tags acceptable

  ```yaml
  uses: actions/checkout@v4
  uses: actions/setup-node@v4
  ```

### Secret Handling

- Never include real secrets in generated workflows
- Use placeholder format: `${{ secrets.EXAMPLE_SECRET }}`
- Include comments indicating required secrets
- Suggest using environment secrets for deployments
- Document secret setup in workflow comments

### Permissions Model

Default permissions for workflow types:

- CI: `permissions: read-all` or `contents: read`
- CD: `contents: read`, `id-token: write` for OIDC
- Release: `contents: write` for tag/release creation
- PR Checks: `contents: read`, `pull-requests: write` for comments

### Directory Management

- Ensure `.github/workflows/` exists before writing
- Create directory with appropriate permissions
- Check for naming conflicts before generation
- Suggest workflow file naming conventions

### Conventions Document

- Check for `docs/infra/github-actions-conventions.md`
- Incorporate organization standards if present
- Reference conventions in generated workflow comments
- Suggest creating conventions doc if missing

## Step-by-Step Process

### Phase 1: Setup and Validation

#### Step 1.1: Parse Arguments

Extract workflow type from arguments:

- Default: `ci`
- Valid types: ci, cd, release, pr-checks, reusable-workflow
- Invalid type: Error with suggestion

#### Step 1.2: Verify Git Repository

```bash
git rev-parse --git-dir
```

If not a git repository, warn but continue (workflows can be created before git init).

#### Step 1.3: Check Workflows Directory

Use Glob to check:

```text
pattern: .github/workflows
```

If doesn't exist, create it:

```bash
mkdir -p .github/workflows
```

#### Step 1.4: Check for Existing Workflow

Target filename based on type:

- ci: `ci.yml`
- cd: `deploy.yml`
- release: `release.yml`
- pr-checks: `pr-checks.yml`
- reusable-workflow: `reusable-workflow.yml`

Use Glob to check if file exists:

```text
pattern: .github/workflows/ci.yml
```

If exists, prompt user:

- Overwrite existing file
- Create with different name (ci-2.yml)
- Abort

#### Step 1.5: Check for Conventions Document

Use Glob:

```text
pattern: docs/infra/github-actions-conventions.md
```

If found, read and incorporate:

- Required actions (security scanners)
- Approved action versions
- Organization-specific settings
- Naming conventions

### Phase 2: Language and Project Detection

#### Step 2.1: Detect Package Managers

Use Glob to check for language indicators:

JavaScript/TypeScript:

```text
pattern: package.json
pattern: yarn.lock
pattern: pnpm-lock.yaml
pattern: package-lock.json
```

Python:

```text
pattern: pyproject.toml
pattern: Pipfile
pattern: poetry.lock
pattern: requirements.txt
pattern: setup.py
```

Java:

```text
pattern: pom.xml
pattern: build.gradle
pattern: build.gradle.kts
```

Go:

```text
pattern: go.mod
pattern: go.sum
```

Rust:

```text
pattern: Cargo.toml
pattern: Cargo.lock
```

Ruby:

```text
pattern: Gemfile
pattern: Gemfile.lock
```

PHP:

```text
pattern: composer.json
pattern: composer.lock
```

.NET:

```text
pattern: *.csproj
pattern: *.fsproj
pattern: *.sln
```

#### Step 2.2: Determine Primary Language

Priority order if multiple languages detected:

1. Most specific lock file (pnpm-lock > package-lock)
2. Most prevalent file type (count source files)
3. Root-level configuration files
4. User prompt if ambiguous

#### Step 2.3: Read Project Configuration

Based on detected language, read config:

For Node.js - Read package.json:

```json
{
  "name": "project-name",
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "build": "webpack"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

Extract:

- Project name for workflow name
- Available scripts for CI steps
- Node version requirement
- Package manager (check lockfile)

For Python - Read pyproject.toml or setup.py:

```toml
[tool.poetry]
name = "project-name"
python = "^3.11"

[tool.poetry.dependencies]
pytest = "^7.0"
```

Extract:

- Python version requirement
- Testing framework
- Build tool (poetry, setuptools, hatch)

For other languages, apply similar patterns.

#### Step 2.4: Detect Monorepo Structure

Check for monorepo indicators:

```text
pattern: packages/*/package.json
pattern: apps/*/package.json
pattern: lerna.json
pattern: pnpm-workspace.yaml
pattern: nx.json
```

If monorepo detected:

- Add paths filtering for pr-checks
- Consider matrix strategy for multiple packages
- Suggest workspace-aware caching

#### Step 2.5: Detect Testing Framework

Based on language, check for:

JavaScript:

```text
pattern: jest.config.*
pattern: vitest.config.*
pattern: karma.conf.*
```

Or check package.json devDependencies.

Python:

```text
pattern: pytest.ini
pattern: tox.ini
pattern: .coveragerc
```

Adjust CI workflow test commands accordingly.

### Phase 3: Template Generation

#### Step 3.1: Select Base Template

Based on workflow type, load appropriate template structure.

#### Step 3.2: Generate CI Workflow

If type is `ci`:

#### CI Template Structure

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

# Cancel outdated CI runs on PR updates
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific setup

      - name: Run linter
        run: # Language-specific lint command

  test:
    name: Test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific setup with caching

      - name: Run tests
        run: # Language-specific test command

      - name: Upload coverage
        uses: codecov/codecov-action@<SHA>
        if: always()

  build:
    name: Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: [lint, test]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific setup

      - name: Build
        run: # Language-specific build command

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: # Language-specific build output
```

#### Step 3.3: Customize for Node.js/JavaScript

If language is Node.js:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20' # From package.json engines or default
    cache: 'npm' # or 'yarn', 'pnpm' based on lockfile

- name: Install dependencies
  run: npm ci # or yarn install --frozen-lockfile, pnpm install --frozen-lockfile

- name: Run linter
  run: npm run lint # If lint script exists

- name: Run tests
  run: npm test
  env:
    CI: true

- name: Build
  run: npm run build # If build script exists
```

#### Step 3.4: Customize for Python

If language is Python:

```yaml
- name: Setup Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.11' # From pyproject.toml or default
    cache: 'pip' # or 'poetry', 'pipenv'

- name: Install dependencies
  run: |
    python -m pip install --upgrade pip
    pip install -r requirements.txt  # or poetry install

- name: Run linter
  run: |
    pip install ruff
    ruff check .

- name: Run tests
  run: |
    pip install pytest pytest-cov
    pytest --cov=. --cov-report=xml

- name: Build
  run: |
    pip install build
    python -m build
```

#### Step 3.5: Customize for Go

If language is Go:

```yaml
- name: Setup Go
  uses: actions/setup-go@v5
  with:
    go-version: '1.21' # From go.mod or default
    cache: true

- name: Download dependencies
  run: go mod download

- name: Run linter
  run: |
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    golangci-lint run

- name: Run tests
  run: go test -v -race -coverprofile=coverage.txt -covermode=atomic ./...

- name: Build
  run: go build -v ./...
```

#### Step 3.6: Customize for Rust

If language is Rust:

```yaml
- name: Setup Rust
  uses: actions-rust-lang/setup-rust-toolchain@v1
  with:
    toolchain: stable
    cache: true

- name: Check formatting
  run: cargo fmt --all -- --check

- name: Run Clippy
  run: cargo clippy -- -D warnings

- name: Run tests
  run: cargo test --all-features

- name: Build
  run: cargo build --release
```

#### Step 3.7: Customize for Java

If language is Java (Maven):

```yaml
- name: Setup Java
  uses: actions/setup-java@v4
  with:
    java-version: '17'
    distribution: 'temurin'
    cache: 'maven'

- name: Build with Maven
  run: mvn clean verify

- name: Run tests
  run: mvn test

- name: Build JAR
  run: mvn package -DskipTests
```

For Gradle:

```yaml
- name: Setup Java
  uses: actions/setup-java@v4
  with:
    java-version: '17'
    distribution: 'temurin'
    cache: 'gradle'

- name: Make gradlew executable
  run: chmod +x gradlew

- name: Build with Gradle
  run: ./gradlew build

- name: Run tests
  run: ./gradlew test
```

#### Step 3.8: Add Matrix Strategy (Optional)

For projects needing multi-version testing:

```yaml
test:
  name: Test (Node ${{ matrix.node-version }})
  runs-on: ubuntu-latest
  timeout-minutes: 15
  strategy:
    matrix:
      node-version: [18, 20, 22]
    fail-fast: false
  steps:
    - name: Setup Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
```

Consider matrix for:

- Multiple language versions
- Multiple OS (ubuntu, windows, macos)
- Different database versions

#### Step 3.9: Generate CD Workflow

If type is `cd`:

#### CD Template with OIDC

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - staging
          - production

permissions:
  contents: read
  id-token: write # Required for OIDC

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    timeout-minutes: 20
    environment:
      name: staging
      url: https://staging.example.com
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # OIDC Authentication - AWS Example
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      - name: Deploy to staging
        run: |
          # Deployment commands here
          # Example: aws s3 sync ./build s3://staging-bucket
          # Example: kubectl apply -f k8s/staging/
          echo "Deploying to staging..."

      - name: Run smoke tests
        run: |
          # Smoke test commands
          echo "Running health checks..."

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    timeout-minutes: 30
    environment:
      name: production
      url: https://example.com
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      # Blue-Green Deployment Pattern
      - name: Deploy to blue environment
        run: |
          echo "Deploying to blue environment..."
          # Update blue environment

      - name: Health check blue environment
        run: |
          echo "Checking blue environment health..."
          # Wait for health checks to pass

      - name: Switch traffic to blue
        run: |
          echo "Switching traffic..."
          # Update load balancer to point to blue

      - name: Monitor for issues
        run: |
          echo "Monitoring deployment..."
          # Watch error rates for 5 minutes

      - name: Keep blue as primary
        run: |
          echo "Deployment successful"
          # Green becomes new blue for next deployment
```

#### CD Template with Azure OIDC

```yaml
- name: Azure Login
  uses: azure/login@92a5484dfaf04ca78a94597f4f19fea633851fa2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Deploy to Azure
  run: |
    az webapp deploy --name myapp --resource-group mygroup
```

#### CD Template with GCP OIDC

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider'
    service_account: 'github-actions@my-project.iam.gserviceaccount.com'

- name: Deploy to GCP
  run: |
    gcloud run deploy myservice --image gcr.io/my-project/myimage
```

#### Step 3.10: Generate Release Workflow

If type is `release`:

#### Release Template

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*' # Semantic versioning tags
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., v1.2.3)'
        required: true

permissions:
  contents: write # Required to create releases

jobs:
  validate:
    name: Validate Release
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Full history for changelog

      - name: Validate version tag
        run: |
          if [[ "${{ github.ref }}" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Valid semantic version tag"
          else
            echo "Invalid version tag format"
            exit 1
          fi

  build:
    name: Build Release Artifacts
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: validate
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific setup and build

      - name: Build artifacts
        run: |
          # Build commands
          # Example: npm run build
          # Example: cargo build --release
          echo "Building release artifacts..."

      - name: Create release archive
        run: |
          tar -czf release.tar.gz dist/  # Adjust path as needed

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: release-artifacts
          path: release.tar.gz

  release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: build
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          name: release-artifacts

      - name: Generate changelog
        id: changelog
        run: |
          # Generate changelog from git commits
          PREVIOUS_TAG=$(git describe --abbrev=0 --tags $(git rev-list --tags --skip=1 --max-count=1) 2>/dev/null || echo "")
          if [ -z "$PREVIOUS_TAG" ]; then
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" ${{ github.ref_name }})
          else
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" $PREVIOUS_TAG..${{ github.ref_name }})
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ github.ref_name }}
          name: Release ${{ github.ref_name }}
          body: |
            ## What's Changed
            ${{ steps.changelog.outputs.changelog }}

            ## Installation
            Download the release archive and extract it.
          files: |
            release.tar.gz
          draft: false
          prerelease: false

  publish:
    name: Publish Package
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: release
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific publishing
      # For npm:
      # - uses: actions/setup-node@v4
      #   with:
      #     node-version: '20'
      #     registry-url: 'https://registry.npmjs.org'
      # - run: npm publish
      #   env:
      #     NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      # For PyPI:
      # - uses: actions/setup-python@v5
      #   with:
      #     python-version: '3.11'
      # - run: |
      #     pip install build twine
      #     python -m build
      #     twine upload dist/*
      #   env:
      #     TWINE_USERNAME: __token__
      #     TWINE_PASSWORD: ${{ secrets.PYPI_TOKEN }}

      # For crates.io:
      # - run: cargo publish --token ${{ secrets.CARGO_TOKEN }}

      - name: Publish package
        run: |
          echo "Package publishing commands here"
```

#### Step 3.11: Generate PR Checks Workflow

If type is `pr-checks`:

#### PR Checks Template

```yaml
name: PR Checks

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'
      - 'package.json' # Adjust for language
      - '.github/workflows/pr-checks.yml'

# Cancel outdated runs when PR is updated
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write # For PR comments

jobs:
  changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      src: ${{ steps.filter.outputs.src }}
      tests: ${{ steps.filter.outputs.tests }}
      docs: ${{ steps.filter.outputs.docs }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check file changes
        uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            src:
              - 'src/**'
            tests:
              - 'tests/**'
              - 'test/**'
            docs:
              - 'docs/**'
              - '**.md'

  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: changes
    if: needs.changes.outputs.src == 'true'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific linting

      - name: Run linter
        run: |
          # Lint commands
          echo "Running linter..."

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: changes
    if: needs.changes.outputs.src == 'true' || needs.changes.outputs.tests == 'true'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific testing

      - name: Run tests
        run: |
          # Test commands
          echo "Running tests..."

      - name: Comment coverage
        uses: actions/github-script@v7
        if: always()
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Test Results\n\nAll tests passed! ✅'
            })

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run security scan
        run: |
          # Security scanning commands
          # Example: npm audit
          # Example: pip-audit
          echo "Running security scan..."

  build:
    name: Build Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: [lint, test]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Language-specific build

      - name: Build
        run: |
          # Build commands
          echo "Building project..."

  summary:
    name: PR Check Summary
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs: [lint, test, security, build]
    if: always()
    steps:
      - name: Check all jobs
        run: |
          if [ "${{ needs.lint.result }}" == "success" ] && \
             [ "${{ needs.test.result }}" == "success" ] && \
             [ "${{ needs.security.result }}" == "success" ] && \
             [ "${{ needs.build.result }}" == "success" ]; then
            echo "All PR checks passed!"
            exit 0
          else
            echo "Some PR checks failed"
            exit 1
          fi
```

#### Step 3.12: Generate Reusable Workflow

If type is `reusable-workflow`:

#### Reusable Workflow Template

```yaml
name: Reusable CI Workflow

on:
  workflow_call:
    inputs:
      node-version:
        description: 'Node.js version to use'
        required: false
        type: string
        default: '20'
      run-tests:
        description: 'Whether to run tests'
        required: false
        type: boolean
        default: true
      environment:
        description: 'Deployment environment'
        required: false
        type: string
        default: 'staging'
    secrets:
      API_TOKEN:
        description: 'API token for deployment'
        required: true
      SLACK_WEBHOOK:
        description: 'Slack webhook for notifications'
        required: false
    outputs:
      build-version:
        description: 'Version of the built artifact'
        value: ${{ jobs.build.outputs.version }}

permissions:
  contents: read

jobs:
  setup:
    name: Setup
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      cache-key: ${{ steps.cache.outputs.key }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Generate cache key
        id: cache
        run: echo "key=deps-${{ hashFiles('package-lock.json') }}" >> $GITHUB_OUTPUT

  test:
    name: Test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: setup
    if: inputs.run-tests
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

  build:
    name: Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: [setup, test]
    if: always() && (needs.test.result == 'success' || needs.test.result == 'skipped')
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Get version
        id: version
        run: echo "version=$(node -p "require('./package.json').version")" >> $GITHUB_OUTPUT

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ steps.version.outputs.version }}
          path: dist/

  notify:
    name: Notify
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs: build
    if: always() && secrets.SLACK_WEBHOOK != ''
    steps:
      - name: Send notification
        run: |
          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"Workflow completed with status: ${{ needs.build.result }}"}' \
            ${{ secrets.SLACK_WEBHOOK }}
```

#### Caller Example (include in comments)

```yaml
# Example: How to use this reusable workflow
#
# name: CI
#
# on:
#   push:
#     branches: [main]
#
# jobs:
#   call-reusable-workflow:
#     uses: ./.github/workflows/reusable-workflow.yml
#     with:
#       node-version: '20'
#       run-tests: true
#       environment: 'production'
#     secrets:
#       API_TOKEN: ${{ secrets.API_TOKEN }}
#       SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
```

### Phase 4: SHA Pinning Resolution

#### Step 4.1: Identify Third-Party Actions

In generated template, identify all third-party actions:

- docker/\*
- aws-actions/\*
- azure/\*
- google-github-actions/\*
- Custom organization actions

#### Step 4.2: Resolve Current SHA

For each third-party action, use git to resolve latest stable SHA:

```bash
git ls-remote https://github.com/docker/setup-buildx-action.git HEAD
```

Parse output to get commit SHA.

#### Step 4.3: Update Template with SHA

Replace version tags with resolved SHA:

```yaml
uses: docker/setup-buildx-action@8c0edd44fd9d2d25d1f32147d34faabc28ce1b7d # v3.0.0
```

Include version comment for human readability.

#### Step 4.4: Handle Resolution Failures

If git resolution fails (network issue):

- Use placeholder SHA with comment
- Document manual resolution needed
- Provide resolution instructions

### Phase 5: Finalization and Output

#### Step 5.1: Add Header Comments

Prepend workflow with documentation:

```yaml
# This workflow was generated by ccfg-github-actions scaffold
# Generated: 2026-02-09
# Language: JavaScript/Node.js
# Type: CI
#
# Required Secrets:
#   - None for basic CI
#   - CODECOV_TOKEN (optional) for coverage upload
#
# Required Repository Settings:
#   - None
#
# Workflow runs on:
#   - Push to main/develop branches
#   - Pull requests to main
#
# For more information, see:
#   - GitHub Actions docs: https://docs.github.com/actions
```

#### Step 5.2: Add Setup Instructions

Include commented instructions:

```yaml
# Setup Instructions:
# 1. Review and adjust branch names if needed
# 2. Configure required secrets in repository settings
# 3. Enable Actions in repository settings
# 4. Adjust timeouts based on project needs
# 5. Customize matrix strategy if multi-version testing needed
#
# Customization:
# - Adjust node-version to match your project requirements
# - Add/remove jobs as needed
# - Configure caching strategy
# - Add deployment steps
```

#### Step 5.3: Add Conventions Reference

If conventions document exists:

```yaml
# Organization Conventions:
# This workflow follows standards documented in:
#   docs/infra/github-actions-conventions.md
#
# Key requirements:
# - SHA-pinned third-party actions
# - Explicit permissions blocks
# - Timeout on all jobs
# - Concurrency controls on PR workflows
```

#### Step 5.4: Write Workflow File

Use Write tool to create workflow file:

```text
file_path: /absolute/path/.github/workflows/ci.yml
content: [generated workflow content]
```

#### Step 5.5: Verify File Creation

Confirm file was written successfully.

#### Step 5.6: Generate Summary Report

Create summary of what was generated:

- Workflow type and filename
- Detected language and version
- Included jobs and steps
- Required secrets
- Next steps for user

### Phase 6: Post-Generation Recommendations

#### Step 6.1: Suggest Related Workflows

Based on generated workflow, suggest complementary workflows:

- If generated CI, suggest cd and release
- If generated cd, suggest release
- If generated pr-checks, suggest ci

#### Step 6.2: Recommend Security Scanning

Suggest adding security scanning if not included:

- npm audit / pip-audit / cargo audit
- CodeQL analysis
- Dependency review
- Container scanning

#### Step 6.3: Suggest Conventions Document

If conventions doc doesn't exist:

"Consider creating a conventions document at: docs/infra/github-actions-conventions.md

This helps maintain consistency across workflows and documents:

- Required actions and versions
- Security requirements
- Deployment procedures
- Approval processes"

#### Step 6.4: Repository Settings Checklist

Provide checklist of repository settings to configure:

- Enable GitHub Actions
- Configure required secrets
- Set up environments (for CD workflows)
- Configure branch protection rules
- Set up required status checks

## Final Report Format

### Success Example - CI Workflow

```text
GitHub Actions Scaffold Complete
=================================

Generated: .github/workflows/ci.yml
Type: CI (Continuous Integration)
Language: JavaScript/Node.js (detected)

Workflow Details:
-----------------
Name: CI
Triggers:
  - Push to main, develop branches
  - Pull requests to main
Concurrency: Enabled with auto-cancel

Jobs:
  1. lint (10min timeout)
     - Checkout code
     - Setup Node.js 20 with npm cache
     - Install dependencies
     - Run ESLint

  2. test (15min timeout)
     - Checkout code
     - Setup Node.js 20 with npm cache
     - Install dependencies
     - Run Jest tests
     - Upload coverage to Codecov

  3. build (10min timeout, needs: [lint, test])
     - Checkout code
     - Setup Node.js 20 with npm cache
     - Install dependencies
     - Build with webpack
     - Upload build artifacts

Security Features:
------------------
✓ SHA-pinned third-party actions
✓ Explicit permissions (contents: read)
✓ Timeout on all jobs
✓ Concurrency controls
✓ Dependency caching

Detected Configuration:
-----------------------
Package Manager: npm (package-lock.json found)
Node Version: 20 (from package.json engines)
Test Command: npm test (from package.json scripts)
Lint Command: npm run lint (from package.json scripts)
Build Command: npm run build (from package.json scripts)

Next Steps:
-----------
1. Review workflow file: .github/workflows/ci.yml
2. Adjust branch names if needed (currently: main, develop)
3. Configure secrets (optional):
   - CODECOV_TOKEN for coverage upload
4. Commit and push to trigger first workflow run
5. Monitor workflow execution in Actions tab

Recommendations:
----------------
- Consider adding matrix testing for Node 18, 20, 22
- Add deployment workflow: /ccfg-github-actions scaffold --type=cd
- Add release automation: /ccfg-github-actions scaffold --type=release
- Create conventions document: docs/infra/github-actions-conventions.md

Resources:
----------
- Workflow file: /home/user/project/.github/workflows/ci.yml
- GitHub Actions docs: https://docs.github.com/actions
- Node.js Actions guide: https://docs.github.com/actions/guides/building-and-testing-nodejs
```

### Success Example - CD Workflow

```text
GitHub Actions Scaffold Complete
=================================

Generated: .github/workflows/deploy.yml
Type: CD (Continuous Deployment)
Language: JavaScript/Node.js (detected)

Workflow Details:
-----------------
Name: Deploy
Triggers:
  - Push to main branch (auto-deploy to staging)
  - Manual workflow dispatch with environment selection

Jobs:
  1. deploy-staging (20min timeout)
     Environment: staging
     - Checkout code
     - Configure AWS credentials (OIDC)
     - Build application
     - Deploy to staging environment
     - Run smoke tests

  2. deploy-production (30min timeout, needs: deploy-staging)
     Environment: production
     - Checkout code
     - Configure AWS credentials (OIDC)
     - Deploy to blue environment
     - Health check blue environment
     - Switch traffic to blue
     - Monitor for issues

Security Features:
------------------
✓ SHA-pinned third-party actions
✓ Explicit permissions (contents: read, id-token: write for OIDC)
✓ Environment protection rules
✓ OIDC authentication (no long-lived credentials)
✓ Blue-green deployment pattern
✓ Health checks before traffic switch

Required Secrets:
-----------------
None - Using OIDC federation

Required Repository Settings:
------------------------------
1. Configure OIDC provider:
   - Settings > Secrets and variables > Actions > Configure
   - Add AWS OIDC provider

2. Create environments:
   - Settings > Environments
   - Create 'staging' environment
   - Create 'production' environment
   - Add protection rules and reviewers for production

3. AWS IAM Role:
   - Create role: GitHubActionsRole
   - Trust policy for OIDC federation
   - ARN: arn:aws:iam::123456789012:role/GitHubActionsRole (update in workflow)

Next Steps:
-----------
1. Review workflow file: .github/workflows/deploy.yml
2. Update AWS IAM role ARN in workflow
3. Update deployment commands for your infrastructure
4. Configure staging and production environments in GitHub
5. Set up OIDC federation in AWS
6. Test deployment to staging first

Deployment Pattern:
-------------------
This workflow uses blue-green deployment:
- Deploy to inactive (blue) environment
- Health check blue environment
- Switch traffic from green to blue
- Monitor for issues
- Keep blue as active, green becomes next blue

Resources:
----------
- Workflow file: /home/user/project/.github/workflows/deploy.yml
- OIDC guide: https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
```

### Success Example - Reusable Workflow

```text
GitHub Actions Scaffold Complete
=================================

Generated: .github/workflows/reusable-workflow.yml
Type: Reusable Workflow
Language: JavaScript/Node.js (detected)

Workflow Details:
-----------------
Trigger: workflow_call

Inputs:
  - node-version (string, default: '20')
  - run-tests (boolean, default: true)
  - environment (string, default: 'staging')

Secrets:
  - API_TOKEN (required)
  - SLACK_WEBHOOK (optional)

Outputs:
  - build-version (version of built artifact)

Jobs:
  1. setup (5min timeout)
     - Checkout and install dependencies
     - Generate cache key

  2. test (15min timeout, conditional)
     - Run tests if run-tests input is true

  3. build (10min timeout)
     - Build application
     - Output version
     - Upload artifacts

  4. notify (5min timeout, conditional)
     - Send Slack notification if webhook provided

Usage Example:
--------------
Create a caller workflow (.github/workflows/ci.yml):
```

```yaml
name: CI

on:
  push:
    branches: [main]

jobs:
  call-reusable-workflow:
    uses: ./.github/workflows/reusable-workflow.yml
    with:
      node-version: '20'
      run-tests: true
      environment: 'production'
    secrets:
      API_TOKEN: ${{ secrets.API_TOKEN }}
      SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
```

```text
Next Steps:
-----------
1. Review reusable workflow: .github/workflows/reusable-workflow.yml
2. Customize inputs and secrets as needed
3. Create caller workflows to use this reusable workflow
4. Test with different input combinations
5. Document workflow contract for other teams

Benefits:
---------
- DRY: Define once, use many times
- Consistency: Same CI/CD logic across projects
- Maintainability: Update in one place
- Flexibility: Parameterized for different use cases

Resources:
----------
- Workflow file: /home/user/project/.github/workflows/reusable-workflow.yml
- Reusable workflows docs: https://docs.github.com/actions/learn-github-actions/reusing-workflows
```

## Implementation Notes

### Language Detection Edge Cases

#### Monorepo Detection

- Check for workspace files (pnpm-workspace.yaml, lerna.json)
- Scan for multiple package.json files
- Suggest paths filters for pr-checks workflow
- Consider matrix strategy for independent packages

#### Multi-Language Projects

- Prioritize by primary language (most source files)
- Consider separate workflows per language
- Suggest polyglot workflow structure
- Document manual customization needed

#### No Clear Language

- Generate generic workflow template
- Include setup placeholders
- Prompt user for language confirmation
- Provide customization guide

### Action Version Management

#### SHA Resolution

- Use git ls-remote for latest version
- Cache resolutions to avoid repeated network calls
- Handle rate limiting gracefully
- Provide manual resolution fallback

#### Version Comments

- Include human-readable version tag as comment
- Example: `@abc123...  # v3.0.0`
- Helps with future updates
- Makes audit easier

#### First-Party Actions

- actions/\* may use version tags
- Use latest stable version
- Document in comments
- Check for major version updates

### Template Maintenance

#### Action Updates

- SHA pins become stale over time
- Suggest periodic updates
- Document update process
- Consider dependabot for actions

#### Best Practices Evolution

- GitHub Actions features change
- New security recommendations emerge
- Update templates accordingly
- Version control template changes

### Error Recovery

#### Directory Creation Failure

- Check permissions
- Suggest manual creation
- Provide clear error message
- Don't fail entire scaffolding

#### File Write Failure

- Check if file locked
- Check disk space
- Suggest alternative location
- Provide workflow content for manual creation

#### Network Failure (SHA Resolution)

- Graceful degradation
- Use placeholder with instructions
- Continue scaffolding
- Document manual steps

## Advanced Features

### Template Customization

Support user-provided templates:

- Check for `.github/workflow-templates/` directory
- Load custom templates if present
- Merge with generated content
- Document customization points

### Organization Defaults

Support organization-wide defaults:

- Load from `.github/.github/workflows/` in org repo
- Apply org-specific settings
- Enforce required checks
- Include org-mandated steps

### Interactive Mode

For ambiguous situations:

- Prompt for language if unclear
- Ask about deployment target
- Confirm branch names
- Select optional features

### Incremental Updates

Update existing workflows:

- Parse existing workflow
- Identify outdated patterns
- Suggest specific improvements
- Preserve custom modifications

## Testing Strategy

Test scaffolding with:

- Empty repository (no language files)
- Single-language projects (Node, Python, Go, Rust, Java)
- Multi-language projects
- Monorepo structures
- Existing workflows (conflict handling)
- Network unavailable (offline mode)
- Non-git directory

Validate generated workflows:

- Syntax correctness
- Action pinning compliance
- Permission appropriateness
- Timeout presence
- Concurrency configuration
- Secret handling
