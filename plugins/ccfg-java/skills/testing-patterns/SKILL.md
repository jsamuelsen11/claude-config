---
name: testing-patterns
description:
  This skill should be used when writing Java tests, creating JUnit 5 test fixtures, using Mockito,
  testing Spring Boot applications, or improving test coverage.
version: 0.1.0
---

# Java Testing Patterns and Best Practices

This skill defines comprehensive testing patterns for Java, covering JUnit 5 lifecycle, Mockito
mocking, Spring Boot test slices, Testcontainers, ArchUnit, and coverage standards.

## JUnit 5 Lifecycle

### Use @BeforeEach for Test Setup

Use @BeforeEach for per-test setup and @AfterEach for cleanup. Avoid @BeforeAll unless expensive
setup is shared safely.

```java
// CORRECT: @BeforeEach for per-test setup
class OrderServiceTest {

    private OrderRepository repository;
    private OrderService service;

    @BeforeEach
    void setUp() {
        repository = new InMemoryOrderRepository();
        service = new OrderService(repository);
    }

    @AfterEach
    void tearDown() {
        repository.clear();
    }

    @Test
    void shouldCreateOrder() {
        var request = new OrderRequest("product-1", 2);
        var order = service.createOrder(request);

        assertThat(order.productId()).isEqualTo("product-1");
        assertThat(order.quantity()).isEqualTo(2);
    }
}
```

```java
// WRONG: Shared mutable state without proper setup
class OrderServiceTest {

    // Shared state leads to flaky tests
    private final OrderRepository repository = new InMemoryOrderRepository();
    private final OrderService service = new OrderService(repository);

    @Test
    void shouldCreateOrder() {
        // Previous test data leaks into this test
        var order = service.createOrder(new OrderRequest("product-1", 2));
        assertThat(order.productId()).isEqualTo("product-1");
    }
}
```

#### Use @BeforeAll for Expensive Shared Resources

Use @BeforeAll only for truly expensive, immutable setup like database containers.

```java
// CORRECT: @BeforeAll for expensive, shared, immutable setup
class DatabaseIntegrationTest {

    private static PostgreSQLContainer<?> postgres;

    @BeforeAll
    static void startContainer() {
        postgres = new PostgreSQLContainer<>("postgres:16-alpine");
        postgres.start();
    }

    @AfterAll
    static void stopContainer() {
        postgres.stop();
    }

    @BeforeEach
    void setUp() {
        // Per-test setup with clean state
        cleanDatabase();
    }
}
```

### Organize Tests with @Nested

Use @Nested classes to group related tests by method or behavior.

```java
// CORRECT: @Nested for logical grouping
class UserServiceTest {

    private UserService service;
    private UserRepository repository;

    @BeforeEach
    void setUp() {
        repository = mock(UserRepository.class);
        service = new UserService(repository);
    }

    @Nested
    @DisplayName("findById")
    class FindById {

        @Test
        @DisplayName("should return user when found")
        void shouldReturnUserWhenFound() {
            var user = new User(1L, "alice@example.com");
            when(repository.findById(1L)).thenReturn(Optional.of(user));

            var result = service.findById(1L);

            assertThat(result).isPresent();
            assertThat(result.get().email()).isEqualTo("alice@example.com");
        }

        @Test
        @DisplayName("should return empty when not found")
        void shouldReturnEmptyWhenNotFound() {
            when(repository.findById(99L)).thenReturn(Optional.empty());

            var result = service.findById(99L);

            assertThat(result).isEmpty();
        }
    }

    @Nested
    @DisplayName("createUser")
    class CreateUser {

        @Test
        @DisplayName("should create user with valid email")
        void shouldCreateUserWithValidEmail() {
            var request = new CreateUserRequest("bob@example.com", "Bob");
            when(repository.save(any(User.class))).thenAnswer(inv -> {
                User u = inv.getArgument(0);
                return new User(1L, u.email());
            });

            var result = service.createUser(request);

            assertThat(result.email()).isEqualTo("bob@example.com");
            verify(repository).save(any(User.class));
        }

        @Test
        @DisplayName("should reject duplicate email")
        void shouldRejectDuplicateEmail() {
            var request = new CreateUserRequest("existing@example.com", "Existing");
            when(repository.existsByEmail("existing@example.com")).thenReturn(true);

            assertThatThrownBy(() -> service.createUser(request))
                .isInstanceOf(DuplicateEmailException.class)
                .hasMessageContaining("existing@example.com");
        }
    }
}
```

