## C# Conventions

- Toolchain: dotnet CLI (build/test), dotnet format (style), xUnit (test)
- File-scoped namespaces (`namespace Foo;` not `namespace Foo { }`)
- Prefer records for immutable data types
- Use primary constructors (C# 12+) where appropriate
- Nullable reference types: `<Nullable>enable</Nullable>` always
- Async: return `Task<T>`, suffix methods with `Async`
- Test classes: `*Tests.cs`, methods: `[Fact]` or `[Theory]`
- Logging: `ILogger<T>` via dependency injection
