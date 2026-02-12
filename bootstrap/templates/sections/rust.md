## Rust Conventions

- Toolchain: cargo (build/test), clippy (lint), rustfmt (format)
- Prefer `&str` over `String` in function parameters
- Use `thiserror` for library errors, `anyhow` for application errors
- Derive common traits: `Debug`, `Clone`, `PartialEq` where appropriate
- Prefer iterators and combinators over explicit loops
- Use `?` operator for error propagation (not `.unwrap()`)
- Test module: `#[cfg(test)] mod tests` in same file
- Document public items with `///` doc comments
