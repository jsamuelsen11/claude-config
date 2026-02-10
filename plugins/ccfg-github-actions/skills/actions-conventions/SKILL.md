---
name: actions-conventions
description:
  This skill should be used when working with GitHub Actions, writing CI/CD workflows, configuring
  workflow triggers, or reviewing GitHub Actions configuration.
version: 0.1.0
---

# GitHub Actions Conventions

This skill provides comprehensive guidelines for writing maintainable, secure, and efficient GitHub
Actions workflows. Following these conventions ensures consistency across repositories, reduces
debugging time, and improves collaboration between team members.

## Existing Repository Compatibility

When working with existing repositories, always respect established workflow patterns and
conventions:

**Discovery Process**:

1. Review all workflows in `.github/workflows/` to understand existing patterns
2. Check for custom composite actions in `.github/actions/`
3. Identify the action version pinning strategy currently in use
4. Note any repository-specific naming conventions or organizational standards
5. Review workflow run history to understand trigger patterns and success rates

**Adaptation Rules**:

- Match existing file naming conventions (some teams use underscores, most use kebab-case)
- Preserve established trigger patterns unless explicitly asked to change them
- Maintain consistency with existing job and step naming styles
- Keep the same level of verbosity in step names as existing workflows
- Respect existing action version pinning strategies (tags vs SHA)
- Flag but don't automatically change tag-based pinning without coordination
- Preserve existing runner selection patterns unless there's a clear reason to change
- Match existing permissions scoping patterns

**When to Propose Changes**:

- Security issues (missing permissions scoping, credentials in logs)
- Performance problems (missing caches, inefficient matrix builds)
- Reliability concerns (missing concurrency controls, race conditions)
- Maintenance burden (duplicated code that could be extracted)

Always explain why changes are necessary and coordinate with the team before making breaking changes
to critical workflows.

## Workflow File Naming

Use descriptive, kebab-case names that clearly indicate the workflow's purpose:

**CORRECT**:

```yaml
# .github/workflows/ci.yml
# .github/workflows/deploy-staging.yml
# .github/workflows/release-npm-package.yml
# .github/workflows/security-scan.yml
# .github/workflows/update-dependencies.yml
```

**WRONG**:

```yaml
# .github/workflows/CI.yml (uppercase)
# .github/workflows/deploy_staging.yml (underscore)
# .github/workflows/workflow1.yml (non-descriptive)
# .github/workflows/do-stuff.yml (vague)
```

**Naming Conventions**:

- Primary CI workflow: `ci.yml` or `test.yml`
- Deployment workflows: `deploy-{environment}.yml` or `cd.yml`
- Release workflows: `release.yml` or `release-{type}.yml`
- Scheduled tasks: `{task-name}-scheduled.yml`
- Manual operations: `{operation-name}-manual.yml`

## Workflow Structure

Every workflow should follow a consistent structure:

**CORRECT**:

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
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

      - name: Run linter
        run: npm run lint

  test:
    name: Run Tests
    runs-on: ubuntu-latest
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

**WRONG**:

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm test
```

## Step Naming

Always provide a descriptive `name:` for every step:

**CORRECT**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Python 3.11
    uses: actions/setup-python@v5
    with:
      python-version: '3.11'

  - name: Install dependencies
    run: pip install -r requirements.txt

  - name: Run unit tests
    run: pytest tests/unit

  - name: Upload coverage report
    uses: actions/upload-artifact@v4
    with:
      name: coverage-report
      path: coverage/
```

**WRONG**:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-python@v5
    with:
      python-version: '3.11'
  - run: pip install -r requirements.txt
  - run: pytest tests/unit
```

**Naming Guidelines**:

- Use imperative mood (Checkout, Run, Upload, not Checking out, Running, Uploading)
- Be specific about what's being done (Run unit tests, not Run tests)
- Include relevant details (Set up Python 3.11, not Set up Python)
- Keep names concise but descriptive (under 60 characters when possible)
- Use consistent terminology across workflows

## Trigger Configuration

Choose triggers carefully based on your workflow's purpose:

**CORRECT - CI Workflow**:

```yaml
on:
  push:
    branches: [main, develop]
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches: [main]
  workflow_dispatch:
