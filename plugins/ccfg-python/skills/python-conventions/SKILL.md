---
name: python-conventions
description:
  This skill should be used when working on Python projects, writing Python code, running Python
  tests, managing Python dependencies, or reviewing Python code.
version: 0.1.0
---

# Python Conventions

This skill defines comprehensive conventions for writing idiomatic, type-safe, and maintainable
Python code. These conventions prioritize modern Python 3.11+ features, toolchain consistency, and
production-ready patterns.

## Toolchain and Existing Repository Compatibility

### Respect Existing Project Conventions

**CRITICAL**: When working on existing projects, always respect the established toolchain and
patterns:

- If the project uses `pip` or `poetry`, continue using those tools
- If the project uses `black` for formatting, use `black` (not `ruff format`)
- If the project uses `flake8` or `pylint`, use those linters
- If the project uses `unittest`, continue with `unittest` (not `pytest`)
- Check for existing configuration files: `setup.py`, `setup.cfg`, `requirements.txt`, `.flake8`,
  `pyproject.toml`

**How to detect existing tooling**:

```python
# Check for poetry
if Path("poetry.lock").exists():
    # Use: poetry install, poetry add, poetry run pytest

# Check for pip + requirements
if Path("requirements.txt").exists():
    # Use: pip install -r requirements.txt, python -m pytest

# Check for black configuration
if "black" in pyproject_toml.get("tool", {}):
    # Use: black . instead of ruff format
```

The conventions below apply to:

1. New projects you create from scratch
1. Scaffold/template output
1. Projects that explicitly adopt these conventions

### Standard Toolchain (for new projects)

Use `uv` as the universal Python package installer and project manager:

```bash
# CORRECT: Use uv for all Python operations
uv run pytest tests/
uv run mypy src/
uv run ruff check .
uv run ruff format .
uv add httpx
uv remove deprecated-package
uv sync

# WRONG: Never use bare commands
python -m pytest tests/        # Missing uv prefix
pip install httpx              # Use uv add
pytest                         # Use uv run pytest
```

**Why `uv`**:

- Fast (Rust-based, 10-100x faster than pip)
- Deterministic dependency resolution
- Built-in virtual environment management
- Drop-in replacement for pip, poetry, pyenv
- Single tool for multiple workflows

### Linting and Formatting

Use `ruff` for all linting and formatting tasks:

```bash
# CORRECT: Use ruff for both linting and formatting
uv run ruff check . --fix
uv run ruff format .

# WRONG: Don't mix tools
black .                        # Use ruff format
isort .                        # ruff handles import sorting
flake8 .                       # Use ruff check
```

**Configure ruff in pyproject.toml**:

```toml
[tool.ruff]
line-length = 100
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
    "SIM",    # flake8-simplify
    "TCH",    # flake8-type-checking
]
ignore = [
    "E501",   # Line too long (handled by formatter)
]

[tool.ruff.lint.isort]
known-first-party = ["mypackage"]
```

### Type Checking

Use `mypy` for static type checking when configured:

```bash
# Run type checking
uv run mypy src/

# Check specific files
uv run mypy src/mypackage/core.py
```

**Configure mypy in pyproject.toml**:

```toml
[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
strict_equality = true
```

## Modern Python Syntax and Imports

### Future Annotations

**RULE**: Always start Python modules with `from __future__ import annotations`:

```python
# CORRECT: Enable modern type syntax
from __future__ import annotations

import logging
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class User:
    name: str
    emails: list[str]              # Modern syntax works
    metadata: dict[str, str]       # No need for typing.Dict


def process_users(users: Sequence[User]) -> list[str]:
    """Process users and return their names."""
    return [user.name for user in users]
```

```python
# WRONG: Missing future import
import logging
from typing import List, Dict  # Old-style typing imports

class User:
    def __init__(self, name: str, emails: List[str]):  # Requires typing.List
        self.name = name
        self.emails = emails
```

**Why**: `from __future__ import annotations` enables:

- Using `list[T]` instead of `typing.List[T]`
- Using `dict[K, V]` instead of `typing.Dict[K, V]`
- Forward references without string quotes
- Faster imports (annotations not evaluated at runtime)

### Modern Union Syntax

**RULE**: Use PEP 604 union syntax (`X | Y`) instead of `typing.Optional` or `typing.Union`:

```python
# CORRECT: Modern union syntax
from __future__ import annotations

def get_user(user_id: int) -> User | None:
    """Fetch user or return None if not found."""
    ...

def parse_value(data: str | bytes | None) -> dict[str, str | int]:
    """Parse value from multiple input types."""
    ...

# WRONG: Old typing imports
from typing import Optional, Union

def get_user(user_id: int) -> Optional[User]:  # Use User | None
    ...

def parse_value(data: Union[str, bytes, None]) -> dict:  # Use str | bytes | None
    ...
```