```java
// WRONG: Flat test structure without grouping
class UserServiceTest {

    @Test
    void testFindByIdFound() { /* ... */ }

    @Test
    void testFindByIdNotFound() { /* ... */ }

    @Test
    void testCreateUser() { /* ... */ }

    @Test
    void testCreateUserDuplicate() { /* ... */ }
    // Hard to see which tests belong to which method
}
```

## Test Naming Conventions

### Use should...when Pattern

Name tests using the shouldDoSomethingWhenCondition pattern for clarity.

```java
// CORRECT: should...when naming pattern
@Test
void shouldReturnDiscountedPrice_whenCustomerIsPremium() {
    var customer = new Customer("premium");
    var price = pricingService.calculate(customer, new BigDecimal("100"));
    assertThat(price).isEqualByComparingTo(new BigDecimal("85.00"));
}

@Test
void shouldThrowException_whenOrderIsEmpty() {
    assertThatThrownBy(() -> orderService.submit(new Order()))
        .isInstanceOf(EmptyOrderException.class);
}

@Test
void shouldReturnPagedResults_whenPageSizeIsSpecified() {
    var page = userService.findAll(PageRequest.of(0, 10));
    assertThat(page.getContent()).hasSize(10);
}
```

```java
// WRONG: Vague or inconsistent naming
@Test
void test1() { /* ... */ }

@Test
void testOrder() { /* ... */ }

@Test
void orderCreation() { /* ... */ }

@Test
void itWorks() { /* ... */ }
```

#### Use @DisplayName for Human-Readable Descriptions

Use @DisplayName to provide human-readable test descriptions in reports.

```java
// CORRECT: @DisplayName for readable reports
@Test
@DisplayName("should apply 15% discount for gold tier customers")
void shouldApplyGoldDiscount() {
    // ...
}

@Nested
@DisplayName("Payment processing")
class PaymentProcessing {

    @Test
    @DisplayName("should process valid credit card payment")
    void shouldProcessValidCreditCard() {
        // ...
    }

    @Test
    @DisplayName("should reject expired credit cards")
    void shouldRejectExpiredCreditCard() {
        // ...
    }
}
```

## Parameterized Tests

### Use @ParameterizedTest with @CsvSource

Use @CsvSource for simple parameterized tests with inline data.

```java
// CORRECT: @CsvSource for inline parameterized data
@ParameterizedTest(name = "calculate({0}, {1}) = {2}")
@CsvSource({
    "0,    0,   0",
    "1,    1,   2",
    "10,   20,  30",
    "-5,   5,   0",
    "100,  -50, 50"
})
void shouldAddNumbers(int a, int b, int expected) {
    assertThat(calculator.add(a, b)).isEqualTo(expected);
}

@ParameterizedTest(name = "validate email: {0} -> valid={1}")
@CsvSource({
    "user@example.com,   true",
    "admin@test.org,     true",
    "invalid,            false",
    "'',                 false",
    "no-at-sign.com,     false"
})
void shouldValidateEmail(String email, boolean expectedValid) {
    assertThat(validator.isValidEmail(email)).isEqualTo(expectedValid);
}
```

```java
// WRONG: Separate tests for each data point
@Test
void shouldAddPositiveNumbers() {
    assertThat(calculator.add(1, 1)).isEqualTo(2);
}

@Test
void shouldAddNegativeNumbers() {
    assertThat(calculator.add(-5, 5)).isEqualTo(0);
}
// Many duplicated tests...
```

#### Use @MethodSource for Complex Parameters

