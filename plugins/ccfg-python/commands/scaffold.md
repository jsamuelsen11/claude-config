---
description: Initialize a new Python project with production-ready defaults
argument-hint: <project-name> [--type=service|library|cli]
allowed-tools: Bash(uv *), Bash(git *), Read, Write, Edit, Glob
---

# scaffold

Initialize a modern Python project with production-ready structure, tooling, and configuration. This
command creates a complete project skeleton following current best practices including src layout,
comprehensive tool configuration, and type-safe foundations.

## Usage

```bash
ccfg python scaffold myproject                    # Default library project
ccfg python scaffold myapp --type=service         # FastAPI web service
ccfg python scaffold mytool --type=cli            # Typer CLI application
```

## Overview

The scaffold command creates a complete Python project structure with:

- **Src layout**: Industry standard for proper packaging and imports
- **Modern tooling**: uv for dependency management, ruff for linting/formatting, mypy for type
  checking
- **Comprehensive configuration**: All tools configured in pyproject.toml following best practices
- **Type safety**: Full mypy strict mode configuration with py.typed marker
- **Testing foundation**: pytest configured with fixtures and markers
- **Production ready**: Appropriate scaffolding for deployment based on project type

All generated code follows PEP 8, includes type hints, and passes quality gates immediately after
creation.

## Project Types

### Library (Default)

A reusable Python package designed for distribution via PyPI.

**Generated structure**:

```text
mylib/
├── src/
│   └── mylib/
│       ├── __init__.py       # Public API exports
│       ├── py.typed          # PEP 561 marker for type checking
│       └── core.py           # Example module
├── tests/
│   ├── __init__.py
│   ├── conftest.py           # Shared fixtures
│   └── test_core.py          # Example tests
├── pyproject.toml            # Project metadata and config
├── .python-version           # Python version (3.11+)
├── README.md                 # Documentation
└── .gitignore                # Python-specific ignores
```

**Key features**:

- Public API defined in `__init__.py` with `__all__`
- `py.typed` marker for downstream type checking
- Example module demonstrating idiomatic patterns
- Comprehensive tests with 100% coverage from start

### Service

A FastAPI-based web service with async patterns and deployment configuration.

**Generated structure**:

```text
myservice/
├── src/
│   └── myservice/
│       ├── __init__.py
│       ├── main.py           # FastAPI application
│       ├── api/
│       │   ├── __init__.py
│       │   └── health.py     # Health check endpoints
│       ├── models.py         # Pydantic models
│       └── config.py         # Settings with pydantic-settings
├── tests/
│   ├── __init__.py
│   ├── conftest.py           # Test client fixtures
│   └── test_health.py        # API tests
├── Dockerfile                # Multi-stage production build
├── docker-compose.yml        # Local development setup
├── pyproject.toml
├── .python-version
├── README.md
└── .gitignore
```

**Key features**:

- FastAPI with async/await patterns
- Pydantic models for validation
- Health and readiness endpoints
- Test client fixtures for API testing
- Production-ready Dockerfile
- Environment-based configuration

### CLI

A command-line application using Typer with rich terminal output.

**Generated structure**:

```text
mytool/
├── src/
│   └── mytool/
│       ├── __init__.py
│       ├── cli.py            # Typer app and commands
│       ├── commands/
│       │   ├── __init__.py
│       │   └── hello.py      # Example command
│       └── utils.py          # Shared utilities
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_cli.py           # CLI tests
├── pyproject.toml            # With console_scripts entry point
├── .python-version
├── README.md
└── .gitignore
```

**Key features**:

- Typer for type-safe CLI building
- Rich library for beautiful output
- Console script entry point
- CLI testing with CliRunner
- Progress bars and colored output

## Step-by-Step Process

### 1. Validate Project Name

Before creating any files, validate the project name:

**Requirements**:

- Valid Python identifier (starts with letter, contains only letters/numbers/underscores)
- Not a Python keyword (e.g., not "class", "import", "async")
- Not already existing in current directory
- Follows naming conventions (lowercase with underscores)

**Validation**:

```python
import keyword
import re

def is_valid_project_name(name: str) -> bool:
    if keyword.iskeyword(name):
        return False
    if not re.match(r'^[a-z][a-z0-9_]*$', name):
        return False
    return True
```

**On invalid name**:

```text
Error: Invalid project name "my-project"
- Must start with a letter
- Can only contain lowercase letters, numbers, and underscores
- Cannot be a Python keyword

Suggested name: my_project
```

