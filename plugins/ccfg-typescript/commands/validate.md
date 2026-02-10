---
description: Run TypeScript quality gates - typecheck, lint, test, format
argument-hint: '[--quick]'
allowed-tools:
  Bash(npx *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(bun *), Bash(git *), Read, Grep, Glob
---

# TypeScript Validation Command

This command runs comprehensive TypeScript quality gates to ensure code quality, type safety, and
formatting consistency. It automatically detects the package manager and available tools, then
executes the appropriate checks.

## Command Behavior

### Package Manager Detection

The command detects the package manager in the following priority order:

1. Check `package.json` for `packageManager` field
2. Check for `pnpm-lock.yaml` (use pnpm)
3. Check for `yarn.lock` (use yarn)
4. Check for `bun.lockb` (use bun)
5. Check for `package-lock.json` (use npm)
6. Default to npm if no lockfile found

### Execution Modes

#### Full Mode (default)

Runs all available quality gates:

1. **Type checking**: `tsc --noEmit`
2. **Linting**: `eslint .` or `eslint . --ext .ts,.tsx,.js,.jsx`
3. **Testing**: `vitest run` or `jest --passWithNoTests`
4. **Formatting**: `prettier --check .`

#### Quick Mode (--quick flag)

Runs only critical checks for fast feedback:

1. **Type checking**: `tsc --noEmit`
2. **Linting**: `eslint .` or `eslint . --ext .ts,.tsx,.js,.jsx`

### Tool Detection and Graceful Degradation

The command must detect whether each tool is available before running:

- Check `package.json` `devDependencies` and `dependencies` for typescript, eslint, vitest, jest,
  prettier
- If a tool is missing, skip it with a clear message
- Never fail the entire validation if one tool is missing
- Report which checks were skipped at the end

## Critical Rules

### Type Safety Enforcement

**NEVER suggest or accept these patterns:**

- `@ts-ignore` comments
- `@ts-expect-error` without explanation
- `any` type usage (use `unknown` instead)
- Type assertions with `as` unless absolutely necessary
- Disabling strict mode flags

**ALWAYS enforce:**

- Strict TypeScript configuration
- Explicit return types on exported functions
- Proper type narrowing instead of type assertions
- `unknown` type for uncertain values, then narrow with type guards
- Discriminated unions for complex state
- `satisfies` operator for type validation without widening

### Linting Enforcement

**NEVER suggest:**

- `eslint-disable` comments without justification
- `eslint-disable-next-line` for fixable issues
- Disabling rules globally in config
- `// @ts-nocheck` file-level disables

**ALWAYS:**

- Fix the underlying issue instead of disabling
- If disable is necessary, require a detailed comment explaining why
- Suggest refactoring to avoid the need for disables
- Report eslint-disable comments as code smells

### Error Handling Strategy

When validation fails:

1. **Parse error output** to identify specific issues
2. **Group errors** by file and type
3. **Prioritize fixes** (type errors first, then lint, then format)
4. **Suggest fixes** with code examples
5. **Never suggest workarounds** that compromise type safety

## Implementation Steps

### Step 1: Detect Project Structure

```typescript
// Check for monorepo
const hasWorkspaces = packageJson.workspaces !== undefined;
const hasLernaJson = fs.existsSync('lerna.json');
const hasPnpmWorkspace = fs.existsSync('pnpm-workspace.yaml');
```

Use Glob to find:

```bash
# Find all package.json files
glob "package.json"
glob "packages/*/package.json"
glob "apps/*/package.json"
```

### Step 2: Detect Package Manager

```typescript
// Priority order
1. Read package.json packageManager field
2. Check for pnpm-lock.yaml
3. Check for yarn.lock
4. Check for bun.lockb
5. Check for package-lock.json
6. Default to npm
```

Read package.json:

```json
{
  "packageManager": "pnpm@8.10.0"
}
```

### Step 3: Detect Available Tools

Read package.json and check for:

```json
{
  "devDependencies": {
    "typescript": "^5.3.3",
    "eslint": "^8.56.0",
    "vitest": "^1.2.0",
    "prettier": "^3.2.4"
  }
}
```

### Step 4: Run Type Checking

```bash
# Always run if typescript is installed
npx tsc --noEmit
```

Expected output patterns:

```text
# Success
Found 0 errors in X files.

# Failure
src/components/Button.tsx(15,3): error TS2322: Type 'string' is not assignable to type 'number'.
src/utils/helpers.ts(42,10): error TS2345: Argument of type 'unknown' is not assignable to parameter of type 'string'.
```

Parse errors:

- File path
- Line and column number
- Error code
- Error message

### Step 5: Run Linting

```bash
# Try flat config first (ESLint 9+)
npx eslint .

# Fallback to extension-based (ESLint 8)
npx eslint . --ext .ts,.tsx,.js,.jsx
```

Expected output patterns:

```text
# Success
✓ X files linted

# Failure
/path/to/file.ts
  15:3  error  'foo' is assigned a value but never used  @typescript-eslint/no-unused-vars
  42:10 error  Unexpected any. Specify a different type    @typescript-eslint/no-explicit-any
```

### Step 6: Run Tests (Full Mode Only)

```bash
# Prefer vitest
npx vitest run

# Fallback to jest
npx jest --passWithNoTests
```

### Step 7: Run Formatting Check (Full Mode Only)

```bash
npx prettier --check .
```

## Example Execution Flow

### Successful Validation

```text
Detecting package manager...
Found: pnpm (via pnpm-lock.yaml)

Detecting available tools...
✓ TypeScript 5.3.3
✓ ESLint 8.56.0
✓ Vitest 1.2.0
✓ Prettier 3.2.4

Running validation checks...

[1/4] Type checking...
✓ No type errors found

[2/4] Linting...
✓ All files pass linting

[3/4] Testing...
✓ 247 tests passed (12 suites)

[4/4] Format checking...
✓ All files formatted correctly

========================================
All validation checks passed!
========================================
```

### Failed Validation with Suggestions

```text
Detecting package manager...
Found: pnpm (via pnpm-lock.yaml)

Running validation checks...

[1/4] Type checking...
✗ Found 3 type errors

src/components/Button.tsx(15,3): error TS2322
  Type 'string' is not assignable to type 'number'.

  Current code:
    const count: number = "123";

  Fix: Parse the string to a number
    const count: number = parseInt("123", 10);

src/utils/api.ts(42,10): error TS7006
  Parameter 'data' implicitly has an 'any' type.

  Current code:
    function processData(data) { }

  Fix: Add explicit type annotation
    function processData(data: unknown) {
      // Use type guard to narrow
      if (typeof data === 'object' && data !== null) {
        // Safe to use data here
      }
    }

[2/4] Linting...
✗ Found 2 linting errors

src/hooks/useAuth.ts:28:5
  error: React Hook useEffect has a missing dependency: 'fetchUser'
  @typescript-eslint/exhaustive-deps

  Fix: Add fetchUser to dependency array or wrap in useCallback

[3/4] Testing...
✗ 2 tests failed

FAIL src/components/Button.test.tsx
  ● Button › should handle click events
    Expected mock function to be called once, but it was called 0 times

[4/4] Format checking...
✗ 5 files need formatting

Run: pnpm exec prettier --write .

========================================
Validation failed
Type errors: 3
Lint errors: 2
Test failures: 2
Format issues: 5
========================================
```

## Monorepo Handling

### Detect Monorepo Structure

```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

```json
// package.json
{
  "workspaces": ["packages/*", "apps/*"]
}
```

### Workspace Validation Strategy

For monorepos, validate from the root:

```bash
# Type check all workspaces
pnpm -r exec tsc --noEmit

# Lint all workspaces
pnpm -r exec eslint .

# Test all workspaces
pnpm -r test

# Format check all workspaces
pnpm exec prettier --check .
```

### Per-Package Validation

If user specifies a package:

```bash
# Change to package directory
cd packages/ui

# Run validation in that package
pnpm run typecheck
pnpm run lint
pnpm test
```

## Advanced Type Error Analysis

### Common Type Errors and Fixes

#### Error: Implicit 'any' type

```typescript
// WRONG
function process(data) {
  return data.value;
}

// CORRECT
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    return (data as { value: unknown }).value;
  }
  throw new Error('Invalid data shape');
}

