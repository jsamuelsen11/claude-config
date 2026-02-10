---
description: Autonomous per-file test coverage improvement loop
argument-hint: '[--threshold=90] [--file=<path>] [--dry-run] [--no-commit]'
allowed-tools: Bash(npx *), Bash(npm *), Bash(pnpm *), Bash(git *), Read, Write, Edit, Grep, Glob
---

# TypeScript Test Coverage Improvement Command

This command autonomously improves test coverage by analyzing coverage reports, identifying gaps,
and writing targeted tests. It operates in an intelligent loop, committing improvements
incrementally per file.

## Command Behavior

### Operating Modes

#### Full Coverage Mode (default)

Analyzes entire project coverage and improves all files below threshold.

```bash
coverage --threshold=90
```

#### Single File Mode

Targets a specific file for coverage improvement.

```bash
coverage --file=src/utils/validation.ts
```

#### Dry Run Mode

Analyzes and generates tests without committing.

```bash
coverage --dry-run
```

#### No Commit Mode

Generates tests but doesn't create git commits.

```bash
coverage --no-commit
```

## Critical Rules

### Match Project Patterns

**ALWAYS analyze existing tests** to understand:

- Testing framework (Vitest or Jest)
- File organization patterns
- Naming conventions (`*.test.ts` vs `*.spec.ts`)
- Test structure and style
- Mock patterns used
- Assertion styles

### React Testing Library for Components

**For React components, ALWAYS use:**

- `render` from @testing-library/react
- `screen` queries over destructured queries
- `userEvent` over `fireEvent`
- `waitFor` for async assertions
- `getByRole` over `getByTestId` when possible
- Accessibility-focused queries

### MSW for API Mocking

**For API calls, ALWAYS use MSW:**

- Define handlers in test setup
- Mock at network level, not function level
- Use typed request handlers
- Test both success and error responses
- Override handlers per test when needed

### Monorepo Awareness

**Detect and handle monorepo structures:**

- Identify workspace packages
- Run coverage per package
- Aggregate results
- Handle package-specific configurations
- Respect package boundaries

## Implementation Steps

### Step 1: Detect Project Structure

Use Glob to identify project type and structure.

```bash
# Check for monorepo
glob "pnpm-workspace.yaml"
glob "package.json" # Check for workspaces field
glob "lerna.json"

# Find all package.json files
glob "packages/*/package.json"
glob "apps/*/package.json"
```

Read package.json to understand testing setup:

```json
{
  "scripts": {
    "test": "vitest",
    "test:coverage": "vitest run --coverage"
  },
  "devDependencies": {
    "vitest": "^1.2.0",
    "@testing-library/react": "^14.0.0",
    "msw": "^2.0.0"
  }
}
```

### Step 2: Detect Package Manager

Priority order:

1. Read `packageManager` field from package.json
1. Check for pnpm-lock.yaml (use pnpm)
1. Check for yarn.lock (use yarn)
1. Check for bun.lockb (use bun)
1. Check for package-lock.json (use npm)
1. Default to npm

### Step 3: Run Coverage Analysis

```bash
# Vitest
pnpm exec vitest run --coverage

# Jest
pnpm exec jest --coverage
```

### Step 4: Parse Coverage Report

Read coverage/coverage-summary.json:

```json
{
  "total": {
    "lines": { "total": 1000, "covered": 850, "skipped": 0, "pct": 85 },
    "statements": { "total": 1200, "covered": 1020, "skipped": 0, "pct": 85 },
    "functions": { "total": 200, "covered": 170, "skipped": 0, "pct": 85 },
    "branches": { "total": 400, "covered": 320, "skipped": 0, "pct": 80 }
  },
  "src/utils/validation.ts": {
    "lines": { "total": 50, "covered": 30, "skipped": 0, "pct": 60 },
    "statements": { "total": 60, "covered": 36, "skipped": 0, "pct": 60 },
    "functions": { "total": 10, "covered": 6, "skipped": 0, "pct": 60 },
    "branches": { "total": 20, "covered": 10, "skipped": 0, "pct": 50 }
  }
}
```

### Step 5: Identify Files Below Threshold