```

**CORRECT - Deployment Workflow**:

```yaml
on:
  push:
    branches: [main]
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to deploy'
        required: true
        type: string
```

**CORRECT - Scheduled Workflow**:

```yaml
on:
  schedule:
    # Run every Monday at 9 AM UTC
    - cron: '0 9 * * 1'
  workflow_dispatch:
```

**WRONG**:

```yaml
on: [push]  # Too broad, runs on all branches

on:
  push:
    branches: ['*']  # Same problem

on:
  schedule:
    - cron: '0 9 * * 1'
  # Missing workflow_dispatch for manual testing
```

**Trigger Selection Guide**:

| Use Case              | Recommended Trigger         | Notes                                  |
| --------------------- | --------------------------- | -------------------------------------- |
| PR validation         | `pull_request`              | Use `types:` to filter specific events |
| Main branch CI        | `push: branches: [main]`    | Validates merged code                  |
| Release automation    | `push: tags:` or `release:` | Tag pattern matching                   |
| Scheduled maintenance | `schedule:`                 | Always add `workflow_dispatch` too     |
| Manual operations     | `workflow_dispatch:`        | Use inputs for parameters              |
| External events       | `repository_dispatch:`      | For webhooks from other systems        |
| Dependency updates    | `pull_request: paths:`      | Target specific files                  |

## YAML Style Guidelines

Consistent YAML formatting improves readability and reduces errors:

**Multi-line Scripts**:

**CORRECT**:

```yaml
- name: Run integration tests
  shell: bash
  run: |
    set -euo pipefail

    echo "Starting integration tests..."
    export DATABASE_URL="postgresql://localhost/test"
    export API_KEY="${{ secrets.TEST_API_KEY }}"

    npm run test:integration

    if [ $? -eq 0 ]; then
      echo "Integration tests passed"
    else
      echo "Integration tests failed"
      exit 1
    fi
```

**WRONG**:

```yaml
- name: Run integration tests
  run: >
    set -euo pipefail && echo "Starting integration tests..." && export
    DATABASE_URL="postgresql://localhost/test" && export API_KEY="${{ secrets.TEST_API_KEY }}" &&
    npm run test:integration
```

**Shell Selection**:

**CORRECT**:

```yaml
- name: Run build script
  shell: bash
  run: |
    ./scripts/build.sh

- name: Windows-specific step
  if: runner.os == 'Windows'
  shell: pwsh
  run: |
    Get-ChildItem -Recurse
```

**WRONG**:

```yaml
- name: Run build script
  run: |
    ./scripts/build.sh
  # Missing explicit shell

- name: Cross-platform command
  shell: sh
  run: |
    # sh is too limited, use bash instead
    [[ -f file.txt ]] && cat file.txt
```

**Shell Guidelines**:

- Always specify `shell: bash` explicitly
- Use `shell: pwsh` for PowerShell on all platforms
- Avoid `sh` (too limited) and `bash -e` (redundant with set -e)
- Add `set -euo pipefail` at the start of complex scripts
- Use `shell: python` for Python one-liners

**Expression Quoting**:

**CORRECT**:

```yaml
- name: Conditional deployment
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  shell: bash
  run: |
    VERSION="${{ github.sha }}"
    ENV_NAME="${{ inputs.environment }}"

    echo "Deploying ${VERSION} to ${ENV_NAME}"
    ./deploy.sh "${VERSION}" "${ENV_NAME}"

- name: Use matrix value
  shell: bash
  run: |
    NODE_VERSION="${{ matrix.node-version }}"
    echo "Testing with Node.js ${NODE_VERSION}"
```

**WRONG**:

```yaml
- name: Conditional deployment
  shell: bash
  run: |
    VERSION=${{ github.sha }}  # Unquoted expression
    ENV_NAME=${{ inputs.environment }}

    echo "Deploying $VERSION to $ENV_NAME"
```

**Environment Variables**:

**CORRECT**:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      NODE_ENV: production
      BUILD_VERSION: ${{ github.sha }}

    steps:
      - name: Build application
        env:
          API_ENDPOINT: ${{ secrets.API_ENDPOINT }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          npm run build

      - name: Another step without extra env vars
        run: |
          echo "Build version: ${BUILD_VERSION}"
```

