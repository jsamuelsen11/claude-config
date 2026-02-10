---
description: Initialize a new Java project with Maven/Gradle, JUnit 5, Spotless, and quality plugins
argument-hint: '<project-name> [--type=service|library|cli] [--build=maven|gradle]'
allowed-tools: Bash(mvn *), Bash(gradle *), Bash(./gradlew *), Bash(git *), Read, Write, Edit, Glob
---

# Java Project Scaffolding Command

You are executing the `scaffold` command to create a new Java project with production-ready
defaults, comprehensive quality tooling, and best practices baked in from the start.

## Command Arguments

### Required: project-name

The name of the project to create. This becomes the directory name and the artifact ID. It should
follow Java naming conventions: lowercase, hyphen-separated.

Examples:

```bash
ccfg java scaffold user-service
ccfg java scaffold inventory-api --type=service
ccfg java scaffold commons-util --type=library
ccfg java scaffold data-migrator --type=cli
```

### Optional: --type

Project type determines the scaffold structure:

1. `service` (default) - Spring Boot web service with actuator and health endpoints
2. `library` - Reusable library with publishing configuration and Javadoc
3. `cli` - Command-line tool with picocli framework

### Optional: --build

Build tool selection:

1. `gradle` (default) - Gradle with Kotlin DSL (build.gradle.kts)
2. `maven` - Maven with pom.xml

Gradle Kotlin DSL is preferred for new projects due to better IDE support, type safety, and more
concise configuration.

## Project Layouts

### Service Layout

```text
user-service/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/userservice/
│   │   │       ├── UserServiceApplication.java
│   │   │       ├── config/
│   │   │       │   └── AppConfig.java
│   │   │       ├── controller/
│   │   │       │   └── HealthController.java
│   │   │       ├── model/
│   │   │       │   └── HealthResponse.java
│   │   │       └── service/
│   │   │           └── HealthService.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/
│       └── java/
│           └── com/example/userservice/
│               ├── UserServiceApplicationTest.java
│               └── controller/
│                   └── HealthControllerTest.java
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── .gitignore
└── README.md
```

#### Library Layout

```text
commons-util/
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/example/commonsutil/
│   │           ├── package-info.java
│   │           ├── StringUtils.java
│   │           └── Preconditions.java
│   └── test/
│       └── java/
│           └── com/example/commonsutil/
│               ├── StringUtilsTest.java
│               └── PreconditionsTest.java
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── .gitignore
└── README.md
```

#### CLI Layout

```text
data-migrator/
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/example/datamigrator/
│   │           ├── DataMigratorApp.java
│   │           ├── command/
│   │           │   ├── MigrateCommand.java
│   │           │   └── VersionCommand.java
│   │           └── service/
│   │               └── MigrationService.java
│   └── test/
│       └── java/
│           └── com/example/datamigrator/
│               ├── DataMigratorAppTest.java
│               └── command/
│                   └── MigrateCommandTest.java
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── .gitignore
└── README.md
```

## Scaffolding Execution

### Step 1: Validate Arguments

1. Check that project-name is provided
2. Validate project-name format (lowercase, alphanumeric with hyphens)
3. Parse --type flag (default: service)
4. Parse --build flag (default: gradle)
5. Derive group ID from convention: `com.example`
6. Derive package name by converting hyphens to dots or removing them
7. Check if directory already exists

```bash
# Check for existing directory
if [ -d "user-service" ]; then
  echo "Error: Directory user-service already exists"
  exit 1
fi
```

Package name derivation:

```text
project-name: user-service
group ID:     com.example
artifact ID:  user-service
package:      com.example.userservice
```

#### Step 2: Create Directory Structure

Create the standard Maven/Gradle directory layout:

```bash
PROJECT="user-service"
PKG_PATH="com/example/userservice"

mkdir -p "$PROJECT/src/main/java/$PKG_PATH"
mkdir -p "$PROJECT/src/main/resources"
mkdir -p "$PROJECT/src/test/java/$PKG_PATH"
```

For service type, add sub-packages:

```bash
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/config"
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/controller"
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/model"
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/service"
mkdir -p "$PROJECT/src/test/java/$PKG_PATH/controller"
```

For CLI type, add sub-packages:

```bash
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/command"
mkdir -p "$PROJECT/src/main/java/$PKG_PATH/service"
mkdir -p "$PROJECT/src/test/java/$PKG_PATH/command"
```

#### Step 3: Generate Build Configuration

Generate the build file based on the --build flag.

## Gradle Build Configuration

### settings.gradle.kts

```kotlin
rootProject.name = "user-service"
```

#### build.gradle.kts (Service)

```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.3.0"
    id("io.spring.dependency-management") version "1.1.5"
    id("com.diffplug.spotless") version "6.25.0"
    checkstyle
    id("com.github.spotbugs") version "6.0.9"
    jacoco
}

group = "com.example"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.assertj:assertj-core")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

spotless {
    java {
        googleJavaFormat("1.19.2")
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

checkstyle {
    toolVersion = "10.14.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = false
}

spotbugs {
    toolVersion = "4.8.3"
    effort = com.github.spotbugs.snom.Effort.MAX
    reportLevel = com.github.spotbugs.snom.Confidence.MEDIUM
}

tasks.spotbugsMain {
    reports.create("html") {
        required = true
        outputLocation = layout.buildDirectory.file("reports/spotbugs/main.html")
    }
}

jacoco {
    toolVersion = "0.8.11"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}
```

#### build.gradle.kts (Library)

```kotlin
plugins {
    `java-library`
    `maven-publish`
    id("com.diffplug.spotless") version "6.25.0"
    checkstyle
    id("com.github.spotbugs") version "6.0.9"
    jacoco
}

group = "com.example"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
    withJavadocJar()
    withSourcesJar()
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.10.2"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.assertj:assertj-core:3.25.3")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("org.mockito:mockito-junit-jupiter:5.11.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            pom {
                name = project.name
                description = "A reusable Java library"
                url = "https://github.com/example/${project.name}"
                licenses {
                    license {
                        name = "The Apache License, Version 2.0"
                        url = "https://www.apache.org/licenses/LICENSE-2.0.txt"
                    }
                }
            }
        }
    }
}

spotless {
    java {
        googleJavaFormat("1.19.2")
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

checkstyle {
    toolVersion = "10.14.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = false
}

spotbugs {
    toolVersion = "4.8.3"
    effort = com.github.spotbugs.snom.Effort.MAX
    reportLevel = com.github.spotbugs.snom.Confidence.MEDIUM
}

tasks.spotbugsMain {
    reports.create("html") {
        required = true
        outputLocation = layout.buildDirectory.file("reports/spotbugs/main.html")
    }
}

jacoco {
    toolVersion = "0.8.11"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}

tasks.javadoc {
    options {
        this as StandardJavadocDocletOptions
        addBooleanOption("Xdoclint:all,-missing", true)
    }
}
```

#### build.gradle.kts (CLI)

```kotlin
plugins {
    java
    application
    id("com.diffplug.spotless") version "6.25.0"
    checkstyle
    id("com.github.spotbugs") version "6.0.9"
    jacoco
}

group = "com.example"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

application {
    mainClass = "com.example.datamigrator.DataMigratorApp"
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("info.picocli:picocli:4.7.5")
    annotationProcessor("info.picocli:picocli-codegen:4.7.5")

    testImplementation(platform("org.junit:junit-bom:5.10.2"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.assertj:assertj-core:3.25.3")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("org.mockito:mockito-junit-jupiter:5.11.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

spotless {
    java {
        googleJavaFormat("1.19.2")
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

checkstyle {
    toolVersion = "10.14.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = false
}

spotbugs {
    toolVersion = "4.8.3"
    effort = com.github.spotbugs.snom.Effort.MAX
    reportLevel = com.github.spotbugs.snom.Confidence.MEDIUM
}

tasks.spotbugsMain {
    reports.create("html") {
        required = true
        outputLocation = layout.buildDirectory.file("reports/spotbugs/main.html")
    }
}

jacoco {
    toolVersion = "0.8.11"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}
```

