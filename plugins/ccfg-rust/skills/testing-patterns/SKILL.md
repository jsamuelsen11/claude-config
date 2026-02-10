---
name: testing-patterns
description:
  This skill should be used when writing tests for Rust code, running cargo test, setting up test
  infrastructure, or reviewing test quality in Rust projects.
version: 0.1.0
---

# Rust Testing Patterns and Conventions

This skill defines comprehensive testing patterns for Rust projects, covering unit tests,
integration tests, doc tests, property-based testing, benchmarking, mocking, and async testing.

## Test Organization

### Unit Tests in #[cfg(test)] Modules

Unit tests live in the same file as the code they test, inside a `#[cfg(test)]` module at the bottom
of the file.

```rust
// CORRECT: Unit tests in the same file, cfg(test) gated
pub fn is_even(n: i32) -> bool {
    n % 2 == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn even_number_returns_true() {
        assert!(is_even(4));
    }

    #[test]
    fn odd_number_returns_false() {
        assert!(!is_even(3));
    }
}
```

```rust
// WRONG: Tests outside of cfg(test) - compiled into production binary
pub fn is_even(n: i32) -> bool {
    n % 2 == 0
}

#[test]
fn test_is_even() {
    assert!(is_even(4));
}
```

### Integration Tests in tests/ Directory

Integration tests go in the `tests/` directory at the crate root. They can only access the public
API.

```rust
// CORRECT: tests/user_service_test.rs
// Integration test accesses only the public API
use my_crate::UserService;

#[test]
fn creates_and_retrieves_user() {
    let service = UserService::new_in_memory();
    let user = service.create("Alice", "alice@test.com").unwrap();
    let found = service.find_by_id(&user.id).unwrap();
    assert_eq!(found.name, "Alice");
}
```

```rust
// WRONG: Integration test reaching into internals
use my_crate::internal::database::UserRepository; // should not be pub
```

### Shared Test Utilities

Put shared helpers in `tests/common/mod.rs` and import them from integration test files.

```rust
// CORRECT: tests/common/mod.rs
pub fn test_config() -> Config {
    Config {
        database_url: "sqlite::memory:".into(),
        log_level: "off".into(),
        ..Config::default()
    }
}

// tests/api_test.rs
mod common;

#[test]
fn api_responds_to_health_check() {
    let config = common::test_config();
    // ...
}
```

```rust
// WRONG: Duplicating setup in every test file
// tests/api_test.rs
fn test_config() -> Config { /* same code duplicated */ }

// tests/user_test.rs
fn test_config() -> Config { /* same code duplicated */ }
```

## Test Naming Conventions

### Descriptive Test Names

Test names should describe the scenario and expected outcome, not mirror the function name.

```rust
// CORRECT: Describes the behavior being tested
#[test]
fn parse_returns_error_on_empty_input() { /* ... */ }

#[test]
fn parse_handles_unicode_characters() { /* ... */ }

#[test]
fn cache_evicts_oldest_entry_when_full() { /* ... */ }
```

```rust
// WRONG: Mirrors function name without describing behavior
#[test]
fn test_parse() { /* ... */ }

#[test]
fn test_cache() { /* ... */ }
```

### Naming Pattern

Follow the pattern: `<unit>_<scenario>_<expected_result>` or `<scenario>_<expected_result>`.

```rust
// CORRECT: Clear pattern
#[test]
fn validate_email_rejects_missing_at_sign() { /* ... */ }

#[test]
fn empty_cart_has_zero_total() { /* ... */ }

#[test]
fn expired_token_returns_unauthorized() { /* ... */ }
```

## Doc Tests

### Every Public Function Gets a Doc Test

Doc tests serve as both documentation and tests. They are compiled and run by `cargo test`.

````rust
// CORRECT: Doc test shows usage and is executable
/// Clamps a value between a minimum and maximum.
///
/// # Examples
///
/// ```rust
/// use my_crate::clamp;
///
/// assert_eq!(clamp(5, 0, 10), 5);
/// assert_eq!(clamp(-1, 0, 10), 0);
/// assert_eq!(clamp(20, 0, 10), 10);
/// ```
pub fn clamp(value: i32, min: i32, max: i32) -> i32 {
    value.max(min).min(max)
}
````

```rust
// WRONG: Doc comment without an executable example
/// Clamps a value between a minimum and maximum.
pub fn clamp(value: i32, min: i32, max: i32) -> i32 {
    value.max(min).min(max)
}
```

### Doc Test Annotations

Use annotations to control doc test behavior:

