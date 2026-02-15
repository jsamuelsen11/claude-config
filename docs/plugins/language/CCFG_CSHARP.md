# Plugin: ccfg-csharp

The C#/.NET language plugin. Provides framework agents for ASP.NET Core and Entity Framework,
specialist agents for testing and build tooling, project scaffolding, autonomous coverage
improvement, and opinionated conventions for consistent C# development with dotnet format, Roslyn
analyzers, xUnit, and Central Package Management.

## Directory Structure

```text
plugins/ccfg-csharp/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── csharp-developer.md
│   ├── aspnet-developer.md
│   ├── ef-core-specialist.md
│   ├── xunit-specialist.md
│   └── dotnet-build-engineer.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
└── skills/
    ├── csharp-conventions/
    │   └── SKILL.md
    ├── testing-patterns/
    │   └── SKILL.md
    └── project-conventions/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-csharp",
  "description": "C#/.NET language plugin: ASP.NET Core and EF Core agents, project scaffolding, coverage automation, and conventions for consistent development with dotnet format, Roslyn analyzers, xUnit, and Central Package Management",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["csharp", "dotnet", "aspnet", "efcore", "xunit", "nuget", "roslyn"],
  "suggestedPermissions": {
    "allow": ["Bash(dotnet:*)"]
  }
}
```

## Agents (5)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent                | Role                                                                                        | Model  |
| -------------------- | ------------------------------------------------------------------------------------------- | ------ |
| `csharp-developer`   | Modern C# 12+, records, pattern matching, nullable reference types, LINQ, async/await       | sonnet |
| `aspnet-developer`   | ASP.NET Core 8+, minimal APIs, controllers, middleware, auth, Blazor, SignalR               | sonnet |
| `ef-core-specialist` | Entity Framework Core, migrations, DbContext design, LINQ queries, performance optimization | sonnet |

### Specialist Agents

| Agent                   | Role                                                                                                                | Model  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------- | ------ |
| `xunit-specialist`      | xUnit, NSubstitute/Moq, FluentAssertions, Testcontainers, WebApplicationFactory, integration testing                | sonnet |
| `dotnet-build-engineer` | .csproj structure, NuGet, solution organization, Directory.Build.props, Central Package Management, MSBuild targets | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-csharp:validate

**Purpose**: Run the full C#/.NET quality gate suite in one command.

**Trigger**: User invokes before committing or shipping C# code.

**Allowed tools**: `Bash(dotnet *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Restore**: `dotnet restore` — ensure all NuGet packages are resolved
2. **Build**: `dotnet build --no-restore -warnaserror` — verify clean compilation with warnings as
   errors. Roslyn analyzers run as part of this step and are enforced via `-warnaserror`
3. **Format check**: `dotnet format --verify-no-changes --exclude obj/ --exclude Migrations/` —
   built-in formatter, excluding generated code directories
4. **Tests**: `dotnet test --no-build --verbosity normal`
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Build**: `dotnet build -warnaserror` (includes implicit restore; `-warnaserror` enforces
   analyzer diagnostics at near-zero extra cost)
2. Report pass/fail — skips tests and format check for speed, but still catches analyzer warnings

**Key rules**:

- `dotnet` CLI is the universal entry point — no wrapper scripts needed (unlike Maven/Gradle)
- Full mode runs explicit `dotnet restore` first, then uses `--no-restore` on subsequent steps for
  efficiency. This ensures validate works on a freshly cloned repo
- Quick mode omits `--no-restore` (allows implicit restore) since the user may not have restored
  recently. Quick mode still uses `-warnaserror` because analyzers run during build anyway and the
  flag has negligible performance cost
- `dotnet format` is the built-in formatter — no external tool required. Excludes `obj/` and
  `Migrations/` by default to avoid formatting generated code
- Roslyn analyzers are built into the SDK and configured via `.editorconfig` and
  `Directory.Build.props`. They are enforced as part of the build step, not as a separate gate
- Never suggest `#pragma warning disable` as a fix — fix the root cause. If suppression is genuinely
  necessary, require `#pragma warning disable <code> // reason` with the specific diagnostic code
  and explanation, at the narrowest scope. Never add bare `#pragma warning disable`
- Reports all gate results, not just the first failure
- Detect-and-skip: if custom analyzer packages are not configured, the build still runs with default
  SDK analyzers. Report custom analyzer configuration as detected or absent

