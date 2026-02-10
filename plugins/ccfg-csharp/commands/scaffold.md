---
description:
  Initialize a new .NET project with xUnit, NSubstitute, FluentAssertions, and quality tooling
argument-hint: '<project-name> [--type=webapi|library|worker|blazor]'
allowed-tools: Bash(dotnet *), Bash(git *), Read, Write, Edit, Glob
---

# .NET Project Scaffolding Command

You are executing the `scaffold` command to create a new .NET project with production-ready
defaults, comprehensive quality tooling, and best practices baked in from the start.

## Command Arguments

### Required: project-name

The name of the project to create. This becomes the root directory name and influences the
namespace. It should follow .NET conventions: PascalCase or hyphen-separated.

Examples:

```bash
ccfg csharp scaffold catalog-service
ccfg csharp scaffold CatalogService --type=webapi
ccfg csharp scaffold Acme.Shared.Contracts --type=library
ccfg csharp scaffold order-processor --type=worker
ccfg csharp scaffold product-dashboard --type=blazor
```

### Optional: --type

Project type determines the scaffold structure:

1. `webapi` (default) - ASP.NET Core minimal API with health checks and OpenAPI
2. `library` - Class library with NuGet packaging configuration
3. `worker` - BackgroundService with hosted service pattern
4. `blazor` - Blazor Web App with interactive server rendering

## Project Layouts

### Web API Layout

```text
catalog-service/
├── src/
│   ├── Catalog.Api/
│   │   ├── Catalog.Api.csproj
│   │   ├── Program.cs
│   │   ├── Endpoints/
│   │   │   └── HealthEndpoints.cs
│   │   ├── Middleware/
│   │   │   └── GlobalExceptionHandler.cs
│   │   └── Configuration/
│   │       └── ServiceCollectionExtensions.cs
│   ├── Catalog.Application/
│   │   ├── Catalog.Application.csproj
│   │   ├── Services/
│   │   └── Models/
│   ├── Catalog.Domain/
│   │   ├── Catalog.Domain.csproj
│   │   ├── Models/
│   │   └── Interfaces/
│   └── Catalog.Infrastructure/
│       ├── Catalog.Infrastructure.csproj
│       └── Data/
├── tests/
│   ├── Directory.Build.props
│   ├── Catalog.Application.Tests/
│   │   ├── Catalog.Application.Tests.csproj
│   │   └── Services/
│   └── Catalog.Api.Tests/
│       ├── Catalog.Api.Tests.csproj
│       └── Endpoints/
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── .editorconfig
├── .gitignore
├── CatalogService.sln
└── README.md
```

#### Library Layout

```text
acme-shared-contracts/
├── src/
│   └── Acme.Shared.Contracts/
│       ├── Acme.Shared.Contracts.csproj
│       ├── Models/
│       │   └── ApiResponse.cs
│       └── Extensions/
│           └── StringExtensions.cs
├── tests/
│   ├── Directory.Build.props
│   └── Acme.Shared.Contracts.Tests/
│       ├── Acme.Shared.Contracts.Tests.csproj
│       └── Models/
│           └── ApiResponseTests.cs
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── .editorconfig
├── .gitignore
├── AcmeSharedContracts.sln
└── README.md
```

#### Worker Layout

```text
order-processor/
├── src/
│   └── OrderProcessor/
│       ├── OrderProcessor.csproj
│       ├── Program.cs
│       ├── Workers/
│       │   └── OrderProcessingWorker.cs
│       └── Services/
│           └── OrderProcessingService.cs
├── tests/
│   ├── Directory.Build.props
│   └── OrderProcessor.Tests/
│       ├── OrderProcessor.Tests.csproj
│       └── Workers/
│           └── OrderProcessingWorkerTests.cs
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── .editorconfig
├── .gitignore
├── OrderProcessor.sln
└── README.md
```

#### Blazor Layout