Use @MethodSource when test data is too complex for @CsvSource.

```java
// CORRECT: @MethodSource for complex data
@ParameterizedTest(name = "{0}")
@MethodSource("orderScenarios")
void shouldCalculateOrderTotal(String scenario, List<OrderItem> items, BigDecimal expectedTotal) {
    var order = new Order(items);
    assertThat(order.total()).isEqualByComparingTo(expectedTotal);
}

static Stream<Arguments> orderScenarios() {
    return Stream.of(
        Arguments.of(
            "single item order",
            List.of(new OrderItem("A", 2, new BigDecimal("10.00"))),
            new BigDecimal("20.00")
        ),
        Arguments.of(
            "multi-item order",
            List.of(
                new OrderItem("A", 1, new BigDecimal("10.00")),
                new OrderItem("B", 3, new BigDecimal("5.00"))
            ),
            new BigDecimal("25.00")
        ),
        Arguments.of(
            "empty order",
            List.of(),
            BigDecimal.ZERO
        )
    );
}
```

#### Use @EnumSource for Enum-Based Tests

Use @EnumSource for testing behavior across all or specific enum values.

```java
// CORRECT: @EnumSource for enum coverage
@ParameterizedTest(name = "tier {0} should have a positive discount rate")
@EnumSource(CustomerTier.class)
void shouldHavePositiveDiscountRate(CustomerTier tier) {
    assertThat(tier.discountRate()).isGreaterThanOrEqualTo(BigDecimal.ZERO);
}

@ParameterizedTest(name = "premium tier {0} should have discount >= 10%")
@EnumSource(value = CustomerTier.class, names = {"GOLD", "PLATINUM"})
void shouldHavePremiumDiscount(CustomerTier tier) {
    assertThat(tier.discountRate()).isGreaterThanOrEqualTo(new BigDecimal("0.10"));
}

@ParameterizedTest(name = "non-premium tier {0} should have discount < 10%")
@EnumSource(value = CustomerTier.class, mode = EnumSource.Mode.EXCLUDE, names = {"GOLD", "PLATINUM"})
void shouldHaveStandardDiscount(CustomerTier tier) {
    assertThat(tier.discountRate()).isLessThan(new BigDecimal("0.10"));
}
```

## AssertJ Assertions

### Prefer AssertJ Over JUnit Assertions

Use AssertJ for fluent, readable assertions with better error messages.

```java
// CORRECT: AssertJ fluent assertions
import static org.assertj.core.api.Assertions.*;

@Test
void shouldFilterActiveUsers() {
    var users = userService.findActive();

    assertThat(users)
        .hasSize(3)
        .extracting(User::email)
        .containsExactlyInAnyOrder(
            "alice@example.com",
            "bob@example.com",
            "carol@example.com"
        );
}

@Test
void shouldCreateOrderWithCorrectDetails() {
    var order = orderService.create(request);

    assertThat(order)
        .isNotNull()
        .satisfies(o -> {
            assertThat(o.status()).isEqualTo(OrderStatus.PENDING);
            assertThat(o.total()).isEqualByComparingTo(new BigDecimal("99.99"));
            assertThat(o.items()).hasSize(2);
            assertThat(o.createdAt()).isCloseTo(Instant.now(), within(1, ChronoUnit.SECONDS));
        });
}
```

```java
// WRONG: JUnit assertions (less readable, worse error messages)
import static org.junit.jupiter.api.Assertions.*;

@Test
void shouldFilterActiveUsers() {
    var users = userService.findActive();

    assertEquals(3, users.size());
    assertTrue(users.stream().anyMatch(u -> u.email().equals("alice@example.com")));
    assertTrue(users.stream().anyMatch(u -> u.email().equals("bob@example.com")));
}
```

#### AssertJ Exception Assertions

Use AssertJ assertThatThrownBy or assertThatCode for exception testing.

