---
name: testing-patterns
description:
  This skill should be used when writing Python tests, creating pytest fixtures, configuring
  conftest.py, parametrizing tests, mocking dependencies, or improving test coverage.
version: 0.1.0
---

# Testing Patterns

This skill defines comprehensive patterns for writing effective, maintainable, and thorough test
suites using pytest. These patterns prioritize test clarity, proper isolation, and high coverage
while maintaining excellent performance.

## Fixtures Over Setup/Teardown

**RULE**: Always prefer pytest fixtures over traditional setup/teardown methods:

```python
# CORRECT: Using fixtures
from __future__ import annotations

import pytest
from pathlib import Path
from myapp.database import Database
from myapp.models import User


@pytest.fixture
def temp_database(tmp_path: Path) -> Database:
    """Create temporary database for testing."""
    db_path = tmp_path / "test.db"
    db = Database(db_path)
    db.initialize()
    return db


@pytest.fixture
def sample_user() -> User:
    """Create sample user for tests."""
    return User(user_id=1, username="testuser", email="test@example.com")


def test_user_creation(temp_database: Database, sample_user: User) -> None:
    """Test creating a user in database."""
    temp_database.save(sample_user)
    retrieved = temp_database.get_user(sample_user.user_id)
    assert retrieved == sample_user
```

```python
# WRONG: Using setup/teardown
import unittest
from myapp.database import Database

class TestDatabase(unittest.TestCase):
    def setUp(self):
        self.db = Database(":memory:")
        self.db.initialize()

    def tearDown(self):
        self.db.close()

    def test_user_creation(self):
        user = User(1, "testuser", "test@example.com")
        self.db.save(user)
        retrieved = self.db.get_user(user.user_id)
        self.assertEqual(retrieved, user)
```

**Why fixtures are better**:

- Explicit dependencies in function signatures
- Automatic cleanup with yield fixtures
- Composable and reusable across tests
- Support for different scopes
- Better IDE integration and type checking

## Fixture Scopes

**RULE**: Choose appropriate fixture scope based on setup cost and state requirements:

```python
# CORRECT: Different fixture scopes
from __future__ import annotations

import pytest
from collections.abc import Iterator
from pathlib import Path

import httpx
from myapp.app import create_app
from myapp.database import Database


@pytest.fixture(scope="session")
def database_schema() -> str:
    """Load database schema once per test session."""
    schema_path = Path(__file__).parent / "schema.sql"
    return schema_path.read_text()


@pytest.fixture(scope="module")
def test_database(database_schema: str, tmp_path_factory) -> Iterator[Database]:
    """Create database once per test module."""
    db_path = tmp_path_factory.mktemp("data") / "test.db"
    db = Database(db_path)
    db.execute(database_schema)
    yield db
    db.close()


@pytest.fixture(scope="function")  # Default scope
def clean_database(test_database: Database) -> Iterator[Database]:
    """Provide clean database for each test."""
    yield test_database
    test_database.clear_all_tables()


@pytest.fixture
def api_client() -> Iterator[httpx.Client]:
    """Create HTTP client for each test."""
    with httpx.Client(app=create_app()) as client:
        yield client


def test_user_creation(clean_database: Database, api_client: httpx.Client) -> None:
    """Test user creation endpoint."""
    response = api_client.post("/users", json={"username": "alice"})
    assert response.status_code == 201

    user_id = response.json()["user_id"]
    user = clean_database.get_user(user_id)
    assert user.username == "alice"
```

**Scope guidelines**:

- `function` (default): Fast setup, test isolation critical
- `class`: Shared across test class methods
- `module`: Expensive setup, read-only usage
- `session`: Very expensive setup, global resources

## Fixture Naming Conventions

**RULE**: Name fixtures as nouns representing the provided resource:

```python
# CORRECT: Noun-based fixture names
@pytest.fixture
def user() -> User:
    """Sample user for testing."""
    return User(user_id=1, username="alice")

@pytest.fixture
def db_session() -> Session:
    """Database session."""
    session = Session()
    yield session
    session.rollback()
    session.close()

@pytest.fixture
def auth_client(user: User) -> AuthenticatedClient:
    """HTTP client with authentication."""
    return AuthenticatedClient(user=user)

@pytest.fixture
def temp_dir(tmp_path: Path) -> Path:
    """Temporary directory for test files."""
    return tmp_path
```

