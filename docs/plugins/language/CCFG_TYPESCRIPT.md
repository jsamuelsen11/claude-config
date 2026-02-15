# Plugin: ccfg-typescript

The TypeScript language plugin. Provides framework agents for frontend and backend development,
specialist agents for testing and packaging, project scaffolding, autonomous coverage improvement,
Playwright MCP integration, and opinionated conventions for consistent TypeScript development with
ESLint, Vitest, and strict tsconfig.

## Directory Structure

```text
plugins/ccfg-typescript/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── typescript-pro.md
│   ├── react-specialist.md
│   ├── nextjs-developer.md
│   ├── angular-architect.md
│   ├── vue-specialist.md
│   ├── svelte-specialist.md
│   ├── node-backend-developer.md
│   ├── vitest-specialist.md
│   └── npm-packaging-engineer.md
├── commands/
│   ├── validate.md
│   ├── scaffold.md
│   └── coverage.md
├── skills/
│   ├── ts-conventions/
│   │   └── SKILL.md
│   ├── testing-patterns/
│   │   └── SKILL.md
│   └── packaging-conventions/
│       └── SKILL.md
└── .mcp.json
```

## plugin.json

```json
{
  "name": "ccfg-typescript",
  "description": "TypeScript language plugin: frontend and backend agents, project scaffolding, coverage automation, Playwright MCP, and conventions for consistent development with ESLint, Vitest, and strict tsconfig",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": [
    "typescript",
    "react",
    "nextjs",
    "angular",
    "vue",
    "svelte",
    "node",
    "vitest",
    "playwright"
  ],
  "suggestedPermissions": {
    "allow": [
      "Bash(npx prettier:*)",
      "Bash(npx eslint:*)",
      "Bash(npx tsc:*)",
      "Bash(npm install:*)",
      "Bash(npm run:*)"
    ]
  }
}
```

## Agents (9)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

### Framework Agents

| Agent                    | Role                                                                          | Model  |
| ------------------------ | ----------------------------------------------------------------------------- | ------ |
| `typescript-pro`         | Modern TypeScript 5+, advanced types, generics, utility types, module systems | sonnet |
| `react-specialist`       | React 18+, hooks, server components, Suspense, state management, performance  | sonnet |
| `nextjs-developer`       | Next.js 14+, App Router, server actions, ISR, middleware, deployment          | sonnet |
| `angular-architect`      | Angular 17+, signals, standalone components, RxJS, NgRx, module architecture  | sonnet |
| `vue-specialist`         | Vue 3, Composition API, Pinia, Nuxt 3, reactivity system, SFC patterns        | sonnet |
| `svelte-specialist`      | Svelte 5, runes, SvelteKit, server-side rendering, form actions               | sonnet |
| `node-backend-developer` | Express/Fastify/NestJS, server-side TS, REST/GraphQL APIs, middleware, auth   | sonnet |

### Specialist Agents

| Agent                    | Role                                                                                                            | Model  |
| ------------------------ | --------------------------------------------------------------------------------------------------------------- | ------ |
| `vitest-specialist`      | Vitest/Jest testing, React Testing Library, component testing, msw mocking, Playwright integration, coverage    | sonnet |
| `npm-packaging-engineer` | package.json, tsconfig, monorepos (turborepo/nx), npm/pnpm workspaces, publishing, bundling (vite/esbuild/tsup) | sonnet |

## Commands (3)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-typescript:validate

**Purpose**: Run the full TypeScript quality gate suite in one command.

**Trigger**: User invokes before committing or shipping TypeScript code.