```java
// CORRECT: AssertJ exception assertions
@Test
void shouldThrowOnInvalidInput() {
    assertThatThrownBy(() -> service.process(null))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("Input must not be null")
        .hasNoCause();
}

@Test
void shouldThrowWithCause() {
    assertThatThrownBy(() -> service.connect())
        .isInstanceOf(ServiceException.class)
        .hasMessageContaining("connection failed")
        .hasCauseInstanceOf(IOException.class);
}

@Test
void shouldNotThrowForValidInput() {
    assertThatCode(() -> service.process(validInput))
        .doesNotThrowAnyException();
}
```

```java
// WRONG: JUnit assertThrows (less fluent)
@Test
void shouldThrowOnInvalidInput() {
    var exception = assertThrows(IllegalArgumentException.class,
        () -> service.process(null));
    assertEquals("Input must not be null", exception.getMessage());
}
```

#### AssertJ Collection Assertions

Use AssertJ's rich collection assertions for expressive tests.

```java
// CORRECT: AssertJ collection assertions
@Test
void shouldReturnSortedActiveUsers() {
    var users = userService.findActiveSorted();

    assertThat(users)
        .isNotEmpty()
        .hasSize(5)
        .isSortedAccordingTo(Comparator.comparing(User::name))
        .allSatisfy(user -> {
            assertThat(user.isActive()).isTrue();
            assertThat(user.email()).contains("@");
        })
        .noneSatisfy(user ->
            assertThat(user.isActive()).isFalse()
        );
}

@Test
void shouldReturnOrdersWithExpectedStatuses() {
    var orders = orderService.findByCustomer(customerId);

    assertThat(orders)
        .extracting(Order::status)
        .containsOnly(OrderStatus.PENDING, OrderStatus.CONFIRMED)
        .doesNotContain(OrderStatus.CANCELLED);
}
```

## Mockito Patterns

### Use MockitoExtension

Use @ExtendWith(MockitoExtension.class) to initialize mocks automatically.

```java
// CORRECT: MockitoExtension for automatic mock initialization
@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock
    private PaymentGateway paymentGateway;

    @Mock
    private OrderRepository orderRepository;

    @InjectMocks
    private PaymentService paymentService;

    @Test
    void shouldProcessPaymentSuccessfully() {
        var order = new Order(1L, new BigDecimal("99.99"));
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));
        when(paymentGateway.charge(any(PaymentRequest.class)))
            .thenReturn(new PaymentResponse("txn-123", PaymentStatus.SUCCESS));

        var result = paymentService.processPayment(1L);

        assertThat(result.status()).isEqualTo(PaymentStatus.SUCCESS);
        assertThat(result.transactionId()).isEqualTo("txn-123");
    }
}
```

```java
// WRONG: Manual mock initialization
class PaymentServiceTest {

    private PaymentGateway paymentGateway;
    private PaymentService paymentService;

    @BeforeEach
    void setUp() {
        paymentGateway = Mockito.mock(PaymentGateway.class);  // Verbose
        paymentService = new PaymentService(paymentGateway);
    }
}
```

#### Verify Interactions with verify()

Use verify to confirm expected interactions occurred.

```java
// CORRECT: Verify interactions
@Test
void shouldSendNotificationAfterOrderCreation() {
    var request = new CreateOrderRequest("product-1", 2);
    when(orderRepository.save(any())).thenReturn(new Order(1L));

    orderService.createOrder(request);

    verify(orderRepository).save(any(Order.class));
    verify(notificationService).sendOrderConfirmation(eq(1L), any(Order.class));
    verifyNoMoreInteractions(notificationService);
}

@Test
void shouldNotSendNotificationOnFailure() {
    when(orderRepository.save(any())).thenThrow(new DataAccessException("DB error") {});

    assertThatThrownBy(() -> orderService.createOrder(request))
        .isInstanceOf(DataAccessException.class);

    verify(notificationService, never()).sendOrderConfirmation(anyLong(), any());
}
```

#### Use ArgumentCaptor for Complex Assertions

Use ArgumentCaptor to capture and assert arguments passed to mocked methods.

