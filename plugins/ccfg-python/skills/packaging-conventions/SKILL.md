---
name: packaging-conventions
description:
  This skill should be used when creating or editing pyproject.toml, managing Python dependencies,
  configuring build systems, setting up uv workspaces, or publishing Python packages.
version: 0.1.0
---

# Packaging Conventions

This skill defines comprehensive conventions for Python project packaging, dependency management,
and distribution. These conventions prioritize modern packaging standards, reproducible builds, and
streamlined tooling using `uv` and `pyproject.toml`.

## pyproject.toml is Canonical

**RULE**: All project configuration must live in `pyproject.toml`. No legacy configuration files:

```toml
# CORRECT: Everything in pyproject.toml
[project]
name = "mypackage"
version = "0.1.0"
description = "A sample Python package"
authors = [{name = "Your Name", email = "you@example.com"}]
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}
keywords = ["example", "package"]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

dependencies = [
    "httpx>=0.24.0,<1.0",
    "pydantic>=2.0,<3.0",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.1.0",
    "mypy>=1.7.0",
    "pre-commit>=3.5.0",
]
test = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-asyncio>=0.21.0",
    "factory-boy>=3.3.0",
]
docs = [
    "mkdocs>=1.5.0",
    "mkdocs-material>=9.4.0",
]

[project.scripts]
myapp = "mypackage.cli:main"

[project.urls]
Homepage = "https://github.com/username/mypackage"
Documentation = "https://mypackage.readthedocs.io"
Repository = "https://github.com/username/mypackage"
Issues = "https://github.com/username/mypackage/issues"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_functions = ["test_*"]
addopts = "-ra -q --strict-markers"
markers = [
    "slow: marks tests as slow",
    "integration: marks tests as integration tests",
]

[tool.coverage.run]
source = ["src"]
branch = true

[tool.coverage.report]
fail_under = 90
show_missing = true
```

**Files to DELETE or never create**:

```bash
# WRONG: These files should not exist
setup.py           # Use pyproject.toml
setup.cfg          # Use pyproject.toml
requirements.txt   # Use pyproject.toml dependencies
dev-requirements.txt   # Use [project.optional-dependencies]
mypy.ini          # Use [tool.mypy] in pyproject.toml
.flake8           # Use [tool.ruff] in pyproject.toml
.isort.cfg        # Use [tool.ruff.lint.isort] in pyproject.toml
pytest.ini        # Use [tool.pytest.ini_options] in pyproject.toml
tox.ini           # Use pyproject.toml or separate workflow
```

## Source Layout

**RULE**: Always use `src/` layout for packages:

```text
# CORRECT: src layout
myproject/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── core.py
│       ├── models.py
│       └── utils.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_core.py
├── docs/
│   └── index.md
├── pyproject.toml
├── uv.lock
├── .python-version
└── README.md
```

```text
# WRONG: Flat layout
myproject/
├── mypackage/          # Package at root level
│   ├── __init__.py
│   └── core.py
├── tests/
├── pyproject.toml
└── README.md
```

**Why src/ layout**:

- Prevents accidentally importing from source instead of installed package
- Ensures tests run against installed package
- Clearer separation between package and project files
- Better for editable installs
- Industry standard practice

**Package structure**:

```python
# src/mypackage/__init__.py
"""MyPackage - A sample Python package."""

from __future__ import annotations

from mypackage.core import main_function
from mypackage.models import User, Post

__version__ = "0.1.0"
__all__ = ["main_function", "User", "Post"]
```

## Dependency Management

**RULE**: Use dependency groups in pyproject.toml with appropriate version constraints:

```toml
# CORRECT: Well-structured dependencies
[project]
name = "mypackage"
version = "0.1.0"
requires-python = ">=3.11"

# Core runtime dependencies
dependencies = [
    "httpx>=0.24.0,<1.0",        # Compatible version range
    "pydantic>=2.0,<3.0",
    "sqlalchemy>=2.0,<3.0",
    "alembic>=1.12,<2.0",
]

[project.optional-dependencies]
# Development tools
dev = [
    "ruff>=0.1.0",
    "mypy>=1.7.0",
    "pre-commit>=3.5.0",
    "ipython>=8.17.0",
]

# Testing dependencies
test = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-asyncio>=0.21.0",
    "pytest-mock>=3.12.0",
    "factory-boy>=3.3.0",
    "faker>=20.0.0",
]

# Documentation
docs = [
    "mkdocs>=1.5.0",
    "mkdocs-material>=9.4.0",
    "mkdocstrings[python]>=0.24.0",
]

# Optional database backends
postgres = [
    "psycopg[binary]>=3.1.0",
]

mysql = [
    "mysqlclient>=2.2.0",
]

# All optional dependencies combined
all = [
    "mypackage[postgres,mysql]",
]
```

**Version pinning guidelines**:

```toml
# CORRECT: Appropriate version constraints
dependencies = [
    "httpx>=0.24.0,<1.0",           # Major version constraint
    "pydantic>=2.5.0,<3.0",         # Minimum minor for required feature
    "python-dateutil>=2.8.2",       # Stable package, minimum version
]

# WRONG: Too restrictive or too loose
dependencies = [
    "httpx==0.24.1",                # Exact pin - prevents security updates
    "pydantic>=2.0",                # No upper bound - may break on v3
    "requests",                     # No version constraint at all
]
```

**When to use exact versions**:

- In lock files (`uv.lock`) only
- For critical production deployments (with regular updates)
- Never in library packages (causes dependency conflicts)

## Python Version Management

**RULE**: Specify Python version in both `pyproject.toml` and `.python-version`:

```toml
# pyproject.toml
[project]
requires-python = ">=3.11"

[tool.ruff]
target-version = "py311"

[tool.mypy]
python_version = "3.11"
```

```text
# .python-version (for uv/pyenv)
3.11
```

**Multiple Python version support**:

```toml
[project]
requires-python = ">=3.11,<4.0"

classifiers = [
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]
```

**Testing multiple versions** (in CI):

```yaml
# .github/workflows/test.yml
strategy:
  matrix:
    python-version: ['3.11', '3.12']
```

## Entry Points and Scripts

**RULE**: Define command-line interfaces using `[project.scripts]`:

```toml
# CORRECT: Console scripts
[project.scripts]
myapp = "mypackage.cli:main"
myapp-admin = "mypackage.admin:admin_main"
myapp-migrate = "mypackage.db.migrations:migrate"

[project.gui-scripts]
myapp-gui = "mypackage.gui:main"  # For GUI applications

[project.entry-points."mypackage.plugins"]
# Plugin system entry points
json-plugin = "mypackage.plugins.json:JsonPlugin"
yaml-plugin = "mypackage.plugins.yaml:YamlPlugin"
```

**CLI implementation**:

```python
# src/mypackage/cli.py
from __future__ import annotations

import sys
from pathlib import Path

import click


@click.group()
@click.version_option()
def main() -> None:
    """MyPackage command-line interface."""


@main.command()
@click.option("--config", type=click.Path(exists=True, path_type=Path))
def run(config: Path | None) -> None:
    """Run the application."""
    click.echo(f"Running with config: {config}")


@main.command()
@click.argument("output", type=click.Path(path_type=Path))
def export(output: Path) -> None:
    """Export data to file."""
    click.echo(f"Exporting to: {output}")


if __name__ == "__main__":
    sys.exit(main())
```

**After installation**:

```bash
# Commands available in PATH
myapp --help
myapp run --config config.toml
myapp export output.json
```

## Build Backend Configuration

**RULE**: Use modern build backends like `hatchling` or `setuptools` with pyproject.toml:

```toml
# CORRECT: Using hatchling (recommended for new projects)
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/mypackage"]

[tool.hatch.build.targets.sdist]
include = [
    "/src",
    "/tests",
    "/README.md",
    "/LICENSE",
]
```

```toml
# ALTERNATIVE: Using setuptools (if needed for compatibility)
[build-system]
requires = ["setuptools>=68", "setuptools-scm>=8"]
build-backend = "setuptools.build_meta"

[tool.setuptools]
package-dir = {"" = "src"}

[tool.setuptools.packages.find]
where = ["src"]
```