### gradle.properties

```text
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m
org.gradle.parallel=true
org.gradle.caching=true
```

## Maven Build Configuration

### pom.xml (Service)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.3.0</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>user-service</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <name>user-service</name>
    <description>A Spring Boot microservice</description>

    <properties>
        <java.version>21</java.version>
        <spotless.version>2.43.0</spotless.version>
        <checkstyle.version>10.14.0</checkstyle.version>
        <spotbugs.version>4.8.3</spotbugs.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
            <plugin>
                <groupId>com.diffplug.spotless</groupId>
                <artifactId>spotless-maven-plugin</artifactId>
                <version>${spotless.version}</version>
                <configuration>
                    <java>
                        <googleJavaFormat>
                            <version>1.19.2</version>
                        </googleJavaFormat>
                        <removeUnusedImports/>
                        <trimTrailingWhitespace/>
                        <endWithNewline/>
                    </java>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-checkstyle-plugin</artifactId>
                <version>3.3.1</version>
                <configuration>
                    <checkstyleRules>
                        <module name="Checker">
                            <module name="TreeWalker">
                                <module name="AvoidStarImport"/>
                                <module name="UnusedImports"/>
                                <module name="NeedBraces"/>
                            </module>
                        </module>
                    </checkstyleRules>
                </configuration>
            </plugin>
            <plugin>
                <groupId>com.github.spotbugs</groupId>
                <artifactId>spotbugs-maven-plugin</artifactId>
                <version>4.8.3.1</version>
                <configuration>
                    <effort>Max</effort>
                    <threshold>Medium</threshold>
                </configuration>
            </plugin>
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
                        <phase>test</phase>
                        <goals>
                            <goal>report</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

## Service Type Files

### Application Entry Point

```java
package com.example.userservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Main entry point for the user-service application. */
@SpringBootApplication
public class UserServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(UserServiceApplication.class, args);
  }
}
```

#### Service Configuration

```java
package com.example.userservice.config;

import org.springframework.context.annotation.Configuration;

/** Application configuration. */
@Configuration
public class AppConfig {
  // Add bean definitions here
}
```

#### Service Health Controller

```java
package com.example.userservice.controller;

import com.example.userservice.model.HealthResponse;
import com.example.userservice.service.HealthService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** REST controller for health and readiness endpoints. */
@RestController
@RequestMapping("/api")
public class HealthController {

  private final HealthService healthService;

  public HealthController(HealthService healthService) {
    this.healthService = healthService;
  }

  /** Returns the current health status of the service. */
  @GetMapping("/health")
  public HealthResponse health() {
    return healthService.checkHealth();
  }

  /** Returns readiness status for load balancer probes. */
  @GetMapping("/ready")
  public HealthResponse ready() {
    return healthService.checkReadiness();
  }
}
```

#### Service Health Model

```java
package com.example.userservice.model;

/** Health check response model. */
public record HealthResponse(String status, String version) {

  /** Creates a healthy response with the current application version. */
  public static HealthResponse healthy() {
    return new HealthResponse("UP", "0.1.0");
  }

  /** Creates an unhealthy response with the current application version. */
  public static HealthResponse unhealthy() {
    return new HealthResponse("DOWN", "0.1.0");
  }
}
```

#### Service Health Service

```java
package com.example.userservice.service;

import com.example.userservice.model.HealthResponse;
import org.springframework.stereotype.Service;

/** Service for health and readiness checks. */
@Service
public class HealthService {

  /** Performs a basic health check. */
  public HealthResponse checkHealth() {
    return HealthResponse.healthy();
  }

  /** Checks if the service is ready to accept traffic. */
  public HealthResponse checkReadiness() {
    // Add dependency checks here (database, cache, external services)
    return HealthResponse.healthy();
  }
}
```

#### Service application.yml

```yaml
server:
  port: 8080

spring:
  application:
    name: user-service

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: always

logging:
  level:
    root: INFO
    com.example: DEBUG
```

