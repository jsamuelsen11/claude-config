# Plugin: ccfg-rust

The Rust language plugin. Provides framework agents for async web development, specialist agents for
testing and concurrency, project scaffolding, autonomous coverage improvement, and opinionated
conventions for consistent Rust development with cargo clippy, rustfmt, cargo-tarpaulin, and cargo
workspaces.

## Directory Structure

```text
plugins/ccfg-rust/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── rust-pro.md
│   ├── axum-developer.md
│   ├── tokio-specialist.md
│   └── cargo-test-specialist.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
└── skills/
    ├── rust-conventions/
    │   └── SKILL.md
    ├── testing-patterns/
    │   └── SKILL.md
    └── cargo-conventions/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-rust",
  "description": "Rust language plugin: async web and concurrency agents, project scaffolding, coverage automation, and conventions for consistent development with cargo clippy, rustfmt, and cargo workspaces",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["rust", "cargo", "axum", "tokio", "clippy", "rustfmt", "tarpaulin"]
}
```

## Agents (4)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent            | Role                                                                                           | Model  |
| ---------------- | ---------------------------------------------------------------------------------------------- | ------ |
| `rust-pro`       | Modern Rust (edition 2021+), ownership, traits, generics, error handling, macros, unsafe rules | sonnet |
| `axum-developer` | axum/tower web APIs, extractors, middleware, state management, REST, WebSocket                 | sonnet |

### Specialist Agents

| Agent                   | Role                                                                                            | Model  |
| ----------------------- | ----------------------------------------------------------------------------------------------- | ------ |
| `tokio-specialist`      | Async Rust, tokio runtime, futures, streams, channels, select, graceful shutdown, task spawning | sonnet |
| `cargo-test-specialist` | Unit/integration testing, proptest, criterion benchmarks, mockall, test organization, doc tests | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-rust:validate

**Purpose**: Run the full Rust quality gate suite in one command.

**Trigger**: User invokes before committing or shipping Rust code.

**Allowed tools**: `Bash(cargo *), Bash(rustfmt *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick] [--all-features]`

**Behavior**:

Workspace detection: if a `[workspace]` section exists in the root `Cargo.toml`, use `--workspace`
flag on all cargo commands to check all crates.

Full mode (default):

1. **Clippy**: `cargo clippy --all-targets -- -D warnings` (workspace: add `--workspace`)
2. **Format check**: `cargo fmt --all -- --check`
3. **Tests**: `cargo test --all-targets` (workspace: add `--workspace`)
4. **Security**: Check for `cargo deny` first (`cargo deny check`), fall back to `cargo audit` if
   deny is not installed, skip with notice if neither is installed
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Check**: `cargo check --all-targets` (type check only, no codegen)
2. **Format check**: `cargo fmt --all -- --check`
3. Report pass/fail — skips tests, clippy, and security audit for speed

`--all-features` (opt-in):

When passed, adds `--all-features` to clippy, test, and check invocations. **Not enabled by
default** because many real-world crates have mutually exclusive features (e.g., `backend-postgres`
vs `backend-sqlite`, `runtime-tokio` vs `runtime-async-std`). Using `--all-features` on such crates
causes compilation errors. Default behavior uses each crate's default features, which is the
standard CI pattern for workspaces.

**Key rules**:

- Uses `--all-targets` by default (includes tests, benches, examples) but not `--all-features`
- Detects workspaces automatically and uses `--workspace` when present
- Quick mode is for inner-loop iteration (~1s vs ~30s+)
- `cargo clippy` IS the linter — there is no separate lint tool
- `cargo deny` is preferred over `cargo audit` when available (superset: advisories + license +
  duplicates + source restrictions). Falls back to `cargo audit`, then skips
- Fix the root cause instead of adding lint suppressions. When `#[allow]` is genuinely necessary
  (false positive, FFI binding, intentional pattern), use the most specific lint name
  (`#[allow(clippy::too_many_arguments)]`), apply it to the narrowest scope (function, not module),
  and include a comment explaining why. Never use `#[allow(warnings)]`, `#![allow(clippy::all)]`, or
  module-level blanket allows