**Including data files**:

```toml
[tool.hatch.build.targets.wheel.shared-data]
"data/templates" = "share/mypackage/templates"
"data/static" = "share/mypackage/static"

[tool.hatch.build.targets.wheel.force-include]
"config/default.toml" = "mypackage/default.toml"
```

## uv Workspace Configuration

**RULE**: For monorepos, use uv workspaces to manage multiple packages:

```text
# Monorepo structure
myproject/
├── pyproject.toml          # Workspace root
├── uv.lock                 # Single lock file
├── packages/
│   ├── core/
│   │   ├── pyproject.toml
│   │   └── src/
│   │       └── myproject_core/
│   ├── api/
│   │   ├── pyproject.toml
│   │   └── src/
│   │       └── myproject_api/
│   └── cli/
│       ├── pyproject.toml
│       └── src/
│           └── myproject_cli/
└── tests/
```

```toml
# Root pyproject.toml
[tool.uv.workspace]
members = ["packages/*"]

[tool.uv.sources]
myproject-core = { workspace = true }
myproject-api = { workspace = true }
myproject-cli = { workspace = true }
```

```toml
# packages/api/pyproject.toml
[project]
name = "myproject-api"
version = "0.1.0"
dependencies = [
    "myproject-core",  # Workspace dependency
    "fastapi>=0.104.0",
]
```

```toml
# packages/cli/pyproject.toml
[project]
name = "myproject-cli"
version = "0.1.0"
dependencies = [
    "myproject-core",  # Workspace dependency
    "myproject-api",
    "click>=8.1.0",
]

[project.scripts]
myproject = "myproject_cli.main:cli"
```

**Working with workspaces**:

```bash
# Install all workspace packages
uv sync

# Add dependency to specific package
uv add --package myproject-api httpx

# Run tests for specific package
uv run --package myproject-core pytest

# Build specific package
uv build --package myproject-api
```

## Lock Files

**RULE**: Always commit `uv.lock` and regenerate after dependency changes:

```bash
# CORRECT: Lock file workflow
uv add httpx                 # Add dependency
uv lock                      # Update lock file
git add pyproject.toml uv.lock
git commit -m "Add httpx dependency"

# Update all dependencies to latest compatible versions
uv lock --upgrade

# Sync environment with lock file
uv sync
```

**Lock file benefits**:

- Reproducible installations across environments
- Faster installation (no resolution needed)
- Security auditing of exact versions
- Dependency tree documentation

**Lock file in CI/CD**:

```yaml
# .github/workflows/test.yml
- name: Install dependencies
  run: uv sync --frozen # Use exact versions from lock file
```

## Common uv Commands

**RULE**: Use `uv` for all dependency and project management:

```bash
# Project initialization
uv init myproject                    # Create new project
uv init --lib mypackage             # Create new library
uv init --app myapp                 # Create new application

# Dependency management
uv add httpx                        # Add dependency
uv add --dev pytest                 # Add dev dependency
uv add --optional postgres psycopg  # Add optional dependency
uv add "httpx>=0.24.0,<1.0"        # Add with version constraint
uv remove httpx                     # Remove dependency
uv tree                            # Show dependency tree

# Environment management
uv sync                            # Install all dependencies
uv sync --all-extras               # Install with all optional deps
uv sync --frozen                   # Install from lock without updating
uv sync --no-dev                   # Install without dev dependencies

# Running commands
uv run python script.py            # Run script in project environment
uv run pytest                      # Run tests
uv run mypy src/                   # Run type checking
uv run python -m mypackage.cli     # Run module

# Lock file operations
uv lock                           # Generate/update lock file
uv lock --upgrade                 # Upgrade all dependencies
uv lock --upgrade-package httpx   # Upgrade specific package

# Build and publish
uv build                          # Build wheel and sdist
uv publish                        # Publish to PyPI
uv publish --token $TOKEN         # Publish with token

# Python version management
uv python install 3.12            # Install Python 3.12
uv python list                    # List available Python versions
uv venv --python 3.12            # Create venv with specific version
```