### 2. Create Directory Structure

Create the project directory and src layout:

```bash
mkdir -p <name>/src/<name>
mkdir -p <name>/tests
cd <name>
```

**Why src layout**:

- Prevents accidental imports from development directory
- Forces proper package installation for testing
- Matches expectations of modern Python tooling
- Required for editable installs in PEP 660 world

### 3. Generate pyproject.toml

Create comprehensive configuration file with all tool settings:

```toml
[project]
name = "<name>"
version = "0.1.0"
description = "A modern Python <type> project"
readme = "README.md"
requires-python = ">=3.11"
authors = [
    { name = "Your Name", email = "you@example.com" }
]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

[project.urls]
Homepage = "https://github.com/yourusername/<name>"
Repository = "https://github.com/yourusername/<name>"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[dependency-groups]
dev = [
    "ruff>=0.8.0",
    "mypy>=1.13.0",
    "pytest>=8.0.0",
    "pytest-cov>=6.0.0",
]

[tool.hatch.build.targets.wheel]
packages = ["src/<name>"]

[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # pyflakes
    "I",      # isort
    "N",      # pep8-naming
    "UP",     # pyupgrade
    "B",      # flake8-bugbear
    "C4",     # flake8-comprehensions
    "DTZ",    # flake8-datetimez
    "T10",    # flake8-debugger
    "PIE",    # flake8-pie
    "PT",     # flake8-pytest-style
    "RET",    # flake8-return
    "SIM",    # flake8-simplify
    "ARG",    # flake8-unused-arguments
    "PTH",    # flake8-use-pathlib
    "ERA",    # eradicate
    "PL",     # pylint
    "RUF",    # ruff-specific rules
]
ignore = [
    "E501",   # line too long (handled by formatter)
    "PLR0913", # too many arguments
]

[tool.ruff.lint.isort]
known-first-party = ["<name>"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "ARG", "PLR2004"]

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_any_generics = true
disallow_subclassing_any = true
disallow_untyped_calls = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true
strict_equality = true

[[tool.mypy.overrides]]
module = "tests.*"
disallow_untyped_defs = false

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
python_functions = ["test_*"]
addopts = [
    "-v",
    "--strict-markers",
    "--strict-config",
    "--cov=src",
    "--cov-report=term-missing:skip-covered",
    "--cov-report=html",
]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks tests as integration tests",
]
```

**Type-specific additions**:

For `service`:

```toml
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "pydantic>=2.9.0",
    "pydantic-settings>=2.6.0",
]

[dependency-groups]
dev = [
    # ... existing ...
    "httpx>=0.27.0",  # For TestClient
]
```

For `cli`:

```toml
dependencies = [
    "typer[all]>=0.15.0",
    "rich>=13.0.0",
]

[project.scripts]
<name> = "<name>.cli:app"
```

### 4. Create Core Files

#### src/<name>/**init**.py (library)

```python
"""
<name> - A modern Python library.
"""

__version__ = "0.1.0"
__all__ = ["example_function"]


def example_function(name: str) -> str:
    """
    Example function demonstrating type hints and docstrings.

    Args:
        name: The name to greet.

    Returns:
        A greeting message.

    Examples:
        >>> example_function("World")
        'Hello, World!'
    """
    return f"Hello, {name}!"
```

#### src/<name>/main.py (service)

```python
"""
FastAPI application entry point.
"""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from <name>.api.health import router as health_router
from <name>.config import Settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    Lifespan context manager for startup and shutdown events.
    """
    # Startup: initialize connections, load models, etc.
    yield
    # Shutdown: cleanup resources


settings = Settings()

app = FastAPI(
    title="<name>",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health_router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Global exception handler for unhandled errors.
    """
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )
```

#### src/<name>/api/health.py (service)

```python
"""
Health check endpoints.
"""

from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/health", tags=["health"])


class HealthResponse(BaseModel):
    """Health check response model."""

    status: Literal["healthy", "unhealthy"]
    version: str = "0.1.0"


@router.get("", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Basic health check endpoint.

    Returns:
        Health status and version information.
    """
    return HealthResponse(status="healthy")


@router.get("/ready", response_model=HealthResponse)
async def readiness_check() -> HealthResponse:
    """
    Readiness check for load balancer.

    Returns:
        Ready status if all dependencies are available.
    """
    # Check database connections, external services, etc.
    return HealthResponse(status="healthy")
```

#### src/<name>/cli.py (cli)

