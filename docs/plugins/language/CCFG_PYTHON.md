# Plugin: ccfg-python

The Python language plugin. Provides framework agents, specialist agents for testing and packaging,
project scaffolding, autonomous coverage improvement, and opinionated conventions for consistent
Python development with uv, ruff, pytest, and mypy.

## Directory Structure

```text
plugins/ccfg-python/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── python-pro.md
│   ├── fastapi-developer.md
│   ├── django-developer.md
│   ├── flask-developer.md
│   ├── data-scientist.md
│   ├── pytest-specialist.md
│   └── packaging-engineer.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
└── skills/
    ├── python-conventions/
    │   └── SKILL.md
    ├── testing-patterns/
    │   └── SKILL.md
    └── packaging-conventions/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-python",
  "description": "Python language plugin: framework and specialist agents, project scaffolding, coverage automation, and conventions for consistent development with uv, ruff, pytest, and mypy",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["python", "uv", "pytest", "ruff", "mypy", "fastapi", "django", "flask"],
  "suggestedPermissions": {
    "allow": [
      "Bash(uvx ruff:*)",
      "Bash(uvx mypy:*)",
      "Bash(uv run pytest:*)",
      "Bash(uv add:*)",
      "Bash(uv sync:*)",
      "Bash(pip install:*)"
    ]
  }
}
```

## Agents (7)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent               | Role                                                                  | Model  |
| ------------------- | --------------------------------------------------------------------- | ------ |
| `python-pro`        | Modern Python 3.11+, type safety, async, packaging, Pythonic patterns | sonnet |
| `fastapi-developer` | FastAPI/Starlette APIs, Pydantic models, async endpoints, OpenAPI     | sonnet |
| `django-developer`  | Django ORM, views, templates, DRF, migrations, admin                  | sonnet |
| `flask-developer`   | Flask blueprints, extensions, lightweight APIs, Jinja templates       | sonnet |
| `data-scientist`    | pandas, numpy, scikit-learn, data analysis, Jupyter, visualization    | sonnet |

### Specialist Agents

| Agent                | Role                                                                                                                             | Model  |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `pytest-specialist`  | Deep pytest expertise: fixtures, parametrize, conftest hierarchy, monkeypatch, factories, markers, hypothesis, coverage analysis | sonnet |
| `packaging-engineer` | pyproject.toml mastery, uv workspaces, dependency groups, version management, publishing, src layout, build backends             | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-python:validate

**Purpose**: Run the full Python quality gate suite in one command.

**Trigger**: User invokes before committing or shipping Python code.

