---
name: testing-patterns
description:
  This skill should be used when writing .NET tests, creating xUnit test fixtures, using
  NSubstitute, testing ASP.NET Core applications, or improving test coverage with FluentAssertions.
version: 0.1.0
---

# .NET Testing Patterns and Best Practices

This skill defines comprehensive testing patterns for .NET, covering xUnit conventions, NSubstitute
mocking, FluentAssertions, WebApplicationFactory, Testcontainers, and coverage standards.

## Arrange-Act-Assert Pattern

### Always Structure Tests with AAA

Every test must clearly separate setup, execution, and verification.

```csharp
// CORRECT: Clear AAA separation
[Fact]
public async Task GetByIdAsync_WhenProductExists_ReturnsProduct()
{
    // Arrange
    var productId = Guid.NewGuid();
    var product = CreateTestProduct(productId);
    _repository.FindByIdAsync(productId, Arg.Any<CancellationToken>())
        .Returns(product);

    // Act
    var result = await _sut.GetByIdAsync(productId, CancellationToken.None);

    // Assert
    result.Should().NotBeNull();
    result!.Name.Should().Be("Test Product");
}
```

```csharp
// WRONG: Mixed setup and assertions
[Fact]
public async Task GetByIdAsync_ReturnsProduct()
{
    var result = await _sut.GetByIdAsync(
        SetupRepositoryAndReturnId(), CancellationToken.None);
    Assert.NotNull(result);
    Assert.Equal("Test Product", result.Name);
    _repository.Received(1); // Verification mixed with assertions
}
```

## Test Naming Conventions

### Use MethodName_Condition_Expected Pattern

```csharp
// CORRECT: Descriptive, consistent naming
[Fact]
public async Task CreateAsync_WithValidRequest_ReturnsCreatedProduct() { }

[Fact]
public async Task CreateAsync_WithDuplicateSku_ThrowsDuplicateException() { }

[Fact]
public async Task DeleteAsync_WhenProductNotFound_ThrowsNotFoundException() { }

[Fact]
public async Task GetAllAsync_WithSearchTerm_ReturnsFilteredResults() { }
```

```csharp
// WRONG: Vague or inconsistent naming
[Fact]
public async Task TestCreate() { }

[Fact]
public async Task ShouldThrowWhenDuplicate() { }

[Fact]
public async Task Test_Delete_NotFound() { }

[Fact]
public async Task GetAll_Works() { }
```

## xUnit Conventions

### Use [Fact] for Tests Without Parameters

```csharp
// CORRECT: [Fact] for single-case tests
[Fact]
public void Constructor_WithNegativePrice_ThrowsArgumentOutOfRange()
{
    var act = () => new Money(-1, "USD");
    act.Should().Throw<ArgumentOutOfRangeException>();
}
```

### Use [Theory] with [InlineData] for Parameterized Tests

```csharp
// CORRECT: [Theory] with [InlineData] for multiple cases
[Theory]
[InlineData("", false)]
[InlineData("a", false)]
[InlineData("ab", false)]
[InlineData("abc", true)]
[InlineData("valid-slug", true)]
[InlineData("INVALID", false)]
[InlineData("has spaces", false)]
public void IsValidSlug_ReturnsExpected(string input, bool expected)
{
    var result = SlugValidator.IsValid(input);
    result.Should().Be(expected);
}
```

```csharp
// WRONG: Separate tests for each case
[Fact]
public void IsValidSlug_EmptyString_ReturnsFalse()
{
    SlugValidator.IsValid("").Should().BeFalse();
}

[Fact]
public void IsValidSlug_SingleChar_ReturnsFalse()
{
    SlugValidator.IsValid("a").Should().BeFalse();
}
// ...many more identical tests
```

### Use [MemberData] for Complex Parameters