### /ccfg-csharp:scaffold

**Purpose**: Initialize a new C#/.NET project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new C# project or service.

**Allowed tools**: `Bash(dotnet *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<project-name> [--type=webapi|library|worker|blazor]`

**Behavior**:

1. Create solution and project with `dotnet new`:

   ```text
   <name>/
   ├── src/
   │   └── <Name>/
   │       ├── <Name>.csproj
   │       ├── Program.cs
   │       └── Properties/
   │           └── launchSettings.json
   ├── tests/
   │   └── <Name>.Tests/
   │       ├── <Name>.Tests.csproj
   │       └── ExampleTest.cs
   ├── <Name>.sln
   ├── Directory.Build.props
   ├── Directory.Packages.props
   ├── .editorconfig
   ├── global.json
   ├── .gitignore
   └── README.md
   ```

2. Generate `Directory.Build.props` with:
   - `<Nullable>enable</Nullable>` for nullable reference types
   - `<ImplicitUsings>enable</ImplicitUsings>`
   - `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` for CI
   - Roslyn analyzer package references (Microsoft.CodeAnalysis.NetAnalyzers)
3. Generate `Directory.Packages.props` for Central Package Management:
   - Centralized version declarations for all NuGet packages
   - `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`
4. Generate `.editorconfig` with C# coding style rules and analyzer severity configuration
5. Generate `global.json` to pin SDK version
6. Scaffold differs by type:
   - `webapi`: adds ASP.NET Core minimal API skeleton, health endpoint, OpenAPI, program.cs with
     builder pattern
   - `library`: adds public API, XML doc comments, NuGet packaging config
   - `worker`: adds BackgroundService skeleton, hosted service registration
   - `blazor`: adds Blazor Server or WebAssembly template, component structure
7. Add test project with xUnit, NSubstitute, FluentAssertions, coverlet
8. Verify `dotnet test` passes

**Key rules**:

- Uses `src/` and `tests/` directory layout for solution organization
- Central Package Management via `Directory.Packages.props` from day one
- `Directory.Build.props` for shared project properties
- Nullable reference types always enabled
- `global.json` pins SDK version (like `.go-version` or `.python-version`)
- `.editorconfig` configures both formatting and analyzer rules

### /ccfg-csharp:coverage