````rust
/// Connects to the database (requires running PostgreSQL).
///
/// ```rust,no_run
/// # // no_run: compiles but does not execute
/// let db = Database::connect("postgres://localhost/test").unwrap();
/// ```
pub fn connect(url: &str) -> Result<Database, DbError> { /* ... */ }
````

````rust
/// This function panics on invalid input.
///
/// ```rust,should_panic
/// my_crate::divide(1, 0);
/// ```
pub fn divide(a: i32, b: i32) -> i32 { /* ... */ }
````

## Property-Based Testing with Proptest

### When to Use Proptest

Use proptest for:

- Functions with many valid inputs (parsers, serializers, math)
- Round-trip properties (serialize then deserialize equals original)
- Invariants that should hold for all inputs
- Finding edge cases humans would miss

```rust
// CORRECT: Property-based test for a round-trip invariant
#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn encode_decode_roundtrip(input in any::<Vec<u8>>()) {
            let encoded = base64_encode(&input);
            let decoded = base64_decode(&encoded).unwrap();
            prop_assert_eq!(input, decoded);
        }
    }
}
```

```rust
// WRONG: Only testing a few hand-picked inputs for a round-trip
#[cfg(test)]
mod tests {
    #[test]
    fn encode_decode_roundtrip() {
        assert_eq!(base64_decode(&base64_encode(b"hello")).unwrap(), b"hello");
        assert_eq!(base64_decode(&base64_encode(b"")).unwrap(), b"");
        // Missing: many edge cases that proptest would find
    }
}
```

### Custom Strategies

Define custom strategies for domain types:

```rust
// CORRECT: Strategy generates valid domain objects
#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    fn valid_port() -> impl Strategy<Value = u16> {
        1024_u16..=65535
    }

    fn valid_host() -> impl Strategy<Value = String> {
        "[a-z]{3,15}(\\.[a-z]{2,5}){1,3}"
    }

    prop_compose! {
        fn server_config()(
            host in valid_host(),
            port in valid_port(),
            max_conn in 1_usize..10000,
        ) -> ServerConfig {
            ServerConfig { host, port, max_connections: max_conn }
        }
    }

    proptest! {
        #[test]
        fn config_serialization_roundtrips(config in server_config()) {
            let json = serde_json::to_string(&config).unwrap();
            let parsed: ServerConfig = serde_json::from_str(&json).unwrap();
            prop_assert_eq!(config, parsed);
        }
    }
}
```

## Benchmarking with Criterion

### When to Write Benchmarks

Write benchmarks for:

- Performance-critical code paths
- Before and after optimization work
- Comparing algorithm implementations
- Regression detection

```rust
// CORRECT: Criterion benchmark with parameterized inputs
// benches/parser_bench.rs
use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use my_crate::parse;

fn bench_parse(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse");

    for size in [10, 100, 1000, 10000] {
        let input: String = (0..size).map(|i| format!("key{i}=value{i}\n")).collect();
        group.bench_with_input(
            BenchmarkId::from_parameter(size),
            &input,
            |b, input| {
                b.iter(|| parse(black_box(input)));
            },
        );
    }

    group.finish();
}

criterion_group!(benches, bench_parse);
criterion_main!(benches);
```

```rust
// WRONG: Using std::time for benchmarking (inaccurate, no statistical analysis)
#[test]
fn bench_parse() {
    let start = std::time::Instant::now();
    for _ in 0..1000 {
        parse("key=value\n");
    }
    println!("elapsed: {:?}", start.elapsed());
}
```

## Mocking with Mockall

### Mock External Boundaries Only

Mock traits that represent external dependencies (databases, HTTP clients, file systems), not
internal logic.

```rust
// CORRECT: Mock the external boundary (repository trait)
use mockall::automock;

#[automock]
pub trait OrderRepository {
    fn find_by_id(&self, id: &str) -> Result<Option<Order>, DbError>;
    fn save(&self, order: &Order) -> Result<(), DbError>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[test]
    fn cancel_order_sets_status_to_cancelled() {
        let mut mock = MockOrderRepository::new();

        mock.expect_find_by_id()
            .with(eq("order-1"))
            .returning(|_| Ok(Some(Order::new("order-1", Status::Pending))));

        mock.expect_save()
            .withf(|order| order.status == Status::Cancelled)
            .returning(|_| Ok(()));

        let service = OrderService::new(mock);
        service.cancel("order-1").unwrap();
    }
}
```

```rust
// WRONG: Mocking internal implementation details
#[automock]
trait StringFormatter {
    fn format(&self, input: &str) -> String;
}

// This is testing the mock, not the real code
```

### Verify Call Counts

Use `.times()` to assert that dependencies are called the expected number of times.