```csharp
// CORRECT: [MemberData] for complex test data
[Theory]
[MemberData(nameof(ShippingTestCases))]
public void CalculateCost_ReturnsExpected(
    Order order, decimal expectedCost)
{
    var result = _sut.CalculateCost(order);
    result.Should().Be(expectedCost);
}

public static IEnumerable<object[]> ShippingTestCases()
{
    yield return [CreateDomesticOrder(weight: 0.5m), 5.99m];
    yield return [CreateDomesticOrder(weight: 3.0m), 9.99m];
    yield return [CreateInternationalOrder(weight: 1.5m), 24.99m];
}
```

### Use Constructor for Setup, IDisposable for Teardown

```csharp
// CORRECT: Constructor injection for setup
public class ProductServiceTests : IDisposable
{
    private readonly IProductRepository _repository;
    private readonly ILogger<ProductService> _logger;
    private readonly ProductService _sut;

    public ProductServiceTests()
    {
        _repository = Substitute.For<IProductRepository>();
        _logger = Substitute.For<ILogger<ProductService>>();
        _sut = new ProductService(_repository, _logger);
    }

    public void Dispose()
    {
        GC.SuppressFinalize(this);
    }
}
```

```csharp
// WRONG: Using [SetUp] (that is NUnit, not xUnit)
// xUnit creates a new instance per test, so constructor IS the setup
```

### Use IAsyncLifetime for Async Setup

```csharp
// CORRECT: IAsyncLifetime for async setup/teardown
public class IntegrationTests : IAsyncLifetime
{
    private HttpClient _client = null!;
    private WebApplicationFactory<Program> _factory = null!;

    public async Task InitializeAsync()
    {
        _factory = new WebApplicationFactory<Program>();
        _client = _factory.CreateClient();
        await SeedDatabaseAsync();
    }

    public async Task DisposeAsync()
    {
        _client.Dispose();
        await _factory.DisposeAsync();
    }
}
```

## NSubstitute Patterns

### Create Substitutes in Constructor

```csharp
// CORRECT: Substitutes created in constructor, SUT assembled from them
public class OrderServiceTests
{
    private readonly IOrderRepository _repository;
    private readonly IPaymentGateway _paymentGateway;
    private readonly OrderService _sut;

    public OrderServiceTests()
    {
        _repository = Substitute.For<IOrderRepository>();
        _paymentGateway = Substitute.For<IPaymentGateway>();
        _sut = new OrderService(_repository, _paymentGateway);
    }
}
```

```csharp
// WRONG: Creating mocks inline in each test
[Fact]
public async Task PlaceOrder_Succeeds()
{
    var repo = Substitute.For<IOrderRepository>();
    var payment = Substitute.For<IPaymentGateway>();
    var sut = new OrderService(repo, payment);
    // Every test recreates everything
}
```

### Use Returns for Stubbing

```csharp
// CORRECT: Returns for setting up return values
_repository.FindByIdAsync(productId, Arg.Any<CancellationToken>())
    .Returns(product);

// Async returns
_repository.FindByIdAsync(productId, Arg.Any<CancellationToken>())
    .Returns(Task.FromResult<Product?>(product));

// Conditional returns
_repository.FindByIdAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
    .Returns(callInfo =>
    {
        var id = callInfo.ArgAt<Guid>(0);
        return id == knownId ? product : null;
    });
```

### Use Received for Verification

```csharp
// CORRECT: Verify interactions after Act
await _repository.Received(1)
    .AddAsync(Arg.Is<Product>(p => p.Name == "Widget"),
        Arg.Any<CancellationToken>());

await _repository.DidNotReceive()
    .DeleteAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>());
```

```csharp
// WRONG: Verify before Act (test passes vacuously)
await _repository.Received(1).AddAsync(Arg.Any<Product>(), Arg.Any<CancellationToken>());
var result = await _sut.CreateAsync(request, CancellationToken.None);
```

### Use ThrowsAsync for Exception Stubbing

```csharp
// CORRECT: Throwing from async substitutes
_paymentGateway.ChargeAsync(Arg.Any<PaymentRequest>(), Arg.Any<CancellationToken>())
    .ThrowsAsync(new PaymentDeclinedException("Insufficient funds"));
```