```typescript
type FileCoverage = {
  path: string;
  lines: number;
  statements: number;
  functions: number;
  branches: number;
};

const filesNeedingCoverage: FileCoverage[] = Object.entries(coverageData)
  .filter(([path, data]) => path !== 'total')
  .filter(([_path, data]) => data.lines.pct < threshold)
  .map(([path, data]) => ({
    path,
    lines: data.lines.pct,
    statements: data.statements.pct,
    functions: data.functions.pct,
    branches: data.branches.pct,
  }))
  .sort((a, b) => a.lines - b.lines); // Lowest coverage first
```

### Step 6: Analyze Source File

For each file needing coverage:

1. Read the source file
1. Parse TypeScript AST (if needed)
1. Identify exported functions, classes, components
1. Check existing test file
1. Identify uncovered lines/branches

Read coverage/lcov.info for line-level detail:

```text
SF:src/utils/validation.ts
FN:1,isEmail
FN:5,isPhoneNumber
FN:10,isValidPassword
FNDA:10,isEmail
FNDA:0,isPhoneNumber
FNDA:5,isValidPassword
DA:1,10
DA:2,10
DA:3,8
DA:5,0
DA:6,0
DA:10,5
DA:11,5
DA:12,3
BRDA:3,0,0,8
BRDA:3,0,1,2
BRDA:12,1,0,3
BRDA:12,1,1,2
end_of_record
```

Parse to understand:

- FN: Function definition
- FNDA: Function execution count (0 = uncovered)
- DA: Line execution count
- BRDA: Branch execution count

### Step 7: Analyze Existing Tests

If test file exists, read it:

```bash
# Find test file
glob "src/utils/validation.test.ts"
glob "src/utils/validation.spec.ts"
glob "src/utils/__tests__/validation.ts"
glob "tests/utils/validation.test.ts"
```

Analyze existing test patterns:

```typescript
import { describe, it, expect } from 'vitest';
import { isEmail, isValidPassword } from './validation';

describe('validation', () => {
  describe('isEmail', () => {
    it('validates correct email', () => {
      expect(isEmail('test@example.com')).toBe(true);
    });

    it('rejects invalid email', () => {
      expect(isEmail('invalid')).toBe(false);
    });
  });

  // isPhoneNumber is NOT tested - gap identified!
  // isValidPassword has partial coverage - need edge cases!
});
```

### Step 8: Generate Missing Tests

Based on uncovered code, generate tests.

Example source file:

```typescript
export function isPhoneNumber(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  return /^\+?[1-9]\d{1,14}$/.test(value);
}

export function isValidPassword(value: string): boolean {
  if (value.length < 8) {
    return false;
  }
  if (!/[A-Z]/.test(value)) {
    return false;
  }
  if (!/[a-z]/.test(value)) {
    return false;
  }
  if (!/[0-9]/.test(value)) {
    return false;
  }
  return true;
}
```

Generated tests for uncovered branches:

```typescript
describe('isPhoneNumber', () => {
  it('returns false for empty string', () => {
    expect(isPhoneNumber('')).toBe(false);
  });

  it('validates E.164 format phone number', () => {
    expect(isPhoneNumber('+12025551234')).toBe(true);
  });

  it('validates phone number without country code', () => {
    expect(isPhoneNumber('2025551234')).toBe(true);
  });

  it('rejects phone number with invalid characters', () => {
    expect(isPhoneNumber('202-555-1234')).toBe(false);
  });

  it('rejects phone number starting with 0', () => {
    expect(isPhoneNumber('0123456789')).toBe(false);
  });
});

describe('isValidPassword', () => {
  // Existing tests cover some cases, add missing ones:

  it('rejects password without uppercase letter', () => {
    expect(isValidPassword('password123')).toBe(false);
  });

  it('rejects password without lowercase letter', () => {
    expect(isValidPassword('PASSWORD123')).toBe(false);
  });

  it('rejects password without number', () => {
    expect(isValidPassword('PasswordABC')).toBe(false);
  });

  it('accepts password with all requirements', () => {
    expect(isValidPassword('Password123')).toBe(true);
  });
});
```

### Step 9: Write or Update Test File

If test file exists, append new tests:

```typescript
// Read existing file
const existingContent = readFile('src/utils/validation.test.ts');

// Add new describe block or tests to existing describe
const updatedContent = addTestsToFile(existingContent, newTests);

// Write back
writeFile('src/utils/validation.test.ts', updatedContent);
```