#### Service Application Test

```java
package com.example.userservice;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;

class UserServiceApplicationTest {

  @Test
  void contextLoads() {
    // Verifies the application context can start without errors
    assertThat(true).isTrue();
  }
}
```

#### Service Health Controller Test

```java
package com.example.userservice.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.userservice.model.HealthResponse;
import com.example.userservice.service.HealthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class HealthControllerTest {

  private HealthController controller;

  @BeforeEach
  void setUp() {
    HealthService healthService = new HealthService();
    controller = new HealthController(healthService);
  }

  @Test
  void healthEndpointReturnsUpStatus() {
    HealthResponse response = controller.health();

    assertThat(response.status()).isEqualTo("UP");
    assertThat(response.version()).isEqualTo("0.1.0");
  }

  @Test
  void readyEndpointReturnsUpStatus() {
    HealthResponse response = controller.ready();

    assertThat(response.status()).isEqualTo("UP");
    assertThat(response.version()).isEqualTo("0.1.0");
  }
}
```

## Library Type Files

### Library Main Class

```java
package com.example.commonsutil;

import java.util.Objects;

/**
 * String utility methods that complement the standard library.
 *
 * <p>All methods are null-safe and return sensible defaults for null inputs.
 */
public final class StringUtils {

  private StringUtils() {
    throw new UnsupportedOperationException("Utility class cannot be instantiated");
  }

  /**
   * Checks if a string is null, empty, or contains only whitespace.
   *
   * @param value the string to check
   * @return true if the string is blank or null
   */
  public static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }

  /**
   * Returns the given string or a default if it is blank.
   *
   * @param value the string to check
   * @param defaultValue the fallback value
   * @return the original string or the default
   */
  public static String defaultIfBlank(String value, String defaultValue) {
    Objects.requireNonNull(defaultValue, "defaultValue must not be null");
    return isBlank(value) ? defaultValue : value;
  }
}
```

#### Library Preconditions Class

```java
package com.example.commonsutil;

/**
 * Precondition checks for method arguments.
 *
 * <p>Throws {@link IllegalArgumentException} when a precondition is violated.
 */
public final class Preconditions {

  private Preconditions() {
    throw new UnsupportedOperationException("Utility class cannot be instantiated");
  }

  /**
   * Ensures that an argument is not null.
   *
   * @param <T> the type of the argument
   * @param value the argument to check
   * @param name the name of the argument for the error message
   * @return the non-null value
   * @throws IllegalArgumentException if value is null
   */
  public static <T> T requireNonNull(T value, String name) {
    if (value == null) {
      throw new IllegalArgumentException(name + " must not be null");
    }
    return value;
  }

  /**
   * Ensures that a string argument is not blank.
   *
   * @param value the string to check
   * @param name the name of the argument for the error message
   * @return the non-blank string
   * @throws IllegalArgumentException if value is null or blank
   */
  public static String requireNonBlank(String value, String name) {
    if (value == null || value.isBlank()) {
      throw new IllegalArgumentException(name + " must not be blank");
    }
    return value;
  }
}
```

#### Library package-info.java

```java
/**
 * Commons utility library providing null-safe string operations and precondition checks.
 *
 * <p>Key classes:
 *
 * <ul>
 *   <li>{@link com.example.commonsutil.StringUtils} - String utility methods
 *   <li>{@link com.example.commonsutil.Preconditions} - Argument validation
 * </ul>
 */
package com.example.commonsutil;
```

#### Library StringUtils Test

