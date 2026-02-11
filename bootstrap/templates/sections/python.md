## Python Conventions

- Toolchain: uv (packaging), ruff (lint+format), mypy (types), pytest (test)
- Always: `from __future__ import annotations`
- Union types: `X | Y` (not Optional[X])
- Paths: pathlib.Path (not os.path)
- Data: dataclasses or Pydantic (not raw dicts)
- Logging: `logging` module (not print())
- Imports: stdlib, third-party, local (one per line)
- Test files: `test_<module>.py`, functions: `test_<behavior>()`
