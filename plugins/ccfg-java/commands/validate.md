---
description: Run compile, format check, tests, lint, and static analysis for Java projects
argument-hint: '[--quick]'
allowed-tools:
  Bash(mvn *), Bash(./mvnw *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Grep, Glob
---

# Java Validation Command

You are executing the `validate` command for a Java project. This command runs a comprehensive suite
of quality gates to ensure code meets production standards before commit or merge.

## Command Modes

### Full Mode (default)

Runs all quality gates in sequence:

1. `compile` - Compile main and test sources
2. `spotlessCheck` - Verify code formatting (google-java-format)
3. `test` - Execute the full test suite
4. `checkstyleMain` - Lint main sources against Checkstyle rules
5. `spotbugsMain` - Static analysis for common bug patterns

#### Quick Mode (--quick flag)

Runs only fast checks for inner-loop development:

1. `compileJava` + `compileTestJava` - Verify compilation of all sources
2. `spotlessCheck` - Verify code formatting

Quick mode skips tests, Checkstyle, and SpotBugs to provide rapid feedback during active
development. Use full mode before committing or opening a pull request.

## Execution Strategy

### Build Tool Detection

Detect the project build tool in the following priority order:

1. Check for `build.gradle.kts` (Gradle Kotlin DSL - preferred)
2. Check for `build.gradle` (Gradle Groovy DSL)
3. Check for `pom.xml` (Maven)

For each build tool, prefer the project wrapper script over the system-installed binary:

- Gradle: prefer `./gradlew` over `gradle`
- Maven: prefer `./mvnw` over `mvn`

If neither build file is found, report an error and exit.

```bash
# Gradle Kotlin DSL detection
ls build.gradle.kts 2>/dev/null

# Gradle Groovy DSL detection
ls build.gradle 2>/dev/null

# Maven detection
ls pom.xml 2>/dev/null
```

#### Wrapper Detection

Check that wrapper scripts exist and are executable:

```bash
# Gradle wrapper
ls -la ./gradlew 2>/dev/null

# Maven wrapper
ls -la ./mvnw 2>/dev/null
```

If the wrapper exists but is not executable, make it executable:

```bash
chmod +x ./gradlew
chmod +x ./mvnw
```

#### Build Tool Summary

After detection, report the configuration:

```text
Build tool: Gradle (Kotlin DSL)
Wrapper: ./gradlew (v8.5)
Java version: 21.0.2 (Eclipse Temurin)
```

### Plugin Availability Detection

Before running each gate, verify the corresponding plugin is configured in the build file. Not all
projects configure every quality plugin.

For Gradle projects, check `build.gradle.kts` or `build.gradle` for plugin declarations:

```bash
# Check for Spotless
grep -q "spotless" build.gradle.kts 2>/dev/null

# Check for Checkstyle
grep -q "checkstyle" build.gradle.kts 2>/dev/null

# Check for SpotBugs
grep -q "spotbugs" build.gradle.kts 2>/dev/null
```

For Maven projects, check `pom.xml` for plugin declarations:

```bash
# Check for Spotless Maven plugin
grep -q "spotless-maven-plugin" pom.xml 2>/dev/null

# Check for Checkstyle Maven plugin
grep -q "maven-checkstyle-plugin" pom.xml 2>/dev/null

# Check for SpotBugs Maven plugin
grep -q "spotbugs-maven-plugin" pom.xml 2>/dev/null
```

If a plugin is not configured, skip that gate gracefully and note it in the report. Never fail
validation because a quality plugin is absent.

## Quality Gate Execution

### Gate 1: Compilation

Compile both main and test sources to verify the project builds.

Gradle full mode:

```bash
./gradlew compileJava compileTestJava --no-daemon
```

Gradle quick mode (identical for this gate):

```bash
./gradlew compileJava compileTestJava --no-daemon
```

Maven full mode:

```bash
./mvnw compile test-compile -q
```

Maven quick mode (identical for this gate):

```bash
./mvnw compile test-compile -q
```

Expected successful output:

```text
BUILD SUCCESSFUL in 4s
2 actionable tasks: 2 executed
```

Expected failure output:

```text
> Task :compileJava FAILED
src/main/java/com/example/service/UserService.java:23: error: cannot find symbol
    private final UserRepository repo;
                        ^
  symbol:   class UserRepository
  location: class UserService
```

Error handling:

1. If compilation fails, capture the error output
2. Parse file paths, line numbers, and error messages
3. Report specific compilation issues found
4. Compilation failure is critical - stop further gates in full mode
5. In quick mode, still continue to spotlessCheck even on compile failure

Common compilation errors to explain:

1. Cannot find symbol - missing import or dependency
2. Incompatible types - type mismatch in assignment or return
3. Method does not override or implement - missing `@Override` target
4. Package does not exist - missing dependency in build configuration

#### Gate 2: Format Checking (Spotless)

Verify code formatting against google-java-format rules.

Gradle:

```bash
./gradlew spotlessCheck --no-daemon
```

Maven:

```bash
./mvnw spotless:check -q
```

Expected successful output:

```text
BUILD SUCCESSFUL in 2s
1 actionable task: 1 executed
```

Expected failure output:

```text
> Task :spotlessJavaCheck FAILED

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':spotlessJavaCheck'.
> The following files had format violations:
    src/main/java/com/example/service/UserService.java
        @@ -12,7 +12,7 @@
        -    private final   UserRepository repo;
        +    private final UserRepository repo;
    Run './gradlew spotlessApply' to fix these violations.
```

Error handling:

1. If Spotless is not configured, skip gracefully with a note
2. If files fail formatting, list each file with the violation
3. Report the total count of files needing formatting
4. Provide the auto-fix command for convenience
5. Continue to the next gate

Auto-fix suggestion:

```text
Found 3 files with formatting violations.
Fix with: ./gradlew spotlessApply
```

If Spotless is not configured, suggest it:

```text
SKIPPED: Spotless plugin not configured.
Recommendation: Add Spotless with google-java-format for consistent formatting.
```

#### Gate 3: Test Suite (Full Mode Only)

Run the full test suite including unit and integration tests.

Gradle:

```bash
./gradlew test --no-daemon
```

Maven:

```bash
./mvnw test -q
```

Expected successful output:

```text
BUILD SUCCESSFUL in 18s

> Task :test
com.example.service.UserServiceTest > shouldCreateUser() PASSED
com.example.service.UserServiceTest > shouldRejectDuplicateEmail() PASSED
com.example.repository.UserRepositoryTest > shouldFindByEmail() PASSED

3 tests completed, 3 passed
```

Expected failure output:

```text
> Task :test FAILED

com.example.service.UserServiceTest > shouldCreateUser() FAILED
    org.opentest4j.AssertionFailedError: expected: <"user@example.com"> but was: <null>
        at app//org.junit.jupiter.api.AssertionUtils.failNotEqual(AssertionUtils.java:55)
        at app//com.example.service.UserServiceTest.shouldCreateUser(UserServiceTest.java:42)

1 tests completed, 0 passed, 1 failed
```

Error handling:

1. Capture test failures with class name, method, and assertion error
2. Parse the stack trace to identify the failing line
3. Report total tests run, passed, failed, and skipped
4. Report test execution time per class
5. Continue to next gate even on test failure

Test report location (for detailed review):

```text
Gradle: build/reports/tests/test/index.html
Maven:  target/surefire-reports/
```

#### Gate 4: Checkstyle (Full Mode Only)

Run Checkstyle for style and convention enforcement.

Gradle:

```bash
./gradlew checkstyleMain --no-daemon
```

Maven:

```bash
./mvnw checkstyle:check -q
```

Expected successful output:

```text
BUILD SUCCESSFUL in 3s
1 actionable task: 1 executed
```

Expected failure output:

```text
> Task :checkstyleMain FAILED

[WARN] src/main/java/com/example/service/UserService.java:15:5:
  Missing a Javadoc comment. [MissingJavadocMethod]
[ERROR] src/main/java/com/example/service/UserService.java:23:120:
  Line is longer than 120 characters. [LineLength]
[ERROR] src/main/java/com/example/service/UserService.java:31:9:
  'if' is not followed by whitespace. [WhitespaceAround]
```

Error handling:

1. If Checkstyle is not configured, skip gracefully with a note
2. Parse violations by file, line, and rule name
3. Group issues by severity: ERROR vs WARN
4. Count total issues and issues per rule
5. Explain common rules and how to fix violations
6. Continue to next gate

Common Checkstyle rules to explain:

1. MissingJavadocMethod - add Javadoc to public methods
2. LineLength - break long lines or extract variables
3. WhitespaceAround - ensure spaces around operators and keywords
4. AvoidStarImport - use explicit imports instead of wildcards
5. UnusedImports - remove imports that are not referenced
6. NeedBraces - always use braces for if/for/while blocks

Never suggest adding `@SuppressWarnings("checkstyle:...")` annotations. Always fix the underlying
issue.

#### Gate 5: SpotBugs (Full Mode Only)

Run SpotBugs static analysis for common bug patterns and security issues.

Gradle:

```bash
./gradlew spotbugsMain --no-daemon
```

Maven:

```bash
./mvnw spotbugs:check -q
```

Expected successful output:

```text
BUILD SUCCESSFUL in 5s
1 actionable task: 1 executed
```

Expected failure output:

```text
> Task :spotbugsMain FAILED

SpotBugs rule violations were found.
See the report at: file:///project/build/reports/spotbugs/main.html

M B NP: Possible null pointer dereference in com.example.service.UserService.findUser(String)
  At UserService.java:[line 45]
H S SQL: com.example.repository.UserRepository.findByName(String) passes a nonconstant String
  to an execute method on an SQL statement  At UserRepository.java:[line 67]
```

Error handling:

1. If SpotBugs is not configured, skip gracefully with a note
2. Parse findings by category, severity, and location
3. Explain the bug pattern and its implications
4. Prioritize HIGH confidence findings
5. Flag security-related findings (SQL injection, path traversal, etc.) as critical

SpotBugs severity levels:

1. **HIGH confidence** - very likely a real bug, must fix
2. **MEDIUM confidence** - probable issue, should investigate
3. **LOW confidence** - possible issue, review if time permits

Common SpotBugs categories to explain:

1. NP (Null Pointer) - add null checks or use Optional
2. SQL (SQL Injection) - use parameterized queries
3. RCN (Redundant Null Check) - simplify null handling logic
4. EI (Exposing Internal) - return defensive copies of mutable fields
5. MS (Mutable Static) - make static fields final or use proper synchronization
6. SE (Serialization) - implement Serializable correctly or mark as non-serializable

Never suggest adding `@SuppressWarnings("spotbugs:...")` or `@SuppressFBWarnings` annotations.
Always fix the underlying issue or explain why it is a false positive.

## Result Reporting

After all gates complete, provide a comprehensive summary.

### Success Report Format

```text
=== Java Validation: PASSED ===

Build tool: Gradle (Kotlin DSL) via ./gradlew
Java: 21.0.2 (Eclipse Temurin)

  compile        PASSED (4.2s)
  spotlessCheck  PASSED (1.8s)
  test           PASSED (18.3s) - 47 tests, 0 failures
  checkstyleMain PASSED (2.9s)
  spotbugsMain   PASSED (4.7s)

Total time: 31.9s
All quality gates passed. Code is ready for commit/merge.
```

#### Failure Report Format

```text
=== Java Validation: FAILED ===

Build tool: Gradle (Kotlin DSL) via ./gradlew
Java: 21.0.2 (Eclipse Temurin)

  compile        PASSED  (4.1s)
  spotlessCheck  FAILED  (1.6s) - 3 files need formatting
  test           FAILED  (12.8s) - 2 failures out of 47 tests
  checkstyleMain FAILED  (2.7s) - 8 violations (5 error, 3 warn)
  spotbugsMain   PASSED  (4.5s)

Total time: 25.7s

Critical issues found:
1. Format violations in 3 files (fix with: ./gradlew spotlessApply)
2. Test failures in com.example.service.UserServiceTest
3. 5 Checkstyle errors must be resolved

Fix these issues before committing.
```

#### Quick Mode Report Format

```text
=== Java Validation: PASSED (quick mode) ===

Build tool: Gradle (Kotlin DSL) via ./gradlew
Java: 21.0.2 (Eclipse Temurin)

  compileJava      PASSED (3.1s)
  compileTestJava  PASSED (1.9s)
  spotlessCheck    PASSED (1.7s)

Total time: 6.7s
Quick validation passed. Run full validation before merge.
```

#### Skipped Gate Report Format

When plugins are not configured, report the skipped gates clearly:

```text
=== Java Validation: PASSED (with skips) ===

Build tool: Maven via ./mvnw
Java: 21.0.2 (Eclipse Temurin)

  compile        PASSED  (5.1s)
  spotlessCheck  SKIPPED - plugin not configured
  test           PASSED  (22.4s) - 31 tests, 0 failures
  checkstyleMain SKIPPED - plugin not configured
  spotbugsMain   SKIPPED - plugin not configured

Total time: 27.5s

Note: 3 quality gates were skipped because plugins are not configured.
Consider adding Spotless, Checkstyle, and SpotBugs for comprehensive validation.
```

### Detailed Issue Reporting

For each failed gate, provide actionable details.

#### Compilation Error Details

```text
Compilation Error Details:
  src/main/java/com/example/service/UserService.java:23
    error: cannot find symbol - class UserRepository
    Possible fix: Add missing import or verify dependency is declared

  src/main/java/com/example/model/User.java:45
    error: incompatible types: String cannot be converted to int
    Possible fix: Use Integer.parseInt() or correct the type declaration
```

#### Formatting Violation Details

```text
Spotless Format Violations:
  3 files need formatting:
    - src/main/java/com/example/service/UserService.java
    - src/main/java/com/example/model/User.java
    - src/test/java/com/example/service/UserServiceTest.java

  Fix all with: ./gradlew spotlessApply
  Or for Maven: ./mvnw spotless:apply
```

#### Test Failure Details

```text
Test Failure Details:
  Class: com.example.service.UserServiceTest
  Method: shouldCreateUser
  File: UserServiceTest.java:42
  Error: expected: <"user@example.com"> but was: <null>

  Class: com.example.service.UserServiceTest
  Method: shouldRejectDuplicateEmail
  File: UserServiceTest.java:67
  Error: Expected exception EmailAlreadyExistsException was not thrown

  Full report: build/reports/tests/test/index.html
```

#### Checkstyle Violation Details

```text
Checkstyle Violation Details:
  ERROR violations (5):
    - UserService.java:23   LineLength - Line is longer than 120 characters
    - UserService.java:31   WhitespaceAround - 'if' not followed by whitespace
    - UserService.java:45   AvoidStarImport - Using wildcard import
    - UserRepository.java:12 MissingJavadocMethod - Missing Javadoc comment
    - User.java:8           UnusedImports - Unused import java.util.List

  WARN violations (3):
    - UserService.java:15   MissingJavadocMethod - Missing Javadoc comment
    - User.java:22          MagicNumber - Magic number: 100
    - User.java:23          MagicNumber - Magic number: 255

  Fix each violation directly. Do not use @SuppressWarnings.
```

#### SpotBugs Finding Details

```text
SpotBugs Finding Details:
  HIGH confidence (1):
    - UserRepository.java:67 SQL_INJECTION
      SQL query built with string concatenation.
      Fix: Use PreparedStatement with parameterized queries.

  MEDIUM confidence (2):
    - UserService.java:45 NP_NULL_ON_SOME_PATH
      Possible null pointer dereference of findUser() return value.
      Fix: Check for null or use Optional.

    - User.java:12 EI_EXPOSE_REP
      Returning mutable Date field directly.
      Fix: Return defensive copy - new Date(this.createdAt.getTime())
```

## Configuration File Detection

Check for and respect project configuration files.

### Checkstyle Configuration

Look for Checkstyle configuration:

```bash
# Common locations
ls config/checkstyle/checkstyle.xml 2>/dev/null
ls checkstyle.xml 2>/dev/null
ls src/main/resources/checkstyle.xml 2>/dev/null
```

Report which configuration is in use:

```text
Using Checkstyle config: config/checkstyle/checkstyle.xml
Based on: Google Java Style (modified)
```

#### SpotBugs Configuration

Look for SpotBugs exclusion filters:

```bash
# Common locations
ls config/spotbugs/exclude.xml 2>/dev/null
ls spotbugs-exclude.xml 2>/dev/null
```

#### Spotless Configuration

Spotless is configured in the build file. Report the formatter in use:

```text
Spotless config: google-java-format 1.19.2
License header: NONE
Import ordering: standard
```

## Error Recovery Patterns

### Build Configuration Errors

If the build tool itself fails to run:

1. Check Java version compatibility: `java -version`
2. Check Gradle/Maven version: `./gradlew --version` or `./mvnw --version`
3. Verify wrapper files are present and executable
4. Suggest running `./gradlew wrapper --gradle-version=8.5` if wrapper is broken

#### Dependency Resolution Failures

If dependencies cannot be resolved:

Gradle:

```bash
./gradlew dependencies --refresh-dependencies --no-daemon
```

Maven:

```bash
./mvnw dependency:resolve -U
```

#### Out of Memory

If the JVM runs out of memory during analysis:

```bash
# Gradle: set in gradle.properties
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m

# Maven: set MAVEN_OPTS
export MAVEN_OPTS="-Xmx2g -XX:MaxMetaspaceSize=512m"
```

## Multi-Module Project Support

### Detecting Multi-Module Projects

For Gradle, check for `settings.gradle.kts` or `settings.gradle`:

```bash
grep "include" settings.gradle.kts 2>/dev/null
```

For Maven, check for module declarations in the parent pom.xml:

```bash
grep "<module>" pom.xml 2>/dev/null
```

#### Running Gates on Multi-Module Projects

Run gates from the root project to cover all modules:

Gradle:

```bash
./gradlew compileJava compileTestJava --no-daemon
./gradlew spotlessCheck --no-daemon
./gradlew test --no-daemon
./gradlew checkstyleMain --no-daemon
./gradlew spotbugsMain --no-daemon
```

Maven:

```bash
./mvnw compile test-compile -q
./mvnw spotless:check -q
./mvnw test -q
./mvnw checkstyle:check -q
./mvnw spotbugs:check -q
```

Report results per module when failures occur:

```text
=== Multi-Module Validation ===

Module: core
  compile        PASSED
  test           PASSED (12 tests)

Module: service
  compile        PASSED
  test           FAILED (3 failures out of 24 tests)

Module: web
  compile        FAILED
```

## Performance Optimization

### Gradle Build Cache

Leverage Gradle's build cache for faster subsequent runs:

```bash
# Ensure build cache is enabled (default in modern Gradle)
./gradlew compileJava --build-cache --no-daemon
```

#### Gradle Parallel Execution

Enable parallel task execution for multi-module projects:

```bash
./gradlew test --parallel --no-daemon
```

#### Maven Parallel Builds

Use Maven's parallel thread option:

```bash
./mvnw test -T 1C -q
```

The `-T 1C` flag uses one thread per CPU core.

#### Avoiding Redundant Work

When running full validation, chain tasks in a single invocation to share the build cache:

Gradle:

```bash
./gradlew compileJava compileTestJava spotlessCheck test checkstyleMain spotbugsMain --no-daemon
```

Maven:

```bash
./mvnw compile test-compile spotless:check test checkstyle:check spotbugs:check -q
```

However, for clear reporting, run each gate separately to capture individual timing and output.

## Common Patterns

### CI/CD Integration

Full mode is appropriate for CI. Use the single-invocation form for speed:

```yaml
# GitHub Actions example
- name: Validate Java code
  run:
    ./gradlew compileJava compileTestJava spotlessCheck test checkstyleMain spotbugsMain --no-daemon
```

#### Pre-commit Hook

Use quick mode for pre-commit validation:

```bash
#!/bin/bash
# .git/hooks/pre-commit
./gradlew compileJava compileTestJava spotlessCheck --no-daemon
```

#### Development Workflow

Recommended workflow:

1. Make changes
2. Run `validate --quick` frequently during development
3. Before commit, run full `validate`
4. Fix all issues before pushing

## Best Practices Enforcement

### Non-Negotiable Rules

1. Never suggest adding `@SuppressWarnings` annotations for quality gate findings
2. Never suggest `@SuppressFBWarnings` to silence SpotBugs
3. Never suggest Checkstyle `@SuppressWarnings("checkstyle:...")` overrides
4. Format issues must be fixed, not suppressed
5. SQL injection findings are critical and must be addressed
6. Null pointer warnings should be resolved with proper null handling

#### Code Quality Standards

1. All public classes and methods should have Javadoc
2. Error handling should use specific exception types
3. Use `try-with-resources` for AutoCloseable resources
4. Prefer immutable objects and final fields
5. Follow the google-java-format conventions

#### Security Requirements

1. SpotBugs security findings (SQL injection, XSS, path traversal) are critical
2. Never suggest disabling security-related checks
3. Report OWASP-related findings with remediation guidance
4. Encourage parameterized queries over string concatenation

## Output Formatting

Use consistent formatting for readability:

1. Gate names left-aligned with status right-aligned
2. Timing information in parentheses
3. File paths relative to project root
4. Line numbers included for all issues
5. Clear separation between gates
6. Summary section at the end with total time

## Exit Codes

Return appropriate exit codes for scripting:

1. `0` - All gates passed (or passed with skipped gates)
2. `1` - One or more gates failed
3. `2` - Command error (no build file found, invalid arguments, wrapper missing)

## Final Validation

Before reporting results:

1. Ensure all gates were attempted (or skipped with documented reason)
2. Provide clear pass/fail/skip for each gate
3. Include timing information for each gate
4. Give actionable next steps for any failures
5. Report the full command to auto-fix formatting if applicable
6. Never leave the user guessing what to do next