```text
product-dashboard/
├── src/
│   └── ProductDashboard/
│       ├── ProductDashboard.csproj
│       ├── Program.cs
│       ├── Components/
│       │   ├── App.razor
│       │   ├── Routes.razor
│       │   ├── Layout/
│       │   │   ├── MainLayout.razor
│       │   │   └── NavMenu.razor
│       │   └── Pages/
│       │       ├── Home.razor
│       │       └── Products.razor
│       └── Services/
│           └── ProductService.cs
├── tests/
│   ├── Directory.Build.props
│   └── ProductDashboard.Tests/
│       ├── ProductDashboard.Tests.csproj
│       └── Components/
├── Directory.Build.props
├── Directory.Packages.props
├── global.json
├── .editorconfig
├── .gitignore
├── ProductDashboard.sln
└── README.md
```

## Scaffold Step-by-Step

### Step 1: Create Directory Structure

Create the root directory and all subdirectories.

```bash
# Create root
mkdir -p catalog-service

# Create src directories
mkdir -p catalog-service/src/Catalog.Api/{Endpoints,Middleware,Configuration}
mkdir -p catalog-service/src/Catalog.Application/{Services,Models}
mkdir -p catalog-service/src/Catalog.Domain/{Models,Interfaces}
mkdir -p catalog-service/src/Catalog.Infrastructure/Data

# Create test directories
mkdir -p catalog-service/tests/Catalog.Application.Tests/Services
mkdir -p catalog-service/tests/Catalog.Api.Tests/Endpoints
```

### Step 2: Create global.json

Pin the .NET SDK version for reproducible builds.

```json
{
  "sdk": {
    "version": "8.0.404",
    "rollForward": "latestPatch",
    "allowPrerelease": false
  }
}
```

Detect the installed SDK version first:

```bash
dotnet --version
```

Use the detected version in `global.json`.

### Step 3: Create Directory.Build.props

Write the root-level shared build properties.

```xml
<Project>

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <LangVersion>latest</LangVersion>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <Deterministic>true</Deterministic>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Meziantou.Analyzer" PrivateAssets="all" />
    <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" PrivateAssets="all" />
  </ItemGroup>

</Project>
```

### Step 4: Create Test-Specific Directory.Build.props

Write `tests/Directory.Build.props` to share test dependencies across all test projects.

```xml
<Project>

  <Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" />

  <PropertyGroup>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
    <NoWarn>$(NoWarn);CA1707</NoWarn>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" />
    <PackageReference Include="FluentAssertions" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="NSubstitute" />
    <PackageReference Include="NSubstitute.Analyzers.CSharp" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="FluentAssertions" />
    <Using Include="NSubstitute" />
    <Using Include="Xunit" />
  </ItemGroup>

</Project>
```

### Step 5: Create Directory.Packages.props

Central Package Management from day one. All versions are declared here and nowhere else.

```xml
<Project>

  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>
  </PropertyGroup>

  <!-- Analyzers -->
  <ItemGroup>
    <PackageVersion Include="Meziantou.Analyzer" Version="2.0.182" />
    <PackageVersion Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="8.0.0" />
  </ItemGroup>

  <!-- Testing -->
  <ItemGroup>
    <PackageVersion Include="coverlet.collector" Version="6.0.2" />
    <PackageVersion Include="FluentAssertions" Version="6.12.2" />
    <PackageVersion Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
    <PackageVersion Include="NSubstitute" Version="5.3.0" />
    <PackageVersion Include="NSubstitute.Analyzers.CSharp" Version="1.0.17" />
    <PackageVersion Include="xunit" Version="2.9.2" />
    <PackageVersion Include="xunit.runner.visualstudio" Version="2.8.2" />
  </ItemGroup>

</Project>
```

Additional packages are added per project type. For `webapi`, add:

```xml
  <!-- ASP.NET Core -->
  <ItemGroup>
    <PackageVersion Include="Swashbuckle.AspNetCore" Version="6.9.0" />
    <PackageVersion Include="Serilog.AspNetCore" Version="8.0.3" />
    <PackageVersion Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.11" />
  </ItemGroup>
```

For `library`, add:

```xml
  <!-- NuGet packaging -->
  <ItemGroup>
    <PackageVersion Include="Microsoft.SourceLink.GitHub" Version="8.0.0" />
  </ItemGroup>
```

For `worker`, add:

```xml
  <!-- Worker hosting -->
  <ItemGroup>
    <PackageVersion Include="Microsoft.Extensions.Hosting" Version="8.0.1" />
    <PackageVersion Include="Serilog.AspNetCore" Version="8.0.3" />
  </ItemGroup>
```

### Step 6: Create .editorconfig

Write a comprehensive `.editorconfig` with C# conventions. Include at minimum:

- `root = true`
- Indentation: 4 spaces for C#, 2 for XML/JSON
- File-scoped namespaces enforced
- `var` preferences
- Naming conventions (PascalCase types, \_camelCase private fields, IPrefix interfaces)
- Analyzer severity overrides
- New line preferences (Allman style braces)

### Step 7: Create .gitignore

Write a standard .NET `.gitignore` covering:

- `bin/`, `obj/`, `TestResults/`
- `.vs/`, `.idea/`
- `*.user`, `*.suo`
- `launchSettings.json`
- NuGet packages

### Step 8: Create Project Files

#### Web API Project (Catalog.Api.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <RootNamespace>Catalog.Api</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\Catalog.Application\Catalog.Application.csproj" />
    <ProjectReference Include="..\Catalog.Infrastructure\Catalog.Infrastructure.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Swashbuckle.AspNetCore" />
  </ItemGroup>

</Project>
```

Notice: no `<TargetFramework>`, `<Nullable>`, or `<ImplicitUsings>` because they come from
`Directory.Build.props`. No `Version` on `PackageReference` because it comes from
`Directory.Packages.props`.

#### Application Layer (Catalog.Application.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <RootNamespace>Catalog.Application</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\Catalog.Domain\Catalog.Domain.csproj" />
  </ItemGroup>

</Project>
```

#### Domain Layer (Catalog.Domain.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <RootNamespace>Catalog.Domain</RootNamespace>
  </PropertyGroup>

</Project>
```

#### Infrastructure Layer (Catalog.Infrastructure.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <RootNamespace>Catalog.Infrastructure</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\Catalog.Application\Catalog.Application.csproj" />
  </ItemGroup>

</Project>
```

#### Unit Test Project (Catalog.Application.Tests.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <ItemGroup>
    <ProjectReference Include="..\..\src\Catalog.Application\Catalog.Application.csproj" />
  </ItemGroup>

</Project>
```

Test projects inherit everything from `tests/Directory.Build.props`, so they are minimal.

#### Integration Test Project (Catalog.Api.Tests.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <ItemGroup>
    <ProjectReference Include="..\..\src\Catalog.Api\Catalog.Api.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" />
  </ItemGroup>

</Project>
```

### Step 9: Create Source Files

#### Program.cs for Web API

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddProblemDetails();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseExceptionHandler();
app.UseHttpsRedirection();

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }))
    .WithName("HealthCheck")
    .WithTags("Health");

app.Run();

public partial class Program;
```

#### Program.cs for Worker

```csharp
using OrderProcessor;
using OrderProcessor.Workers;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddHostedService<OrderProcessingWorker>();

var host = builder.Build();
host.Run();
```

#### Program.cs for Blazor

```csharp
using ProductDashboard.Components;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
```

#### Sample Test File

```csharp
namespace Catalog.Application.Tests.Services;

public class SampleServiceTests
{
    [Fact]
    public void SampleTest_ShouldPass()
    {
        // Arrange
        var expected = 42;

        // Act
        var actual = 42;

        // Assert
        actual.Should().Be(expected);
    }
}
```

### Step 10: Create Solution and Link Projects

```bash
cd catalog-service