## Complete pyproject.toml Examples

### Example 1: FastAPI Service

```toml
[project]
name = "myapi"
version = "0.1.0"
description = "RESTful API service"
authors = [{name = "Your Name", email = "you@example.com"}]
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}

dependencies = [
    "fastapi>=0.104.0,<1.0",
    "uvicorn[standard]>=0.24.0,<1.0",
    "pydantic>=2.5.0,<3.0",
    "pydantic-settings>=2.1.0,<3.0",
    "sqlalchemy>=2.0,<3.0",
    "alembic>=1.13.0,<2.0",
    "psycopg[binary]>=3.1.0,<4.0",
    "python-jose[cryptography]>=3.3.0,<4.0",
    "passlib[bcrypt]>=1.7.4,<2.0",
    "httpx>=0.25.0,<1.0",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.1.0",
    "mypy>=1.7.0",
    "pre-commit>=3.5.0",
]

test = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-asyncio>=0.21.0",
    "factory-boy>=3.3.0",
]

[project.scripts]
myapi = "myapi.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/myapi"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "C4", "SIM"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.11"
plugins = ["pydantic.mypy"]
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-ra -q --strict-markers --cov=src --cov-report=html --cov-report=term"

[tool.coverage.run]
source = ["src"]
branch = true
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 90
show_missing = true
```

### Example 2: CLI Application

```toml
[project]
name = "mycli"
version = "0.1.0"
description = "Command-line tool for data processing"
authors = [{name = "Your Name", email = "you@example.com"}]
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}

dependencies = [
    "click>=8.1.0,<9.0",
    "rich>=13.7.0,<14.0",
    "pydantic>=2.5.0,<3.0",
    "httpx>=0.25.0,<1.0",
    "python-dateutil>=2.8.2",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.1.0",
    "mypy>=1.7.0",
]

test = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
]

[project.scripts]
mycli = "mycli.main:cli"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/mycli"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.mypy]
python_version = "3.11"
warn_return_any = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### Example 3: Python Library

```toml
[project]
name = "mylib"
version = "0.1.0"
description = "Reusable Python library"
authors = [{name = "Your Name", email = "you@example.com"}]
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}
keywords = ["library", "utilities"]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

# Minimal dependencies for libraries
dependencies = [
    "typing-extensions>=4.8.0; python_version < '3.12'",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.1.0",
    "mypy>=1.7.0",
    "pre-commit>=3.5.0",
]

test = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "hypothesis>=6.92.0",
]

docs = [
    "mkdocs>=1.5.0",
    "mkdocs-material>=9.4.0",
    "mkdocstrings[python]>=0.24.0",
]

[project.urls]
Homepage = "https://github.com/username/mylib"
Documentation = "https://mylib.readthedocs.io"
Repository = "https://github.com/username/mylib"
Issues = "https://github.com/username/mylib/issues"
Changelog = "https://github.com/username/mylib/blob/main/CHANGELOG.md"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.version]
path = "src/mylib/__init__.py"

[tool.hatch.build.targets.wheel]
packages = ["src/mylib"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
strict = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra -q --strict-markers --cov=src --cov-report=html"

[tool.coverage.run]
source = ["src"]
branch = true

[tool.coverage.report]
fail_under = 95
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "@abstractmethod",
]
```

## Publishing Packages

**RULE**: Follow standard publishing workflow:

```bash
# 1. Update version in pyproject.toml
# 2. Update CHANGELOG.md
# 3. Commit and tag
git add pyproject.toml CHANGELOG.md
git commit -m "Release v0.1.0"
git tag v0.1.0

# 4. Build package
uv build

# Verify build artifacts
ls dist/
# mypackage-0.1.0-py3-none-any.whl
# mypackage-0.1.0.tar.gz

# 5. Publish to TestPyPI first
uv publish --publish-url https://test.pypi.org/legacy/ \
           --token $TEST_PYPI_TOKEN

# 6. Test installation from TestPyPI
uv pip install --index-url https://test.pypi.org/simple/ mypackage

# 7. Publish to PyPI
uv publish --token $PYPI_TOKEN

