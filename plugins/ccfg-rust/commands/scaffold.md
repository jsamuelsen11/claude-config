---
description: >
  Initialize a new Rust project with opinionated production-ready defaults
argument-hint: '<project-name> [--type=service|library|cli]'
allowed-tools: 'Bash(cargo *), Bash(git *), Read, Write, Edit, Glob'
---

# Rust Project Scaffolding Command

You are executing the `scaffold` command to create a new Rust project with production-ready defaults
and best practices baked in from the start.

## Command Arguments

### Required: project-name

The name of the project (used as the crate name and directory name).

Examples:

```bash
ccfg-rust scaffold my-service
ccfg-rust scaffold inventory-api --type=service
ccfg-rust scaffold mathlib --type=library
ccfg-rust scaffold mytool --type=cli
```

#### Optional: --type

Project type determines the scaffold structure:

1. `service` (default) - axum + tokio HTTP service with health endpoint and graceful shutdown
1. `library` - Reusable library with doc comments, examples/, and `#![deny(missing_docs)]`
1. `cli` - Command-line tool with clap derive API

## Common Configuration

### Edition and Lints

All project types use edition 2021 and configure lints in Cargo.toml:

```toml
[package]
name = "project-name"
version = "0.1.0"
edition = "2021"

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"
```

### Rustfmt Configuration

All project types include a `rustfmt.toml`:

```toml
edition = "2021"
max_width = 100
use_field_init_shorthand = true
use_try_shorthand = true
```

### Gitignore

All project types include a `.gitignore`:

```text
/target
Cargo.lock
*.swp
*.swo
.env
.env.*
!.env.example
coverage/
*.profraw
```

Note: Libraries should gitignore `Cargo.lock` (it should not be committed for libraries). Services
and CLIs should commit `Cargo.lock`, so remove it from `.gitignore` for those types.

### Clippy Configuration

Clippy is configured via `[lints.clippy]` in Cargo.toml (not a separate file). This is the modern
approach since Rust 1.74.

## Project Layouts

### Service Layout

```text
project-name/
├── src/
│   ├── main.rs
│   ├── config.rs
│   ├── error.rs
│   ├── routes/
│   │   ├── mod.rs
│   │   └── health.rs
│   └── state.rs
├── tests/
│   └── health_test.rs
├── .gitignore
├── Cargo.toml
└── rustfmt.toml
```

#### Service Cargo.toml

```toml
[package]
name = "project-name"
version = "0.1.0"
edition = "2021"

[dependencies]
anyhow = "1"
axum = "0.8"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
tokio = { version = "1", features = ["full"] }
tower-http = { version = "0.6", features = ["cors", "trace"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

[dev-dependencies]
reqwest = { version = "0.12", features = ["json"] }
tokio = { version = "1", features = ["full", "test-util"] }

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[profile.release]
lto = true
codegen-units = 1
strip = true
```

#### Service main.rs

```rust
use anyhow::Result;
use std::sync::Arc;
use tokio::net::TcpListener;

mod config;
mod error;
mod routes;
mod state;

use config::Config;
use state::AppState;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let config = Config::from_env()?;
    let state = Arc::new(AppState::new(&config)?);

    let app = routes::router(state);

    let addr = format!("{}:{}", config.host, config.port);
    let listener = TcpListener::bind(&addr).await?;
    tracing::info!("listening on {addr}");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    tracing::info!("shutdown signal received");
}
```

#### Service config.rs

```rust
use anyhow::{Context, Result};

pub struct Config {
    pub host: String,
    pub port: u16,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        Ok(Self {
            host: std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".into()),
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "3000".into())
                .parse()
                .context("PORT must be a valid u16")?,
        })
    }
}
```

#### Service error.rs

```rust
use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("internal error: {0}")]
    Internal(String),
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = match &self {
            Self::NotFound(_) => StatusCode::NOT_FOUND,
            Self::BadRequest(_) => StatusCode::BAD_REQUEST,
            Self::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        };

        let body = ErrorResponse {
            error: self.to_string(),
        };

        (status, Json(body)).into_response()
    }
}
```

#### Service state.rs

```rust
use crate::config::Config;
use anyhow::Result;

pub struct AppState {
    // Add shared state fields here (db pool, cache, etc.)
}

impl AppState {
    pub fn new(_config: &Config) -> Result<Self> {
        Ok(Self {})
    }
}
```

#### Service routes/mod.rs

```rust
use axum::Router;
use std::sync::Arc;
use tower_http::trace::TraceLayer;

use crate::state::AppState;

pub mod health;

pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .merge(health::routes())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
```

#### Service routes/health.rs

```rust
use axum::{extract::State, http::StatusCode, routing::get, Json, Router};
use serde::Serialize;
use std::sync::Arc;

use crate::state::AppState;

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
}

pub fn routes() -> Router<Arc<AppState>> {
    Router::new()
        .route("/health", get(health))
        .route("/ready", get(ready))
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse { status: "ok" })
}

async fn ready(State(_state): State<Arc<AppState>>) -> StatusCode {
    // Add readiness checks here (database, cache, etc.)
    StatusCode::OK
}
```