If test file doesn't exist, create it:

```typescript
const testContent = generateCompleteTestFile({
  sourcePath: 'src/utils/validation.ts',
  imports: ['isEmail', 'isPhoneNumber', 'isValidPassword'],
  tests: generatedTests,
});

writeFile('src/utils/validation.test.ts', testContent);
```

### Step 10: Verify Improvement

```bash
# Run tests for this file
pnpm exec vitest run src/utils/validation.test.ts

# Run coverage again
pnpm exec vitest run --coverage
```

Parse new coverage to verify improvement:

```json
{
  "src/utils/validation.ts": {
    "lines": { "pct": 95 }, // Improved from 60%
    "statements": { "pct": 95 },
    "functions": { "pct": 100 }, // All functions now tested
    "branches": { "pct": 90 }
  }
}
```

### Step 11: Commit Per File (unless --no-commit)

```bash
git add src/utils/validation.ts src/utils/validation.test.ts
git commit -m "test: improve coverage for validation utilities

- Add tests for isPhoneNumber function
- Add edge case tests for isValidPassword
- Coverage improved from 60% to 95%

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### Step 12: Continue Loop

Repeat steps 6-11 for next file below threshold.

## React Component Testing Patterns

### Analyze React Component

```typescript
import { useState } from 'react';

interface CounterProps {
  initialCount?: number;
  onCountChange?: (count: number) => void;
}

export function Counter({ initialCount = 0, onCountChange }: CounterProps) {
  const [count, setCount] = useState(initialCount);

  const increment = () => {
    const newCount = count + 1;
    setCount(newCount);
    onCountChange?.(newCount);
  };

  const decrement = () => {
    const newCount = count - 1;
    setCount(newCount);
    onCountChange?.(newCount);
  };

  const reset = () => {
    setCount(initialCount);
    onCountChange?.(initialCount);
  };

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={increment}>Increment</button>
      <button onClick={decrement}>Decrement</button>
      <button onClick={reset}>Reset</button>
    </div>
  );
}
```

### Generate Component Tests

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { Counter } from './Counter';

describe('Counter', () => {
  it('renders with default initial count', () => {
    render(<Counter />);
    expect(screen.getByText('Count: 0')).toBeInTheDocument();
  });

  it('renders with custom initial count', () => {
    render(<Counter initialCount={5} />);
    expect(screen.getByText('Count: 5')).toBeInTheDocument();
  });

  it('increments count when increment button is clicked', async () => {
    const user = userEvent.setup();
    render(<Counter />);

    await user.click(screen.getByRole('button', { name: 'Increment' }));

    expect(screen.getByText('Count: 1')).toBeInTheDocument();
  });

  it('decrements count when decrement button is clicked', async () => {
    const user = userEvent.setup();
    render(<Counter initialCount={5} />);

    await user.click(screen.getByRole('button', { name: 'Decrement' }));

    expect(screen.getByText('Count: 4')).toBeInTheDocument();
  });

  it('resets count to initial value when reset button is clicked', async () => {
    const user = userEvent.setup();
    render(<Counter initialCount={5} />);

    await user.click(screen.getByRole('button', { name: 'Increment' }));
    await user.click(screen.getByRole('button', { name: 'Increment' }));
    expect(screen.getByText('Count: 7')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Reset' }));

    expect(screen.getByText('Count: 5')).toBeInTheDocument();
  });

  it('calls onCountChange callback when count changes', async () => {
    const user = userEvent.setup();
    const onCountChange = vi.fn();
    render(<Counter onCountChange={onCountChange} />);

    await user.click(screen.getByRole('button', { name: 'Increment' }));

    expect(onCountChange).toHaveBeenCalledWith(1);
  });

  it('calls onCountChange callback on decrement', async () => {
    const user = userEvent.setup();
    const onCountChange = vi.fn();
    render(<Counter initialCount={5} onCountChange={onCountChange} />);

    await user.click(screen.getByRole('button', { name: 'Decrement' }));

    expect(onCountChange).toHaveBeenCalledWith(4);
  });

  it('calls onCountChange callback on reset', async () => {
    const user = userEvent.setup();
    const onCountChange = vi.fn();
    render(<Counter initialCount={5} onCountChange={onCountChange} />);

    await user.click(screen.getByRole('button', { name: 'Increment' }));
    await user.click(screen.getByRole('button', { name: 'Reset' }));

    expect(onCountChange).toHaveBeenLastCalledWith(5);
  });
});
```