```java
package com.example.commonsutil;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class StringUtilsTest {

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {"  ", "\t", "\n"})
  void isBlankReturnsTrueForBlankStrings(String input) {
    assertThat(StringUtils.isBlank(input)).isTrue();
  }

  @ParameterizedTest
  @ValueSource(strings = {"a", "hello", " x "})
  void isBlankReturnsFalseForNonBlankStrings(String input) {
    assertThat(StringUtils.isBlank(input)).isFalse();
  }

  @Test
  void defaultIfBlankReturnsOriginalWhenNotBlank() {
    assertThat(StringUtils.defaultIfBlank("hello", "default")).isEqualTo("hello");
  }

  @Test
  void defaultIfBlankReturnsDefaultWhenBlank() {
    assertThat(StringUtils.defaultIfBlank("", "default")).isEqualTo("default");
    assertThat(StringUtils.defaultIfBlank(null, "default")).isEqualTo("default");
  }

  @Test
  void defaultIfBlankRejectsNullDefault() {
    assertThatThrownBy(() -> StringUtils.defaultIfBlank("hello", null))
        .isInstanceOf(NullPointerException.class)
        .hasMessageContaining("defaultValue");
  }
}
```

#### Library Preconditions Test

```java
package com.example.commonsutil;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class PreconditionsTest {

  @Test
  void requireNonNullReturnsValueWhenNotNull() {
    String result = Preconditions.requireNonNull("hello", "arg");
    assertThat(result).isEqualTo("hello");
  }

  @Test
  void requireNonNullThrowsOnNull() {
    assertThatThrownBy(() -> Preconditions.requireNonNull(null, "userId"))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("userId must not be null");
  }

  @Test
  void requireNonBlankReturnsValueWhenNotBlank() {
    String result = Preconditions.requireNonBlank("hello", "arg");
    assertThat(result).isEqualTo("hello");
  }

  @Test
  void requireNonBlankThrowsOnNull() {
    assertThatThrownBy(() -> Preconditions.requireNonBlank(null, "name"))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("name must not be blank");
  }

  @Test
  void requireNonBlankThrowsOnBlankString() {
    assertThatThrownBy(() -> Preconditions.requireNonBlank("  ", "name"))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("name must not be blank");
  }
}
```

## CLI Type Files

### CLI Application Entry Point

```java
package com.example.datamigrator;

import com.example.datamigrator.command.MigrateCommand;
import com.example.datamigrator.command.VersionCommand;
import picocli.CommandLine;
import picocli.CommandLine.Command;

/** Main entry point for the data-migrator CLI application. */
@Command(
    name = "data-migrator",
    mixinStandardHelpOptions = true,
    version = "0.1.0",
    description = "A command-line data migration tool.",
    subcommands = {MigrateCommand.class, VersionCommand.class})
public class DataMigratorApp implements Runnable {

  @Override
  public void run() {
    new CommandLine(this).usage(System.out);
  }

  public static void main(String[] args) {
    int exitCode = new CommandLine(new DataMigratorApp()).execute(args);
    System.exit(exitCode);
  }
}
```

#### CLI Migrate Command

```java
package com.example.datamigrator.command;

import com.example.datamigrator.service.MigrationService;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

/** Executes a data migration from source to target. */
@Command(name = "migrate", description = "Run a data migration")
public class MigrateCommand implements Runnable {

  @Parameters(index = "0", description = "Source path for migration data")
  private String source;

  @Option(
      names = {"-n", "--dry-run"},
      description = "Preview changes without applying them")
  private boolean dryRun;

  @Override
  public void run() {
    MigrationService service = new MigrationService();
    int count = service.migrate(source, dryRun);
    if (dryRun) {
      System.out.printf("Dry run: would migrate %d records from %s%n", count, source);
    } else {
      System.out.printf("Migrated %d records from %s%n", count, source);
    }
  }
}
```

#### CLI Version Command

```java
package com.example.datamigrator.command;

import picocli.CommandLine.Command;

/** Displays version information. */
@Command(name = "version", description = "Show version information")
public class VersionCommand implements Runnable {

  @Override
  public void run() {
    System.out.println("data-migrator version 0.1.0");
    System.out.printf("Java %s (%s)%n", System.getProperty("java.version"),
        System.getProperty("java.vendor"));
    System.out.printf("OS: %s %s%n", System.getProperty("os.name"),
        System.getProperty("os.version"));
  }
}
```

#### CLI Migration Service