**Allowed tools**:
`Bash(npx *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(bun *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Package manager detection (in priority order):

1. `packageManager` field in package.json (takes precedence)
2. `pnpm-lock.yaml` → pnpm
3. `yarn.lock` → yarn
4. `bun.lockb` → bun
5. `package-lock.json` → npm

Full mode (default):

1. **Type check**: `tsc --noEmit`
2. **Lint**: `eslint .` (if ESLint config exists, skip with notice if not)
3. **Tests**: `vitest run` (or `jest` if Jest project)
4. **Format check**: `prettier --check .` (if Prettier configured, skip with notice if not)
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Type check**: `tsc --noEmit`
2. **Lint**: `eslint .` (if configured)
3. Report pass/fail — skips tests and format check for speed

All commands run via the detected package manager's exec mechanism (`pnpm exec`, `npx`, `yarn`,
`bunx`).

**Key rules**:

- Detects package manager automatically and uses the correct one (see detection order above)
- Never suggests `@ts-ignore` or `any` casts — fix the type error
- Never suggests eslint-disable comments — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a tool is not configured (e.g., no ESLint config, no Prettier config), skip
  that gate and report it as SKIPPED. Never fail because an optional tool is missing

### /ccfg-typescript:scaffold

**Purpose**: Initialize a new TypeScript project with opinionated, production-ready defaults.

**Trigger**: User invokes when starting a new TypeScript project.

**Allowed tools**: `Bash(npm *), Bash(npx *), Bash(pnpm *), Bash(git *), Read, Write, Edit, Glob`

**Argument**: `<project-name> [--type=react|nextjs|node-api|library]`

**Behavior**:

1. Create project using appropriate tooling:
   - `react`: Vite + React template
   - `nextjs`: `create-next-app` with App Router
   - `node-api`: Express/Fastify skeleton with src/ layout
   - `library`: tsup + vitest for publishable library
2. Configure strict tsconfig.json:
   - `strict: true`, `noUncheckedIndexedAccess: true`
   - `exactOptionalPropertyTypes: true`
   - Appropriate `module`/`moduleResolution` for target
3. Set up ESLint with TypeScript plugin and strict rules
4. Set up Vitest (or Jest for Next.js if preferred)
5. Set up Prettier config
6. Initialize git repo if not inside one, verify tests pass

**Key rules**:

- Always uses strict TypeScript configuration
- Vitest preferred over Jest for new projects (faster, ESM-native)
- ESLint flat config format (eslint.config.js, not .eslintrc)
- Package manager: pnpm preferred, npm as fallback

### /ccfg-typescript:coverage

**Purpose**: Autonomous per-file test coverage improvement loop.

**Trigger**: User invokes when coverage needs to increase.

**Allowed tools**:
`Bash(npx *), Bash(npm *), Bash(pnpm *), Bash(git *), Read, Write, Edit, Grep, Glob`

**Argument**: `[--threshold=90] [--file=<path>] [--dry-run] [--no-commit]`

**Behavior**:

1. **Detect layout**: Check for monorepo indicators (`workspaces` field in package.json,
   `pnpm-workspace.yaml`). If monorepo, iterate per workspace package rather than running once at
   root
2. **Measure**: Run `vitest run --coverage` (or Jest equivalent) via detected package manager
3. **Identify**: Parse coverage report, rank files by uncovered lines
4. **Target**: For each under-threshold file: a. Read the source file and existing tests b. Identify
   untested branches, functions, and edge cases c. Write targeted tests following project's existing
   test patterns d. Run tests to confirm new tests pass e. Run lint on new test files f. Commit:
   `git add <test-file> && git commit -m "test: add coverage for <module>"`
5. **Report**: Summary table of before/after coverage per file (per package in monorepos)
6. Stop when threshold reached or all files processed

**Modes**:

- **Default**: Write tests and auto-commit after each file
- `--dry-run`: Report coverage gaps and describe what tests would be generated. No code changes
- `--no-commit`: Write tests but do not commit. User reviews before committing manually

**Key rules**:

- Reads existing tests first to match project patterns
- One commit per file (not one giant commit)
- Tests must exercise real behavior, not just satisfy coverage
- For React components: uses React Testing Library, tests user interactions not implementation
- Uses `msw` for API mocking in integration tests
- Monorepo-aware: reports coverage per workspace package, not just globally

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### ts-conventions

**Trigger description**: "This skill should be used when working on TypeScript projects, writing
TypeScript code, configuring tsconfig, or reviewing TypeScript code."

**Existing repo compatibility**: For existing projects, respect the established toolchain. Use the
project's package manager (npm, yarn, pnpm, bun), test runner (Jest, Vitest), and lint config format
(`.eslintrc.*` or `eslint.config.js`). These preferences apply to new projects and scaffold output
only.

**Type safety rules**:

- Enable `strict: true` in tsconfig. Never disable strict checks
- Never use `any` — use `unknown` and narrow with type guards
- Never use `@ts-ignore` or `@ts-expect-error` without a linked issue explaining why
- Use discriminated unions over type assertions
- Use `satisfies` operator for type-safe object literals
- Use `const` assertions for literal types (`as const`)
- Use branded types for domain primitives (e.g., `UserId`, `Email`)
- Use `Readonly<T>` for immutable data, `ReadonlyArray<T>` for arrays

**Code style rules**:

- Prefer `interface` for object shapes, `type` for unions/intersections/utilities
- Use `enum` sparingly — prefer union types of string literals
- Prefer named exports over default exports
- Use barrel exports (`index.ts`) at package boundaries only, not for every directory
- Use `import type` for type-only imports
- Async functions must return `Promise<T>`, never raw callbacks
- Use Zod or similar for runtime validation at system boundaries

**Tooling rules**:

- Use ESLint with `@typescript-eslint` plugin (flat config format)
- Use Prettier for formatting (not ESLint formatting rules)
- Use Vitest for new projects (faster, ESM-native), Jest acceptable for existing
- Use `tsx` for running TypeScript scripts directly

### testing-patterns

**Trigger description**: "This skill should be used when writing TypeScript tests, configuring
Vitest or Jest, testing React components, mocking APIs, or improving test coverage."

**Contents**:

- **Vitest preferred**: Use Vitest for new projects. Faster, ESM-native, Vite-compatible. Use
  `vitest.config.ts` separate from Vite config
- **Naming**: Test files: `<module>.test.ts` or `<module>.spec.ts`. Consistent within project.
  Describe blocks: noun (the unit). Test names: `it("should <behavior> when <condition>")`
- **React Testing Library**: Test user behavior, not implementation details. Use `screen.getByRole`
  over `getByTestId`. Fire events with `userEvent`, not `fireEvent`
- **msw (Mock Service Worker)**: Use `msw` for API mocking. Define handlers in `src/mocks/`. Use
  `server.use()` for per-test overrides
- **Snapshot testing**: Use sparingly. Prefer explicit assertions. If used, keep snapshots small and
  review them in PRs
- **Component testing**: Test props, user interactions, and rendered output. Mock child components
  only when necessary. Use `render` + `screen` pattern
- **Async testing**: Use `waitFor` for async assertions. Use `vi.useFakeTimers()` for timer-based
  code. Always `await` async operations
- **Mocking**: Use `vi.mock()` for module mocks, `vi.spyOn()` for partial mocks. Clear mocks in
  `afterEach` or use `vi.restoreAllMocks()`
- **E2E with Playwright**: Use Playwright for E2E tests. Page Object Model for complex flows. Use
  Playwright MCP for browser interaction during development

### packaging-conventions

**Trigger description**: "This skill should be used when creating or editing package.json, tsconfig,
managing npm dependencies, configuring monorepos, or publishing npm packages."

**Contents**:

- **package.json is canonical**: All project metadata, scripts, and dependency declarations in
  package.json
- **Package manager**: pnpm preferred for workspace support and disk efficiency. Use
  `packageManager` field in package.json for corepack
- **Dependency types**: `dependencies` for runtime, `devDependencies` for build/test/lint. Never put
  test frameworks in `dependencies`
- **Version pinning**: Use caret ranges (`^1.2.3`) for libraries, exact versions for apps. Always
  commit lock files (pnpm-lock.yaml, package-lock.json)
- **tsconfig structure**: Base `tsconfig.json` with extends for app/lib variants. Use project
  references for monorepos
- **Monorepos**: Use pnpm workspaces or Turborepo. Each package has its own package.json and
  tsconfig. Shared config in root
- **Bundling**: Use `tsup` for libraries (simple, zero-config), Vite for apps, esbuild for
  serverless functions
- **Publishing**: Use `"type": "module"` for ESM. Provide dual CJS/ESM with `exports` field. Include
  `types` field pointing to declaration files
- **Scripts**: Standardize: `dev`, `build`, `test`, `lint`, `typecheck`. Use `concurrently` for
  parallel scripts

## MCP Servers (.mcp.json)

| Server         | Purpose                                               | Status |
| -------------- | ----------------------------------------------------- | ------ |
| playwright-mcp | Browser automation for E2E testing and UI development | Active |

The `.mcp.json` file at plugin root configures Playwright MCP for browser-based testing and
development workflows.