```java
// CORRECT: ArgumentCaptor for detailed argument assertions
@Test
void shouldCreateAuditLogWithCorrectDetails() {
    var request = new TransferRequest(1L, 2L, new BigDecimal("500.00"));

    transferService.executeTransfer(request);

    var captor = ArgumentCaptor.forClass(AuditLog.class);
    verify(auditLogRepository).save(captor.capture());

    var auditLog = captor.getValue();
    assertThat(auditLog.action()).isEqualTo("TRANSFER");
    assertThat(auditLog.amount()).isEqualByComparingTo(new BigDecimal("500.00"));
    assertThat(auditLog.fromAccountId()).isEqualTo(1L);
    assertThat(auditLog.toAccountId()).isEqualTo(2L);
    assertThat(auditLog.timestamp()).isCloseTo(Instant.now(), within(1, ChronoUnit.SECONDS));
}
```

#### Stubbing Void Methods

Use doNothing, doThrow, or doAnswer for void methods.

```java
// CORRECT: Stubbing void methods
@Test
void shouldHandleNotificationFailureGracefully() {
    doThrow(new NotificationException("SMTP down"))
        .when(notificationService).sendEmail(any());

    // Service should handle notification failure without throwing
    assertThatCode(() -> orderService.createOrder(request))
        .doesNotThrowAnyException();

    verify(notificationService).sendEmail(any());
}

@Test
void shouldCallDeleteSuccessfully() {
    doNothing().when(repository).deleteById(1L);

    service.removeUser(1L);

    verify(repository).deleteById(1L);
}
```

## Spring Boot Test Slices

### Use @WebMvcTest for Controller Tests

Use @WebMvcTest for testing Spring MVC controllers in isolation.

```java
// CORRECT: @WebMvcTest for controller layer
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void shouldReturnUserById() throws Exception {
        var user = new UserResponse(1L, "alice", "alice@example.com");
        when(userService.findById(1L)).thenReturn(Optional.of(user));

        mockMvc.perform(get("/api/users/1")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.username").value("alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    void shouldReturn404WhenUserNotFound() throws Exception {
        when(userService.findById(99L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/99")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isNotFound());
    }

    @Test
    void shouldCreateUser() throws Exception {
        var request = """
            {
                "username": "bob",
                "email": "bob@example.com"
            }
            """;
        var response = new UserResponse(2L, "bob", "bob@example.com");
        when(userService.createUser(any())).thenReturn(response);

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(request))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(2))
            .andExpect(jsonPath("$.username").value("bob"));
    }

    @Test
    void shouldReturn400ForInvalidRequest() throws Exception {
        var invalidRequest = """
            {
                "username": "",
                "email": "not-an-email"
            }
            """;

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidRequest))
            .andExpect(status().isBadRequest());
    }
}
```

```java
// WRONG: @SpringBootTest for controller-only testing (loads full context)
@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {
    // Loads entire application context unnecessarily
}
```

#### Use @DataJpaTest for Repository Tests

Use @DataJpaTest for testing JPA repositories with an embedded database.

```java
// CORRECT: @DataJpaTest for repository layer
@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldFindUserByEmail() {
        var user = new User("alice", "alice@example.com");
        entityManager.persistAndFlush(user);

        var found = userRepository.findByEmail("alice@example.com");

        assertThat(found).isPresent();
        assertThat(found.get().getUsername()).isEqualTo("alice");
    }

    @Test
    void shouldReturnEmptyForNonExistentEmail() {
        var found = userRepository.findByEmail("nonexistent@example.com");

        assertThat(found).isEmpty();
    }

    @Test
    void shouldFindActiveUsersByRole() {
        entityManager.persist(new User("alice", "alice@example.com", Role.ADMIN, true));
        entityManager.persist(new User("bob", "bob@example.com", Role.USER, true));
        entityManager.persist(new User("carol", "carol@example.com", Role.ADMIN, false));
        entityManager.flush();

        var activeAdmins = userRepository.findByRoleAndActiveTrue(Role.ADMIN);

        assertThat(activeAdmins)
            .hasSize(1)
            .extracting(User::getUsername)
            .containsExactly("alice");
    }
}
```

