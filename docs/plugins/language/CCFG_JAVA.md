# Plugin: ccfg-java

The Java language plugin. Provides framework agents for Spring and Kotlin development, specialist
agents for testing and build tooling, project scaffolding, autonomous coverage improvement, and
opinionated conventions for consistent Java development with Maven/Gradle, JUnit 5, and Checkstyle.

## Directory Structure

```text
plugins/ccfg-java/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── java-architect.md
│   ├── spring-boot-engineer.md
│   ├── kotlin-specialist.md
│   ├── junit-specialist.md
│   └── maven-gradle-engineer.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
└── skills/
    ├── java-conventions/
    │   └── SKILL.md
    ├── testing-patterns/
    │   └── SKILL.md
    └── build-conventions/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-java",
  "description": "Java language plugin: Spring and Kotlin agents, project scaffolding, coverage automation, and conventions for consistent development with Maven/Gradle, JUnit 5, and Checkstyle",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["java", "kotlin", "spring-boot", "maven", "gradle", "junit"],
  "suggestedPermissions": {
    "allow": ["Bash(mvn:*)", "Bash(gradle:*)"]
  }
}
```

## Agents (5)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent                  | Role                                                                                    | Model  |
| ---------------------- | --------------------------------------------------------------------------------------- | ------ |
| `java-architect`       | Modern Java 21+, records, sealed classes, pattern matching, virtual threads, modularity | sonnet |
| `spring-boot-engineer` | Spring Boot 3+, Spring Cloud, WebFlux, Spring Data, Spring Security, actuator           | sonnet |
| `kotlin-specialist`    | Kotlin coroutines, multiplatform, DSLs, Spring Kotlin integration, Ktor                 | sonnet |

### Specialist Agents

| Agent                   | Role                                                                                                          | Model  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- | ------ |
| `junit-specialist`      | JUnit 5 lifecycle, parameterized tests, Mockito, AssertJ, Testcontainers, Spring Boot Test, ArchUnit          | sonnet |
| `maven-gradle-engineer` | pom.xml/build.gradle.kts mastery, multi-module projects, dependency management, plugins, profiles, publishing | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-java:validate

**Purpose**: Run the full Java quality gate suite in one command.

**Trigger**: User invokes before committing or shipping Java code.