- Reports all gate results, not just the first failure
- Detect-and-skip: if an optional tool is not installed (e.g., `cargo-deny`, `cargo-audit`), skip
  that gate and report it as SKIPPED. Never fail because an optional tool is missing

### /ccfg-rust:scaffold

**Purpose**: Initialize a new Rust project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new Rust project or service.

**Allowed tools**: `Bash(cargo *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<project-name> [--type=service|library|cli]`

**Behavior**:

1. Create project with `cargo new` or `cargo init`:

   ```text
   <name>/
   ├── src/
   │   ├── main.rs (or lib.rs for library)
   │   └── lib.rs (for service/cli, re-exports modules)
   ├── tests/
   │   └── integration_test.rs
   ├── Cargo.toml
   ├── rustfmt.toml
   ├── .gitignore
   └── README.md
   ```

2. Generate `Cargo.toml` with:
   - Edition 2021
   - Appropriate dependencies per type
   - `[lints.clippy]` section with opinionated lint levels (this is the single source of truth for
     clippy configuration — no separate `clippy.toml`)
3. Generate `rustfmt.toml` with formatting preferences (only if non-default settings are needed;
   omit if using all rustfmt defaults)
4. Scaffold differs by type:
   - `service`: adds axum + tokio skeleton, health endpoint, graceful shutdown, tower middleware.
     Includes `[profile.release]` with `lto = true`, `codegen-units = 1`
   - `library`: adds public API in `lib.rs`, doc comments, `examples/` directory,
     `#![deny(missing_docs)]`. No release profile customization (consumers control their own
     profile)
   - `cli`: adds clap skeleton with derive-based argument parsing. Includes `[profile.release]` with
     `lto = true`, `codegen-units = 1`
5. Verify `cargo test` and `cargo clippy` pass

**Key rules**:

- Edition 2021 minimum
- Lint configuration lives in `[lints.clippy]` in Cargo.toml, not in a separate `clippy.toml`
  (single source of truth, works with `[workspace.lints]` in workspaces)
- Uses `tests/` directory for integration tests, `#[cfg(test)]` modules for unit tests
- Service template includes graceful shutdown with tokio signal handling
- Library template includes doc comments and `#![deny(missing_docs)]` but no release profile
  customization
- Release profile optimization (`lto`, `codegen-units`) only for service and cli types where the
  crate produces a final binary

### /ccfg-rust:coverage

**Purpose**: Autonomous per-crate test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**: `Bash(cargo *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**:
`[--threshold=90] [--crate=<name>] [--dry-run] [--no-commit] [--tool=tarpaulin|llvm-cov]`

**Behavior**:

1. **Detect tool**: Default to `cargo-tarpaulin` (works on stable toolchain, most common). Use
   `cargo-llvm-cov` only if explicitly requested via `--tool=llvm-cov` or if the project already
   uses it (detectable by presence in CI configs or `.cargo/config.toml`). Skip with notice if
   neither is installed
2. **Measure**: Run `cargo tarpaulin --out json --output-dir target/tarpaulin` or
   `cargo llvm-cov --json`
3. **Identify**: Parse JSON output, rank files by uncovered lines (most gaps first)
4. **Target**: For each under-threshold file: a. Read the source file and existing tests b. Identify
   untested functions, branches, and edge cases c. Write targeted tests following project's existing
   test patterns d. Run `cargo test` to confirm new tests pass e. Run `cargo clippy` on changed
   files f. Commit: `git add <test-file> && git commit -m "test: add coverage for <module>"`
5. **Report**: Summary table of before/after coverage per file
6. **Clean up**: Remove coverage artifacts (`target/tarpaulin/`, `target/llvm-cov-target/`,
   `tarpaulin-report.json` if present)
7. Stop when threshold reached or all files processed

**Modes**:

- **Default**: Write tests and auto-commit after each file
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Defaults to `cargo-tarpaulin` because it works on stable Rust. `cargo-llvm-cov` is more accurate
  but requires the `llvm-tools-preview` rustup component; prefer it only when the project already
  uses it
- Uses `--output-dir` to control artifact location for deterministic discovery
- Reads existing tests first to match project patterns (unit in `#[cfg(test)]`, integration in
  `tests/`, proptest usage, etc.)