```rust
// CORRECT: Verify the save is called exactly once
#[test]
fn update_user_saves_once() {
    let mut mock = MockUserRepository::new();
    mock.expect_find_by_id().returning(|_| Ok(Some(test_user())));
    mock.expect_save()
        .times(1)  // Exactly once
        .returning(|_| Ok(()));

    let service = UserService::new(mock);
    service.update("user-1", "new-name").unwrap();
}
```

## Async Testing

### Use #[tokio::test] for Async Tests

```rust
// CORRECT: Async test with tokio
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn fetches_user_from_api() {
        let client = TestHttpClient::new();
        let user = fetch_user(&client, "user-1").await.unwrap();
        assert_eq!(user.name, "Alice");
    }
}
```

```rust
// WRONG: Manually creating a runtime
#[test]
fn fetches_user_from_api() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let user = fetch_user("user-1").await.unwrap();
        assert_eq!(user.name, "Alice");
    });
}
```

### Test Timeouts for Async Code

Use `tokio::time::timeout` to prevent tests from hanging indefinitely.

```rust
// CORRECT: Test has an explicit timeout
#[tokio::test]
async fn worker_processes_within_deadline() {
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(5),
        process_work_item(),
    )
    .await;

    assert!(result.is_ok(), "worker timed out after 5 seconds");
    assert!(result.unwrap().is_ok());
}
```

### Time Manipulation in Tests

Use `tokio::time::pause()` to control time in tests without real delays.

```rust
// CORRECT: Deterministic time-based tests
#[tokio::test]
async fn cache_expires_entries() {
    tokio::time::pause();

    let cache = TtlCache::new();
    cache.insert("key", "value", Duration::from_secs(60));

    assert!(cache.get("key").is_some());

    tokio::time::advance(Duration::from_secs(61)).await;

    assert!(cache.get("key").is_none());
}
```

## Test Fixtures

### Builder Pattern for Test Data

Use builders to create test data with sensible defaults that can be customized per test.

```rust
// CORRECT: Builder with defaults for test data
#[cfg(test)]
struct OrderBuilder {
    id: String,
    customer: String,
    items: Vec<Item>,
    status: Status,
}

#[cfg(test)]
impl Default for OrderBuilder {
    fn default() -> Self {
        Self {
            id: "order-001".into(),
            customer: "test-customer".into(),
            items: vec![Item::new("widget", 1, 999)],
            status: Status::Pending,
        }
    }
}

#[cfg(test)]
impl OrderBuilder {
    fn status(mut self, status: Status) -> Self {
        self.status = status;
        self
    }

    fn items(mut self, items: Vec<Item>) -> Self {
        self.items = items;
        self
    }

    fn build(self) -> Order {
        Order {
            id: self.id,
            customer: self.customer,
            items: self.items,
            status: self.status,
        }
    }
}
```

```rust
// WRONG: Constructing full objects manually in every test
#[test]
fn test_cancel() {
    let order = Order {
        id: "order-001".into(),
        customer: "test".into(),
        items: vec![Item::new("w", 1, 999)],
        status: Status::Pending,
        created_at: Utc::now(),
        updated_at: Utc::now(),
        shipping_address: None,
        billing_address: None,
        notes: String::new(),
    };
    // Every test repeats all these fields even if they are irrelevant
}
```

### Temporary Files and Directories

Use the `tempfile` crate for tests that need filesystem access.

```rust
// CORRECT: Temporary directory auto-cleaned on drop
#[test]
fn writes_and_reads_data() {
    let dir = tempfile::tempdir().unwrap();
    let file_path = dir.path().join("data.json");

    write_data(&file_path, &test_data()).unwrap();
    let loaded = read_data(&file_path).unwrap();

    assert_eq!(loaded, test_data());
    // dir is automatically cleaned up when it goes out of scope
}
```

```rust
// WRONG: Writing to a fixed path that may conflict with other tests
#[test]
fn writes_and_reads_data() {
    let path = "/tmp/test_data.json"; // May conflict with parallel tests
    write_data(path, &test_data()).unwrap();
    let loaded = read_data(path).unwrap();
    assert_eq!(loaded, test_data());
    std::fs::remove_file(path).unwrap(); // Manual cleanup, easy to forget
}
```

## Running Tests

### Common Cargo Test Commands

```bash
# Run all tests (unit + integration + doc)
cargo test

# Run tests matching a pattern
cargo test parse

# Run tests in a specific module
cargo test --lib service::tests

# Run only integration tests
cargo test --test integration_test

# Run only doc tests
cargo test --doc

# Run with output capture disabled (see println)
cargo test -- --nocapture

# Run ignored tests
cargo test -- --ignored

# Run tests in a single thread (for tests with shared state)
cargo test -- --test-threads=1
```