## API Mocking with MSW

### Analyze Component with API Calls

```typescript
import { useEffect, useState } from 'react';

interface User {
  id: number;
  name: string;
  email: string;
}

export function UserList() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/users')
      .then((res) => {
        if (!res.ok) {
          throw new Error('Failed to fetch users');
        }
        return res.json();
      })
      .then((data) => {
        setUsers(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (error) {
    return <div>Error: {error}</div>;
  }

  return (
    <ul>
      {users.map((user) => (
        <li key={user.id}>
          {user.name} ({user.email})
        </li>
      ))}
    </ul>
  );
}
```

### Generate Tests with MSW

First, check if MSW is installed:

```json
{
  "devDependencies": {
    "msw": "^2.0.0"
  }
}
```

If not installed, suggest installation:

```text
MSW is not installed. To mock API calls, install it:
  pnpm add -D msw
```

Generate MSW setup:

```typescript
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: 1, name: 'John Doe', email: 'john@example.com' },
      { id: 2, name: 'Jane Smith', email: 'jane@example.com' },
    ]);
  }),
];
```

```typescript
// src/test/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

Update test setup:

```typescript
// src/test/setup.ts
import { beforeAll, afterEach, afterAll } from 'vitest';
import { server } from './mocks/server';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Generate component tests:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { server } from '@/test/mocks/server';
import { UserList } from './UserList';

describe('UserList', () => {
  it('shows loading state initially', () => {
    render(<UserList />);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('displays users after loading', async () => {
    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText('John Doe (john@example.com)')).toBeInTheDocument();
    });

    expect(screen.getByText('Jane Smith (jane@example.com)')).toBeInTheDocument();
  });

  it('displays error message when fetch fails', async () => {
    server.use(
      http.get('/api/users', () => {
        return new HttpResponse(null, { status: 500 });
      })
    );

    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText(/Error: Failed to fetch users/)).toBeInTheDocument();
    });
  });

  it('handles empty user list', async () => {
    server.use(
      http.get('/api/users', () => {
        return HttpResponse.json([]);
      })
    );

    render(<UserList />);

    await waitFor(() => {
      expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
    });
  });

  it('handles network error', async () => {
    server.use(
      http.get('/api/users', () => {
        return HttpResponse.error();
      })
    );

    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText(/Error:/)).toBeInTheDocument();
    });
  });
});
```

## Hook Testing Patterns

### Analyze Custom Hook

```typescript
import { useState, useEffect } from 'react';

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}
```

### Generate Hook Tests

```typescript
import { describe, it, expect, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { useDebounce } from './useDebounce';

describe('useDebounce', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns initial value immediately', () => {
    const { result } = renderHook(() => useDebounce('initial', 500));
    expect(result.current).toBe('initial');
  });

  it('updates value after delay', async () => {
    const { result, rerender } = renderHook(({ value, delay }) => useDebounce(value, delay), {
      initialProps: { value: 'initial', delay: 500 },
    });

    expect(result.current).toBe('initial');

    rerender({ value: 'updated', delay: 500 });

    expect(result.current).toBe('initial'); // Still initial

    vi.advanceTimersByTime(500);

    await waitFor(() => {
      expect(result.current).toBe('updated');
    });
  });

  it('cancels previous timeout when value changes rapidly', async () => {
    const { result, rerender } = renderHook(({ value, delay }) => useDebounce(value, delay), {
      initialProps: { value: 'first', delay: 500 },
    });

    rerender({ value: 'second', delay: 500 });
    vi.advanceTimersByTime(300);

    rerender({ value: 'third', delay: 500 });
    vi.advanceTimersByTime(500);

    await waitFor(() => {
      expect(result.current).toBe('third');
    });
  });

  it('handles delay changes', async () => {
    const { result, rerender } = renderHook(({ value, delay }) => useDebounce(value, delay), {
      initialProps: { value: 'initial', delay: 500 },
    });

    rerender({ value: 'updated', delay: 1000 });

    vi.advanceTimersByTime(500);
    expect(result.current).toBe('initial');

    vi.advanceTimersByTime(500);

    await waitFor(() => {
      expect(result.current).toBe('updated');
    });
  });
});
```

## Monorepo Coverage Handling

### Detect Monorepo

```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