# Create solution
dotnet new sln --name CatalogService

# Add source projects
dotnet sln add src/Catalog.Api/Catalog.Api.csproj
dotnet sln add src/Catalog.Application/Catalog.Application.csproj
dotnet sln add src/Catalog.Domain/Catalog.Domain.csproj
dotnet sln add src/Catalog.Infrastructure/Catalog.Infrastructure.csproj

# Add test projects
dotnet sln add tests/Catalog.Application.Tests/Catalog.Application.Tests.csproj
dotnet sln add tests/Catalog.Api.Tests/Catalog.Api.Tests.csproj
```

### Step 11: Verify the Scaffold

Run the validation suite to confirm the scaffold is correct:

```bash
# Restore
dotnet restore

# Build with warnings as errors
dotnet build -warnaserror

# Run tests
dotnet test --no-build
```

All three commands must pass before the scaffold is considered complete.

## Library-Specific Configuration

### NuGet Package Properties

For `--type=library`, add NuGet packaging metadata to the main `.csproj`:

```xml
<PropertyGroup>
    <PackageId>Acme.Shared.Contracts</PackageId>
    <Version>0.1.0</Version>
    <Description>Shared contracts and DTOs</Description>
    <PackageTags>acme;contracts</PackageTags>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <EmbedUntrackedSources>true</EmbedUntrackedSources>
</PropertyGroup>
```

### Multi-Target Framework for Libraries

Libraries may need to target multiple frameworks for broader compatibility:

```xml
<PropertyGroup>
    <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
</PropertyGroup>
```

## Worker-Specific Configuration

### BackgroundService Template

```csharp
namespace OrderProcessor.Workers;

public class OrderProcessingWorker(
    ILogger<OrderProcessingWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Order processing worker starting");

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(30));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                logger.LogDebug("Processing orders...");
                // Process orders here
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error processing orders");
            }
        }

        logger.LogInformation("Order processing worker stopping");
    }
}
```

## Post-Scaffold Checklist

After the scaffold is complete, verify:

1. `dotnet restore` succeeds
2. `dotnet build -warnaserror` succeeds with zero warnings
3. `dotnet test` succeeds (sample test passes)
4. `dotnet format --verify-no-changes --exclude obj/` succeeds
5. `Directory.Build.props` sets `TreatWarningsAsErrors` and `Nullable`
6. `Directory.Packages.props` has `ManagePackageVersionsCentrally` enabled
7. `global.json` pins the SDK version
8. `.editorconfig` exists with C# conventions
9. `.gitignore` covers .NET build artifacts
10. No `Version` attributes on any `PackageReference` in `.csproj` files (CPM enforced)

## Naming Conventions

### Project Naming

Derive the namespace and solution name from the project name:

- `catalog-service` -> Namespace prefix: `Catalog`, Solution: `CatalogService.sln`
- `order-processor` -> Namespace prefix: `OrderProcessor`, Solution: `OrderProcessor.sln`
- `Acme.Shared.Contracts` -> Namespace prefix: `Acme.Shared.Contracts`, Solution:
  `AcmeSharedContracts.sln`

### Namespace Structure

For `webapi` type with project name `catalog-service`:

- `Catalog.Api` - Web layer
- `Catalog.Application` - Business logic
- `Catalog.Domain` - Domain models and interfaces
- `Catalog.Infrastructure` - External concerns
- `Catalog.Application.Tests` - Unit tests
- `Catalog.Api.Tests` - Integration tests

For `library` type with project name `acme-shared-contracts`:

- `Acme.Shared.Contracts` - Library
- `Acme.Shared.Contracts.Tests` - Tests

For `worker` type with project name `order-processor`:

- `OrderProcessor` - Worker
- `OrderProcessor.Tests` - Tests