**WRONG**:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Build application
        env:
          NODE_ENV: production
          BUILD_VERSION: ${{ github.sha }}
          API_ENDPOINT: ${{ secrets.API_ENDPOINT }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          npm run build

      - name: Another step
        env:
          # Duplicating env vars in every step
          NODE_ENV: production
          BUILD_VERSION: ${{ github.sha }}
        run: |
          echo "Build version: ${BUILD_VERSION}"
```

**Environment Variable Scoping Rules**:

- Job-level `env:` for variables used across multiple steps
- Step-level `env:` for variables used only in that step
- Workflow-level `env:` sparingly (rarely needed)
- Always scope secrets to the minimal necessary level

## Permissions

Always use explicit permissions to follow the principle of least privilege:

**CORRECT - Read-Only Workflow**:

```yaml
name: CI

on:
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        run: npm test
```

**CORRECT - Workflow with PR Comments**:

```yaml
name: Test Coverage

on:
  pull_request:

permissions:
  contents: read
  pull-requests: write

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests with coverage
        run: npm run test:coverage

      - name: Comment coverage on PR
        uses: actions/github-script@v7
        with:
          script: |
            // Post coverage results
```

**CORRECT - Deployment with OIDC**:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1
```

**CORRECT - Job-Specific Permissions**:

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build artifacts
        run: npm run build

  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
```

**WRONG**:

```yaml
name: CI

on:
  pull_request:

# Missing permissions - uses default which may be too permissive

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

**Permissions Reference**:

| Permission      | Read        | Write                         | Common Use Cases         |
| --------------- | ----------- | ----------------------------- | ------------------------ |
| `contents`      | Clone repo  | Push commits, create releases | Most workflows need read |
| `pull-requests` | Read PRs    | Comment on PRs, update labels | PR feedback workflows    |
| `issues`        | Read issues | Comment, update labels        | Issue management         |
| `id-token`      | N/A         | Request OIDC token            | Cloud authentication     |
| `packages`      | Download    | Publish packages              | Container registries     |
| `deployments`   | Read        | Create deployments            | Deployment tracking      |
| `checks`        | Read        | Create check runs             | Custom CI reporting      |
| `statuses`      | Read        | Create commit statuses        | Legacy CI reporting      |

**Default Permissions Strategy**:

1. Start with `permissions: contents: read`
2. Add specific permissions as needed
3. Scope additional permissions to specific jobs when possible
4. Never use `permissions: write-all` in production workflows

## Concurrency Control

Use concurrency groups to prevent workflow conflicts and save resources:

**CORRECT - Pull Request Workflow**:

```yaml
name: PR Validation

on:
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        run: npm test
```

**CORRECT - Branch-Based Workflow**:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build project
        run: npm run build
```

**CORRECT - Deployment Workflow (No Cancellation)**:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

concurrency:
  group: production-deployment
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy application
        run: ./deploy.sh production
```

**CORRECT - Job-Level Concurrency**:

```yaml
name: Multi-Environment Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]

jobs:
  deploy:
    runs-on: ubuntu-latest
    concurrency:
      group: deploy-${{ inputs.environment }}
      cancel-in-progress: false
    steps:
      - name: Deploy to ${{ inputs.environment }}
        run: ./deploy.sh ${{ inputs.environment }}
```

**WRONG**:

```yaml
name: Deploy

on:
  push:
    branches: [main]

concurrency:
  group: deployment
  cancel-in-progress: true # DANGEROUS: Could cancel in-flight deployments

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

**Concurrency Guidelines**:

| Workflow Type | Group Pattern                                                    | Cancel in Progress               |
| ------------- | ---------------------------------------------------------------- | -------------------------------- |
| PR validation | `${{ github.workflow }}-${{ github.event.pull_request.number }}` | `true`                           |
| Branch CI     | `${{ github.workflow }}-${{ github.ref }}`                       | `true` for PRs, `false` for main |
| Deployment    | `deploy-${{ environment }}`                                      | `false`                          |
| Release       | `release-${{ github.ref }}`                                      | `false`                          |
| Scheduled     | `${{ github.workflow }}`                                         | `false`                          |

## Runner Selection

Choose appropriate runners based on your needs:

**CORRECT - Standard Linux Workflow**:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        run: npm test
```

**CORRECT - Pinned Version for Reproducibility**:

```yaml
jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build with specific tools
        run: |
          # This workflow requires specific Ubuntu 22.04 dependencies
          ./build.sh
```

**CORRECT - Multi-OS Matrix**:

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
```

**CORRECT - Self-Hosted Runners**:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, deployment]
    steps:
      - name: Deploy to internal network
        run: ./deploy.sh
```

**WRONG**:

```yaml
jobs:
  test:
    runs-on: ubuntu-20.04 # Don't use old versions without reason
    steps:
      - run: npm test

  deploy:
    runs-on: self-hosted # Too broad, should include labels
    steps:
      - run: ./deploy.sh
```

**Runner Selection Guide**:

| Use Case            | Recommended Runner                     | Notes                         |
| ------------------- | -------------------------------------- | ----------------------------- |
| General CI/CD       | `ubuntu-latest`                        | Fastest and cheapest          |
| macOS builds        | `macos-latest`                         | For iOS, macOS apps           |
| Windows builds      | `windows-latest`                       | For .NET, Windows apps        |
| Reproducible builds | `ubuntu-22.04`                         | Pin when you need consistency |
| GPU workloads       | `ubuntu-latest-8-cores` or self-hosted | Larger runners available      |
| Network-isolated    | Self-hosted                            | For internal deployments      |
| Cost optimization   | `ubuntu-latest` + matrix               | Linux runners are cheapest    |

**Runner Sizing**:

GitHub offers larger runners for performance-critical workloads:

```yaml
jobs:
  intensive-build:
    runs-on: ubuntu-latest-8-cores
    steps:
      - name: Build large project
        run: cargo build --release
```

Available sizes (for paid plans):

- `ubuntu-latest-4-cores` (16 GB RAM)
- `ubuntu-latest-8-cores` (32 GB RAM)
- `ubuntu-latest-16-cores` (64 GB RAM)

## Action Version Pinning

Pin action versions for security and stability:

**CORRECT - SHA Pinning (Most Secure)**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1

  - name: Set up Node.js
    uses: actions/setup-node@60edb5dd545a775178f52524783378180af0d1f8 # v4.0.2
    with:
      node-version: '20'
```

**CORRECT - Tag Pinning (More Maintainable)**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Set up Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
```

**WRONG**:

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@main # Unstable, could break unexpectedly

  - name: Set up Node.js
    uses: actions/setup-node@latest # Not a valid reference
```

**Pinning Strategy Decision Matrix**:

| Factor       | SHA Pinning                 | Tag Pinning                     |
| ------------ | --------------------------- | ------------------------------- |
| Security     | Best (immutable)            | Good (can be moved)             |
| Maintenance  | Higher (manual updates)     | Lower (automatic minor updates) |
| Readability  | Lower (hash not meaningful) | Higher (version clear)          |
| Auditability | Best (exact code version)   | Good (if using comment)         |

**Recommended Approach**:

1. Use SHA pinning for security-critical workflows (production deployments)
2. Use tag pinning with comments for most workflows
3. Set up Dependabot to update action versions automatically
4. Never use branch names except for actions you control

**Dependabot Configuration**:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    commit-message:
      prefix: 'chore(deps)'
```

## Workflow Organization

Structure complex workflows for maintainability:

**CORRECT - Job Dependencies**:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Run linter
        run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Run tests
        run: npm test

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Build application
        run: npm run build

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: ./deploy.sh staging
```

**CORRECT - Conditional Jobs**:

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check for changes
        uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - 'api/**'
              - 'services/**'
            frontend:
              - 'web/**'
              - 'public/**'

  test-backend:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Test backend
        run: npm run test:backend

  test-frontend:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Test frontend
        run: npm run test:frontend
```

This comprehensive guide ensures your GitHub Actions workflows are secure, efficient, and
maintainable. Always prioritize clarity, security, and team collaboration when writing workflow
configurations.