```python
"""
Command-line interface for <name>.
"""

import typer
from rich.console import Console
from rich.table import Table

app = typer.Typer(
    name="<name>",
    help="A modern Python CLI application.",
    add_completion=False,
)
console = Console()


@app.command()
def hello(
    name: str = typer.Argument(..., help="Name to greet"),
    count: int = typer.Option(1, "--count", "-c", help="Number of greetings"),
) -> None:
    """
    Say hello to someone.
    """
    for _ in range(count):
        console.print(f"[bold green]Hello, {name}![/bold green]")


@app.command()
def version() -> None:
    """
    Show version information.
    """
    table = Table(title="<name> Version Info")
    table.add_column("Component", style="cyan")
    table.add_column("Version", style="green")

    table.add_row("<name>", "0.1.0")
    table.add_row("Python", "3.11+")

    console.print(table)


if __name__ == "__main__":
    app()
```

### 5. Create Test Files

#### tests/conftest.py

```python
"""
Pytest configuration and shared fixtures.
"""

import pytest


@pytest.fixture
def sample_data() -> dict[str, str]:
    """
    Sample data for testing.
    """
    return {"key": "value"}
```

**Type-specific fixtures**:

For `service`:

```python
from collections.abc import AsyncGenerator

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient

from <name>.main import app


@pytest.fixture
def client() -> TestClient:
    """
    Synchronous test client.
    """
    return TestClient(app)


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """
    Async test client for async endpoints.
    """
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
```

For `cli`:

```python
from typer.testing import CliRunner

from <name>.cli import app


@pytest.fixture
def runner() -> CliRunner:
    """
    CLI test runner.
    """
    return CliRunner()
```

#### tests/test_core.py (library)

```python
"""
Tests for core functionality.
"""

from <name> import example_function


def test_example_function() -> None:
    """
    Test example function with valid input.
    """
    result = example_function("World")
    assert result == "Hello, World!"


def test_example_function_empty_name() -> None:
    """
    Test example function with empty name.
    """
    result = example_function("")
    assert result == "Hello, !"
```

#### tests/test_health.py (service)

```python
"""
Tests for health check endpoints.
"""

from fastapi.testclient import TestClient


def test_health_check(client: TestClient) -> None:
    """
    Test basic health check endpoint.
    """
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data


def test_readiness_check(client: TestClient) -> None:
    """
    Test readiness check endpoint.
    """
    response = client.get("/health/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
```

### 6. Create Supporting Files

#### .python-version

```text
3.11
```

#### .gitignore

```text
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# PyInstaller
*.manifest
*.spec

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Virtual environments
venv/
env/
ENV/
env.bak/
venv.bak/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# Type checking
.mypy_cache/
.dmypy.json
dmypy.json

# Ruff
.ruff_cache/

# Environment variables
.env
.env.local

# OS files
.DS_Store
Thumbs.db
```

#### README.md

````markdown
# <name>

A modern Python <type> project built with production-ready tooling.

## Installation

### Development

```bash
# Clone the repository
git clone https://github.com/yourusername/<name>.git
cd <name>

# Install dependencies with uv
uv sync

# Run tests
uv run pytest

# Run quality checks
uv run ruff check .
uv run mypy src/
```
````

### Production

```bash
pip install <name>
```

## Usage Examples

[Type-specific usage examples]

## Development

This project uses modern Python tooling:

- **uv**: Fast Python package installer and resolver
- **ruff**: Extremely fast Python linter and formatter
- **mypy**: Static type checker with strict mode
- **pytest**: Testing framework with coverage reporting

### Running Quality Checks

```bash
# Lint and format
uv run ruff check .
uv run ruff format .

# Type checking
uv run mypy src/

# Tests with coverage
uv run pytest --cov
```

### Project Structure

```text
<name>/
├── src/<name>/     # Source code
├── tests/          # Test files
└── pyproject.toml  # Project configuration
```

## License

[Your chosen license]

````text

#### Dockerfile (service only)

```dockerfile
FROM python:3.11-slim as builder

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml .
COPY src/ src/

# Install dependencies
RUN uv sync --frozen --no-dev

# Production stage
FROM python:3.11-slim

WORKDIR /app

# Copy installed dependencies
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src /app/src

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "<name>.main:app", "--host", "0.0.0.0", "--port", "8000"]
````

### 7. Initialize Dependencies

Run uv to create virtual environment and install dependencies:

```bash
uv sync
```

This will:

- Create a virtual environment in `.venv/`
- Install all dependencies including dev group
- Generate `uv.lock` for reproducible installs
- Make the package available in editable mode

### 8. Verify Installation

Run the test suite to ensure everything works:

```bash
uv run pytest -v
```

Expected output:

```text
======================== test session starts ========================
collected 2 items