```csharp
// WRONG: Returns(Task.FromException(...))
_paymentGateway.ChargeAsync(Arg.Any<PaymentRequest>(), Arg.Any<CancellationToken>())
    .Returns(Task.FromException<PaymentResult>(new PaymentDeclinedException("Insufficient funds")));
```

## FluentAssertions Patterns

### Use Should() for All Assertions

```csharp
// CORRECT: FluentAssertions
result.Should().NotBeNull();
result!.Name.Should().Be("Widget");
result.Price.Should().BeGreaterThan(0);
result.Tags.Should().Contain("electronics");
```

```csharp
// WRONG: xUnit Assert class
Assert.NotNull(result);
Assert.Equal("Widget", result.Name);
Assert.True(result.Price > 0);
Assert.Contains("electronics", result.Tags);
```

### Chain Assertions for Readability

```csharp
// CORRECT: Chained assertions on collections
products.Should()
    .NotBeEmpty()
    .And.HaveCount(3)
    .And.OnlyContain(p => p.Price > 0)
    .And.BeInAscendingOrder(p => p.Name);
```

```csharp
// WRONG: Separate assertion statements for related checks
products.Should().NotBeEmpty();
products.Should().HaveCount(3);
products.All(p => p.Price > 0).Should().BeTrue();
```

### Use BeEquivalentTo for Object Comparison

```csharp
// CORRECT: Structural comparison with exclusions
actual.Should().BeEquivalentTo(expected, options => options
    .Excluding(x => x.Id)
    .Excluding(x => x.CreatedAt)
    .WithStrictOrdering());
```

```csharp
// WRONG: Comparing each property individually
actual.Name.Should().Be(expected.Name);
actual.Price.Should().Be(expected.Price);
actual.Category.Should().Be(expected.Category);
// Easy to miss a property
```

### Use Invoking for Exception Assertions

```csharp
// CORRECT: FluentAssertions exception testing
await _sut.Invoking(s => s.DeleteAsync(id, CancellationToken.None))
    .Should().ThrowAsync<NotFoundException>()
    .WithMessage("*not found*");
```

```csharp
// WRONG: Try-catch in tests
try
{
    await _sut.DeleteAsync(id, CancellationToken.None);
    Assert.Fail("Should have thrown");
}
catch (NotFoundException ex)
{
    Assert.Contains("not found", ex.Message);
}
```

### Assert Time Ranges with BeCloseTo

```csharp
// CORRECT: Tolerant time assertion
result.CreatedAt.Should().BeCloseTo(
    DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
```

```csharp
// WRONG: Exact time comparison (flaky)
result.CreatedAt.Should().Be(DateTimeOffset.UtcNow);
```

## WebApplicationFactory Patterns

### Custom Factory with Service Overrides

```csharp
// CORRECT: Override services for integration tests
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove real DbContext
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor is not null) services.Remove(descriptor);

            // Add test DbContext
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("TestDb"));

            // Replace external services with substitutes
            services.AddSingleton(Substitute.For<IExternalApi>());
        });

        builder.UseEnvironment("Testing");
    }
}
```

```csharp
// WRONG: Testing against real external services
public class ApiFactory : WebApplicationFactory<Program>
{
    // No overrides - tests hit real database and external APIs
}
```

### Use IClassFixture for Shared Factory

```csharp
// CORRECT: Shared factory across tests in a class
public class ProductEndpointTests(ApiFactory factory)
    : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task GetProducts_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/products");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

```csharp
// WRONG: Creating a new factory per test (slow)
public class ProductEndpointTests
{
    [Fact]
    public async Task GetProducts_ReturnsOk()
    {
        await using var factory = new WebApplicationFactory<Program>();
        var client = factory.CreateClient();
        // Factory startup cost for every test
    }
}
```

## Testcontainers Patterns

### Use IAsyncLifetime for Container Management

```csharp
// CORRECT: Container managed via IAsyncLifetime
public class DatabaseFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }
}
```

### Share Containers with Collection Fixtures

```csharp
// CORRECT: Collection fixture shares one container across many test classes
[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture>;

[Collection("Database")]
public class ProductRepositoryTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task AddProduct_PersistsToDatabase()
    {
        await using var dbContext = fixture.CreateDbContext();
        // Test against real database
    }
}

