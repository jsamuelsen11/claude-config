---
description: Autonomously improve Java test coverage using JaCoCo analysis
argument-hint: '[--threshold=90] [--package=<path>] [--dry-run] [--no-commit]'
allowed-tools:
  Bash(mvn *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Write, Edit, Grep, Glob
---

# Java Coverage Improvement Command

You are executing the `coverage` command to autonomously improve test coverage across a Java project
by analyzing JaCoCo reports, identifying gaps, and generating comprehensive tests.

## Command Arguments

### Optional: --threshold

Minimum coverage percentage to achieve per class (default: 90).

```bash
ccfg java coverage --threshold=85
```

#### Optional: --package

Target a specific package instead of the entire project.

```bash
ccfg java coverage --package=com.example.service
```

#### Optional: --dry-run

Report coverage gaps without generating any tests.

```bash
ccfg java coverage --dry-run
```

#### Optional: --no-commit

Generate tests but do not auto-commit changes.

```bash
ccfg java coverage --no-commit
```

## Execution Strategy

### Phase 1: Coverage Baseline

Measure current test coverage and establish the baseline.

1. Run tests with JaCoCo coverage collection
2. Parse the JaCoCo XML report (not HTML)
3. Calculate per-class line coverage
4. Identify classes below threshold
5. Rank classes by uncovered line count
6. Report the current state

#### Phase 2: Gap Analysis

For each under-threshold class:

1. Read the source file to understand its structure
2. Read existing test files to match patterns and style
3. Identify untested methods and branches
4. Determine what test patterns the project uses
5. Plan targeted test cases

#### Phase 3: Test Generation

For each identified gap:

1. Write targeted tests matching project patterns
2. Use AssertJ assertions for readability
3. Use Mockito for dependency isolation
4. Use Testcontainers for integration tests when needed
5. Follow the project's existing test naming conventions

#### Phase 4: Validation

After generating tests for each class:

1. Run tests to verify they pass
2. Run Spotless to ensure formatting
3. Measure new coverage for the class
4. Report the improvement

#### Phase 5: Commit (unless --no-commit or --dry-run)

Create one commit per improved class:

1. Stage only the test files for that class
2. Commit with a descriptive message including coverage delta
3. Move to the next class

## Coverage Baseline Analysis

### Step 1: Run Tests with JaCoCo

Generate the JaCoCo coverage report.

Gradle:

```bash
./gradlew test jacocoTestReport --no-daemon
```

Maven:

```bash
./mvnw test jacoco:report -q
```

If JaCoCo is not configured, report the error and suggest adding it:

```text
ERROR: JaCoCo plugin not configured.

For Gradle, add to build.gradle.kts:
  plugins {
      jacoco
  }
  tasks.jacocoTestReport {
      dependsOn(tasks.test)
      reports {
          xml.required = true
      }
  }

For Maven, add the jacoco-maven-plugin to pom.xml.
```

#### Step 2: Locate the XML Report

Find the JaCoCo XML report for parsing. Always use the XML report, never parse HTML.

Gradle default location:

```bash
ls build/reports/jacoco/test/jacocoTestReport.xml 2>/dev/null
```

Maven default location:

```bash
ls target/site/jacoco/jacoco.xml 2>/dev/null
```

If the XML report is missing but the task succeeded, check that XML output is enabled:

```text
WARNING: JaCoCo XML report not found.
Ensure XML reporting is enabled in your build configuration.
```

#### Step 3: Parse the XML Report

Parse the JaCoCo XML report to extract per-class coverage data. The XML structure contains
`<package>` elements with nested `<class>` elements and `<counter>` elements.

Key counter types to extract:

1. `LINE` - line coverage (primary metric)
2. `BRANCH` - branch coverage (secondary metric)
3. `METHOD` - method coverage
4. `INSTRUCTION` - bytecode instruction coverage

Example XML structure:

```xml
<package name="com/example/service">
  <class name="com/example/service/UserService" sourcefilename="UserService.java">
    <method name="createUser" desc="(Lcom/example/model/User;)Lcom/example/model/User;">
      <counter type="INSTRUCTION" missed="12" covered="8"/>
      <counter type="BRANCH" missed="2" covered="4"/>
      <counter type="LINE" missed="4" covered="6"/>
    </method>
    <counter type="LINE" missed="15" covered="45"/>
    <counter type="BRANCH" missed="6" covered="14"/>
  </class>
</package>
```

Calculate line coverage percentage per class:

```text
coverage = covered / (covered + missed) * 100
```

Parse the XML using grep and text processing:

```bash
# Extract class-level LINE counters from JaCoCo XML
grep -B1 'type="LINE"' build/reports/jacoco/test/jacocoTestReport.xml | grep "class\|LINE"
```

For more precise parsing, read the XML file and extract the data programmatically by examining the
structure of each `<class>` element and its `<counter type="LINE">` child.

#### Step 4: Rank Classes by Coverage Gap

Sort classes by the number of uncovered lines (descending) to prioritize the biggest impact:

```text
Class                                    Lines    Covered  Missed  Coverage
com.example.service.UserService          60       45       15      75.0%
com.example.repository.UserRepository    40       28       12      70.0%
com.example.controller.UserController    35       30       5       85.7%
com.example.model.User                   20       19       1       95.0%
```

#### Step 5: Report Initial State

Provide a summary before making improvements:

```text
=== Coverage Analysis ===

Project: user-service
Build tool: Gradle via ./gradlew
Current Coverage: 79.4% (lines)
Target Threshold: 90.0%
Gap: 10.6%

Classes Below Threshold:
  1. com.example.repository.UserRepository  70.0%  (12 lines missed)
  2. com.example.service.UserService        75.0%  (15 lines missed)
  3. com.example.controller.UserController  85.7%  (5 lines missed)

Classes Above Threshold:
  - com.example.model.User                 95.0%

Planning to improve 3 classes...
```

## Gap Analysis

For each class below threshold, identify specific untested code paths.

### Analyzing Source Code

Read the source file to understand methods, branches, and error paths:

```bash
# Find the source file
find src/main/java -name "UserService.java"
```

Read the file and catalog:

1. Public methods and their signatures
2. Conditional branches (if/else, switch, ternary)
3. Exception handling blocks (try/catch)
4. Null checks and guard clauses
5. Loop bodies and edge conditions

#### Analyzing Existing Tests

Read existing test files to understand the project's testing patterns:

```bash
# Find corresponding test file
find src/test/java -name "UserServiceTest.java"
```

Examine existing tests for:

1. Test class structure and annotations
2. Setup methods (`@BeforeEach`, `@BeforeAll`)
3. Assertion library (AssertJ, Hamcrest, or plain JUnit)
4. Mock framework usage (Mockito patterns)
5. Test naming conventions
6. Use of parameterized tests
7. Use of nested test classes
8. Custom test utilities or fixtures

#### Mapping Uncovered Code

Cross-reference the JaCoCo method-level counters with the source to identify exactly which methods
and branches need tests:

```text
UserService analysis:
  createUser()     - 4 lines missed (null-check branch, validation branch)
  updateUser()     - 6 lines missed (not-found path, concurrent modification catch)
  deleteUser()     - 3 lines missed (already-deleted check, audit log)
  findByEmail()    - 2 lines missed (empty result branch)

Existing tests cover:
  - createUser() happy path
  - updateUser() happy path
  - deleteUser() happy path

Missing tests:
  - createUser() with null input
  - createUser() with invalid email
  - updateUser() when user not found
  - updateUser() on concurrent modification
  - deleteUser() when already deleted
  - findByEmail() when no match found
```

## Test Generation

Generate comprehensive, well-structured tests for each identified gap.

### Test Structure Patterns

Use JUnit 5 with AssertJ assertions. Match the project's existing test style.

#### Unit Test Pattern

```java
package com.example.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.model.User;
import com.example.repository.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

  @Mock private UserRepository userRepository;

  @InjectMocks private UserService userService;

  @Nested
  class CreateUser {

    @Test
    void createsUserSuccessfully() {
      User user = new User("user@example.com", "Jane Doe");
      when(userRepository.save(any(User.class))).thenReturn(user);

      User result = userService.createUser(user);

      assertThat(result.email()).isEqualTo("user@example.com");
      verify(userRepository).save(user);
    }

    @Test
    void rejectsNullUser() {
      assertThatThrownBy(() -> userService.createUser(null))
          .isInstanceOf(IllegalArgumentException.class)
          .hasMessage("user must not be null");
    }

    @Test
    void rejectsUserWithInvalidEmail() {
      User user = new User("not-an-email", "Jane Doe");

      assertThatThrownBy(() -> userService.createUser(user))
          .isInstanceOf(IllegalArgumentException.class)
          .hasMessageContaining("email");
    }
  }

  @Nested
  class UpdateUser {

    @Test
    void updatesExistingUser() {
      User existing = new User("user@example.com", "Jane Doe");
      when(userRepository.findById("123")).thenReturn(Optional.of(existing));
      when(userRepository.save(any(User.class))).thenReturn(existing);

      User result = userService.updateUser("123", existing);

      assertThat(result).isNotNull();
      verify(userRepository).save(existing);
    }

    @Test
    void throwsWhenUserNotFound() {
      when(userRepository.findById("999")).thenReturn(Optional.empty());

      assertThatThrownBy(() -> userService.updateUser("999", new User("a@b.c", "X")))
          .isInstanceOf(UserNotFoundException.class)
          .hasMessageContaining("999");
    }
  }
}
```

#### Parameterized Test Pattern

```java
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class EmailValidatorTest {

  @ParameterizedTest
  @ValueSource(strings = {"user@example.com", "a@b.co", "test+tag@domain.org"})
  void acceptsValidEmails(String email) {
    assertThat(EmailValidator.isValid(email)).isTrue();
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {"notanemail", "@domain.com", "user@", "user @domain.com"})
  void rejectsInvalidEmails(String email) {
    assertThat(EmailValidator.isValid(email)).isFalse();
  }

  @ParameterizedTest
  @CsvSource({
    "hello, HELLO",
    "world, WORLD",
    "'', ''"
  })
  void convertsToUpperCase(String input, String expected) {
    assertThat(StringUtils.toUpper(input)).isEqualTo(expected);
  }
}
```

#### Integration Test with Testcontainers

When the class under test requires a real database or external service, use Testcontainers:

```java
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {

  @Container
  static PostgreSQLContainer<?> postgres =
      new PostgreSQLContainer<>("postgres:16-alpine");

  @DynamicPropertySource
  static void configureProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
    registry.add("spring.datasource.username", postgres::getUsername);
    registry.add("spring.datasource.password", postgres::getPassword);
  }

  @Autowired private UserRepository userRepository;

  @Test
  void savesAndFindsUser() {
    User user = new User("user@example.com", "Jane Doe");
    userRepository.save(user);

    Optional<User> found = userRepository.findByEmail("user@example.com");

    assertThat(found).isPresent();
    assertThat(found.get().name()).isEqualTo("Jane Doe");
  }
}
```

Only use Testcontainers when the existing project already has it as a dependency. Do not add new
dependencies without explicit approval.

### Test Generation Guidelines

1. Use AssertJ assertions exclusively (`assertThat(...).isEqualTo(...)`)
2. Use Mockito with `@ExtendWith(MockitoExtension.class)` for unit tests
3. Use `@Nested` classes to group related test cases by method
4. Use `@ParameterizedTest` for testing multiple inputs
5. Test both happy path and error/edge cases
6. Validate exception types AND messages with `assertThatThrownBy`
7. Use `@BeforeEach` for common test setup
8. Name tests descriptively: `shouldCreateUser`, `rejectsNullInput`, `throwsWhenNotFound`
9. Never use `@SuppressWarnings` in test code
10. Keep each test focused on a single behavior
11. Match the import style of existing test files
12. Maintain the same package structure in test sources

### What Not to Test

Focus coverage efforts on meaningful code paths. Skip:

1. Trivial getters and setters (Java records handle these)
2. Framework-generated code (Spring proxy methods, Lombok)
3. Configuration classes with only bean declarations
4. Main method entry points (unless they contain logic)
5. DTOs and records with no behavior

## Validation Phase

After generating tests for each class, validate the results.

### Run the New Tests

Execute tests for the specific class:

Gradle:

```bash
./gradlew test --tests "com.example.service.UserServiceTest" --no-daemon
```

Maven:

```bash
./mvnw test -Dtest=com.example.service.UserServiceTest -q
```

Expected successful output:

```text
> Task :test

com.example.service.UserServiceTest$CreateUser > createsUserSuccessfully() PASSED
com.example.service.UserServiceTest$CreateUser > rejectsNullUser() PASSED
com.example.service.UserServiceTest$CreateUser > rejectsUserWithInvalidEmail() PASSED
com.example.service.UserServiceTest$UpdateUser > updatesExistingUser() PASSED
com.example.service.UserServiceTest$UpdateUser > throwsWhenUserNotFound() PASSED

5 tests completed, 5 passed
```

#### Handle Test Failures

If generated tests fail:

1. Analyze the failure message and stack trace
2. Check if assumptions about source code behavior were wrong
3. Fix the test logic, not the source code
4. Re-read the source to understand actual behavior
5. Re-run to confirm the fix
6. If persistent failures, report and skip the class

Example failure handling:

```text
Test failure: UserServiceTest$CreateUser > rejectsNullUser()
  Expected: IllegalArgumentException
  Actual: NullPointerException at UserService.java:25

Analysis: Source code does not explicitly check for null; NPE occurs naturally.
Action: Updating test to expect NullPointerException instead.
```

#### Run Spotless Check

Ensure generated test code follows project formatting:

Gradle:

```bash
./gradlew spotlessCheck --no-daemon
```

If formatting violations exist, apply the fix:

```bash
./gradlew spotlessApply --no-daemon
```

Maven:

```bash
./mvnw spotless:check -q
```

If violations exist:

```bash
./mvnw spotless:apply -q
```

#### Measure Updated Coverage

Re-run coverage for the specific class to measure improvement:

Gradle:

```bash
./gradlew test jacocoTestReport --no-daemon
```

Parse the updated XML report and extract the class coverage:

```text
Before: com.example.service.UserService  75.0% (45/60 lines)
After:  com.example.service.UserService  93.3% (56/60 lines)
Improvement: +18.3%
```

## Commit Strategy

Create one commit per improved class (unless --no-commit is set).

### Per-Class Commit

After successfully improving a class:

1. Stage only the test files for that class
2. Create a descriptive commit message
3. Include the coverage delta in the message

```bash
git add src/test/java/com/example/service/UserServiceTest.java
git commit -m "$(cat <<'EOF'
test(UserService): improve line coverage from 75.0% to 93.3%

Add tests for:
- createUser() with null input
- createUser() with invalid email
- updateUser() when user not found
- findByEmail() when no match found

Coverage improvement: +18.3% (45/60 -> 56/60 lines)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

#### Commit Message Format

Use this format for all coverage commits:

```text
test(<ClassName>): improve line coverage from X% to Y%

Add tests for:
- Specific method or scenario 1
- Specific method or scenario 2
- Specific method or scenario 3

Coverage improvement: +Z% (a/b -> c/d lines)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

#### Handle Commit Failures

If a commit fails due to pre-commit hooks:

1. Run the failing check (usually formatting or lint)
2. Fix any issues in the generated tests
3. Re-stage and create a NEW commit (do not amend)
4. Never use `--no-verify`

## Reporting

Provide comprehensive reports throughout execution.

### Initial Analysis Report

```text
=== Coverage Improvement Plan ===

Current State:
  Project coverage: 79.4% (lines)
  Target threshold: 90.0%
  Classes analyzed: 8
  Classes below threshold: 3

Improvement Plan:
  1. com.example.repository.UserRepository (70.0% -> ~92%)
     - Test findByEmail() empty result path
     - Test save() constraint violation handling
     - Test deleteById() when not found
     Estimated new tests: 6

  2. com.example.service.UserService (75.0% -> ~93%)
     - Test createUser() null and validation paths
     - Test updateUser() not-found scenario
     - Test deleteUser() already-deleted case
     Estimated new tests: 8

  3. com.example.controller.UserController (85.7% -> ~94%)
     - Test error response formatting
     - Test request validation failures
     Estimated new tests: 4

Estimated total new tests: 18
Estimated time: 5-10 minutes
```

#### Progress Updates

Report after each class:

```text
[1/3] Processing com.example.repository.UserRepository...
  - Analyzed 4 methods, 3 need additional tests
  - Generated 6 test cases
  - Tests pass
  - Formatting clean
  - Coverage: 70.0% -> 92.5% (+22.5%)
  - Committed: a1b2c3d

[2/3] Processing com.example.service.UserService...
  - Analyzed 5 methods, 4 need additional tests
  - Generated 8 test cases
  - Tests pass
  - Formatting clean
  - Coverage: 75.0% -> 93.3% (+18.3%)
  - Committed: e4f5g6h

[3/3] Processing com.example.controller.UserController...
  - Analyzed 3 methods, 2 need additional tests
  - Generated 4 test cases
  - Tests pass
  - Formatting clean
  - Coverage: 85.7% -> 94.3% (+8.6%)
  - Committed: i7j8k9l
```

#### Final Summary

```text
=== Coverage Improvement Complete ===

Before:
  Project coverage: 79.4%
  Classes below threshold: 3

After:
  Project coverage: 92.8%
  Classes below threshold: 0

Improvements:
  com.example.repository.UserRepository:  70.0% -> 92.5% (+22.5%)
  com.example.service.UserService:        75.0% -> 93.3% (+18.3%)
  com.example.controller.UserController:  85.7% -> 94.3% (+8.6%)

Tests Added: 18
Commits Created: 3
Time Taken: 7m 12s

All classes now meet the 90% line coverage threshold.
```

#### Dry-Run Report

If --dry-run flag is used, report only the analysis without generating tests:

```text
=== Coverage Analysis (Dry Run) ===

Current coverage: 79.4%
Target threshold: 90.0%

Recommended improvements:

1. com.example.repository.UserRepository (70.0%)
   Untested paths:
   - findByEmail() empty result branch (2 lines)
   - save() duplicate key exception handler (4 lines)
   - deleteById() not-found guard clause (3 lines)
   - findAll() empty collection return (3 lines)
   Estimated tests needed: 6
   Projected coverage: ~92%

2. com.example.service.UserService (75.0%)
   Untested paths:
   - createUser() null user check (2 lines)
   - createUser() email validation branch (3 lines)
   - updateUser() user-not-found exception (4 lines)
   - deleteUser() already-deleted check (3 lines)
   - findByEmail() delegation and null handling (3 lines)
   Estimated tests needed: 8
   Projected coverage: ~93%

3. com.example.controller.UserController (85.7%)
   Untested paths:
   - createUser() validation error response (3 lines)
   - updateUser() not-found error response (2 lines)
   Estimated tests needed: 4
   Projected coverage: ~94%

Total estimated tests: 18
Projected project coverage: ~92%

Run without --dry-run to generate tests.
```

## Edge Cases and Error Handling

### No JaCoCo Plugin Configured

If JaCoCo is not in the build configuration:

```text
ERROR: JaCoCo plugin is not configured in this project.

To add JaCoCo for Gradle (build.gradle.kts):
  plugins {
      jacoco
  }
  tasks.jacocoTestReport {
      dependsOn(tasks.test)
      reports {
          xml.required = true
          html.required = true
      }
  }

To add JaCoCo for Maven (pom.xml):
  <plugin>
      <groupId>org.jacoco</groupId>
      <artifactId>jacoco-maven-plugin</artifactId>
      <version>0.8.11</version>
      <executions>
          <execution>
              <goals><goal>prepare-agent</goal></goals>
          </execution>
          <execution>
              <id>report</id>
              <phase>test</phase>
              <goals><goal>report</goal></goals>
          </execution>
      </executions>
  </plugin>
```

#### No Test Files Exist for a Class

If a class has no corresponding test file:

1. Create a new test file in the mirror package under `src/test/java`
2. Follow the naming convention: `<ClassName>Test.java`
3. Add appropriate imports and annotations
4. Generate a complete test suite

#### Class Uses Dependencies Not in Test Scope

If the class depends on libraries not available in test:

1. Check if the dependency exists in the project
2. If Mockito is available, mock the dependency
3. If the dependency is a database, check for Testcontainers
4. Never add new dependencies without reporting it
5. If unable to test without new deps, skip the class and report

#### Abstract Classes and Interfaces

Do not directly test abstract classes or interfaces. Instead:

1. Test concrete implementations
2. If no concrete implementation exists, skip
3. Report abstract classes separately in the analysis

#### Generated Code and Frameworks

Skip classes that are primarily framework-generated:

1. Spring Boot auto-configuration classes
2. Lombok-generated methods (getters, setters, builders)
3. MapStruct mapper implementations
4. JPA metamodel classes

Report these as excluded in the analysis:

```text
Excluded from analysis:
  - User_.java (JPA metamodel, generated)
  - UserMapperImpl.java (MapStruct, generated)
```

## Multi-Module Project Support

### Detecting Modules

For Gradle multi-module projects:

```bash
grep "include" settings.gradle.kts 2>/dev/null
```

For Maven multi-module projects:

```bash
grep "<module>" pom.xml 2>/dev/null
```

#### Per-Module Coverage

Run JaCoCo for each module and aggregate:

Gradle:

```bash
./gradlew :core:test :core:jacocoTestReport --no-daemon
./gradlew :service:test :service:jacocoTestReport --no-daemon
```

Maven:

```bash
./mvnw test jacoco:report -pl core -q
./mvnw test jacoco:report -pl service -q
```

Report coverage per module:

```text
Module: core
  Coverage: 88.2%
  Classes below threshold: 1

Module: service
  Coverage: 74.5%
  Classes below threshold: 4

Module: web
  Coverage: 91.0%
  Classes below threshold: 0
```

## Best Practices

### Test Quality Standards

1. Every test must have a clear, descriptive name
2. Use `@Nested` to group tests by method or scenario
3. Include both success and failure test cases
4. Test null inputs, empty collections, and boundary values
5. Validate exception types and messages together
6. Use `@ParameterizedTest` for repetitive input variations
7. Keep test setup minimal and focused
8. Avoid test interdependence (each test is self-contained)
9. Make tests deterministic (no random values, no time-dependent logic)

#### Assertion Style

Always use AssertJ:

```java
// Preferred: AssertJ
assertThat(result).isEqualTo("expected");
assertThat(list).hasSize(3).contains("a", "b");
assertThatThrownBy(() -> service.process(null))
    .isInstanceOf(IllegalArgumentException.class)
    .hasMessageContaining("must not be null");

// Avoid: JUnit assertions
assertEquals("expected", result);
assertThrows(IllegalArgumentException.class, () -> service.process(null));
```

#### Mock Usage Guidelines

1. Mock external dependencies (repositories, clients, external services)
2. Do not mock value objects or DTOs
3. Use `@InjectMocks` for the class under test
4. Use `verify()` sparingly, only for side-effect verification
5. Prefer behavior verification over interaction verification
6. Use `lenient()` only when strictly necessary

#### Coverage Goals

1. Aim for meaningful coverage, not just high percentages
2. Prioritize business logic and error handling paths
3. Do not write tests that only exercise framework code
4. Focus on branches and conditional logic
5. Test error paths as thoroughly as happy paths

## Cleanup

After completion, leave the workspace clean:

```bash
# Remove generated coverage files from working directory
rm -f coverage.out
```

The JaCoCo reports in `build/reports/` or `target/site/` are part of the build output and do not
need manual cleanup.

## Exit Codes

1. `0` - Coverage improvement successful or already above threshold
2. `1` - Failed to improve coverage (test failures, JaCoCo errors)
3. `2` - Command error (invalid arguments, no build file, JaCoCo not configured)

## Integration with Validate Command

This command complements the validate command:

1. Run `coverage` to improve test coverage
2. Run `validate` to ensure all quality gates pass
3. Both commands work together for comprehensive code quality

Suggested workflow:

```bash
# Improve coverage
ccfg java coverage --threshold=90

# Validate everything
ccfg java validate
```

## Performance Considerations

For large projects with many classes:

1. Process classes in order of most missed lines first (highest impact)
2. Skip classes already above threshold immediately
3. Run tests incrementally for individual classes during generation
4. Run full test suite only once at the end for final validation
5. Provide progress updates so the user knows the command is working
6. Allow interruption between classes without losing progress

## Final Notes

The coverage command is autonomous but transparent:

1. Shows what it plans to do before acting
2. Reports progress after each class
3. Explains which test cases were generated and why
4. Creates atomic commits for easy review and revert
5. Supports dry-run mode for safe exploration
6. Never modifies production source code, only test code
7. Never adds `@SuppressWarnings` or ignores warnings

Always prioritize test quality over coverage percentage. Well-tested code at 85% is more valuable
than poorly-tested code at 95%. Every generated test should verify meaningful behavior, not just
execute lines.