tests/test_core.py::test_example_function PASSED            [ 50%]
tests/test_core.py::test_example_function_empty_name PASSED [100%]

======================== 2 passed in 0.12s ==========================
```

### 9. Initialize Git Repository

If not already in a git repository, initialize one:

```bash
# Check if already in git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    git init
    git add .
    git commit -m "feat: initialize <name> project with ccfg-python scaffold"
fi
```

**Do not initialize git if**:

- Already inside a git repository
- User explicitly wants to add to existing repo
- Creating as a subproject/monorepo package

### 10. Display Success Message

```text
Successfully created <name> project!

Project structure:
  <name>/
  ├── src/<name>/          # Source code
  ├── tests/               # Test suite
  ├── pyproject.toml       # Configuration
  └── README.md            # Documentation

Next steps:
  1. cd <name>
  1. uv run pytest          # Run tests
  1. uv run ruff check .    # Lint code
  1. uv run mypy src/       # Type check

Development:
  - Edit src/<name>/ to add functionality
  - Add tests in tests/
  - Run 'ccfg python validate' before committing

[Type-specific next steps]
```

## Key Rules and Requirements

### Always Use Src Layout

Never create flat layout projects. The src layout is required for:

- Proper import testing
- Avoiding accidental development imports
- Standard packaging expectations
- Tool compatibility (uv, hatchling, mypy)

### Single Configuration File

All tool configuration goes in `pyproject.toml`. Never create:

- `setup.py` or `setup.cfg` (obsolete)
- `requirements.txt` (use pyproject.toml dependencies)
- `ruff.toml` (use `[tool.ruff]` section)
- `mypy.ini` (use `[tool.mypy]` section)
- `pytest.ini` (use `[tool.pytest.ini_options]` section)

### Type Safety from Start

Every generated file must:

- Include complete type hints
- Pass mypy strict mode
- Include `py.typed` marker for libraries
- Use modern type syntax (e.g., `list[str]` not `List[str]`)

### Testing Foundation

Generated test files must:

- Follow project's naming convention
- Include docstrings explaining what they test
- Achieve 100% coverage of generated code
- Use appropriate fixtures from conftest.py
- Demonstrate testing patterns for the project type

### Production Ready

Generated projects should be immediately deployable:

- Service: includes Dockerfile and health endpoints
- CLI: includes console script entry point
- Library: includes proper packaging metadata

## Common Scenarios

### Scenario 1: Creating Microservice

```bash
ccfg python scaffold user-service --type=service
```

Creates FastAPI service with:

- Async request handlers
- Pydantic validation models
- Health and readiness endpoints
- Docker configuration
- Test client fixtures

### Scenario 2: Building CLI Tool

```bash
ccfg python scaffold mytool --type=cli
```

Creates Typer CLI with:

- Rich terminal output
- Command structure
- Entry point configuration
- CLI testing setup

### Scenario 3: Publishing Library

```bash
ccfg python scaffold awesome-lib
```

Creates distributable library with:

- Public API definition
- Type checking marker
- Complete package metadata
- Publishing-ready structure

## Integration with Other Commands

### After Scaffolding

1. **Validate immediately**: `ccfg python validate`
1. **Add dependencies**: `uv add requests httpx`
1. **Run tests**: `uv run pytest`
1. **Check coverage**: `ccfg python coverage`

### Customization

After scaffolding, customize:

- Author information in pyproject.toml
- Project URLs and repository links
- License file
- Additional dependencies
- Ruff rule selection
- Mypy strictness level

## Troubleshooting

### "Project directory already exists"

Choose a different name or remove existing directory.

### "uv: command not found"

Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`

### "Python 3.11+ required"

Update Python or modify `.python-version` file (not recommended).

### Tests fail after scaffolding

This should never happen. Generated code must pass all tests. If it does, it's a bug in the scaffold
command.

## Summary

The scaffold command creates production-ready Python projects with modern tooling and best practices
baked in. Projects are immediately testable, type-safe, and ready for development without manual
configuration of linters, formatters, or test frameworks.

By enforcing src layout, single configuration file, and comprehensive tool setup, scaffolded
projects provide a consistent foundation for Python development across teams and projects.