// BETTER: Use type guard
type DataWithValue = { value: string };

function isDataWithValue(data: unknown): data is DataWithValue {
  return (
    typeof data === 'object' &&
    data !== null &&
    'value' in data &&
    typeof (data as DataWithValue).value === 'string'
  );
}

function process(data: unknown) {
  if (isDataWithValue(data)) {
    return data.value; // Type-safe!
  }
  throw new Error('Invalid data shape');
}
```

#### Error: Type 'X' is not assignable to type 'Y'

```typescript
// WRONG: Force with assertion
const result = response as SuccessResponse;

// CORRECT: Validate at runtime
function isSuccessResponse(response: unknown): response is SuccessResponse {
  return (
    typeof response === 'object' &&
    response !== null &&
    'status' in response &&
    (response as { status: unknown }).status === 'success'
  );
}

const result = isSuccessResponse(response) ? response : null;
```

#### Error: Object is possibly 'undefined'

```typescript
// WRONG: Non-null assertion
const value = user!.name;

// CORRECT: Optional chaining
const value = user?.name;

// CORRECT: Explicit check
const value = user !== undefined ? user.name : 'Guest';

// CORRECT: Early return
if (user === undefined) {
  throw new Error('User is required');
}
const value = user.name;
```

## Lint Error Resolution Patterns

### No Unused Variables

```typescript
// WRONG: Disable the rule
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const unused = 42;