#### Service Integration Test

```rust
// tests/health_test.rs

use axum::{body::Body, http::Request};
use tower::ServiceExt;

#[tokio::test]
async fn health_endpoint_returns_ok() {
    let state = std::sync::Arc::new(
        project_name::state::AppState::new(
            &project_name::config::Config::from_env().unwrap()
        ).unwrap()
    );
    let app = project_name::routes::router(state);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), 200);
}
```

### Library Layout

```text
project-name/
├── src/
│   └── lib.rs
├── examples/
│   └── basic.rs
├── tests/
│   └── integration_test.rs
├── .gitignore
├── Cargo.toml
└── rustfmt.toml
```

#### Library Cargo.toml

```toml
[package]
name = "project-name"
version = "0.1.0"
edition = "2021"
description = "A brief description of the library"
license = "MIT OR Apache-2.0"
repository = ""
readme = "README.md"
keywords = []
categories = []

[dependencies]
thiserror = "2"

[dev-dependencies]
proptest = "1"

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"
```

Note: Libraries do NOT get `[profile.release]` customization. That is the responsibility of the
consuming binary crate.

#### Library lib.rs

````rust
#![deny(missing_docs)]
#![doc = include_str!("../README.md")]

//! # project-name
//!
//! A brief description of the library.

/// Adds two numbers together.
///
/// # Examples
///
/// ```rust
/// use project_name::add;
///
/// assert_eq!(add(2, 3), 5);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_works() {
        assert_eq!(add(1, 2), 3);
    }
}
````

#### Library Example

```rust
// examples/basic.rs

use project_name::add;

fn main() {
    let result = add(40, 2);
    println!("40 + 2 = {result}");
}
```

### CLI Layout

```text
project-name/
├── src/
│   ├── main.rs
│   └── cli.rs
├── tests/
│   └── cli_test.rs
├── .gitignore
├── Cargo.toml
└── rustfmt.toml
```

#### CLI Cargo.toml

```toml
[package]
name = "project-name"
version = "0.1.0"
edition = "2021"

[dependencies]
anyhow = "1"
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

[dev-dependencies]
assert_cmd = "2"
predicates = "3"
tempfile = "3"

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"

[profile.release]
lto = true
codegen-units = 1
strip = true
```

#### CLI main.rs

```rust
use anyhow::Result;

mod cli;

use cli::Cli;
use clap::Parser;

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "warn".into()),
        )
        .init();

    let cli = Cli::parse();
    cli.run()
}
```

#### CLI cli.rs

```rust
use anyhow::Result;
use clap::{Parser, Subcommand};

/// A brief description of the CLI tool.
#[derive(Parser)]
#[command(version, about, long_about = None)]
pub struct Cli {
    /// Enable verbose output
    #[arg(short, long, global = true)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Run the main operation
    Run {
        /// Input file path
        #[arg(short, long)]
        input: String,

        /// Output file path (defaults to stdout)
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Show configuration
    Config,
}

impl Cli {
    pub fn run(&self) -> Result<()> {
        match &self.command {
            Commands::Run { input, output } => {
                tracing::info!(input = %input, "processing");
                // Implement main logic here
                if let Some(out) = output {
                    tracing::info!(output = %out, "writing output");
                }
                Ok(())
            }
            Commands::Config => {
                println!("Configuration:");
                // Show configuration
                Ok(())
            }
        }
    }
}
```

#### CLI Integration Test

```rust
// tests/cli_test.rs

use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn cli_prints_help() {
    Command::cargo_bin("project-name")
        .unwrap()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn cli_prints_version() {
    Command::cargo_bin("project-name")
        .unwrap()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains(env!("CARGO_PKG_VERSION")));
}
```

## Post-Scaffold Steps

### Initialize Git Repository

```bash
cd project-name
git init
git add .
git commit -m "chore: initial scaffold with ccfg-rust"
```

### Verify the Scaffold

After scaffolding, run a quick validation:

```bash
# Verify it compiles
cargo check

# Verify formatting
cargo fmt --all -- --check

# Run tests
cargo test

# Run clippy
cargo clippy --all-targets -- -D warnings
```

### Report Completion

After scaffolding, report:

1. Project type created (service, library, or cli)
1. Directory structure
1. Key files generated
1. Dependencies included
1. Next steps for the developer (add dependencies, implement logic, etc.)

## Customization Notes

### What NOT to Include

- No CI/CD files (that is project-specific)
- No Docker files (that is deployment-specific)
- No README.md (the developer should write their own)
- No LICENSE file (the developer should choose their own)
- No benchmarks (add when needed, not by default)

### Naming Conventions

- Project name becomes the crate name (hyphens converted to underscores in Rust identifiers)
- Module names use snake_case
- Files use snake_case
- Replace `project-name` and `project_name` placeholders with the actual project name