**Purpose**: Autonomous per-project test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**: `Bash(dotnet *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**: `[--threshold=90] [--project=<path>] [--dry-run] [--no-commit]`

**Behavior**:

1. **Discover test projects**: Find test projects by scanning `.csproj` files for
   `<IsTestProject>true</IsTestProject>` or test framework package references (xUnit, NUnit,
   MSTest). Do not assume a specific directory naming convention — test projects may be named
   `*.Tests`, `*.UnitTests`, `*.IntegrationTests`, or placed in `test/` (lowercase) or `tests/`
2. **Measure**: Run `dotnet test --collect:"XPlat Code Coverage" --results-directory ./TestResults`
   (coverlet built into test SDK, `--results-directory` controls output location for deterministic
   discovery)
3. **Identify**: Discover Cobertura XML reports via `**/coverage.cobertura.xml` glob under
   `./TestResults/`. If multiple test projects produce reports, merge by iterating over all reports.
   Rank classes by uncovered lines (most gaps first)
4. **Target**: For each under-threshold class: a. Read the source class and existing tests b.
   Identify untested methods, branches, and edge cases c. Write targeted tests following project's
   existing test patterns d. Run `dotnet test` to confirm new tests pass e. Run
   `dotnet build -warnaserror` to verify no warnings f. Commit:
   `git add <test-file> && git commit -m "test: add coverage for <class>"`
5. **Report**: Summary table of before/after coverage per class
6. **Clean up**: Remove `./TestResults/` directory created during coverage measurement
7. Stop when threshold reached or all classes processed

**Modes**:

- **Default**: Write tests and auto-commit after each class
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Discovers test projects by `.csproj` metadata, not directory naming conventions. Supports xUnit,
  NUnit, and MSTest test projects
- Uses `--results-directory` for deterministic coverage report location, avoiding GUID-based
  `TestResults/` subdirectories scattered across projects
- Uses glob discovery (`**/coverage.cobertura.xml`) for robust report finding across arbitrary
  solution layouts
- Reads existing tests first to match project patterns (xUnit conventions, FluentAssertions style,
  NSubstitute vs Moq usage)
- One commit per class (not one giant commit)
- Tests must exercise real behavior with meaningful assertions
- Uses FluentAssertions fluent style, not raw `Assert.Equal`
- Uses `WebApplicationFactory<T>` for integration testing ASP.NET Core endpoints
- Coverage via coverlet (bundled with `dotnet test`), output as Cobertura XML for parsing
- Cleans up `TestResults/` directory after completion

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### csharp-conventions

**Trigger description**: "This skill should be used when working on C#/.NET projects, writing C#
code, configuring ASP.NET Core, using Entity Framework, or reviewing C# code."

**Existing repo compatibility**: For existing projects, respect the established patterns, framework
version, and conventions. If the project uses Moq instead of NSubstitute, follow it. If the project
uses controllers instead of minimal APIs, follow that pattern. If the project uses NUnit or MSTest
instead of xUnit, follow the established test framework. These preferences apply to new projects and
scaffold output only.

**Modern C# rules**:

- Use C# 12+ features: primary constructors, collection expressions, `required` members, raw string
  literals
- Use records for DTOs and value objects. Use `record struct` for small value types
- Use pattern matching extensively: `is`, `switch` expressions, property patterns, list patterns
- Use nullable reference types (`<Nullable>enable</Nullable>`) in all projects. Never suppress with
  `!` (null-forgiving operator) without a comment explaining why
- Use `init` properties for immutable objects. Use `required` for mandatory initialization
- Use `file`-scoped namespaces (single `namespace Foo;` per file, not `namespace Foo { }`)
- Use `global using` directives in a dedicated `GlobalUsings.cs` for commonly used namespaces

**Async/await rules**:

- Use `async`/`await` throughout — never block on async code with `.Result` or `.Wait()`
- Use `CancellationToken` for all async operations that support it
- Return `Task` or `ValueTask`, never `async void` (except event handlers)
- Use `ConfigureAwait(false)` in library code, omit in ASP.NET Core (no sync context)
- Prefer `ValueTask` over `Task` for hot paths that often complete synchronously

**LINQ rules**:

- Use LINQ method syntax for simple queries, query syntax for complex joins
- Never use LINQ in tight loops — materialize collections with `.ToList()` or `.ToArray()` when
  appropriate
- Use `FirstOrDefault` with null checks, never `First` unless the collection is guaranteed non-empty
- Prefer `Any()` over `Count() > 0` for existence checks

**DI rules**:

- Use constructor injection exclusively. Never use service locator pattern
- Register services with the most restrictive lifetime: `AddTransient` > `AddScoped` >
  `AddSingleton`
- Use `IOptions<T>` pattern for configuration binding
- Define interfaces for services that need to be mocked in tests

**Naming rules**:

- PascalCase for types, methods, properties, events. camelCase for parameters and local variables
- `I` prefix for interfaces (`IRepository`, `ILogger`). No prefix for abstract classes
- `Async` suffix for async methods (`GetUsersAsync`, `SaveChangesAsync`)
- `_camelCase` for private fields (with underscore prefix)

**Warning suppression rules**:

- Fix the root cause when possible. When `#pragma warning disable` is genuinely necessary:
  - Use the specific diagnostic code: `#pragma warning disable CA1062 // reason`, not bare
    `#pragma warning disable`
  - Restore immediately after: `#pragma warning restore CA1062`
  - Apply to the narrowest scope possible (around specific lines, not entire files)
  - Include a comment explaining why the suppression is necessary
- `[SuppressMessage]` attribute is acceptable for method/class-level suppression when it reads
  better than pragma pairs. Always include `Justification`

### testing-patterns

**Trigger description**: "This skill should be used when writing C# tests, creating xUnit test
fixtures, using FluentAssertions, mocking with NSubstitute, or improving test coverage."

**Contents**:

- **xUnit conventions**: Use `[Fact]` for single-case tests, `[Theory]` with `[InlineData]` for
  parameterized tests. Use `[MemberData]` or `[ClassData]` for complex test data. Constructor
  injection for test fixtures via `IClassFixture<T>`