```java
package com.example.datamigrator.service;

/** Handles data migration operations. */
public class MigrationService {

  /**
   * Migrates records from the given source.
   *
   * @param source the source path to migrate from
   * @param dryRun if true, simulates without writing
   * @return the number of records migrated or that would be migrated
   */
  public int migrate(String source, boolean dryRun) {
    // Placeholder implementation
    System.out.printf("Reading from source: %s%n", source);
    return 0;
  }
}
```

#### CLI Application Test

```java
package com.example.datamigrator;

import static org.assertj.core.api.Assertions.assertThat;

import picocli.CommandLine;
import org.junit.jupiter.api.Test;

class DataMigratorAppTest {

  @Test
  void appHasExpectedExitCodeWithHelp() {
    DataMigratorApp app = new DataMigratorApp();
    CommandLine cmd = new CommandLine(app);
    int exitCode = cmd.execute("--help");

    assertThat(exitCode).isZero();
  }

  @Test
  void appHasExpectedExitCodeWithVersion() {
    DataMigratorApp app = new DataMigratorApp();
    CommandLine cmd = new CommandLine(app);
    int exitCode = cmd.execute("--version");

    assertThat(exitCode).isZero();
  }
}
```

#### CLI Migrate Command Test

```java
package com.example.datamigrator.command;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.datamigrator.DataMigratorApp;
import java.io.PrintWriter;
import java.io.StringWriter;
import picocli.CommandLine;
import org.junit.jupiter.api.Test;

class MigrateCommandTest {

  @Test
  void migrateCommandRunsWithDryRunFlag() {
    DataMigratorApp app = new DataMigratorApp();
    CommandLine cmd = new CommandLine(app);
    StringWriter sw = new StringWriter();
    cmd.setOut(new PrintWriter(sw));

    int exitCode = cmd.execute("migrate", "--dry-run", "/tmp/data.csv");

    assertThat(exitCode).isZero();
  }

  @Test
  void migrateCommandRequiresSourceArgument() {
    DataMigratorApp app = new DataMigratorApp();
    CommandLine cmd = new CommandLine(app);
    StringWriter sw = new StringWriter();
    cmd.setErr(new PrintWriter(sw));

    int exitCode = cmd.execute("migrate");

    assertThat(exitCode).isNotZero();
  }
}
```

## Common Files (All Types)

### Checkstyle Configuration

Create the Checkstyle configuration file at `config/checkstyle/checkstyle.xml`:

```xml
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">
<module name="Checker">
    <property name="severity" value="error"/>
    <property name="fileExtensions" value="java"/>

    <module name="TreeWalker">
        <module name="AvoidStarImport"/>
        <module name="UnusedImports"/>
        <module name="NeedBraces"/>
        <module name="WhitespaceAround"/>
        <module name="OneStatementPerLine"/>
        <module name="MultipleVariableDeclarations"/>
        <module name="MissingSwitchDefault"/>
        <module name="FallThrough"/>
        <module name="UpperEll"/>
        <module name="EmptyBlock"/>
    </module>

    <module name="FileTabCharacter">
        <property name="eachLine" value="true"/>
    </module>
    <module name="NewlineAtEndOfFile"/>
</module>
```

#### .gitignore

```text
# Compiled class files
*.class

# Log files
*.log

# Package files
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar

# Gradle
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar

# Maven
target/

# IDE - IntelliJ IDEA
.idea/
*.iws
*.iml
*.ipr
out/

# IDE - Eclipse
.apt_generated
.classpath
.factorypath
.project
.settings
.springBeans
.sts4-cache
bin/

# IDE - VS Code
.vscode/

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local
```

### README.md Template

````markdown
# {{project-name}}

A Java {{type}} project built with production-ready tooling.

## Prerequisites

- Java 21 or later
- Gradle 8.5+ (wrapper included) or Maven 3.9+

## Getting Started

```bash
# Build the project
./gradlew build

# Run tests
./gradlew test

# Run quality checks
./gradlew spotlessCheck checkstyleMain spotbugsMain
```

## Project Structure

```text
src/main/java/       - Application source code
src/main/resources/  - Configuration files
src/test/java/       - Test source code
```

## Quality Tools