#### Use @WebFluxTest for WebFlux Controller Tests

Use @WebFluxTest for testing reactive WebFlux controllers.

```java
// CORRECT: @WebFluxTest for reactive controller testing
@WebFluxTest(UserController.class)
class UserControllerWebFluxTest {

    @Autowired
    private WebTestClient webTestClient;

    @MockBean
    private UserService userService;

    @Test
    void shouldReturnUserById() {
        var user = new UserResponse(1L, "alice", "alice@example.com");
        when(userService.findById(1L)).thenReturn(Mono.just(user));

        webTestClient.get()
            .uri("/api/users/1")
            .accept(MediaType.APPLICATION_JSON)
            .exchange()
            .expectStatus().isOk()
            .expectBody(UserResponse.class)
            .value(response -> {
                assertThat(response.id()).isEqualTo(1L);
                assertThat(response.username()).isEqualTo("alice");
            });
    }

    @Test
    void shouldStreamUsers() {
        var users = Flux.just(
            new UserResponse(1L, "alice", "alice@example.com"),
            new UserResponse(2L, "bob", "bob@example.com")
        );
        when(userService.streamAll()).thenReturn(users);

        webTestClient.get()
            .uri("/api/users/stream")
            .accept(MediaType.TEXT_EVENT_STREAM)
            .exchange()
            .expectStatus().isOk()
            .expectBodyList(UserResponse.class)
            .hasSize(2);
    }
}
```

## Testcontainers

### Use @Container with Static Lifecycle

Use Testcontainers with static lifecycle for shared containers across tests.

```java
// CORRECT: Testcontainers with static shared container
@SpringBootTest
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private OrderService orderService;

    @Autowired
    private OrderRepository orderRepository;

    @BeforeEach
    void setUp() {
        orderRepository.deleteAll();
    }

    @Test
    void shouldCreateAndRetrieveOrder() {
        var request = new CreateOrderRequest("product-1", 3, new BigDecimal("29.99"));
        var created = orderService.createOrder(request);

        var retrieved = orderService.findById(created.id());

        assertThat(retrieved).isPresent();
        assertThat(retrieved.get().productId()).isEqualTo("product-1");
        assertThat(retrieved.get().total()).isEqualByComparingTo(new BigDecimal("89.97"));
    }
}
```

```java
// WRONG: Non-static container (restarted per test, very slow)
@SpringBootTest
@Testcontainers
class OrderIntegrationTest {

    @Container  // Non-static: new container per test method
    PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");
    // This is extremely slow
}
```

#### Multi-Container Setup

Use multiple containers for integration tests requiring multiple services.

```java
// CORRECT: Multiple containers for full integration test
@SpringBootTest
@Testcontainers
class FullIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb");

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);

    @Container
    static KafkaContainer kafka = new KafkaContainer(
        DockerImageName.parse("confluentinc/cp-kafka:7.5.0"));

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", () -> redis.getMappedPort(6379));
        registry.add("spring.kafka.bootstrap-servers", kafka::getBootstrapServers);
    }
}
```

#### Reusable Container Base Class

Create a base class for shared container configuration.

```java
// CORRECT: Reusable base class for Testcontainers
public abstract class AbstractIntegrationTest {

    @Container
    protected static final PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}

// Tests extend the base class
@SpringBootTest
@Testcontainers
class UserIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private UserService userService;

    @Test
    void shouldCreateUser() {
        var user = userService.create(new CreateUserRequest("alice@example.com"));
        assertThat(user.id()).isNotNull();
    }
}
```

## ArchUnit Architecture Tests

### Enforce Layer Dependencies

Use ArchUnit to enforce architectural boundaries between layers.