- **NUnit conventions**: If the project uses NUnit, follow its patterns: `[Test]` for single tests,
  `[TestCase]` for parameterized, `[SetUp]`/`[TearDown]` for lifecycle, `Assert.That` with
  constraint model
- **MSTest conventions**: If the project uses MSTest, follow its patterns: `[TestMethod]`,
  `[DataRow]` for parameterized, `[TestInitialize]`/`[TestCleanup]` for lifecycle
- **Naming**: Test classes: `<Class>Tests.cs`. Test methods:
  `<Method>_Should<Expected>_When<Condition>()`. Use descriptive names that document behavior
- **Arrange-Act-Assert**: Follow AAA pattern strictly. Separate sections with blank lines and
  `// Arrange`, `// Act`, `// Assert` comments for complex tests
- **FluentAssertions**: Use `actual.Should().Be(expected)` fluent style. Use
  `actual.Should().BeEquivalentTo(expected)` for deep comparison. Use `act.Should().Throw<T>()` for
  exception assertions
- **NSubstitute**: Use `Substitute.For<IService>()` for mock creation. Use `.Returns()` for
  stubbing, `.Received()` for verification. Prefer NSubstitute over Moq for new projects (cleaner
  syntax, no lambda expressions for setup)
- **WebApplicationFactory**: Use for integration testing ASP.NET Core endpoints. Override
  `ConfigureWebHost` for test-specific service registration. Use `HttpClient` from factory for API
  calls
- **Testcontainers**: Use for integration tests requiring real databases. Use
  `Testcontainers.MsSql`, `Testcontainers.PostgreSql` etc. Manage container lifecycle with
  `IAsyncLifetime`
- **Test project structure**: One test project per source project is the default convention. Mirror
  source project namespace structure. Share test utilities via a `TestUtilities` project in the
  `tests/` directory. However, some projects use a single test project or split into `*.UnitTests`
  and `*.IntegrationTests` — follow the project's established pattern
- **Coverage**: Target 90%+ line coverage. Exclude generated code, DTOs, and auto-properties from
  coverage with `[ExcludeFromCodeCoverage]` attribute only when justified

### project-conventions

**Trigger description**: "This skill should be used when creating or editing .csproj files, managing
NuGet packages, configuring solution structure, or setting up Directory.Build.props."

**Contents**:

- **.csproj structure**: Use SDK-style project format. Minimize `.csproj` content — use
  `Directory.Build.props` for shared properties. Avoid `<ItemGroup>` clutter with globbing patterns
  (default in SDK-style)
- **Central Package Management**: Use `Directory.Packages.props` at solution root with
  `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`. Individual `.csproj`
  files reference packages without versions. Eliminates version conflicts across projects. For
  existing projects not using CPM, do not recommend migration as a default action — it requires
  touching every `.csproj` and is a significant change. Acknowledge version pinning directly in
  `.csproj` as the established pattern for non-CPM projects
- **Directory.Build.props**: Shared properties at solution root: `<TargetFramework>`,
  `<Nullable>enable</Nullable>`, `<ImplicitUsings>enable</ImplicitUsings>`,
  `<TreatWarningsAsErrors>`, analyzer packages. Avoid deep nesting of `Directory.Build.props` files.
  Must be at or above the solution root to be discovered by all projects
- **Solution organization**: `src/` for production code, `tests/` for test projects. Use solution
  folders to group related projects. Keep solution file at repository root
- **global.json**: Pin SDK version for reproducible builds. Use `rollForward` policy for flexibility
  (`latestFeature` for apps, `disable` for libraries)
- **NuGet publishing**: Include `<PackageId>`, `<Description>`, `<Authors>`,
  `<PackageLicenseExpression>`, `<PackageReadmeFile>`, `<RepositoryUrl>` in `.csproj`. Use
  `dotnet pack` for package creation. Use `<IsPackable>false</IsPackable>` for non-publishable
  projects
- **.editorconfig**: Configure both IDE formatting rules and Roslyn analyzer severity levels. Use
  `dotnet_diagnostic.<rule>.severity = warning|error` for analyzer rules. Commit to repository for
  consistent team settings
- **Target framework**: Use latest LTS (`net8.0`). Specify `<TargetFramework>` in
  `Directory.Build.props` for solution-wide consistency. Multi-target only when publishing libraries
  that need broad compatibility