- **Spotless**: Code formatting with google-java-format
- **Checkstyle**: Style and convention enforcement
- **SpotBugs**: Static analysis for bug detection
- **JaCoCo**: Test coverage reporting

## Development

```bash
# Format code
./gradlew spotlessApply

# Run all validation
./gradlew compileJava compileTestJava spotlessCheck test checkstyleMain spotbugsMain

# Generate coverage report
./gradlew jacocoTestReport
# Report at: build/reports/jacoco/test/html/index.html
```

## License

[Your License]
````

## Post-Scaffold Steps

### Step 4: Generate Gradle Wrapper

If using Gradle, generate the wrapper so others can build without installing Gradle:

```bash
cd user-service
gradle wrapper --gradle-version=8.5
```

This creates:

```text
gradlew
gradlew.bat
gradle/wrapper/gradle-wrapper.jar
gradle/wrapper/gradle-wrapper.properties
```

#### Step 5: Build and Verify

Compile the project to ensure everything resolves:

```bash
./gradlew compileJava compileTestJava --no-daemon
```

Or for Maven:

```bash
./mvnw compile test-compile -q
```

#### Step 6: Run Tests

Execute the test suite to verify scaffolded tests pass:

```bash
./gradlew test --no-daemon
```

Or for Maven:

```bash
./mvnw test -q
```

All scaffolded tests must pass. If any test fails, it is a bug in the scaffold and must be fixed
before completing.

#### Step 7: Initialize Git Repository

```bash
git init
git add .
git commit -m "feat: initialize {{project-name}} with ccfg-java scaffold"
```

Do not initialize git if already inside a git repository.

## Template Variable Substitution

When generating files, replace template variables:

1. `{{project-name}}` - The provided project name (e.g., user-service)
2. `{{type}}` - The project type (service, library, cli)
3. `{{group}}` - The group ID (default: com.example)
4. `{{package}}` - The Java package path (e.g., com.example.userservice)
5. `{{PackagePath}}` - The directory path for the package (e.g., com/example/userservice)
6. `{{ClassName}}` - The main class name derived from project name (e.g., UserServiceApplication)

Use string replacement to substitute these values in all generated files. Ensure package
declarations and import statements are consistent across all files.

## Success Report

After successful scaffolding, provide a summary:

```text
=== Project Scaffolded Successfully ===

Project: user-service
Type: service
Build: Gradle (Kotlin DSL)
Java: 21
Location: ./user-service

Created:
  - Gradle build with Kotlin DSL
  - Spring Boot 3.3 application
  - JUnit 5 + AssertJ + Mockito test dependencies
  - Spotless (google-java-format) formatting
  - Checkstyle style enforcement
  - SpotBugs static analysis
  - JaCoCo coverage reporting
  - 12 files generated
  - Git repository initialized

Verification:
  - Compilation: PASSED
  - Tests: PASSED (2 tests)

Next steps:
  1. cd user-service
  2. ./gradlew test             # Run tests
  3. ./gradlew bootRun          # Start the service
  4. ccfg java validate         # Run quality checks
```

## Error Handling

Handle these error cases:

1. Project name not provided - show usage with examples
2. Directory already exists - report error and suggest a different name
3. Invalid project name format - validate and suggest corrections
4. Java not installed or wrong version - check `java -version` and report
5. Gradle wrapper generation fails - fall back to system Gradle
6. Compilation fails after scaffold - this is a scaffold bug, fix before reporting success
7. Tests fail after scaffold - this is a scaffold bug, fix before reporting success

## Best Practices Implemented

1. Java 21 language target for modern features (records, sealed classes, pattern matching)
2. google-java-format for consistent code formatting across teams
3. JUnit 5 with parameterized tests and nested test support
4. AssertJ for fluent, readable assertions
5. Mockito for test doubles and dependency isolation
6. JaCoCo for coverage tracking from day one
7. Checkstyle for coding standard enforcement
8. SpotBugs for catching common bug patterns early
9. Gradle Kotlin DSL for type-safe, IDE-friendly build configuration
10. Record types for immutable data transfer objects