### Run Coverage Per Package

```bash
# Find all packages
pnpm -r exec pwd

# Run coverage per package
pnpm -r exec vitest run --coverage
```

### Aggregate Coverage Results

```typescript
type PackageCoverage = {
  name: string;
  path: string;
  coverage: {
    lines: number;
    statements: number;
    functions: number;
    branches: number;
  };
  filesNeedingWork: string[];
};

// Collect from each package
const packageCoverages: PackageCoverage[] = [];

for (const pkg of packages) {
  const coveragePath = `${pkg.path}/coverage/coverage-summary.json`;
  const coverage = JSON.parse(readFile(coveragePath));

  packageCoverages.push({
    name: pkg.name,
    path: pkg.path,
    coverage: coverage.total,
    filesNeedingWork: identifyLowCoverageFiles(coverage),
  });
}
```

### Improve Coverage Package by Package

```bash
# Process packages in order
for package in packages; do
  cd "$package"
  # Improve coverage for this package
  improve_coverage_for_package "$package"
  cd -
done
```

## Coverage Report Output

### Initial Analysis

```text
========================================
Test Coverage Analysis
========================================

Project: my-app
Package Manager: pnpm
Testing Framework: Vitest
Threshold: 90%

Current Coverage:
  Lines: 85.3%
  Statements: 85.1%
  Functions: 82.4%
  Branches: 78.9%

Files below threshold: 12

Top priority files (lowest coverage):
  1. src/utils/validation.ts (45%)
  2. src/hooks/useAuth.ts (62%)
  3. src/components/UserProfile.tsx (68%)
  4. src/api/client.ts (71%)
  5. src/utils/formatting.ts (73%)

Starting autonomous coverage improvement...
========================================
```

### Per-File Progress

```text
[1/12] Improving src/utils/validation.ts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current coverage: 45%
Target: 90%

Analyzing source code...
  ✓ Found 3 exported functions
  ✓ Identified 2 uncovered functions
  ✓ Found 8 uncovered branches

Analyzing existing tests...
  ✓ Test file exists: src/utils/validation.test.ts
  ✓ 1 function partially tested
  ✓ 2 functions not tested

Generating new tests...
  ✓ Added tests for isPhoneNumber (5 test cases)
  ✓ Added edge case tests for isValidPassword (4 test cases)
  ✓ Added branch coverage tests (8 test cases)

Running tests...
  ✓ All tests pass (17 tests, 0 failures)

Verifying coverage improvement...
  ✓ New coverage: 95% (+50%)
  ✓ Target achieved!

Committing changes...
  ✓ Committed: test: improve coverage for validation utilities

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ File 1 of 12 complete
```

### Final Summary

```text
========================================
Coverage Improvement Complete
========================================

Duration: 8 minutes 32 seconds
Files processed: 12
Tests generated: 147
Commits created: 12

Coverage improvement:
  Lines: 85.3% → 94.7% (+9.4%)
  Statements: 85.1% → 94.5% (+9.4%)
  Functions: 82.4% → 96.2% (+13.8%)
  Branches: 78.9% → 91.3% (+12.4%)

✓ All metrics above 90% threshold!

Files improved:
  ✓ src/utils/validation.ts: 45% → 95%
  ✓ src/hooks/useAuth.ts: 62% → 93%
  ✓ src/components/UserProfile.tsx: 68% → 91%
  ✓ src/api/client.ts: 71% → 94%
  ✓ src/utils/formatting.ts: 73% → 92%
  ... 7 more files

Git commits:
  test: improve coverage for validation utilities
  test: improve coverage for useAuth hook
  test: improve coverage for UserProfile component
  ... 9 more commits

Next steps:
  1. Review generated tests for correctness
  2. Run full test suite: pnpm test
  3. Push commits: git push

========================================
```

## Error Handling and Edge Cases