```python
# WRONG: Verb-based or unclear fixture names
@pytest.fixture
def setup_user():  # Sounds like setup method
    return User(user_id=1, username="alice")

@pytest.fixture
def get_db_session():  # Sounds like function
    session = Session()
    yield session
    session.close()

@pytest.fixture
def create_authenticated_client(user):  # Too verbose
    return AuthenticatedClient(user=user)
```

## conftest.py Hierarchy

**RULE**: Organize fixtures in `conftest.py` files following test directory structure:

```text
tests/
├── conftest.py                 # Global fixtures
├── test_models.py
├── integration/
│   ├── conftest.py            # Integration test fixtures
│   ├── test_api.py
│   └── test_database.py
└── unit/
    ├── conftest.py            # Unit test fixtures
    ├── test_services.py
    └── test_utils.py
```

```python
# tests/conftest.py - Global fixtures
from __future__ import annotations

import pytest
from pathlib import Path


@pytest.fixture(scope="session")
def test_data_dir() -> Path:
    """Directory containing test data files."""
    return Path(__file__).parent / "data"


@pytest.fixture
def sample_config() -> dict[str, str]:
    """Sample configuration for tests."""
    return {
        "api_key": "test-key",
        "base_url": "http://localhost:8000",
        "timeout": "30",
    }
```

```python
# tests/integration/conftest.py - Integration fixtures
from __future__ import annotations

import pytest
from collections.abc import Iterator

import httpx
from myapp.app import create_app
from myapp.database import Database


@pytest.fixture(scope="module")
def test_database() -> Iterator[Database]:
    """Create test database for integration tests."""
    db = Database(":memory:")
    db.initialize_schema()
    yield db
    db.close()


@pytest.fixture
def api_client() -> Iterator[httpx.Client]:
    """HTTP client for API testing."""
    app = create_app()
    with httpx.Client(app=app, base_url="http://test") as client:
        yield client
```

## Test Naming Conventions

**RULE**: Use descriptive test names following `test_<behavior>_<scenario>` pattern:

```python
# CORRECT: Descriptive test names
def test_user_creation_with_valid_data() -> None:
    """Test that users are created with valid input."""
    user = create_user(username="alice", email="alice@example.com")
    assert user.username == "alice"
    assert user.email == "alice@example.com"


def test_user_creation_raises_error_on_duplicate_username() -> None:
    """Test that creating user with duplicate username raises error."""
    create_user(username="alice", email="alice@example.com")

    with pytest.raises(ValueError, match="Username already exists"):
        create_user(username="alice", email="different@example.com")


def test_email_validation_rejects_invalid_format() -> None:
    """Test that invalid email format is rejected."""
    with pytest.raises(ValueError, match="Invalid email format"):
        create_user(username="bob", email="not-an-email")


def test_user_search_returns_empty_list_when_no_matches() -> None:
    """Test that search returns empty list when no users match."""
    results = search_users(query="nonexistent")
    assert results == []
```

```python
# WRONG: Poor test names
def test_user():  # What about the user?
    user = create_user(username="alice", email="alice@example.com")
    assert user.username == "alice"

def test_duplicate():  # Duplicate what?
    create_user(username="alice", email="alice@example.com")
    with pytest.raises(ValueError):
        create_user(username="alice", email="different@example.com")

def test_1():  # Meaningless
    results = search_users(query="nonexistent")
    assert results == []
```

**Test file naming**:

- `test_<module>.py` for testing a specific module
- `test_integration_<feature>.py` for integration tests
- `test_e2e_<scenario>.py` for end-to-end tests

## Parametrize for Input Variations

**RULE**: Use `@pytest.mark.parametrize` to test multiple input scenarios:

```python
# CORRECT: Parametrized tests with IDs
from __future__ import annotations

import pytest


@pytest.mark.parametrize(
    ("input_value", "expected"),
    [
        (0, "zero"),
        (1, "one"),
        (2, "two"),
        (10, "ten"),
    ],
    ids=["zero", "one", "two", "ten"],
)
def test_number_to_word(input_value: int, expected: str) -> None:
    """Test number to word conversion."""
    assert number_to_word(input_value) == expected


@pytest.mark.parametrize(
    ("email", "is_valid"),
    [
        ("user@example.com", True),
        ("user.name@example.co.uk", True),
        ("user+tag@example.com", True),
        ("invalid", False),
        ("@example.com", False),
        ("user@", False),
        ("", False),
    ],
    ids=[
        "simple_email",
        "subdomain",
        "with_plus",
        "no_at_sign",
        "no_user",
        "no_domain",
        "empty",
    ],
)
def test_email_validation(email: str, is_valid: bool) -> None:
    """Test email validation with various formats."""
    assert validate_email(email) == is_valid


@pytest.mark.parametrize("user_role", ["admin", "editor", "viewer"])
@pytest.mark.parametrize("resource_type", ["document", "image", "video"])
def test_permission_check(user_role: str, resource_type: str) -> None:
    """Test permission checking for all role/resource combinations."""
    user = User(role=user_role)
    resource = Resource(type=resource_type)

    # Should not raise for any valid combination
    check_permission(user, resource, action="read")
```

```python
# WRONG: Repetitive test functions
def test_number_to_word_zero() -> None:
    assert number_to_word(0) == "zero"

def test_number_to_word_one() -> None:
    assert number_to_word(1) == "one"

def test_number_to_word_two() -> None:
    assert number_to_word(2) == "two"

# WRONG: Testing multiple cases in one test
def test_email_validation() -> None:
    assert validate_email("user@example.com") == True
    assert validate_email("invalid") == False
    assert validate_email("@example.com") == False
    # If first assertion fails, others don't run
```

**Parametrize with pytest.param for complex cases**:

```python
@pytest.mark.parametrize(
    ("input_data", "expected_output", "expected_warnings"),
    [
        pytest.param(
            {"name": "Alice", "age": 30},
            User(name="Alice", age=30),
            [],
            id="valid_data",
        ),
        pytest.param(
            {"name": "Bob"},
            User(name="Bob", age=0),
            ["Missing age field"],
            id="missing_age",
        ),
        pytest.param(
            {"name": "", "age": -5},
            None,
            ["Empty name", "Invalid age"],
            marks=pytest.mark.xfail(reason="Validation not implemented"),
            id="invalid_data",
        ),
    ],
)
def test_user_parsing(
    input_data: dict[str, int | str],
    expected_output: User | None,
    expected_warnings: list[str],
) -> None:
    """Test user data parsing with various inputs."""
    with warnings.catch_warnings(record=True) as w:
        result = parse_user(input_data)
        assert result == expected_output
        warning_messages = [str(warning.message) for warning in w]
        assert warning_messages == expected_warnings
```

## Monkeypatch Over mock.patch

**RULE**: Prefer `monkeypatch` fixture over `unittest.mock.patch` for patching:

```python
# CORRECT: Using monkeypatch
from __future__ import annotations

import pytest
from pathlib import Path

from myapp import config
from myapp.services import external_api


def test_config_loading(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Test configuration loading from environment."""
    config_file = tmp_path / "config.json"
    config_file.write_text('{"api_key": "test-key"}')

    monkeypatch.setenv("CONFIG_PATH", str(config_file))

    loaded_config = config.load()
    assert loaded_config["api_key"] == "test-key"


def test_api_call_with_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test API call behavior when timeout occurs."""
    def mock_request(*args, **kwargs):
        raise TimeoutError("Connection timeout")

    monkeypatch.setattr(external_api, "make_request", mock_request)

    with pytest.raises(TimeoutError, match="Connection timeout"):
        external_api.fetch_data()


def test_current_time_mocking(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test time-dependent behavior with mocked time."""
    from datetime import datetime

    fixed_time = datetime(2024, 1, 1, 12, 0, 0)

    class MockDatetime:
        @classmethod
        def now(cls):
            return fixed_time

    monkeypatch.setattr("myapp.utils.datetime", MockDatetime)

    result = get_timestamp()
    assert result == fixed_time
```

```python
# WRONG: Using unittest.mock.patch
from unittest.mock import patch

@patch("myapp.config.load")
def test_config_loading(mock_load):
    """Test with patch decorator."""
    mock_load.return_value = {"api_key": "test-key"}
    # String-based patching is fragile
    # Cleanup is less explicit

@patch("myapp.external_api.make_request")
def test_api_call(mock_request):
    mock_request.side_effect = TimeoutError("Connection timeout")
    # Less clear what's being patched
```