```java
// CORRECT: ArchUnit layer dependency rules
@AnalyzeClasses(packages = "com.example.myapp")
class ArchitectureTest {

    @ArchTest
    static final ArchRule layerDependencies = layeredArchitecture()
        .consideringAllDependencies()
        .layer("Controller").definedBy("..controller..")
        .layer("Service").definedBy("..service..")
        .layer("Repository").definedBy("..repository..")
        .layer("Domain").definedBy("..domain..")
        .whereLayer("Controller").mayNotBeAccessedByAnyLayer()
        .whereLayer("Service").mayOnlyBeAccessedByLayers("Controller")
        .whereLayer("Repository").mayOnlyBeAccessedByLayers("Service")
        .whereLayer("Domain").mayOnlyBeAccessedByLayers("Service", "Repository");
}
```

#### Enforce Naming Conventions with ArchUnit

Use ArchUnit to enforce consistent naming patterns across the codebase.

```java
// CORRECT: ArchUnit naming conventions
@AnalyzeClasses(packages = "com.example.myapp")
class NamingConventionTest {

    @ArchTest
    static final ArchRule controllersShouldEndWithController =
        classes()
            .that().resideInAPackage("..controller..")
            .and().areAnnotatedWith(RestController.class)
            .should().haveSimpleNameEndingWith("Controller");

    @ArchTest
    static final ArchRule servicesShouldEndWithService =
        classes()
            .that().resideInAPackage("..service..")
            .and().areAnnotatedWith(Service.class)
            .should().haveSimpleNameEndingWith("Service");

    @ArchTest
    static final ArchRule repositoriesShouldEndWithRepository =
        classes()
            .that().resideInAPackage("..repository..")
            .should().haveSimpleNameEndingWith("Repository");

    @ArchTest
    static final ArchRule noFieldInjection =
        noFields()
            .should().beAnnotatedWith(Autowired.class)
            .because("Field injection is not allowed; use constructor injection");
}
```

#### Enforce Package Dependencies with ArchUnit

Prevent circular dependencies and enforce package boundaries.

```java
// CORRECT: No circular dependencies
@AnalyzeClasses(packages = "com.example.myapp")
class PackageDependencyTest {

    @ArchTest
    static final ArchRule noCyclicDependencies =
        slices().matching("com.example.myapp.(*)..")
            .should().beFreeOfCycles();

    @ArchTest
    static final ArchRule domainShouldNotDependOnInfrastructure =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..infrastructure..", "..controller..");
}
```

## Coverage Standards

### Target 90%+ Line Coverage

Aim for at least 90% line coverage on business logic. Use JaCoCo for measurement.

```xml
<!-- CORRECT: JaCoCo Maven plugin configuration -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
        <execution>
            <id>check</id>
            <phase>verify</phase>
            <goals>
                <goal>check</goal>
            </goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.90</minimum>
                            </limit>
                            <limit>
                                <counter>BRANCH</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

#### JaCoCo Exclusions for Non-Business Code

Exclude generated code, configuration, and DTOs from coverage requirements.

```xml
<!-- CORRECT: JaCoCo exclusions in Maven -->
<configuration>
    <excludes>
        <exclude>**/config/**</exclude>
        <exclude>**/dto/**</exclude>
        <exclude>**/*Application.*</exclude>
        <exclude>**/*Config.*</exclude>
        <exclude>**/*Properties.*</exclude>
    </excludes>