**Allowed tools**:
`Bash(mvn *), Bash(./mvnw *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Build tool detection:

1. `build.gradle.kts` or `build.gradle` → Gradle (prefer `./gradlew` wrapper if present)
2. `pom.xml` → Maven (prefer `./mvnw` wrapper if present)

Full mode (default):

1. **Compile**: `./gradlew compileJava` or `./mvnw compile` — verify clean compilation
2. **Format check**: `./gradlew spotlessCheck` or `./mvnw spotless:check` (if Spotless configured,
   skip with notice if not)
3. **Tests**: `./gradlew test` or `./mvnw test`
4. **Lint/style**: `./gradlew checkstyleMain` or `./mvnw checkstyle:check` (if configured, skip with
   notice if not)
5. **Static analysis**: `./gradlew spotbugsMain` or `./mvnw spotbugs:check` (if configured, skip
   with notice if not)
6. Report pass/fail for each gate with output
7. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Compile**: `./gradlew compileJava compileTestJava` or `./mvnw compile test-compile`
2. **Format check**: `./gradlew spotlessCheck` or `./mvnw spotless:check` (if configured)
3. Report pass/fail — skips tests, checkstyle, and spotbugs for speed

**Key rules**:

- Detects build tool automatically (Maven or Gradle)
- Uses Gradle wrapper (`./gradlew`) when present, never global `gradle`
- Uses Maven wrapper (`./mvnw`) when present, never global `mvn`
- Never suggests `@SuppressWarnings` as a fix — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a plugin is not configured (e.g., no Spotless, no Checkstyle, no SpotBugs),
  skip that gate and report it as SKIPPED. Never fail because an optional plugin is missing

### /ccfg-java:scaffold

**Purpose**: Initialize a new Java project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new Java project or service.

**Allowed tools**:
`Bash(mvn *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<project-name> [--type=service|library|cli] [--build=maven|gradle]`

**Behavior**:

1. Create project directory with standard Java layout:

   ```text
   <name>/
   ├── src/
   │   ├── main/
   │   │   ├── java/<package>/
   │   │   │   └── Application.java
   │   │   └── resources/
   │   │       └── application.yml
   │   └── test/
   │       └── java/<package>/
   │           └── ApplicationTest.java
   ├── pom.xml (or build.gradle.kts)
   ├── .gitignore
   └── README.md
   ```

2. Generate build file with:
   - Java 21 source/target
   - JUnit 5, Mockito, AssertJ as test dependencies
   - Spotless plugin for autoformatting (google-java-format)
   - Checkstyle plugin configured
   - JaCoCo plugin for coverage
   - SpotBugs plugin for static analysis
3. Scaffold differs by type:
   - `service`: adds Spring Boot starter, health actuator, application.yml
   - `library`: adds publishing config, Javadoc generation
   - `cli`: adds picocli skeleton with main command
4. Verify `mvn test` or `./gradlew test` passes

**Key rules**:

- Java 21 minimum (LTS, virtual threads, records, pattern matching)
- Gradle Kotlin DSL (`build.gradle.kts`) preferred over Groovy DSL
- `src/main/java` + `src/test/java` standard layout
- application.yml preferred over application.properties (for Spring projects)

### /ccfg-java:coverage

**Purpose**: Autonomous per-package test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**:
`Bash(mvn *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**: `[--threshold=90] [--package=<path>] [--dry-run] [--no-commit]`

**Behavior**:

1. **Measure**: Run `./gradlew jacocoTestReport` or `./mvnw jacoco:report` (uses wrapper when
   present)
2. **Identify**: Parse JaCoCo **XML** report (`build/reports/jacoco/test/jacocoTestReport.xml` for
   Gradle, `target/site/jacoco/jacoco.xml` for Maven). Rank classes by uncovered lines. HTML report
   is for human review only — always parse XML for programmatic analysis
3. **Target**: For each under-threshold class: a. Read the source class and existing tests b.
   Identify untested methods, branches, and edge cases c. Write targeted tests following project's
   existing test patterns d. Run tests to confirm new tests pass e. Run lint/style checks on new
   test files f. Commit: `git add <test-file> && git commit -m "test: add coverage for <class>"`
4. **Report**: Summary table of before/after coverage per class
5. Stop when threshold reached or all classes processed

**Modes**:

- **Default**: Write tests and auto-commit after each class
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Reads existing tests first to match project patterns (JUnit vs Mockito vs Spring Boot Test)
- One commit per class (not one giant commit)
- Tests must exercise real behavior with meaningful assertions
- Uses AssertJ fluent assertions, not JUnit `assertEquals`
- Uses Testcontainers for integration tests requiring databases/services

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### java-conventions

**Trigger description**: "This skill should be used when working on Java or Kotlin projects, writing
Java code, configuring Spring Boot, or reviewing Java code."

**Existing repo compatibility**: For existing projects, respect the established build tool,
formatting conventions, and library choices. If the project uses Maven, use Maven. If the project
uses Lombok, use Lombok consistently. These preferences apply to new projects and scaffold output
only.

**Modern Java rules**:

- Use Java 21+ features: records for DTOs, sealed interfaces for type hierarchies, pattern matching
  in switch, virtual threads for concurrent I/O
- Use `var` for local variables when the type is obvious from the right-hand side
- Use `Optional` for return types that may be absent. Never use `Optional` as a field or parameter
- Use `Stream` API for collection transformations. Prefer method references over lambdas where
  readable
- Use text blocks (`"""`) for multi-line strings
- Never use raw types. Always parameterize generics

**Code style rules**:

- Follow Google Java Style Guide conventions
- Use `final` for fields that don't change after construction
- Prefer composition over inheritance. Use interfaces for polymorphism
- Use `@Nullable` and `@NonNull` annotations from JSpecify
- Favor immutable collections (`List.of`, `Map.of`, `Collections.unmodifiable*`)
- Use `try-with-resources` for all `AutoCloseable` resources
- Log with SLF4J (`LoggerFactory.getLogger`), never `System.out.println`

**Lombok rules**:

- Follow the project's existing Lombok usage. If Lombok is present, use it consistently (`@Data`,
  `@Builder`, `@Slf4j`). For new projects, prefer Java records and manual builders over Lombok —
  modern Java has reduced the need for it
- Never mix Lombok and manual implementations for the same pattern within a project

**Spring-specific rules**:

- Use constructor injection, never field injection (`@Autowired` on fields)
- Use `@ConfigurationProperties` over `@Value` for config binding
- Use Spring profiles for environment-specific config
- Define beans in `@Configuration` classes, not XML
- Use `@Transactional` only on public methods. Never call a `@Transactional` method from within the
  same class (self-invocation bypasses the proxy). Specify `propagation` and `readOnly` explicitly
  for non-default behavior

### testing-patterns

**Trigger description**: "This skill should be used when writing Java tests, creating JUnit 5 test
fixtures, using Mockito, testing Spring Boot applications, or improving test coverage."

**Contents**:

- **JUnit 5 lifecycle**: Use `@BeforeEach`/`@AfterEach` for test setup. Use `@Nested` for grouping
  related tests. Use `@DisplayName` for readable test names
- **Naming**: Test classes: `<Class>Test.java`. Test methods:
  `should<ExpectedBehavior>_when<Condition>()`. No `test` prefix needed with JUnit 5
- **Parameterized tests**: Use `@ParameterizedTest` with `@CsvSource`, `@MethodSource`, or
  `@EnumSource`. Always include `name` parameter for readable output
- **AssertJ over JUnit assertions**: Use `assertThat(actual).isEqualTo(expected)` fluent style. Use
  `assertThatThrownBy` for exception testing with chained assertions
- **Mockito**: Use `@ExtendWith(MockitoExtension.class)` (not `MockitoAnnotations.openMocks`). Use
  `@Mock` for dependencies, `@InjectMocks` for the class under test. Verify interactions only when
  side effects matter
- **Spring Boot Test**: Use `@SpringBootTest` sparingly (slow). Prefer `@WebMvcTest`,
  `@DataJpaTest`, `@WebFluxTest` for sliced tests. Use `@MockBean` for Spring-managed mocks
- **Testcontainers**: Use for integration tests requiring real databases, message brokers, etc. Use
  `@Container` annotation with `@Testcontainers`. Define containers as `static` for shared lifecycle
- **ArchUnit**: Use for architecture tests (package dependencies, layer enforcement, naming
  conventions)
- **Coverage**: Target 90%+ line coverage. Exclude generated code, DTOs, and config classes from
  coverage with JaCoCo exclusion patterns

### build-conventions

**Trigger description**: "This skill should be used when creating or editing pom.xml,
build.gradle.kts, managing Java dependencies, configuring Maven/Gradle plugins, or organizing
multi-module projects."

**Contents**:

- **Gradle Kotlin DSL preferred**: Use `build.gradle.kts` for new projects. Type-safe, IDE support,
  consistent with Kotlin
- **Dependency management**: Use BOM imports (`platform()` in Gradle, `dependencyManagement` in
  Maven) for version alignment. Never duplicate version numbers across modules
- **Dependency scopes**: `implementation` for runtime, `testImplementation` for test-only. Use `api`
  only when consumers need transitive access
- **Formatting**: Use Spotless plugin with `google-java-format` for consistent autoformatting.
  Configure in the build file alongside other quality plugins. Run `spotlessApply` to fix,
  `spotlessCheck` to verify
- **Plugin configuration**: Configure Spotless, Checkstyle, SpotBugs, JaCoCo in the build file. Fail
  builds on violations in CI
- **Multi-module projects**: Use parent POM (Maven) or `buildSrc`/convention plugins (Gradle) for
  shared config. Each module declares only its unique dependencies
- **Version catalogs**: Use Gradle version catalogs (`libs.versions.toml`) for centralized
  dependency versions
- **Profiles/variants**: Use Maven profiles or Gradle build variants for environment-specific
  builds. Keep profiles minimal
- **Reproducible builds**: Pin plugin versions. Use Maven wrapper (`mvnw`) or Gradle wrapper
  (`gradlew`). Commit wrapper files
- **Publishing**: Configure Maven Central publishing with GPG signing. Use `maven-publish` plugin
  for Gradle
- **Build performance**: Enable Gradle build cache and parallel execution
  (`org.gradle.parallel=true`, `org.gradle.caching=true` in `gradle.properties`). Use Gradle daemon
  (default in modern Gradle). For Maven, consider `mvnd` (Maven Daemon) for local development.
  Configure incremental compilation
