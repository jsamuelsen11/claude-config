## Shell Conventions

- Shebang: `#!/usr/bin/env bash` (or `#!/bin/sh` for POSIX)
- Strict mode: `set -euo pipefail` at top of every script
- Quote all variable expansions: `"${var}"` not `$var`
- Use `[[ ]]` for conditionals (not `[ ]`) in bash scripts
- Functions: `func_name() { }` — lowercase with underscores
- Validate with shellcheck, format with shfmt
- Prefer `printf` over `echo` for portability
- Use `local` for function-scoped variables