- One commit per module (not one giant commit)
- Tests must exercise real behavior with meaningful assertions
- Respects ownership semantics — test fixtures handle `Clone`, `Default`, and builder patterns
  appropriately
- Cleans up coverage artifacts after completion

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### rust-conventions

**Trigger description**: "This skill should be used when working on Rust projects, writing Rust
code, running Rust tests, managing Cargo dependencies, or reviewing Rust code."

**Existing repo compatibility**: For existing projects, respect the established patterns, edition,
and conventions. If the project uses a specific error handling crate (anyhow vs eyre), follow it. If
the project has a custom `clippy.toml` or `rustfmt.toml`, respect those settings. If the project
configures lints in `Cargo.toml` via `[lints]`, follow that pattern. These preferences apply to new
projects and scaffold output only.

**Ownership and borrowing rules**:

- Prefer borrowing (`&T`, `&mut T`) over ownership transfer when the callee doesn't need to own the
  data
- Use `Clone` only when borrowing is genuinely insufficient. Never sprinkle `.clone()` to silence
  the borrow checker without understanding the ownership issue
- Use `Cow<'_, str>` when a function may or may not need to allocate
- Prefer `&str` over `&String` in function parameters, `&[T]` over `&Vec<T>`
- Use `Arc<T>` for shared ownership across threads, `Rc<T>` only in single-threaded contexts

**Error handling rules**:

- Use `thiserror` for library error types (derives `std::error::Error` with structured variants)
- Use `anyhow` for application-level error handling (context chaining, no custom types needed)
- Never use `unwrap()` in library code. Use `expect("reason")` only when the invariant is documented
- Use `?` operator for error propagation. Define `Result<T>` type aliases in library crates
- Map errors at API boundaries — don't leak internal error types to consumers

**Code style rules**:

- Follow `cargo clippy` recommendations — clippy IS the style guide
- Use `cargo fmt` (rustfmt) for formatting. Never manually format code
- Prefer iterators and combinators (`.map()`, `.filter()`, `.collect()`) over manual loops
- Use `enum` with `match` for state machines. All match arms must be handled, no `_ =>` catch-all
  unless justified
- Use `#[must_use]` on functions whose return value should not be silently discarded
- Prefer `impl Trait` in argument position for simple generics, explicit generics for complex bounds
- Use `pub(crate)` for crate-internal visibility, not `pub` for everything
- Module organization: one module per file, `mod.rs` only for re-exports, prefer `file.rs` over
  `file/mod.rs`

**Lint suppression rules**:

- Fix the root cause when possible. When `#[allow]` is genuinely necessary, follow these rules:
  - Use the most specific lint name: `#[allow(clippy::too_many_arguments)]`, not
    `#[allow(clippy::all)]`
  - Apply to the narrowest scope: annotate the function or item, not the module or crate
  - Include a comment explaining why: `#[allow(dead_code)] // Used via FFI, not visible to rustc`
- Common legitimate uses: `#[allow(dead_code)]` during development, `#[allow(unused_imports)]` in
  re-export modules, `#[allow(clippy::too_many_arguments)]` on FFI bindings or builder constructors
- Never use `#[allow(warnings)]`, `#![allow(clippy::all)]`, or crate-level blanket suppression

**Unsafe rules**:

- Avoid `unsafe` unless absolutely necessary (FFI, performance-critical paths with documented
  invariants)
- Every `unsafe` block must have a `// SAFETY:` comment explaining why the invariants are upheld
- Wrap unsafe code in safe abstractions — callers should never need to use `unsafe`
- Prefer safe alternatives: `std::mem::replace` over raw pointer manipulation, `crossbeam` over
  manual lock-free structures

**Macro rules**:

- Prefer generics and traits over macros where possible
- Use `macro_rules!` for simple pattern-based macros, procedural macros for complex code generation
- Macros must have comprehensive doc comments with usage examples
- Test macros with `cargo expand` to verify generated code