**Allowed tools**: `Bash(uv *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Lint check**: `uv run ruff check .`
2. **Format check**: `uv run ruff format --check .`
3. **Type check**: `uv run mypy src/` (if mypy is configured in pyproject.toml, skip with notice if
   not)
4. **Tests**: `uv run pytest tests/ -v`
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Lint check**: `uv run ruff check .`
2. **Format check**: `uv run ruff format --check .`
3. **Type check**: `uv run mypy src/` (if configured)
4. Report pass/fail — skips test suite for speed

**Key rules**:

- Always uses `uv run`, never bare `pytest`, `ruff`, or `mypy`
- Never suggests `noqa` or lint suppressions as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a tool is not configured (e.g., no mypy config in pyproject.toml), skip that
  gate and report it as SKIPPED. Never fail because an optional tool is missing

### /ccfg-python:scaffold

**Purpose**: Initialize a new Python project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new Python project or service.

**Allowed tools**: `Bash(uv *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<project-name> [--type=service|library|cli]`

**Behavior**:

1. Create project directory with src layout:

   ```text
   <name>/
   ├── src/<name>/
   │   ├── __init__.py
   │   └── py.typed
   ├── tests/
   │   ├── __init__.py
   │   └── conftest.py
   ├── pyproject.toml
   ├── .python-version
   └── README.md
   ```

2. Generate `pyproject.toml` with:
   - uv as build backend
   - ruff config (select rules, line length, isort section)
   - mypy strict mode config
   - pytest config (testpaths, markers, strict mode)
   - Dependency groups: dev (pytest, ruff, mypy), test, docs
3. Scaffold differs by type:
   - `service`: adds FastAPI skeleton, Dockerfile, health endpoint
   - `library`: adds py.typed marker, public API `__init__.py`
   - `cli`: adds Typer skeleton with entry point
4. Initialize with `uv sync` and verify `uv run pytest` passes
5. Initialize git repo if not inside one

**Key rules**:

- Always uses src layout (never flat)
- pyproject.toml only (never setup.py, setup.cfg, or requirements.txt)
- Configures all tools in pyproject.toml (no separate ruff.toml, mypy.ini, etc.)
- conftest.py includes standard fixtures skeleton

### /ccfg-python:coverage

**Purpose**: Autonomous per-file test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**: `Bash(uv *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**: `[--threshold=90] [--file=<path>] [--dry-run] [--no-commit]`

**Behavior**:

1. **Measure**: Run `uv run pytest --cov=src --cov-report=term-missing`
2. **Identify**: Parse output, rank files by uncovered lines (most gaps first)
3. **Target**: For each under-threshold file: a. Read the source file and existing tests b. Identify
   untested branches, functions, and edge cases c. Write targeted tests following project's existing
   test patterns d. Run `uv run pytest` to confirm new tests pass e. Run `uv run ruff check` on new
   test files f. Commit: `git add <test-file> && git commit -m "test: add coverage for <module>"`
4. **Report**: Summary table of before/after coverage per file
5. Stop when threshold reached or all files processed

**Modes**:

- **Default**: Write tests and auto-commit after each file
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Reads existing tests first to match project patterns (fixtures, naming, style)
- One commit per file (not one giant commit)
- Never writes tests that just assert `True` or mock everything
- Tests must exercise real behavior, not just line coverage
- Respects pytestmark decorators and match parameters on raises

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### python-conventions

**Trigger description**: "This skill should be used when working on Python projects, writing Python
code, running Python tests, managing Python dependencies, or reviewing Python code."

**Existing repo compatibility**: For existing projects, respect the established toolchain. If the
project uses pip/poetry instead of uv, use what's configured. If the project uses black instead of
ruff format, follow it. These preferences apply to new projects and scaffold output only.

**Tooling rules**:

- Use `uv` for all Python operations (tests, deps, scripts). Never use bare `python`, `pip`, or
  `pytest` directly
- Use `ruff` for linting and formatting (not black, not flake8, not isort)
- Use `mypy` for type checking where configured
- Use `uv run` prefix for all tool execution

**Code style rules**:

- Prefer `pathlib.Path` over `os.path`
- Use type hints on all function signatures
- Use dataclasses or Pydantic models over plain dicts for structured data
- Use `logging` module, never bare `print()` for production code
- Use `from __future__ import annotations` in all modules for modern type syntax
- Prefer `str | None` over `Optional[str]` (PEP 604 union syntax)
- Use `collections.abc` types for function args (`Sequence`, `Mapping`), concrete types for return
  values (`list`, `dict`)
- Async functions must have proper `async`/`await` — never wrap sync code in async without
  justification
- Use `contextlib.suppress` over bare `try/except/pass`
- Constants at module level in `UPPER_SNAKE_CASE`
- Use `enum.StrEnum` for string enumerations (Python 3.11+)

**Testing rules**:

- All test files must have proper `pytestmark` decorators
- Use specific `match` parameters on all `pytest.raises` calls

### testing-patterns

**Trigger description**: "This skill should be used when writing Python tests, creating pytest
fixtures, configuring conftest.py, parametrizing tests, mocking dependencies, or improving test
coverage."

**Contents**:

- **Fixtures**: Prefer fixtures over setup/teardown. Use `conftest.py` hierarchy for shared
  fixtures. Scope fixtures appropriately (`function` default, `session` for expensive resources)
- **Naming**: Test files: `test_<module>.py`. Test functions: `test_<behavior>_<scenario>`.
  Fixtures: noun-based (`db_session`, `auth_client`, not `setup_db`)
- **Parametrize**: Use `@pytest.mark.parametrize` for input variations. Use `ids` parameter for
  readable test names. Group related parametrize values in tuples
- **Monkeypatch over mock.patch**: Prefer `monkeypatch.setattr` for patching. It auto-restores, is
  more explicit, and scopes to the test function
- **Factory pattern**: For complex test objects, create fixture factories that return callables:
  `def make_user(**overrides)` pattern over hard-coded fixtures
- **Assertion style**: Use plain `assert` with descriptive messages. Use `pytest.approx` for floats.
  Never assert on repr or string output of objects
- **Markers**: Use `@pytest.mark.slow`, `@pytest.mark.integration` for test categorization. Register
  all custom markers in pyproject.toml
- **Async tests**: Use `pytest-asyncio` with `@pytest.mark.asyncio`. Use `auto` mode in
  pyproject.toml if most tests are async
- **Coverage**: Target 90%+ line coverage. Use `# pragma: no cover` only for defensive code paths
  that genuinely can't be tested (e.g., `if TYPE_CHECKING:`)

### packaging-conventions

**Trigger description**: "This skill should be used when creating or editing pyproject.toml,
managing Python dependencies, configuring build systems, setting up uv workspaces, or publishing
Python packages."

**Contents**:

- **pyproject.toml is canonical**: All config in pyproject.toml. No setup.py, setup.cfg,
  requirements.txt, mypy.ini, .flake8, or .isort.cfg
- **src layout**: Always `src/<package>/` structure, never flat layout
- **Dependency groups**: Use uv dependency groups — `dev` (ruff, mypy, pre-commit), `test` (pytest,
  pytest-cov, factory-boy), `docs` (sphinx/mkdocs)
- **Version pinning**: Pin direct dependencies to compatible ranges (`>=1.2,<2`). Never pin to exact
  versions unless there's a specific compatibility reason
- **Python version**: Specify `requires-python = ">=3.11"` in pyproject.toml. Use `.python-version`
  file for uv/pyenv
- **Entry points**: Use `[project.scripts]` for CLI tools, `[project.gui-scripts]` for GUI apps
- **Build backend**: Use `hatchling` or `setuptools` with pyproject.toml. Prefer `hatchling` for new
  projects (simpler config)
- **uv workspaces**: For monorepos, use `[tool.uv.workspace]` with `members` pattern. Each member
  has its own pyproject.toml
- **Lock files**: Always commit `uv.lock`. Run `uv lock` after dependency changes