**Why monkeypatch is better**:

- Automatic cleanup (restores after test)
- More explicit (see what's being patched)
- Scoped to test function automatically
- Better error messages
- Works with environment variables easily

## Factory Pattern for Complex Fixtures

**RULE**: Use factory fixtures that return callables for flexible test object creation:

```python
# CORRECT: Factory fixture pattern
from __future__ import annotations

import pytest
from collections.abc import Callable
from datetime import datetime

from myapp.models import User, Post


@pytest.fixture
def make_user() -> Callable[..., User]:
    """Factory for creating test users with custom attributes."""
    created_users = []

    def _make_user(
        user_id: int | None = None,
        username: str = "testuser",
        email: str | None = None,
        is_active: bool = True,
        **kwargs,
    ) -> User:
        if user_id is None:
            user_id = len(created_users) + 1
        if email is None:
            email = f"{username}@example.com"

        user = User(
            user_id=user_id,
            username=username,
            email=email,
            is_active=is_active,
            **kwargs,
        )
        created_users.append(user)
        return user

    return _make_user


@pytest.fixture
def make_post(make_user: Callable[..., User]) -> Callable[..., Post]:
    """Factory for creating test posts."""
    def _make_post(
        title: str = "Test Post",
        content: str = "Test content",
        author: User | None = None,
        published_at: datetime | None = None,
        **kwargs,
    ) -> Post:
        if author is None:
            author = make_user()

        return Post(
            title=title,
            content=content,
            author=author,
            published_at=published_at or datetime.now(),
            **kwargs,
        )

    return _make_post


def test_user_with_defaults(make_user: Callable[..., User]) -> None:
    """Test creating user with default values."""
    user = make_user()
    assert user.username == "testuser"
    assert user.email == "testuser@example.com"
    assert user.is_active is True


def test_user_with_custom_values(make_user: Callable[..., User]) -> None:
    """Test creating user with custom values."""
    user = make_user(username="alice", email="alice@custom.com", is_active=False)
    assert user.username == "alice"
    assert user.email == "alice@custom.com"
    assert user.is_active is False


def test_multiple_users(make_user: Callable[..., User]) -> None:
    """Test creating multiple users with different attributes."""
    alice = make_user(username="alice")
    bob = make_user(username="bob")
    charlie = make_user(username="charlie", is_active=False)

    assert alice.user_id != bob.user_id != charlie.user_id
    assert charlie.is_active is False


def test_post_creation(make_post: Callable[..., Post]) -> None:
    """Test creating post with auto-generated author."""
    post = make_post(title="My Post")
    assert post.title == "My Post"
    assert post.author.username == "testuser"
```

```python
# WRONG: Hard-coded fixtures without flexibility
@pytest.fixture
def user() -> User:
    """Fixed user fixture - not flexible."""
    return User(user_id=1, username="testuser", email="test@example.com")

def test_multiple_users(user: User) -> None:
    """Can't easily create multiple different users."""
    # Have to manually create variations
    alice = User(user_id=2, username="alice", email="alice@example.com")
    bob = User(user_id=3, username="bob", email="bob@example.com")
```

## Assertion Patterns

**RULE**: Use clear, descriptive assertions with appropriate methods:

```python
# CORRECT: Clear assertions with messages
from __future__ import annotations

import pytest


def test_user_creation() -> None:
    """Test user creation with proper assertions."""
    user = create_user(username="alice", email="alice@example.com")

    # Use direct assertions
    assert user.username == "alice"
    assert user.email == "alice@example.com"
    assert user.is_active is True

    # Check types when important
    assert isinstance(user.user_id, int)
    assert user.user_id > 0


def test_collection_operations() -> None:
    """Test collection assertions."""
    users = get_all_users()

    # Check collection properties
    assert len(users) == 3
    assert all(user.is_active for user in users)

    # Check membership
    usernames = [user.username for user in users]
    assert "alice" in usernames
    assert "banned_user" not in usernames


def test_float_comparison() -> None:
    """Test floating point comparison."""
    result = calculate_average([1.0, 2.0, 3.0])

    # Use pytest.approx for floats
    assert result == pytest.approx(2.0)
    assert result == pytest.approx(2.0, abs=0.01)


def test_exception_with_message() -> None:
    """Test exception is raised with specific message."""
    with pytest.raises(ValueError, match="Username must be alphanumeric"):
        create_user(username="alice!", email="alice@example.com")


def test_multiple_exceptions() -> None:
    """Test multiple exception scenarios."""
    with pytest.raises(ValueError, match="Username too short"):
        create_user(username="a", email="alice@example.com")

    with pytest.raises(ValueError, match="Invalid email"):
        create_user(username="alice", email="not-an-email")
```

```python
# WRONG: Poor assertion patterns
def test_user_creation() -> None:
    user = create_user(username="alice", email="alice@example.com")

    # Asserting on repr/str is fragile
    assert str(user) == "User(alice, alice@example.com)"  # Breaks if repr changes

    # No descriptive message
    assert user.is_active  # What does True mean here?


def test_float_comparison() -> None:
    result = calculate_average([1.0, 2.0, 3.0])

    # Direct float comparison is unreliable
    assert result == 2.0  # May fail due to precision


def test_exception_without_match() -> None:
    # Too broad - any ValueError passes
    with pytest.raises(ValueError):
        create_user(username="alice!", email="alice@example.com")
```

## Test Markers

**RULE**: Use markers to categorize and selectively run tests:

```python
# CORRECT: Using test markers
from __future__ import annotations

import pytest


@pytest.mark.unit
def test_user_validation() -> None:
    """Fast unit test for user validation."""
    assert validate_username("alice") is True


@pytest.mark.integration
def test_database_user_creation(db_session) -> None:
    """Integration test with database."""
    user = User(username="alice")
    db_session.add(user)
    db_session.commit()

    retrieved = db_session.query(User).filter_by(username="alice").first()
    assert retrieved.username == "alice"


@pytest.mark.slow
@pytest.mark.integration
def test_bulk_data_import(db_session) -> None:
    """Slow integration test for bulk operations."""
    users = [User(username=f"user{i}") for i in range(10000)]
    db_session.bulk_save_objects(users)
    db_session.commit()

    count = db_session.query(User).count()
    assert count == 10000


@pytest.mark.external
def test_api_call() -> None:
    """Test requiring external API access."""
    response = call_external_api()
    assert response.status_code == 200


@pytest.mark.parametrize("value", [1, 2, 3])
@pytest.mark.skip(reason="Feature not implemented yet")
def test_future_feature(value: int) -> None:
    """Test for upcoming feature."""
    assert process_value(value) > 0


@pytest.mark.xfail(reason="Known bug in dependency")
def test_with_known_bug() -> None:
    """Test that currently fails due to known issue."""
    assert buggy_function() == expected_value
```

**Configure markers in pyproject.toml**:

```toml
[tool.pytest.ini_options]
markers = [
    "unit: Fast unit tests",
    "integration: Integration tests with external dependencies",
    "slow: Slow-running tests",
    "external: Tests requiring external services",
]
```

**Run specific marker groups**:

```bash
# Run only unit tests
uv run pytest -m unit

# Run everything except slow tests
uv run pytest -m "not slow"

# Run integration tests excluding external dependencies
uv run pytest -m "integration and not external"
```

## Async Test Patterns

**RULE**: Use `pytest-asyncio` for testing async code:

```python
# CORRECT: Async test patterns
from __future__ import annotations

import pytest
import pytest_asyncio
from collections.abc import AsyncIterator

import httpx
from myapp.services import AsyncUserService


# Configure pytest-asyncio in pyproject.toml:
# [tool.pytest.ini_options]
# asyncio_mode = "auto"


@pytest_asyncio.fixture
async def async_client() -> AsyncIterator[httpx.AsyncClient]:
    """Async HTTP client fixture."""
    async with httpx.AsyncClient(base_url="http://test") as client:
        yield client


@pytest_asyncio.fixture
async def user_service() -> AsyncUserService:
    """Async user service fixture."""
    service = AsyncUserService()
    await service.initialize()
    return service


@pytest.mark.asyncio
async def test_async_user_creation(user_service: AsyncUserService) -> None:
    """Test async user creation."""
    user = await user_service.create_user(username="alice")
    assert user.username == "alice"

    retrieved = await user_service.get_user(user.user_id)
    assert retrieved == user


@pytest.mark.asyncio
async def test_concurrent_operations(user_service: AsyncUserService) -> None:
    """Test concurrent async operations."""
    import asyncio

    # Create multiple users concurrently
    tasks = [
        user_service.create_user(username=f"user{i}")
        for i in range(10)
    ]
    users = await asyncio.gather(*tasks)

    assert len(users) == 10
    assert all(user.username.startswith("user") for user in users)


@pytest.mark.asyncio
async def test_async_context_manager(async_client: httpx.AsyncClient) -> None:
    """Test with async context manager."""
    response = await async_client.get("/users")
    assert response.status_code == 200

    users = response.json()
    assert isinstance(users, list)
```

```python
# WRONG: Mixing sync and async incorrectly
def test_async_user_creation(user_service):  # Missing async
    user = await user_service.create_user(username="alice")  # SyntaxError
    assert user.username == "alice"


@pytest.mark.asyncio
async def test_with_sync_fixture(sync_client):  # Fixture should be async
    response = sync_client.get("/users")  # Blocking call in async test
    assert response.status_code == 200
```

## Coverage Best Practices

**RULE**: Aim for high coverage with meaningful tests:

```python
# CORRECT: Comprehensive test coverage
from __future__ import annotations

import pytest
from typing import TYPE_CHECKING

from myapp.calculator import Calculator


def test_calculator_addition() -> None:
    """Test addition operation."""
    calc = Calculator()
    assert calc.add(2, 3) == 5
    assert calc.add(-1, 1) == 0
    assert calc.add(0, 0) == 0


def test_calculator_division() -> None:
    """Test division operation."""
    calc = Calculator()
    assert calc.divide(6, 2) == 3
    assert calc.divide(5, 2) == 2.5


def test_calculator_division_by_zero() -> None:
    """Test division by zero raises error."""
    calc = Calculator()
    with pytest.raises(ZeroDivisionError, match="Cannot divide by zero"):
        calc.divide(5, 0)


def test_calculator_operation_history() -> None:
    """Test operation history tracking."""
    calc = Calculator()
    calc.add(2, 3)
    calc.divide(10, 2)

    history = calc.get_history()
    assert len(history) == 2
    assert history[0] == "add(2, 3) = 5"
    assert history[1] == "divide(10, 2) = 5.0"


# Legitimate use of pragma: no cover
if TYPE_CHECKING:  # pragma: no cover
    from myapp.models import User

# Defensive code that can't be tested
def safe_divide(a: float, b: float) -> float:
    """Safely divide two numbers."""
    try:
        return a / b
    except Exception as e:  # pragma: no cover
        # This should never happen, but defensive
        logger.critical("Unexpected error in safe_divide: %s", e)
        raise
```

**Configure coverage in pyproject.toml**:

```toml
[tool.coverage.run]
source = ["src"]
branch = true
omit = [
    "*/tests/*",
    "*/migrations/*",
    "*/__main__.py",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
    "@abstractmethod",
]
show_missing = true
fail_under = 90
```

**Run coverage**:

```bash
# Run tests with coverage
uv run pytest --cov=src --cov-report=html --cov-report=term

# Check coverage threshold
uv run pytest --cov=src --cov-fail-under=90
```

## Testing Best Practices Summary

### Test Structure

**AAA Pattern**: Arrange, Act, Assert

```python
def test_user_creation() -> None:
    """Test user creation with valid data."""
    # Arrange
    username = "alice"
    email = "alice@example.com"

    # Act
    user = create_user(username=username, email=email)

    # Assert
    assert user.username == username
    assert user.email == email
```

### Test Independence

**RULE**: Each test must be independent and isolated:

```python
# CORRECT: Independent tests
@pytest.fixture
def clean_database(database):
    """Provide clean database for each test."""
    yield database
    database.clear()


def test_user_creation(clean_database) -> None:
    """Test creates its own data."""
    user = User(username="alice")
    clean_database.save(user)
    assert clean_database.count() == 1


def test_user_deletion(clean_database) -> None:
    """Test doesn't depend on previous test."""
    user = User(username="bob")
    clean_database.save(user)
    clean_database.delete(user)
    assert clean_database.count() == 0
```

```python
# WRONG: Tests depend on each other
def test_user_creation() -> None:
    """Creates user that other tests depend on."""
    global created_user
    created_user = User(username="alice")
    database.save(created_user)


def test_user_deletion() -> None:
    """Depends on test_user_creation running first."""
    database.delete(created_user)  # Fails if test_user_creation didn't run
```

### Performance Considerations

```python
# CORRECT: Efficient test setup
@pytest.fixture(scope="module")
def expensive_resource():
    """Setup expensive resource once per module."""
    resource = ExpensiveResource()
    resource.initialize()  # Slow operation
    yield resource
    resource.cleanup()


@pytest.fixture
def clean_resource(expensive_resource):
    """Reset resource state for each test."""
    yield expensive_resource
    expensive_resource.reset()  # Fast operation
```

### Testing Private Methods

**RULE**: Test behavior through public interface, not private methods:

```python
# CORRECT: Test public interface
def test_user_password_validation() -> None:
    """Test password validation through public method."""
    user = User(username="alice")

    # Test through public method
    user.set_password("weakpw")
    assert user.is_password_valid("weakpw") is True
    assert user.is_password_valid("wrongpw") is False
```

```python
# WRONG: Testing private methods directly
def test_user_password_hashing() -> None:
    """Testing implementation detail."""
    user = User(username="alice")

    # Testing private method
    hashed = user._hash_password("password")  # Implementation detail
    assert len(hashed) == 64
```

## Anti-Patterns to Avoid

### 1. Testing Implementation Instead of Behavior

```python
# WRONG: Testing implementation
def test_user_service_calls_repository() -> None:
    """Test that service calls repository method."""
    repo = Mock()
    service = UserService(repo)
    service.get_user(1)

    repo.find_by_id.assert_called_once_with(1)  # Testing implementation
```

```python
# CORRECT: Testing behavior
def test_user_service_returns_user() -> None:
    """Test that service returns correct user."""
    repo = InMemoryUserRepository()
    repo.save(User(user_id=1, username="alice"))

    service = UserService(repo)
    user = service.get_user(1)

    assert user.username == "alice"  # Testing behavior
```

### 2. Overly Complex Test Setup

```python
# WRONG: Complex test with too much setup
def test_order_processing() -> None:
    db = Database()
    db.connect()
    db.create_tables()
    user = User(username="alice")
    db.save(user)
    product1 = Product(name="Widget")
    db.save(product1)
    product2 = Product(name="Gadget")
    db.save(product2)
    cart = ShoppingCart(user=user)
    cart.add_item(product1, quantity=2)
    cart.add_item(product2, quantity=1)

    order = process_order(cart)
    assert order.total == 30
```

```python
# CORRECT: Use fixtures to simplify
def test_order_processing(user, cart_with_items) -> None:
    """Test order processing with fixtures."""
    order = process_order(cart_with_items)
    assert order.total == 30
```

### 3. Not Using Specific Exception Matching

```python
# WRONG: Too broad exception testing
def test_invalid_email() -> None:
    with pytest.raises(ValueError):  # Any ValueError passes
        validate_email("invalid")
```

```python
# CORRECT: Specific exception message
def test_invalid_email() -> None:
    with pytest.raises(ValueError, match="Invalid email format"):
        validate_email("invalid")
```

## Summary Checklist

When writing tests, ensure:

- [ ] Using fixtures instead of setup/teardown
- [ ] Fixture names are nouns (not verbs)
- [ ] Appropriate fixture scope chosen
- [ ] Tests named as `test_<behavior>_<scenario>`
- [ ] Using `@pytest.mark.parametrize` for input variations
- [ ] Providing `ids` for parametrized tests
- [ ] Using `monkeypatch` instead of `mock.patch`
- [ ] Factory fixtures for complex object creation
- [ ] Specific `match` parameter on `pytest.raises`
- [ ] Using `pytest.approx` for float comparisons
- [ ] Never asserting on object repr/str
- [ ] Markers registered in pyproject.toml
- [ ] Async tests use `@pytest.mark.asyncio`
- [ ] Coverage target >= 90%
- [ ] Tests are independent and isolated
- [ ] Testing behavior, not implementation

These patterns ensure test suites are maintainable, reliable, and provide confidence in code
quality.