### Import Organization

**RULE**: Organize imports in three blocks separated by blank lines:

1. Standard library imports
1. Third-party imports
1. Local/application imports

```python
# CORRECT: Properly organized imports
from __future__ import annotations

import json
import logging
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import httpx
from pydantic import BaseModel, Field

from mypackage.config import Settings
from mypackage.db import Database

if TYPE_CHECKING:
    from mypackage.models import User

logger = logging.getLogger(__name__)
```

```python
# WRONG: Disorganized imports
import json
from mypackage.config import Settings
import httpx
import logging
from mypackage.db import Database
from typing import Optional
```

**Use `collections.abc` for abstract types**:

```python
# CORRECT: Use abstract types for inputs
from collections.abc import Mapping, Sequence, Iterable

def process_items(items: Sequence[str]) -> list[str]:
    """Accept any sequence (list, tuple, etc)."""
    return [item.upper() for item in items]

def merge_configs(configs: Iterable[Mapping[str, str]]) -> dict[str, str]:
    """Accept any iterable of mappings, return concrete dict."""
    result = {}
    for config in configs:
        result.update(config)
    return result
```

```python
# WRONG: Using concrete types for inputs
def process_items(items: list[str]) -> list[str]:  # Too restrictive
    return [item.upper() for item in items]

def merge_configs(configs: list[dict[str, str]]) -> dict[str, str]:  # Too restrictive
    result = {}
    for config in configs:
        result.update(config)
    return result
```

## Path Handling

**RULE**: Always use `pathlib.Path` over `os.path`:

```python
# CORRECT: Use pathlib.Path
from pathlib import Path

def load_config(config_path: Path) -> dict[str, str]:
    """Load configuration from file."""
    if not config_path.exists():
        raise FileNotFoundError(f"Config not found: {config_path}")

    return json.loads(config_path.read_text())

def setup_directories(base_dir: Path) -> None:
    """Create directory structure."""
    (base_dir / "data").mkdir(parents=True, exist_ok=True)
    (base_dir / "logs").mkdir(parents=True, exist_ok=True)

    for subdir in ["raw", "processed"]:
        (base_dir / "data" / subdir).mkdir(exist_ok=True)

# Usage
config = load_config(Path("config.json"))
setup_directories(Path.cwd() / "output")
```

```python
# WRONG: Using os.path
import os
import os.path

def load_config(config_path: str) -> dict[str, str]:
    """Load configuration from file."""
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Config not found: {config_path}")

    with open(config_path) as f:
        return json.load(f)

def setup_directories(base_dir: str) -> None:
    """Create directory structure."""
    os.makedirs(os.path.join(base_dir, "data"), exist_ok=True)
    os.makedirs(os.path.join(base_dir, "logs"), exist_ok=True)
```

**Path manipulation patterns**:

```python
from pathlib import Path

# Joining paths
config_dir = Path.home() / ".config" / "myapp"
data_file = config_dir / "data.json"

# Reading/writing
content = data_file.read_text()
data_file.write_text(json.dumps(data, indent=2))

# Iteration
for py_file in Path("src").rglob("*.py"):
    print(py_file.relative_to("src"))

# Checking properties
if data_file.is_file() and data_file.suffix == ".json":
    process_json(data_file)
```

## Type Hints

**RULE**: Add type hints to all function signatures and class attributes:

```python
# CORRECT: Full type coverage
from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass
class User:
    user_id: int
    username: str
    email: str | None = None
    is_active: bool = True


class UserRepository(Protocol):
    """Protocol for user storage backends."""

    def get(self, user_id: int) -> User | None:
        """Get user by ID."""
        ...

    def save(self, user: User) -> None:
        """Save user to storage."""
        ...


def format_user_display(user: User, include_email: bool = False) -> str:
    """Format user for display."""
    parts = [f"{user.username} (ID: {user.user_id})"]
    if include_email and user.email:
        parts.append(f"<{user.email}>")
    return " ".join(parts)


def batch_process_users(
    users: Sequence[User],
    processor: Callable[[User], None],
    max_workers: int = 4,
) -> None:
    """Process users in parallel."""
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        executor.map(processor, users)
```

```python
# WRONG: Missing or incomplete type hints
class User:
    def __init__(self, user_id, username, email=None):  # Missing types
        self.user_id = user_id
        self.username = username
        self.email = email

def format_user_display(user, include_email=False):  # Missing types
    parts = [f"{user.username} (ID: {user.user_id})"]
    if include_email and user.email:
        parts.append(f"<{user.email}>")
    return " ".join(parts)
```