# 8. Push tags
git push origin v0.1.0
```

**GitHub Actions for publishing**:

```yaml
# .github/workflows/publish.yml
name: Publish to PyPI

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Build package
        run: uv build

      - name: Publish to PyPI
        env:
          UV_PUBLISH_TOKEN: ${{ secrets.PYPI_TOKEN }}
        run: uv publish
```

## Metadata Best Practices

**RULE**: Provide comprehensive package metadata:

```toml
[project]
name = "mypackage"
version = "0.1.0"
description = "Clear one-line description of what package does"
authors = [
    {name = "Primary Author", email = "author@example.com"},
    {name = "Contributor Name"},
]
maintainers = [
    {name = "Maintainer Name", email = "maintainer@example.com"},
]
readme = "README.md"
requires-python = ">=3.11"
license = {text = "MIT"}
keywords = ["specific", "searchable", "keywords"]

classifiers = [
    # Development status
    "Development Status :: 4 - Beta",

    # Audience
    "Intended Audience :: Developers",
    "Intended Audience :: System Administrators",

    # License
    "License :: OSI Approved :: MIT License",

    # Python versions
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",

    # Topics
    "Topic :: Software Development :: Libraries :: Python Modules",
    "Topic :: Internet :: WWW/HTTP",
]

[project.urls]
Homepage = "https://mypackage.example.com"
Documentation = "https://docs.mypackage.example.com"
Repository = "https://github.com/username/mypackage"
Issues = "https://github.com/username/mypackage/issues"
Changelog = "https://github.com/username/mypackage/blob/main/CHANGELOG.md"
```

## Anti-Patterns to Avoid

### 1. Mixing Configuration Locations

```bash
# WRONG: Configuration scattered across multiple files
setup.py
setup.cfg
requirements.txt
dev-requirements.txt
mypy.ini
.flake8

# CORRECT: Everything in pyproject.toml
pyproject.toml
```

### 2. Incorrect Dependency Pinning

```toml
# WRONG: Too restrictive for libraries
dependencies = [
    "requests==2.31.0",  # Exact pin causes conflicts
]

# WRONG: No version constraints
dependencies = [
    "requests",  # Any version - may break
]

# CORRECT: Compatible range
dependencies = [
    "requests>=2.31.0,<3.0",
]
```

### 3. Flat Package Layout

```text
# WRONG: Package at project root
myproject/
├── mypackage/          # Confusing - easy to import from wrong location
│   └── __init__.py
├── tests/
└── pyproject.toml

# CORRECT: src/ layout
myproject/
├── src/
│   └── mypackage/      # Clear separation
│       └── __init__.py
├── tests/
└── pyproject.toml
```

### 4. Not Committing Lock Files

```bash
# WRONG: Ignoring lock files
echo "uv.lock" >> .gitignore

# CORRECT: Commit lock files for reproducibility
git add uv.lock
git commit -m "Update dependencies"
```

### 5. Using setup.py for Configuration

```python
# WRONG: Using setup.py
from setuptools import setup

setup(
    name="mypackage",
    version="0.1.0",
    # ... configuration
)
```

```toml
# CORRECT: Use pyproject.toml
[project]
name = "mypackage"
version = "0.1.0"
```

## Summary Checklist

When setting up Python packaging, ensure:

- [ ] All configuration in `pyproject.toml`
- [ ] Using `src/` layout for packages
- [ ] No legacy files (setup.py, requirements.txt, etc.)
- [ ] `requires-python` specifies minimum Python version
- [ ] `.python-version` file for uv/pyenv
- [ ] Dependencies use compatible version ranges
- [ ] Dependency groups for dev, test, docs
- [ ] Entry points defined in `[project.scripts]`
- [ ] Build backend configured (hatchling or setuptools)
- [ ] `uv.lock` committed to repository
- [ ] Using `uv` for all dependency operations
- [ ] Comprehensive package metadata
- [ ] Tool configurations in respective `[tool.*]` sections
- [ ] For monorepos, workspace properly configured
- [ ] README.md and LICENSE files present

These conventions ensure Python packages are well-structured, maintainable, and follow modern
packaging standards.