### Coverage Tool Not Available

```text
Error: Vitest coverage provider not installed

Install coverage provider:
  pnpm add -D @vitest/coverage-v8

Or for c8:
  pnpm add -D @vitest/coverage-c8
```

### No Coverage Report Found

```text
Error: Coverage report not found

Run coverage first:
  pnpm run test:coverage

Or ensure vitest.config.ts has coverage configured:
  coverage: {
    provider: 'v8',
    reporter: ['text', 'json', 'html'],
  }
```

### File Already at Threshold

```text
File src/utils/helpers.ts already meets threshold:
  Current coverage: 96%
  Threshold: 90%

Skipping this file.
```

### Cannot Parse Source File

```text
Warning: Failed to parse src/legacy/parser.js

This file may contain syntax errors or use unsupported features.
Skipping test generation for this file.

Consider:
  1. Fix syntax errors
  2. Update to TypeScript
  3. Manually write tests
```

### Tests Fail After Generation

```text
Error: Generated tests are failing

Test output:
  FAIL src/utils/validation.test.ts
    ● isPhoneNumber › validates international format
      Expected false, received true

This may indicate:
  1. Incorrect test logic
  2. Misunderstanding of function behavior
  3. Edge case not handled

Actions:
  1. Review generated tests
  2. Fix test expectations or source code
  3. Re-run coverage command

Not committing failed tests.
```

### Git Working Directory Not Clean

```text
Warning: Git working directory has uncommitted changes

Files with changes:
  M src/components/Button.tsx
  M src/utils/helpers.ts

Options:
  1. Commit existing changes first
  2. Run with --no-commit to skip git commits
  3. Stash changes: git stash

Exiting.
```

## Configuration Options

### Threshold Levels

```bash
# Conservative (easier to achieve)
coverage --threshold=80

# Recommended (good balance)
coverage --threshold=90

# Strict (comprehensive coverage)
coverage --threshold=95

# Maximum (every line covered)
coverage --threshold=100
```

### Coverage Types

```bash
# Focus on statement coverage
coverage --type=statements --threshold=90

# Focus on branch coverage (more thorough)
coverage --type=branches --threshold=85

# All types must meet threshold (default)
coverage --threshold=90
```

### File Patterns

```bash
# Only test utilities
coverage --pattern="src/utils/**/*.ts"

# Only components
coverage --pattern="src/components/**/*.tsx"

# Exclude specific directories
coverage --exclude="src/legacy/**"
```

## Integration with CI/CD

### GitHub Actions Workflow

```yaml
name: Coverage Improvement
on:
  schedule:
    - cron: '0 2 * * 1' # Weekly on Monday at 2 AM
  workflow_dispatch:

jobs:
  improve-coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: pnpm install
      - run: pnpm coverage --threshold=90
      - run: git push
```

### Pre-commit Hook

```bash
#!/bin/sh
# Ensure new code has adequate coverage

# Run coverage on staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$')

if [ -n "$STAGED_FILES" ]; then
  pnpm exec vitest run --coverage --changed

  # Check if coverage threshold met
  # (requires custom script to parse coverage-summary.json)
fi
```

## Advanced Features

### Smart Test Generation

Analyze function complexity and generate appropriate tests:

- Simple functions: Basic input/output tests
- Functions with conditionals: Branch coverage tests
- Functions with loops: Edge case tests (empty, single, multiple)
- Async functions: Success, error, and timeout tests
- React components: Rendering, interaction, and state tests

### Test Quality Metrics

After generating tests, evaluate quality:

- Assertions per test (aim for 1-3)
- Test independence (no shared state)
- Descriptive test names
- Proper setup and teardown
- Meaningful test data

### Mutation Testing Integration

```bash
# Run mutation testing to verify test quality
pnpm add -D @stryker-mutator/core @stryker-mutator/vitest-runner

pnpm exec stryker run
```

## Summary

The coverage command provides:

1. Autonomous coverage improvement
1. Intelligent test generation
1. Per-file incremental commits
1. React Testing Library integration
1. MSW for API mocking
1. Monorepo support
1. Pattern matching for existing tests
1. Coverage verification
1. Detailed progress reporting
1. Error handling and recovery

All generated tests follow best practices and match the project's existing test patterns.