**Generic types**:

```python
from __future__ import annotations

from typing import TypeVar, Generic

T = TypeVar("T")
K = TypeVar("K")
V = TypeVar("V")


class Cache(Generic[K, V]):
    """Generic cache implementation."""

    def __init__(self) -> None:
        self._data: dict[K, V] = {}

    def get(self, key: K) -> V | None:
        """Get value by key."""
        return self._data.get(key)

    def set(self, key: K, value: V) -> None:
        """Set value for key."""
        self._data[key] = value


# Usage with specific types
user_cache: Cache[int, User] = Cache()
user_cache.set(1, User(1, "alice", "alice@example.com"))
```

## Structured Data

**RULE**: Use `dataclasses` or `pydantic` models instead of plain dictionaries:

```python
# CORRECT: Using dataclasses for internal data
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass(frozen=True)  # Immutable
class Point:
    x: float
    y: float

    def distance_to(self, other: Point) -> float:
        """Calculate Euclidean distance."""
        return ((self.x - other.x) **2 + (self.y - other.y)** 2) ** 0.5


@dataclass
class User:
    user_id: int
    username: str
    email: str
    created_at: datetime = field(default_factory=datetime.now)
    tags: list[str] = field(default_factory=list)

    def add_tag(self, tag: str) -> None:
        """Add tag to user."""
        if tag not in self.tags:
            self.tags.append(tag)
```

```python
# CORRECT: Using Pydantic for API/validation
from pydantic import BaseModel, Field, EmailStr, field_validator


class UserCreate(BaseModel):
    """Request model for creating users."""

    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8)
    tags: list[str] = Field(default_factory=list)

    @field_validator("username")
    @classmethod
    def username_alphanumeric(cls, v: str) -> str:
        """Validate username is alphanumeric."""
        if not v.isalnum():
            raise ValueError("Username must be alphanumeric")
        return v


class UserResponse(BaseModel):
    """Response model for user data."""

    user_id: int
    username: str
    email: str
    created_at: datetime
    tags: list[str]

    model_config = {"from_attributes": True}  # Enable ORM mode
```

```python
# WRONG: Using plain dictionaries
def create_user(username, email, password):
    """Create user with dict."""
    user = {
        "username": username,
        "email": email,
        "password": password,
        "created_at": datetime.now(),
        "tags": [],
    }
    return user  # No validation, no type safety

def add_tag(user, tag):
    """Add tag to user dict."""
    if "tags" not in user:  # Error-prone key checking
        user["tags"] = []
    user["tags"].append(tag)
```

## Logging

**RULE**: Use the `logging` module, never bare `print()` for production code:

```python
# CORRECT: Proper logging setup
from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def setup_logging(log_file: Path | None = None, level: int = logging.INFO) -> None:
    """Configure application logging."""
    handlers: list[logging.Handler] = [logging.StreamHandler()]

    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(log_file))

    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=handlers,
    )


def process_file(file_path: Path) -> None:
    """Process a single file."""
    logger.info("Processing file: %s", file_path)

    try:
        content = file_path.read_text()
        logger.debug("File size: %d bytes", len(content))

        # Process content
        result = transform(content)
        logger.info("Successfully processed: %s", file_path)

    except FileNotFoundError:
        logger.error("File not found: %s", file_path)
        raise
    except Exception as e:
        logger.exception("Unexpected error processing %s", file_path)
        raise
```

```python
# WRONG: Using print statements
def process_file(file_path):
    print(f"Processing file: {file_path}")  # Not configurable, no levels

    try:
        content = file_path.read_text()
        print(f"File size: {len(content)} bytes")  # Always prints debug info
        result = transform(content)
        print(f"Success: {file_path}")
    except Exception as e:
        print(f"ERROR: {e}")  # Can't filter by severity
```

**Logging levels**:

```python
logger.debug("Detailed diagnostic info")     # Development only
logger.info("Normal operational messages")   # Track application flow
logger.warning("Warning: deprecated API")    # Potential issues
logger.error("Failed to process file")       # Errors that are handled
logger.exception("Unhandled exception")      # Include full traceback
logger.critical("Database unavailable")      # System-level failures
```

## Error Handling

**RULE**: Use specific exceptions and proper error handling patterns:

```python
# CORRECT: Custom exceptions with context
from __future__ import annotations


class ApplicationError(Exception):
    """Base exception for application errors."""


class ValidationError(ApplicationError):
    """Raised when validation fails."""


class ResourceNotFoundError(ApplicationError):
    """Raised when a resource is not found."""

    def __init__(self, resource_type: str, resource_id: int | str) -> None:
        self.resource_type = resource_type
        self.resource_id = resource_id
        super().__init__(f"{resource_type} not found: {resource_id}")


def get_user(user_id: int) -> User:
    """Get user by ID."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ResourceNotFoundError("User", user_id)
    return user


def process_with_fallback(data: str) -> dict[str, str]:
    """Process data with graceful error handling."""
    try:
        return json.loads(data)
    except json.JSONDecodeError as e:
        logger.warning("Invalid JSON, using empty dict: %s", e)
        return {}
```

```python
# CORRECT: Use contextlib.suppress for expected errors
from contextlib import suppress
from pathlib import Path

def clean_temp_files(temp_dir: Path) -> None:
    """Remove temporary files, ignoring missing files."""
    for temp_file in temp_dir.glob("*.tmp"):
        with suppress(FileNotFoundError):
            temp_file.unlink()
```

```python
# WRONG: Bare except or generic exceptions
def get_user(user_id):
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise Exception("Not found")  # Too generic
        return user
    except:  # Catches everything, including KeyboardInterrupt
        return None

def clean_temp_files(temp_dir):
    for temp_file in temp_dir.glob("*.tmp"):
        try:
            temp_file.unlink()
        except:
            pass  # Unclear what's being suppressed
```

## Constants and Enumerations

**RULE**: Use module-level constants in `UPPER_SNAKE_CASE` and `enum.StrEnum` for string
enumerations:

```python
# CORRECT: Module constants and enumerations
from __future__ import annotations

from enum import StrEnum, auto

# Module-level constants
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30.0
API_BASE_URL = "https://api.example.com/v1"


class UserRole(StrEnum):
    """User role enumeration."""

    ADMIN = "admin"
    EDITOR = "editor"
    VIEWER = "viewer"


class Environment(StrEnum):
    """Deployment environment."""

    DEVELOPMENT = auto()  # Generates "development"
    STAGING = auto()
    PRODUCTION = auto()


def check_permission(user_role: UserRole, required_role: UserRole) -> bool:
    """Check if user has required permission level."""
    role_hierarchy = {
        UserRole.VIEWER: 1,
        UserRole.EDITOR: 2,
        UserRole.ADMIN: 3,
    }
    return role_hierarchy[user_role] >= role_hierarchy[required_role]


# Usage
if check_permission(user.role, UserRole.EDITOR):
    allow_edit()
```

```python
# WRONG: Magic strings and values
def check_permission(user_role, required_role):
    """Check permission with magic strings."""
    role_hierarchy = {
        "viewer": 1,    # Typo-prone
        "editor": 2,
        "admin": 3,
    }
    return role_hierarchy[user_role] >= role_hierarchy[required_role]

# Usage - no IDE autocomplete, no type safety
if check_permission(user.role, "editr"):  # Typo — no IDE autocomplete!
    allow_edit()
```

## Async Patterns

**RULE**: Use `async`/`await` properly for I/O-bound operations:

```python
# CORRECT: Proper async patterns
from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator

import httpx


async def fetch_user(client: httpx.AsyncClient, user_id: int) -> dict[str, str]:
    """Fetch single user asynchronously."""
    response = await client.get(f"/users/{user_id}")
    response.raise_for_status()
    return response.json()


async def fetch_users_batch(user_ids: list[int]) -> list[dict[str, str]]:
    """Fetch multiple users concurrently."""
    async with httpx.AsyncClient(base_url=API_BASE_URL) as client:
        tasks = [fetch_user(client, user_id) for user_id in user_ids]
        return await asyncio.gather(*tasks)


async def stream_large_dataset(
    client: httpx.AsyncClient,
    endpoint: str,
) -> AsyncIterator[dict[str, str]]:
    """Stream data items asynchronously."""
    async with client.stream("GET", endpoint) as response:
        response.raise_for_status()
        async for line in response.aiter_lines():
            if line:
                yield json.loads(line)
```

```python
# WRONG: Mixing sync and async incorrectly
import httpx

async def fetch_user(user_id):
    client = httpx.Client()  # Sync client in async function
    response = client.get(f"/users/{user_id}")  # Blocking call
    return response.json()

def fetch_users_batch(user_ids):  # Sync function
    return [await fetch_user(uid) for uid in user_ids]  # await in sync function
```

## Class Design

**RULE**: Follow Python class design best practices:

```python
# CORRECT: Well-designed classes
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Protocol


class Notifier(Protocol):
    """Protocol for notification implementations."""

    def send(self, message: str, recipient: str) -> None:
        """Send notification."""
        ...


class EmailNotifier:
    """Send notifications via email."""

    def __init__(self, smtp_host: str, smtp_port: int) -> None:
        self._smtp_host = smtp_host
        self._smtp_port = smtp_port

    def send(self, message: str, recipient: str) -> None:
        """Send email notification."""
        logger.info("Sending email to %s", recipient)
        # Implementation


class UserService:
    """Service for user operations."""

    def __init__(self, db: Database, notifier: Notifier) -> None:
        self._db = db
        self._notifier = notifier

    def create_user(self, username: str, email: str) -> User:
        """Create new user and send welcome email."""
        user = User(username=username, email=email)
        self._db.save(user)
        self._notifier.send("Welcome!", user.email)
        return user


# Usage with dependency injection
notifier = EmailNotifier(smtp_host="localhost", smtp_port=25)
service = UserService(db=database, notifier=notifier)
```

```python
# WRONG: Poor class design
class UserService:
    def __init__(self):
        self.db = Database()  # Hard-coded dependency
        self.smtp_host = "localhost"  # Configuration in class

    def create_user(self, username, email):
        user = User(username=username, email=email)
        self.db.save(user)
        # Directly coupling to email implementation
        send_email(self.smtp_host, email, "Welcome!")
        return user
```

## Project Structure

**RULE**: Organize projects with clear separation of concerns:

```text
myproject/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── cli.py              # Command-line interface
│       ├── config.py           # Configuration management
│       ├── models.py           # Data models
│       ├── services/
│       │   ├── __init__.py
│       │   ├── user_service.py
│       │   └── auth_service.py
│       ├── repositories/
│       │   ├── __init__.py
│       │   └── user_repo.py
│       └── utils/
│           ├── __init__.py
│           └── formatting.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_models.py
│   └── test_services/
│       └── test_user_service.py
├── pyproject.toml
├── uv.lock
├── .python-version
└── README.md
```

**Module organization principles**:

- `models.py`: Data classes, domain models
- `services/`: Business logic layer
- `repositories/`: Data access layer
- `cli.py`: Command-line interface
- `config.py`: Configuration and settings
- `utils/`: Pure utility functions

## Anti-Patterns to Avoid

### 1. Mutable Default Arguments

```python
# WRONG: Mutable default argument
def add_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)
    return items

# CORRECT: Use None and create new list
def add_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items

# BETTER: Use immutable operation
def add_item(item: str, items: Sequence[str] = ()) -> list[str]:
    return [*items, item]
```

### 2. Bare `except`

```python
# WRONG: Catching all exceptions
try:
    risky_operation()
except:
    logger.error("Failed")

# CORRECT: Catch specific exceptions
try:
    risky_operation()
except (ValueError, KeyError) as e:
    logger.error("Failed: %s", e)
    raise
```

### 3. String Concatenation in Loops

```python
# WRONG: String concatenation
result = ""
for item in items:
    result += str(item) + ","

# CORRECT: Use join
result = ",".join(str(item) for item in items)
```

### 4. Checking Type with `type()`

```python
# WRONG: Using type()
if type(value) == str:
    process_string(value)

# CORRECT: Use isinstance()
if isinstance(value, str):
    process_string(value)
```

### 5. Manual Context Management

```python
# WRONG: Manual file handling
f = open("data.txt")
try:
    data = f.read()
finally:
    f.close()

# CORRECT: Use context manager
with open("data.txt") as f:
    data = f.read()

# BETTER: Use Path
from pathlib import Path
data = Path("data.txt").read_text()
```

## Summary Checklist

When writing Python code, ensure:

- [ ] Using `uv` for all tool invocations (unless existing project uses different tools)
- [ ] `from __future__ import annotations` at top of module
- [ ] Type hints on all function signatures
- [ ] `pathlib.Path` for all file operations
- [ ] `logging` instead of `print()` for production code
- [ ] Dataclasses or Pydantic for structured data
- [ ] Modern union syntax (`X | Y`) instead of `Optional`
- [ ] `collections.abc` types for function parameters
- [ ] `enum.StrEnum` for string enumerations
- [ ] `contextlib.suppress` over bare `try/except/pass`
- [ ] Async/await for I/O-bound operations
- [ ] Custom exceptions with clear naming
- [ ] Module constants in `UPPER_SNAKE_CASE`
- [ ] Imports organized in three blocks
- [ ] `ruff` for linting and formatting
- [ ] `mypy` for type checking when configured

These conventions ensure code is maintainable, type-safe, and follows modern Python best practices.