</configuration>
```

```kotlin
// CORRECT: JaCoCo exclusions in Gradle Kotlin DSL
tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.90".toBigDecimal()
            }
        }
    }
    afterEvaluate {
        classDirectories.setFrom(files(classDirectories.files.map {
            fileTree(it) {
                exclude(
                    "**/config/**",
                    "**/dto/**",
                    "**/*Application*",
                    "**/*Config*",
                    "**/*Properties*"
                )
            }
        }))
    }
}
```

## Complete Test Class Example

### Full Service Test with Mockito and AssertJ

A complete example demonstrating all testing conventions together.

```java
// CORRECT: Complete test class following all conventions
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private InventoryService inventoryService;

    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private OrderService orderService;

    @Nested
    @DisplayName("createOrder")
    class CreateOrder {

        @Test
        @DisplayName("should create order when inventory is available")
        void shouldCreateOrder_whenInventoryAvailable() {
            var request = new CreateOrderRequest("SKU-001", 5);
            when(inventoryService.checkAvailability("SKU-001", 5)).thenReturn(true);
            when(orderRepository.save(any(Order.class))).thenAnswer(invocation -> {
                Order order = invocation.getArgument(0);
                return order.withId(42L);
            });

            var result = orderService.createOrder(request);

            assertThat(result.id()).isEqualTo(42L);
            assertThat(result.sku()).isEqualTo("SKU-001");
            assertThat(result.quantity()).isEqualTo(5);
            assertThat(result.status()).isEqualTo(OrderStatus.PENDING);

            verify(inventoryService).reserve("SKU-001", 5);
            verify(notificationService).sendOrderCreated(eq(42L));
        }

        @Test
        @DisplayName("should throw when inventory is insufficient")
        void shouldThrow_whenInventoryInsufficient() {
            var request = new CreateOrderRequest("SKU-001", 100);
            when(inventoryService.checkAvailability("SKU-001", 100)).thenReturn(false);

            assertThatThrownBy(() -> orderService.createOrder(request))
                .isInstanceOf(InsufficientInventoryException.class)
                .hasMessageContaining("SKU-001");

            verify(orderRepository, never()).save(any());
            verify(notificationService, never()).sendOrderCreated(anyLong());
        }
    }

    @Nested
    @DisplayName("cancelOrder")
    class CancelOrder {

        @Test
        @DisplayName("should cancel pending order")
        void shouldCancelPendingOrder() {
            var order = new Order(1L, "SKU-001", 5, OrderStatus.PENDING);
            when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

            orderService.cancelOrder(1L);

            var captor = ArgumentCaptor.forClass(Order.class);
            verify(orderRepository).save(captor.capture());
            assertThat(captor.getValue().status()).isEqualTo(OrderStatus.CANCELLED);
            verify(inventoryService).release("SKU-001", 5);
        }

        @Test
        @DisplayName("should throw when cancelling shipped order")
        void shouldThrow_whenCancellingShippedOrder() {
            var order = new Order(1L, "SKU-001", 5, OrderStatus.SHIPPED);
            when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

            assertThatThrownBy(() -> orderService.cancelOrder(1L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Cannot cancel order in SHIPPED status");
        }
    }

    @Nested
    @DisplayName("calculateDiscount")
    class CalculateDiscount {

        @ParameterizedTest(name = "tier {0} with amount {1} should get discount {2}")
        @CsvSource({
            "BRONZE,  100.00, 5.00",
            "SILVER,  100.00, 10.00",
            "GOLD,    100.00, 15.00",
            "PLATINUM,100.00, 20.00"
        })
        @DisplayName("should apply correct discount per tier")
        void shouldApplyCorrectDiscount(
                CustomerTier tier, BigDecimal amount, BigDecimal expectedDiscount) {
            var discount = orderService.calculateDiscount(tier, amount);
            assertThat(discount).isEqualByComparingTo(expectedDiscount);
        }
    }
}
```

## Existing Repository Compatibility

### Match Established Testing Patterns

When contributing to existing repositories, follow their established test conventions.

```java
// Check existing test patterns before writing tests:
// - Look at existing test classes for structure
// - Check for testify/AssertJ/Hamcrest usage
// - Check for Mockito vs other mocking frameworks
// - Look for shared test fixtures or base classes
// - Check for Testcontainers configuration
// - Follow existing naming conventions
```

```bash
# Discover test conventions
find src/test -name "*Test.java" | head -10    # Test file structure
grep -r "import static" src/test/ | head -5     # Assertion library
grep -r "@ExtendWith" src/test/ | head -5       # Extensions used
grep -r "Testcontainers" src/test/ | head -5    # Container usage
```

This skill ensures comprehensive, maintainable test suites following JUnit 5, AssertJ, Mockito,
Spring Boot, and Testcontainers best practices. Apply these patterns consistently to maintain
high-quality, reliable test coverage.
