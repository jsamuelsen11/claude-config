---
name: ci-patterns
description:
  This skill should be used when implementing CI pipelines, configuring caching, setting up matrix
  builds, creating composite actions, or optimizing workflow performance.
version: 0.1.0
---

# CI Patterns for GitHub Actions

This skill covers advanced continuous integration patterns that improve build speed, reliability,
and maintainability. These patterns are essential for scaling CI systems across large projects and
teams.

## Existing Repository Compatibility

When implementing CI patterns in existing repositories, careful analysis is required:

**Assessment Process**:

1. Review existing workflow execution times and identify bottlenecks
2. Check current caching strategy (if any) and measure hit rates
3. Analyze matrix build configurations and success/failure patterns
4. Identify duplicated step sequences across multiple workflows
5. Review artifact usage and retention policies
6. Check for existing composite actions or reusable workflows
7. Measure current CI costs and resource usage

**Compatibility Considerations**:

- Preserve existing cache keys unless you have a migration plan
- Test new caching strategies on a feature branch before main
- Don't break existing matrix configurations without team coordination
- Ensure new composite actions are backwards compatible
- Maintain existing artifact naming conventions for dependent workflows
- Keep workflow run times stable during optimization (avoid regressions)
- Document all changes to CI patterns in pull requests

**Migration Strategies**:

- Introduce new patterns alongside old ones initially
- Use feature flags or branch conditions to test new approaches
- Migrate one workflow at a time to reduce risk
- Monitor metrics before and after changes
- Have rollback plans for performance-critical workflows
- Communicate changes to team members who depend on CI artifacts

## Caching Strategies

Effective caching dramatically reduces build times and costs:

**Built-in Cache on Setup Actions**:

**CORRECT - Node.js with npm**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'

  - name: Install dependencies
    run: npm ci

  - name: Run tests
    run: npm test
```

**CORRECT - Python with pip**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Python
    uses: actions/setup-python@v5
    with:
      python-version: '3.11'
      cache: 'pip'

  - name: Install dependencies
    run: pip install -r requirements.txt

  - name: Run tests
    run: pytest
```

**CORRECT - Multiple Package Managers**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Node.js for npm
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
      cache-dependency-path: 'web/package-lock.json'

  - name: Install web dependencies
    working-directory: web
    run: npm ci
```

**WRONG**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      # Missing cache configuration

  - name: Install dependencies
    run: npm ci
```

**Actions with Built-in Caching**:

| Setup Action   | Cache Parameter   | Cached Content     |
| -------------- | ----------------- | ------------------ |
| `setup-node`   | `cache: 'npm'`    | `~/.npm`           |
| `setup-node`   | `cache: 'yarn'`   | `~/.yarn/cache`    |
| `setup-node`   | `cache: 'pnpm'`   | `~/.pnpm-store`    |
| `setup-python` | `cache: 'pip'`    | `~/.cache/pip`     |
| `setup-python` | `cache: 'pipenv'` | `~/.cache/pipenv`  |
| `setup-java`   | `cache: 'maven'`  | `~/.m2/repository` |
| `setup-java`   | `cache: 'gradle'` | `~/.gradle/caches` |
| `setup-go`     | `cache: true`     | `~/go/pkg/mod`     |

**Manual Caching with actions/cache**:

**CORRECT - Build Output Caching**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Cache build output
    uses: actions/cache@v4
    with:
      path: |
        dist/
        .next/cache
      key: build-${{ runner.os }}-${{ hashFiles('src/**', 'package-lock.json') }}
      restore-keys: |
        build-${{ runner.os }}-

  - name: Build application
    run: npm run build
```

**CORRECT - Cargo/Rust Caching**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Cache Cargo registry
    uses: actions/cache@v4
    with:
      path: |
        ~/.cargo/bin/
        ~/.cargo/registry/index/
        ~/.cargo/registry/cache/
        ~/.cargo/git/db/
        target/
      key: cargo-${{ runner.os }}-${{ hashFiles('**/Cargo.lock') }}
      restore-keys: |
        cargo-${{ runner.os }}-

  - name: Build project
    run: cargo build --release
```

**CORRECT - Multiple Cache Paths**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Cache dependencies and build
    uses: actions/cache@v4
    with:
      path: |
        node_modules/
        .npm/
        dist/
        .eslintcache
      key: ci-${{ runner.os }}-${{ hashFiles('package-lock.json', 'src/**/*.ts') }}
      restore-keys: |
        ci-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
        ci-${{ runner.os }}-