### testing-patterns

**Trigger description**: "This skill should be used when writing Rust tests, creating test fixtures,
benchmarks, property-based tests, or improving test coverage."

**Contents**:

- **Unit tests**: Place in `#[cfg(test)] mod tests` at the bottom of the source file. Use `#[test]`
  attribute. Has access to private items in the parent module
- **Integration tests**: Place in `tests/` directory at crate root. Each file is a separate test
  binary. Tests the public API only
- **Naming**: Test functions: `test_<function>_<scenario>` or `<function>_returns_<expected>`. Test
  modules: `tests` (unit), descriptive file names (integration)
- **Doc tests**: Write examples in doc comments with triple-backtick rust blocks. They compile and
  run as tests. Use `#` prefix to hide setup lines. Essential for library crates
- **proptest**: Use for property-based testing. Define strategies with `prop_compose!`. Test
  invariants rather than specific values. Use `ProptestConfig` for tuning iterations
- **criterion**: Use for benchmarks. Place in `benches/` directory. Use `criterion_group!` and
  `criterion_main!`. Compare before/after with `criterion compare`
- **mockall**: Use `#[automock]` on traits for mock generation. Set expectations with
  `.expect_method().returning(|args| result)`. Prefer real implementations over mocks where possible
- **Test fixtures**: Use builder pattern or `Default` trait for complex test data. Prefer
  constructing fixtures inline over shared mutable state
- **Async tests**: Use `#[tokio::test]` for async unit tests. Use
  `#[tokio::test(flavor = "multi_thread")]` when testing concurrent behavior
- **Conditional compilation**: Use `#[cfg(test)]` to include test-only code. Use
  `#[cfg(feature = "test-utils")]` for test utilities shared across crates

### cargo-conventions

**Trigger description**: "This skill should be used when creating or editing Cargo.toml, managing
Rust dependencies, configuring Cargo workspaces, or publishing crates."

**Contents**:

- **Cargo.toml structure**: `[package]` with name, version, edition, description, license.
  `[dependencies]` for runtime, `[dev-dependencies]` for test/bench. Use feature flags to gate
  optional dependencies
- **Lint configuration**: Use `[lints.clippy]` in Cargo.toml for lint levels. In workspaces, use
  `[workspace.lints]` and inherit with `[lints] workspace = true` in member crates. This is
  preferred over `clippy.toml` because it integrates with workspace inheritance and is the standard
  Rust ecosystem approach
- **Edition management**: Use edition 2021 minimum. Set `rust-version` field for MSRV (minimum
  supported Rust version). Test MSRV in CI
- **Workspace management**: Use `[workspace]` in root `Cargo.toml` for multi-crate projects.
  `[workspace.dependencies]` for shared dependency versions. `[workspace.lints]` for shared lint
  configuration
- **Feature flags**: Use `default = []` to keep defaults minimal. Use descriptive feature names.
  Document features in Cargo.toml comments and crate-level docs. Avoid feature creep. Be aware that
  features must be additive — mutually exclusive features cause `--all-features` failures and should
  be avoided in library crates
- **Dependency management**: Use caret ranges (`^1.2`) for flexibility. Pin exact versions only for
  stability-critical dependencies. Run `cargo update` periodically. Use `cargo deny` for license,
  advisory, duplicate, and source checks (preferred over `cargo audit` alone)
- **Publishing**: Include `description`, `license`, `repository`, `readme`, and `keywords` in
  `[package]`. Use `publish = false` for internal crates. Run `cargo publish --dry-run` before
  publishing
- **Profiles**: Configure `[profile.release]` with `lto = true`, `codegen-units = 1` for binary
  crates only. Library crates should not customize release profiles (consumers control their own).
  Use `[profile.dev]` with `opt-level = 1` for faster dev builds if needed. Custom profiles for
  benchmarking
- **Crates.io conventions**: Follow semver strictly. Use `CHANGELOG.md`. Tag releases with `v`
  prefix. Use `cargo release` for automated publishing workflow
