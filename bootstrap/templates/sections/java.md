## Java Conventions

- Toolchain: Maven or Gradle (build), JUnit 5 (test), Checkstyle or Spotless (format)
- Prefer records for data carriers (Java 16+)
- Use sealed interfaces for closed hierarchies (Java 17+)
- Pattern matching: instanceof with binding variables (Java 16+)
- Prefer `Optional` over nullable returns for query methods
- Dependency injection via constructor (not field injection)
- Test classes: `*Test.java`, methods: `@Test void shouldDescribeBehavior()`
- Logging: SLF4J facade (not `System.out.println`)