// CORRECT: Remove unused variable
// (just delete it)

// CORRECT: Prefix with underscore if intentionally unused
const _unused = 42; // Convention for intentionally unused

// CORRECT: Use the variable
const result = 42;
console.log(result);
```

### Exhaustive Dependency Arrays

```typescript
// WRONG: Disable the rule
useEffect(() => {
  fetchData(userId);
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, []);

// CORRECT: Include dependency
useEffect(() => {
  fetchData(userId);
}, [userId]);

// CORRECT: Wrap in useCallback if needed
const fetchDataCallback = useCallback(() => {
  fetchData(userId);
}, [userId]);

useEffect(() => {
  fetchDataCallback();
}, [fetchDataCallback]);
```

### No Explicit Any

```typescript
// WRONG: Disable or use any
const data: any = await response.json();

// CORRECT: Use unknown and narrow
const data: unknown = await response.json();
if (isValidData(data)) {
  // data is now properly typed
}

// CORRECT: Define proper type
type ApiResponse = {
  status: 'success' | 'error';
  data: UserData;
};
const data = (await response.json()) as unknown;
if (isApiResponse(data)) {
  // Type-safe usage
}
```

## Testing Integration

### Run Tests with Coverage

```bash
# Vitest
npx vitest run --coverage

# Jest
npx jest --coverage --passWithNoTests
```

### Parse Coverage Output

```text
% Stmts | % Branch | % Funcs | % Lines | Uncovered Lines
--------|----------|---------|---------|----------------
  85.32 |    78.45 |   82.14 |   85.32 |
```

### Report Coverage Gaps

```text
Testing complete: 247 tests passed

Coverage summary:
  Statements: 85.32% (below 90% threshold)
  Branches: 78.45% (below 80% threshold)
  Functions: 82.14%
  Lines: 85.32%

Files with low coverage:
  src/utils/validation.ts: 45% (lines 23-45, 67-89 uncovered)
  src/hooks/useAuth.ts: 62% (error paths not tested)

Suggestion: Run coverage command to improve specific files
```

## Format Checking

### Check Formatting

```bash
npx prettier --check .
```

### Auto-fix Formatting Issues

When format check fails, offer to fix:

```text
Format check failed: 5 files need formatting

Would you like me to run prettier --write to fix these files?

Files that need formatting:
  src/components/Button.tsx
  src/utils/helpers.ts
  src/hooks/useAuth.ts
  tests/setup.ts
  vite.config.ts
```

### Format-Only Changes

```bash
# Fix formatting
npx prettier --write .

# Verify
npx prettier --check .
```

## Git Integration

### Pre-commit Validation

Suggest adding validation to pre-commit:

```json
{
  "scripts": {
    "validate": "tsc --noEmit && eslint . && vitest run && prettier --check .",
    "validate:quick": "tsc --noEmit && eslint ."
  }
}
```

With husky:

```bash
#!/bin/sh
npm run validate:quick
```

### CI Integration

Suggest GitHub Actions workflow:

```yaml
name: Validate
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: pnpm install
      - run: pnpm run validate
```

## Error Recovery Strategies

### When TypeScript Compilation Fails

1. Run `tsc --noEmit --pretty` for better error messages
2. Identify the root cause (missing types, wrong configuration, etc.)
3. Check tsconfig.json for misconfigurations
4. Verify all dependencies are installed
5. Check for circular dependencies

### When ESLint Fails to Run

1. Check if eslint is installed
2. Verify eslint config exists (eslint.config.js or .eslintrc.cjs)
3. Check for conflicting plugins
4. Try `npx eslint --debug` for detailed errors
5. Verify file extensions are configured

### When Tests Fail

1. Check if test framework is installed
2. Verify test config exists (vitest.config.ts or jest.config.js)
3. Check for missing test setup files
4. Verify test files follow naming convention
5. Check for environment issues (jsdom, node, etc.)

## Performance Optimization

### Parallel Execution

For independent checks, run in parallel:

```bash
# Run typecheck and lint simultaneously
pnpm exec tsc --noEmit & pnpm exec eslint . & wait
```

### Incremental Checking

For large projects:

```bash
# TypeScript incremental compilation
tsc --noEmit --incremental

# ESLint cache
eslint . --cache

# Vitest watch mode (not in CI)
vitest --watch
```

### Selective Validation

For monorepos with many packages:

```bash
# Only validate changed packages
pnpm --filter @myorg/changed-package validate
```

## Output Formatting

### Summary Format

```text
========================================
TypeScript Validation Results
========================================

Package Manager: pnpm 8.10.0
Mode: Full validation

Checks run:
  [✓] Type checking (0 errors)
  [✓] Linting (0 errors, 2 warnings)
  [✓] Testing (247 passed, 0 failed)
  [✓] Format checking (all files formatted)

Warnings:
  - src/utils/deprecated.ts uses deprecated API

Duration: 12.4s

========================================
Status: PASSED
========================================
```

### Detailed Error Format

```text
Type Errors (3)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

src/components/Button.tsx:15:3
TS2322: Type 'string' is not assignable to type 'number'

   13 | function Counter() {
   14 |   const [count, setCount] = useState<number>(0);
 > 15 |   setCount("123");
      |   ^^^^^^^^^^^^^^^^
   16 |   return <div>{count}</div>;
   17 | }

Fix: Parse string to number
  setCount(parseInt("123", 10));

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Configuration File Validation

### Check tsconfig.json

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

Verify strict mode is enabled:

```typescript
const config = JSON.parse(fs.readFileSync('tsconfig.json', 'utf-8'));
if (config.compilerOptions?.strict !== true) {
  console.warn('⚠ strict mode is not enabled in tsconfig.json');
}
```

### Check ESLint Configuration

Look for flat config (eslint.config.js) or legacy (.eslintrc.cjs):

```javascript
// eslint.config.js (flat config)
export default [js.configs.recommended, ...tseslint.configs.strictTypeChecked];
```

### Check Prettier Configuration

```json
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100
}
```

## Tool Version Compatibility

### Check Tool Versions

```bash
npx tsc --version
npx eslint --version
npx vitest --version
npx prettier --version
```

### Warn About Version Issues

```text
⚠ Version compatibility issues detected:

TypeScript 5.3.3 is installed, but @typescript-eslint/parser 6.0.0
expects TypeScript ^5.0.0 || ^5.1.0

Consider upgrading @typescript-eslint packages:
  pnpm add -D @typescript-eslint/parser@latest @typescript-eslint/eslint-plugin@latest
```

## Exit Codes and Status

Return appropriate exit codes:

- 0: All checks passed
- 1: At least one check failed
- 2: Configuration error (missing tools, invalid config)

## Final Output Template

```text
========================================
TypeScript Validation Complete
========================================

Package Manager: [detected package manager]
Mode: [full|quick]
Duration: [time in seconds]

Results:
  Type Check: [PASS|FAIL] ([X] errors)
  Linting: [PASS|FAIL] ([X] errors, [Y] warnings)
  Testing: [PASS|FAIL|SKIP] ([X] passed, [Y] failed)
  Formatting: [PASS|FAIL|SKIP] ([X] files need formatting)

[If failures, show detailed breakdown]

[If all passed]
✓ All validation checks passed!

[If failures]
✗ Validation failed
  [Actionable suggestions for fixes]

========================================
```