```

**WRONG - Overly Broad Cache Key**:

```yaml
steps:
  - name: Cache dependencies
    uses: actions/cache@v4
    with:
      path: node_modules/
      key: deps-${{ runner.os }}
      # Missing hashFiles - cache won't update when dependencies change
```

**WRONG - Caching Generated Files Without Dependencies**:

```yaml
steps:
  - name: Cache build
    uses: actions/cache@v4
    with:
      path: dist/
      key: build-${{ runner.os }}
      # No source code hash - stale builds will be reused
```

**Cache Key Best Practices**:

1. **Primary Key Structure**: `{type}-{os}-{hash}`
   - Type: Purpose of cache (deps, build, test)
   - OS: Platform identifier
   - Hash: Content-based hash using `hashFiles()`

2. **Hash Selection**:

   ```yaml
   # Dependencies only
   key: deps-${{ hashFiles('package-lock.json') }}

   # Multiple lock files
   key: deps-${{ hashFiles('**/package-lock.json', '**/yarn.lock') }}

   # Source code + dependencies
   key: build-${{ hashFiles('src/**', 'package-lock.json') }}

   # Include configuration files
   key: build-${{ hashFiles('src/**', 'tsconfig.json', 'webpack.config.js') }}
   ```

3. **Restore Keys Priority**:

   ```yaml
   restore-keys: |
     deps-${{ runner.os }}-${{ hashFiles('package-lock.json') }}-
     deps-${{ runner.os }}-
   ```

   - Most specific first (exact version)
   - Progressively broader (same OS)
   - Never restore from different OS

**Cache Management**:

**CORRECT - Cache Cleanup Strategy**:

```yaml
# Automatically handled by GitHub (7 days retention)
# Total size limit: 10 GB per repository

# Manual cache invalidation when needed:
# 1. Change cache key prefix
# 2. Clear via GitHub UI or API
# 3. Update hashFiles() pattern
```

**Cache Hit Rate Monitoring**:

```yaml
steps:
  - name: Cache dependencies
    id: cache-deps
    uses: actions/cache@v4
    with:
      path: node_modules/
      key: deps-${{ hashFiles('package-lock.json') }}

  - name: Report cache status
    run: |
      if [ "${{ steps.cache-deps.outputs.cache-hit }}" = "true" ]; then
        echo "✓ Cache hit - dependencies restored from cache"
      else
        echo "✗ Cache miss - installing dependencies"
      fi

  - name: Install dependencies
    if: steps.cache-deps.outputs.cache-hit != 'true'
    run: npm ci
```

## Matrix Builds

Matrix builds enable testing across multiple configurations efficiently:

**CORRECT - Basic Matrix**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: [18, 20, 22]
        os: [ubuntu-latest, macos-latest, windows-latest]

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
```