[Collection("Database")]
public class CategoryRepositoryTests(DatabaseFixture fixture)
{
    // Shares the same container as ProductRepositoryTests
}
```

```csharp
// WRONG: Each test class starts its own container (very slow)
public class ProductRepositoryTests : IAsyncLifetime
{
    private MsSqlContainer _container = null!;

    public async Task InitializeAsync()
    {
        _container = new MsSqlBuilder().Build();
        await _container.StartAsync(); // 10+ seconds per test class
    }
}
```

## Test Data Creation

### Use Factory Methods for Test Data

```csharp
// CORRECT: Centralized test data factory
public static class TestDataFactory
{
    public static Product CreateProduct(
        string? name = null,
        decimal? price = null,
        ProductStatus? status = null) => new()
    {
        Id = new ProductId(Guid.NewGuid()),
        Name = name ?? $"Product-{Guid.NewGuid():N}"[..20],
        Price = price ?? 29.99m,
        Status = status ?? ProductStatus.Active,
        Sku = $"SKU-{Guid.NewGuid():N}"[..12],
        CategoryId = Guid.NewGuid(),
        CreatedAt = DateTimeOffset.UtcNow
    };
}
```

```csharp
// WRONG: Duplicated test data in every test
[Fact]
public async Task Test1()
{
    var product = new Product
    {
        Id = new ProductId(Guid.NewGuid()),
        Name = "Test",
        Price = 29.99m,
        Status = ProductStatus.Active,
        // 10 more properties...
    };
}

[Fact]
public async Task Test2()
{
    var product = new Product
    {
        // Same 10+ properties copied again...
    };
}
```

## Test Isolation

### Each Test Must Be Independent

```csharp
// CORRECT: Each test sets up its own state
[Fact]
public async Task AddProduct_PersistsToDatabase()
{
    await using var dbContext = fixture.CreateDbContext();
    var repository = new ProductRepository(dbContext);

    var product = TestDataFactory.CreateProduct(name: "Isolated Product");
    await repository.AddAsync(product);
    await dbContext.SaveChangesAsync();

    // Verify in a fresh context
    await using var verifyContext = fixture.CreateDbContext();
    var saved = await verifyContext.Products.FindAsync(product.Id);
    saved.Should().NotBeNull();
}
```

```csharp
// WRONG: Tests share state and depend on execution order
private static Product? _sharedProduct;

[Fact]
public async Task Test1_CreateProduct()
{
    _sharedProduct = await _sut.CreateAsync(request, CancellationToken.None);
    _sharedProduct.Should().NotBeNull();
}

[Fact]
public async Task Test2_UpdateProduct()
{
    // Depends on Test1 running first
    await _sut.UpdateAsync(_sharedProduct!.Id, updateRequest, CancellationToken.None);
}
```

## Coverage Standards

### Minimum Coverage by Layer

- **Domain models**: 95%+ (pure logic, easy to test)
- **Application services**: 90%+ (business rules, mock dependencies)
- **Infrastructure**: 70%+ (integration tests needed)
- **API endpoints**: 80%+ (WebApplicationFactory tests)

### What NOT to Test

- Auto-generated code (EF Core migrations, designer files)
- Pure DI registration methods (just `services.AddScoped`)
- Framework infrastructure (ASP.NET middleware pipeline configuration)
- Third-party library internals

### What to Always Test

- Business rules and domain logic
- Input validation
- Error handling and edge cases
- State transitions
- Boundary conditions (empty collections, max values, null inputs)
