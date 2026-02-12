# Best Practices

## Code Quality

- Fix linter/formatter errors — never bypass with nolint, noqa, or eslint-disable
- No magic numbers — use named constants
- Handle errors explicitly — no empty catch blocks or swallowed exceptions
- Type-annotate function signatures in typed languages

## Incremental Validation

- Run linters and tests after each logical unit of work — not just at the end
- Fix failures immediately before moving to the next piece
- Never batch all testing to the end of implementation
- If a test or lint check fails, stop and fix before writing more code

## Git Workflow

- Never push to main directly — use feature branches
- Stage specific files (not `git add -A`)
- Conventional commits: type(scope): description
- Never skip hooks (--no-verify) unless explicitly requested
- After hook failure, create a NEW commit (never amend the previous one)

## Security

- Never commit secrets (.env, credentials, private keys)
- Never use chmod 777
- Never pipe remote content to shell (curl | sh)

## Task Discipline

- Complete one task fully before starting the next
- Work is not done until git push succeeds
- When multiple approaches exist, present options before implementing