**CORRECT - Matrix with Include/Exclude**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node-version: [18, 20]
        include:
          # Add specific combination with extra configuration
          - os: ubuntu-latest
            node-version: 20
            experimental: true
            coverage: true
        exclude:
          # Remove unsupported combination
          - os: macos-latest
            node-version: 18

    runs-on: ${{ matrix.os }}
    continue-on-error: ${{ matrix.experimental || false }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Run tests
        run: npm test

      - name: Generate coverage
        if: matrix.coverage
        run: npm run test:coverage
```

**CORRECT - Matrix with Multiple Dimensions**:

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        python-version: ['3.9', '3.10', '3.11', '3.12']
        django-version: ['3.2', '4.2', '5.0']
        database: [postgres, mysql, sqlite]
        exclude:
          # Django 5.0 requires Python 3.10+
          - python-version: '3.9'
            django-version: '5.0'
          # Don't test all DB combinations for older versions
          - python-version: '3.9'
            database: mysql

    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install Django ${{ matrix.django-version }}
        run: pip install Django==${{ matrix.django-version }}

      - name: Run tests with ${{ matrix.database }}
        env:
          DATABASE_ENGINE: ${{ matrix.database }}
        run: pytest
```

**WRONG - Too Many Combinations**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node-version: [16, 18, 20, 22]
        python-version: ['3.9', '3.10', '3.11', '3.12']
        database: [postgres, mysql, sqlite, mongodb]
    # This creates 3 * 4 * 4 * 4 = 192 jobs!
    # Way too many, will be slow and expensive
```

**WRONG - Missing fail-fast Configuration**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
      # Missing fail-fast: false
      # One failure will cancel all other jobs
```

**Matrix Strategy Guidelines**:

| Factor             | Recommendation           | Rationale                        |
| ------------------ | ------------------------ | -------------------------------- |
| Total combinations | Keep under 20            | Reduces cost and completion time |
| `fail-fast`        | `false` for matrix tests | See all failures, not just first |
| `max-parallel`     | Usually omit             | GitHub optimizes automatically   |
| Required checks    | Use separate job         | Don't require all matrix jobs    |

**CORRECT - Matrix with Dynamic Configuration**:

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set matrix configurations
        id: set-matrix
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            # Minimal matrix for PRs
            echo 'matrix={"node-version": [20], "os": ["ubuntu-latest"]}' >> $GITHUB_OUTPUT
          else
            # Full matrix for main branch
            echo 'matrix={"node-version": [18, 20, 22], "os": ["ubuntu-latest", "macos-latest", "windows-latest"]}' >> $GITHUB_OUTPUT
          fi

  test:
    needs: setup
    strategy:
      matrix: ${{ fromJson(needs.setup.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    steps:
      - name: Run tests
        run: npm test
```

**Matrix Caching Best Practices**:

**CORRECT - Separate Caches per Matrix Dimension**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        node-version: [18, 20]
        os: [ubuntu-latest, macos-latest]

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
          # Cache key automatically includes OS and Node version

      - name: Cache test fixtures
        uses: actions/cache@v4
        with:
          path: test-fixtures/
          key: fixtures-${{ runner.os }}-${{ matrix.node-version }}-${{ hashFiles('test/**') }}
```

## Composite Actions

Composite actions reduce duplication by encapsulating reusable step sequences:

**When to Create Composite Actions**:

- 3+ steps repeated across multiple workflows
- Complex setup that requires specific configuration
- Steps that need to stay in sync across workflows
- Common patterns used by multiple teams

**CORRECT - Simple Composite Action**:

```yaml
# .github/actions/setup-node-project/action.yml
name: Setup Node.js Project
description: Checkout code, setup Node.js, and install dependencies

inputs:
  node-version:
    description: Node.js version to use
    required: false
    default: '20'
  working-directory:
    description: Directory containing package.json
    required: false
    default: '.'

runs:
  using: composite
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
        cache-dependency-path: ${{ inputs.working-directory }}/package-lock.json

    - name: Install dependencies
      shell: bash
      working-directory: ${{ inputs.working-directory }}
      run: npm ci
```

**Using the Composite Action**:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Setup project
        uses: ./.github/actions/setup-node-project
        with:
          node-version: '20'

      - name: Run tests
        run: npm test
```

**CORRECT - Composite Action with Outputs**:

```yaml
# .github/actions/build-info/action.yml
name: Build Information
description: Extract version and commit information

outputs:
  version:
    description: Version from package.json
    value: ${{ steps.version.outputs.version }}
  short-sha:
    description: Short commit SHA
    value: ${{ steps.sha.outputs.short-sha }}
  build-tag:
    description: Full build tag
    value: ${{ steps.tag.outputs.build-tag }}

runs:
  using: composite
  steps:
    - name: Extract version
      id: version
      shell: bash
      run: |
        VERSION=$(node -p "require('./package.json').version")
        echo "version=${VERSION}" >> $GITHUB_OUTPUT

    - name: Get short SHA
      id: sha
      shell: bash
      run: |
        SHORT_SHA=$(git rev-parse --short HEAD)
        echo "short-sha=${SHORT_SHA}" >> $GITHUB_OUTPUT

    - name: Create build tag
      id: tag
      shell: bash
      run: |
        TAG="v${{ steps.version.outputs.version }}-${{ steps.sha.outputs.short-sha }}"
        echo "build-tag=${TAG}" >> $GITHUB_OUTPUT
```

**Using with Outputs**:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get build info
        id: info
        uses: ./.github/actions/build-info

      - name: Build with version tag
        run: |
          echo "Building version ${{ steps.info.outputs.version }}"
          echo "Build tag: ${{ steps.info.outputs.build-tag }}"
          docker build -t app:${{ steps.info.outputs.build-tag }} .
```

**CORRECT - Composite Action with Error Handling**:

```yaml
# .github/actions/deploy-check/action.yml
name: Deployment Checks
description: Run pre-deployment validation

inputs:
  environment:
    description: Target environment
    required: true
  health-check-url:
    description: URL to check before deployment
    required: true

runs:
  using: composite
  steps:
    - name: Validate environment
      shell: bash
      run: |
        VALID_ENVS="staging production"
        if [[ ! " ${VALID_ENVS} " =~ " ${{ inputs.environment }} " ]]; then
          echo "Error: Invalid environment '${{ inputs.environment }}'"
          echo "Valid environments: ${VALID_ENVS}"
          exit 1
        fi

    - name: Check service health
      shell: bash
      run: |
        MAX_RETRIES=3
        RETRY=0

        while [ $RETRY -lt $MAX_RETRIES ]; do
          if curl -f -s "${{ inputs.health-check-url }}" > /dev/null; then
            echo "Health check passed"
            exit 0
          fi

          RETRY=$((RETRY + 1))
          echo "Health check failed (attempt $RETRY/$MAX_RETRIES)"

          if [ $RETRY -lt $MAX_RETRIES ]; then
            sleep 5
          fi
        done

        echo "Health check failed after $MAX_RETRIES attempts"
        exit 1

    - name: Verify deployment permissions
      shell: bash
      env:
        GITHUB_TOKEN: ${{ github.token }}
      run: |
        # Check if workflow has deployment permissions
        gh api repos/${{ github.repository }}/environments/${{ inputs.environment }} \
          || echo "Warning: Environment not configured"
```

**WRONG - Missing Shell Specification**:

```yaml
# .github/actions/bad-example/action.yml
runs:
  using: composite
  steps:
    - name: Run command
      run: echo "This will fail"
      # Missing shell: bash
```

**WRONG - Using Checkout in Composite Action**:

```yaml
# Don't checkout in composite actions - do it in the calling workflow
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4 # WRONG - caller should checkout
    - name: Do something
      shell: bash
      run: ./script.sh
```

**Composite Action Best Practices**:

1. **Always specify `shell`** in run steps
2. **Don't include checkout** - let callers handle it
3. **Use inputs for configuration** - don't hardcode values
4. **Provide sensible defaults** for optional inputs
5. **Document outputs clearly** in descriptions
6. **Handle errors explicitly** - don't assume success
7. **Keep actions focused** - single responsibility principle
8. **Version your actions** if shared across repositories

## Reusable Workflows

Reusable workflows enable sharing entire workflow logic:

**CORRECT - Reusable Workflow Definition**:

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deployment

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      version:
        required: true
        type: string
      region:
        required: false
        type: string
        default: 'us-east-1'
    secrets:
      AWS_ACCESS_KEY_ID:
        required: true
      AWS_SECRET_ACCESS_KEY:
        required: true
      DEPLOY_TOKEN:
        required: false
    outputs:
      deployment-url:
        description: URL of the deployed application
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    outputs:
      url: ${{ steps.deploy.outputs.url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ inputs.region }}

      - name: Deploy application
        id: deploy
        run: |
          echo "Deploying version ${{ inputs.version }} to ${{ inputs.environment }}"
          URL=$(./deploy.sh ${{ inputs.environment }} ${{ inputs.version }})
          echo "url=${URL}" >> $GITHUB_OUTPUT

      - name: Verify deployment
        run: |
          curl -f ${{ steps.deploy.outputs.url }}/health
```

**Calling the Reusable Workflow**:

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [develop]

jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      version: ${{ github.sha }}
      region: us-west-2
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.STAGING_AWS_KEY }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.STAGING_AWS_SECRET }}
```

**CORRECT - Reusable Workflow with Multiple Jobs**:

```yaml
# .github/workflows/reusable-test.yml
name: Reusable Test Suite

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
      run-integration-tests:
        type: boolean
        default: false

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run test:unit

  integration-test:
    if: inputs.run-integration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run test:integration
```

**WRONG - Nesting Too Deep**:

```yaml
# Workflow A calls Workflow B calls Workflow C calls Workflow D
# Maximum nesting depth is 4 - avoid going this deep
# Better: flatten the hierarchy or use composite actions
```

**Reusable Workflow vs Composite Action Decision Matrix**:

| Factor         | Reusable Workflow           | Composite Action            |
| -------------- | --------------------------- | --------------------------- |
| Scope          | Multiple jobs               | Multiple steps within a job |
| Secrets        | Can define required secrets | Uses caller's secrets       |
| Permissions    | Can define permissions      | Inherits from job           |
| Conditionals   | Job-level conditionals      | Step-level conditionals     |
| Matrix         | Can use matrix              | Cannot use matrix           |
| Use case       | Complete CI/CD pipeline     | Reusable step sequence      |
| Calling syntax | `uses:` at job level        | `uses:` at step level       |

## Artifacts

Artifacts enable sharing data between jobs and workflow runs:

**CORRECT - Basic Artifact Upload/Download**:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          retention-days: 7

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-output
          path: dist/

      - name: Deploy application
        run: ./deploy.sh dist/
```

**CORRECT - Multiple Artifacts with Context-Aware Naming**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node-version: [18, 20]

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Run tests
        run: npm test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.os }}-node${{ matrix.node-version }}
          path: |
            test-results/
            coverage/
          retention-days: 14
```

**CORRECT - Conditional Artifact Upload**:

```yaml
steps:
  - name: Run tests with coverage
    run: npm run test:coverage
    continue-on-error: true

  - name: Upload coverage report
    if: success() || failure()
    uses: actions/upload-artifact@v4
    with:
      name: coverage-report-${{ github.sha }}
      path: coverage/
      if-no-files-found: warn
      retention-days: 30
```

**CORRECT - Large Binary Artifacts**:

```yaml
steps:
  - name: Build release binaries
    run: cargo build --release

  - name: Upload Linux binary
    uses: actions/upload-artifact@v4
    with:
      name: binary-linux-amd64
      path: target/release/myapp
      retention-days: 90
      compression-level: 9 # Maximum compression for large files
```

**WRONG - Uploading Sensitive Files**:

```yaml
steps:
  - name: Upload everything
    uses: actions/upload-artifact@v4
    with:
      name: all-files
      path: .
      # WRONG: Will include .env, secrets, node_modules, etc.
```

**WRONG - No Retention Policy**:

```yaml
steps:
  - name: Upload temporary build
    uses: actions/upload-artifact@v4
    with:
      name: build
      path: dist/
      # Missing retention-days - uses default 90 days
      # Wastes storage for temporary artifacts
```

**Artifact Best Practices**:

| Aspect     | Recommendation                      | Rationale                         |
| ---------- | ----------------------------------- | --------------------------------- |
| Naming     | Include context (OS, version, SHA)  | Avoid conflicts, enable debugging |
| Retention  | Set appropriate days (7-90)         | Balance storage costs vs needs    |
| Size       | Compress or filter large files      | Faster upload/download            |
| Paths      | Use specific paths, not `.`         | Avoid uploading secrets           |
| Conditions | Use `if: always()` for test results | Capture failures                  |

## Monorepo Patterns

Optimize workflows for monorepo repositories:

**CORRECT - Path Filters on Triggers**:

```yaml
name: Backend CI

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - 'shared/**'
      - '.github/workflows/backend-ci.yml'
  pull_request:
    paths:
      - 'backend/**'
      - 'shared/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Test backend
        working-directory: backend
        run: npm test
```

**CORRECT - Dynamic Job Execution with Path Filters**:

```yaml
name: Monorepo CI

on:
  pull_request:

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
      mobile: ${{ steps.filter.outputs.mobile }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check for changes
        uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - 'apps/backend/**'
              - 'packages/shared/**'
            frontend:
              - 'apps/frontend/**'
              - 'packages/ui/**'
              - 'packages/shared/**'
            mobile:
              - 'apps/mobile/**'
              - 'packages/shared/**'

  backend:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test backend
        run: npm run test:backend

  frontend:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test frontend
        run: npm run test:frontend

  mobile:
    needs: changes
    if: needs.changes.outputs.mobile == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test mobile
        run: npm run test:mobile
```

**CORRECT - Selective Caching by Project**:

```yaml
jobs:
  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: 'backend/package-lock.json'

      - name: Install backend dependencies
        working-directory: backend
        run: npm ci

      - name: Test backend
        working-directory: backend
        run: npm test
```

**CORRECT - Matrix Build for Multiple Projects**:

```yaml
jobs:
  test:
    strategy:
      matrix:
        project:
          - name: backend
            path: apps/backend
            test-command: npm run test:unit
          - name: frontend
            path: apps/frontend
            test-command: npm run test
          - name: api
            path: services/api
            test-command: cargo test

    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Test ${{ matrix.project.name }}
        working-directory: ${{ matrix.project.path }}
        run: ${{ matrix.project.test-command }}
```

These CI patterns form the foundation of efficient, maintainable continuous integration pipelines.
Apply them thoughtfully based on your project's specific needs and constraints.
