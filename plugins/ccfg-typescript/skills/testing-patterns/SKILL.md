---
name: testing-patterns
description:
  This skill should be used when writing TypeScript tests, configuring Vitest or Jest, testing React
  components, mocking APIs, or improving test coverage.
version: 0.1.0
---

# TypeScript Testing Patterns and Best Practices

This skill defines comprehensive testing patterns for TypeScript projects, covering unit tests,
integration tests, component tests, and E2E tests with Vitest, React Testing Library, MSW, and
Playwright.

## Testing Framework - Vitest Preferred

### Why Vitest Over Jest

**ALWAYS use Vitest for new TypeScript projects.**

Advantages:

1. Native ESM support
1. Faster execution
1. Better TypeScript integration
1. Vite integration for frontend projects
1. Compatible API with Jest
1. Superior watch mode
1. Built-in coverage with c8/v8

### Vitest Configuration

CORRECT vitest.config.ts:

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react'; // If testing React
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom', // or 'node' for backend
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      exclude: ['node_modules/', 'src/test/', '**/*.d.ts', '**/*.config.*', '**/mockData', 'dist/'],
      all: true,
      lines: 90,
      functions: 90,
      branches: 85,
      statements: 90,
    },
    include: ['**/*.{test,spec}.{ts,tsx}'],
    exclude: ['node_modules', 'dist', '.next'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

Setup file (src/test/setup.ts):

```typescript
import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';
import * as matchers from '@testing-library/jest-dom/matchers';

// Extend Vitest matchers with jest-dom
expect.extend(matchers);

// Cleanup after each test
afterEach(() => {
  cleanup();
});
```

## Test Structure and Organization

### Test File Naming

CORRECT patterns:

1. `Button.test.tsx` - colocated with component
1. `utils.test.ts` - colocated with module
1. `__tests__/Button.tsx` - in tests directory
1. `Button.spec.tsx` - alternative convention

WRONG:

1. `ButtonTest.tsx` - not standard
1. `test-button.tsx` - not standard
1. `button-test.tsx` - not standard

### Test Structure with describe/it

CORRECT:

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest';

describe('UserService', () => {
  describe('createUser', () => {
    it('creates a user with valid data', () => {
      const user = createUser({ name: 'Alice', email: 'alice@example.com' });
      expect(user.name).toBe('Alice');
      expect(user.email).toBe('alice@example.com');
    });

    it('throws error when email is invalid', () => {
      expect(() => {
        createUser({ name: 'Alice', email: 'invalid' });
      }).toThrow('Invalid email');
    });

    it('generates unique ID for each user', () => {
      const user1 = createUser({ name: 'Alice', email: 'alice@example.com' });
      const user2 = createUser({ name: 'Bob', email: 'bob@example.com' });
      expect(user1.id).not.toBe(user2.id);
    });
  });

  describe('updateUser', () => {
    let existingUser: User;

    beforeEach(() => {
      existingUser = createUser({ name: 'Alice', email: 'alice@example.com' });
    });

    it('updates user properties', () => {
      const updated = updateUser(existingUser.id, { name: 'Alicia' });
      expect(updated.name).toBe('Alicia');
      expect(updated.email).toBe('alice@example.com');
    });
  });
});
```

WRONG:

```typescript
// Don't use test() instead of it()
test('should create user', () => {
  /* ... */
});

// Don't skip describe blocks
it('creates user', () => {
  /* ... */
});
it('updates user', () => {
  /* ... */
});
it('deletes user', () => {
  /* ... */
});

// Don't use unclear test names
it('works', () => {
  /* ... */
});
it('test 1', () => {
  /* ... */
});
```

### Test Naming Conventions

**Write test names in plain English that describe behavior, not implementation.**

CORRECT:

```typescript
it('displays user name after loading');
it('shows error message when API fails');
it('disables submit button while form is invalid');
it('filters items by search query');
it('calculates total price including tax');
```

WRONG:

```typescript
it('should work'); // Too vague
it('test handleClick'); // Implementation detail
it('renders correctly'); // What does "correctly" mean?
it('test #1234'); // No context
```

## React Component Testing with React Testing Library

### Core Principles

1. Test behavior, not implementation
1. Query by accessibility role first
1. Use `userEvent` over `fireEvent`
1. Await async operations with `waitFor`
1. Avoid `getByTestId` when possible

### Component Test Template

CORRECT:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { Button } from './Button';

describe('Button', () => {
  it('renders children text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
  });

  it('calls onClick handler when clicked', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();

    render(<Button onClick={onClick}>Click me</Button>);

    await user.click(screen.getByRole('button', { name: 'Click me' }));

    expect(onClick).toHaveBeenCalledOnce();
  });

  it('is disabled when disabled prop is true', () => {
    render(<Button disabled>Click me</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('applies variant class', () => {
    render(<Button variant="secondary">Click me</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveClass('button--secondary');
  });
});
```

### Query Priority

**Follow this priority order for queries:**

1. `getByRole` - Preferred (accessible)
1. `getByLabelText` - Form inputs
1. `getByPlaceholderText` - If no label
1. `getByText` - Non-interactive elements
1. `getByDisplayValue` - Current value
1. `getByAltText` - Images
1. `getByTitle` - SVG, iframes
1. `getByTestId` - Last resort only

CORRECT:

```typescript
// Prefer accessible queries
screen.getByRole('button', { name: 'Submit' });
screen.getByRole('textbox', { name: 'Email' });
screen.getByRole('heading', { level: 1, name: 'Welcome' });

// For form inputs
screen.getByLabelText('Email address');

// For text content
screen.getByText('Welcome back!');
screen.getByText(/welcome/i); // Case insensitive regex
```

WRONG:

```typescript
// Don't use getByTestId as first choice
screen.getByTestId('submit-button');
screen.getByTestId('email-input');

// Don't query by class or implementation details
container.querySelector('.button');
container.querySelector('#submit');
```

### userEvent vs fireEvent

**ALWAYS use userEvent for simulating user interactions.**

CORRECT:

```typescript
import { userEvent } from '@testing-library/user-event';

it('handles user typing', async () => {
  const user = userEvent.setup();
  render(<Input />);

  const input = screen.getByRole('textbox');

  await user.type(input, 'Hello World');
  expect(input).toHaveValue('Hello World');
});

it('handles user clicking', async () => {
  const user = userEvent.setup();
  const onClick = vi.fn();
  render(<Button onClick={onClick}>Click</Button>);

  await user.click(screen.getByRole('button'));
  expect(onClick).toHaveBeenCalled();
});

it('handles user selecting option', async () => {
  const user = userEvent.setup();
  render(<Select options={['A', 'B', 'C']} />);

  await user.selectOptions(screen.getByRole('combobox'), 'B');
  expect(screen.getByRole('combobox')).toHaveValue('B');
});
```

WRONG:

```typescript
import { fireEvent } from '@testing-library/react';

// Don't use fireEvent - it doesn't simulate real user behavior
fireEvent.change(input, { target: { value: 'Hello' } });
fireEvent.click(button);
```

### Async Testing with waitFor

**Use waitFor for async operations.**

CORRECT:

```typescript
import { waitFor } from '@testing-library/react';

it('displays user data after loading', async () => {
  render(<UserProfile userId="123" />);

  expect(screen.getByText('Loading...')).toBeInTheDocument();

  await waitFor(() => {
    expect(screen.getByText('John Doe')).toBeInTheDocument();
  });

  expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
});

it('shows error message when API fails', async () => {
  server.use(
    http.get('/api/user', () => {
      return new HttpResponse(null, { status: 500 });
    })
  );

  render(<UserProfile userId="123" />);

  await waitFor(() => {
    expect(screen.getByText(/error/i)).toBeInTheDocument();
  });
});

// Alternative: use findBy queries (combines getBy + waitFor)
it('displays user data after loading', async () => {
  render(<UserProfile userId="123" />);

  const userName = await screen.findByText('John Doe');
  expect(userName).toBeInTheDocument();
});
```

WRONG:

```typescript
// Don't use act() manually - waitFor handles it
act(() => {
  render(<UserProfile />);
});

// Don't use arbitrary timeouts
await new Promise(resolve => setTimeout(resolve, 1000));
expect(screen.getByText('John Doe')).toBeInTheDocument();

// Don't test implementation details
expect(component.state.loading).toBe(false);
```

## API Mocking with MSW (Mock Service Worker)

### MSW Setup

**ALWAYS use MSW for mocking HTTP requests in tests.**

Install:

```bash
pnpm add -D msw
```

Create handlers (src/test/mocks/handlers.ts):

```typescript
import { http, HttpResponse } from 'msw';

export const handlers = [
  // GET request
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: '1', name: 'John Doe', email: 'john@example.com' },
      { id: '2', name: 'Jane Smith', email: 'jane@example.com' },
    ]);
  }),

  // POST request
  http.post('/api/users', async ({ request }) => {
    const user = await request.json();
    return HttpResponse.json({ id: '3', ...user }, { status: 201 });
  }),

  // Error response
  http.get('/api/error', () => {
    return new HttpResponse(null, { status: 500 });
  }),

  // Dynamic path parameters
  http.get('/api/users/:id', ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      id,
      name: `User ${id}`,
      email: `user${id}@example.com`,
    });
  }),

  // Query parameters
  http.get('/api/search', ({ request }) => {
    const url = new URL(request.url);
    const query = url.searchParams.get('q');

    return HttpResponse.json({
      results: [`Result for ${query}`],
    });
  }),
];
```

Create server (src/test/mocks/server.ts):

```typescript
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

Setup in test config (src/test/setup.ts):

```typescript
import { beforeAll, afterEach, afterAll } from 'vitest';
import { server } from './mocks/server';

// Start server before all tests
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));

// Reset handlers after each test
afterEach(() => server.resetHandlers());

// Close server after all tests
afterAll(() => server.close());
```

### Per-Test Handler Overrides

CORRECT:

```typescript
import { http, HttpResponse } from 'msw';
import { server } from '@/test/mocks/server';

describe('UserList', () => {
  it('displays users from API', async () => {
    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });
  });

  it('displays error when API fails', async () => {
    // Override handler for this test
    server.use(
      http.get('/api/users', () => {
        return new HttpResponse(null, { status: 500 });
      })
    );

    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText(/error/i)).toBeInTheDocument();
    });
  });

  it('displays empty state when no users', async () => {
    server.use(
      http.get('/api/users', () => {
        return HttpResponse.json([]);
      })
    );

    render(<UserList />);

    await waitFor(() => {
      expect(screen.getByText('No users found')).toBeInTheDocument();
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
      expect(screen.getByText(/network error/i)).toBeInTheDocument();
    });
  });
});
```

### Typed MSW Handlers

CORRECT:

```typescript
import { http, HttpResponse, type HttpHandler } from 'msw';

type User = {
  id: string;
  name: string;
  email: string;
};

type CreateUserRequest = Omit<User, 'id'>;
type CreateUserResponse = User;

export const handlers: HttpHandler[] = [
  http.get<never, never, User[]>('/api/users', () => {
    return HttpResponse.json([{ id: '1', name: 'John', email: 'john@example.com' }]);
  }),

  http.post<never, CreateUserRequest, CreateUserResponse>('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({
      id: '123',
      ...body,
    });
  }),

  http.get<{ id: string }, never, User>('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'John',
      email: 'john@example.com',
    });
  }),
];
```

## Mocking and Spying

### Mock Functions with vi.fn()

CORRECT:

```typescript
import { vi } from 'vitest';

it('calls callback with result', () => {
  const callback = vi.fn();

  processData('input', callback);

  expect(callback).toHaveBeenCalledWith('RESULT');
  expect(callback).toHaveBeenCalledOnce();
});

it('uses mock implementation', () => {
  const fetchUser = vi.fn().mockResolvedValue({
    id: '1',
    name: 'John',
  });

  const result = await fetchUser('1');
  expect(result.name).toBe('John');
});

it('tracks multiple calls', () => {
  const logger = vi.fn();

  logger('first');
  logger('second');
  logger('third');

  expect(logger).toHaveBeenCalledTimes(3);
  expect(logger).toHaveBeenNthCalledWith(1, 'first');
  expect(logger).toHaveBeenNthCalledWith(2, 'second');
  expect(logger).toHaveBeenNthCalledWith(3, 'third');
});
```

### Spy on Modules with vi.mock()

CORRECT:

```typescript
import { vi, beforeEach } from 'vitest';
import { sendEmail } from './email';
import { notifyUser } from './notifications';

// Mock entire module
vi.mock('./email', () => ({
  sendEmail: vi.fn(),
}));

describe('notifyUser', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('sends email to user', () => {
    notifyUser('user@example.com', 'Hello');

    expect(sendEmail).toHaveBeenCalledWith({
      to: 'user@example.com',
      subject: 'Notification',
      body: 'Hello',
    });
  });
});
```

### Spy on Object Methods with vi.spyOn()

CORRECT:

```typescript
import { vi } from 'vitest';

it('tracks console.log calls', () => {
  const logSpy = vi.spyOn(console, 'log');

  logger.info('test message');

  expect(logSpy).toHaveBeenCalledWith('[INFO]', 'test message');

  logSpy.mockRestore();
});

it('mocks Date.now', () => {
  const now = new Date('2024-01-01').getTime();
  vi.spyOn(Date, 'now').mockReturnValue(now);

  const timestamp = getCurrentTimestamp();

  expect(timestamp).toBe(now);

  vi.restoreAllMocks();
});
```

### Mock Timers

CORRECT:

```typescript
import { vi, beforeEach, afterEach } from 'vitest';

describe('debounce', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('delays function execution', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 1000);

    debounced('arg1');

    expect(fn).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1000);

    expect(fn).toHaveBeenCalledWith('arg1');
  });

  it('cancels previous timeout', () => {
    const fn = vi.fn();
    const debounced = debounce(fn, 1000);

    debounced('first');
    vi.advanceTimersByTime(500);

    debounced('second');
    vi.advanceTimersByTime(1000);

    expect(fn).toHaveBeenCalledOnce();
    expect(fn).toHaveBeenCalledWith('second');
  });
});
```

## Testing Hooks

### Use renderHook from React Testing Library

CORRECT:

```typescript
import { renderHook, waitFor } from '@testing-library/react';
import { useCounter } from './useCounter';

describe('useCounter', () => {
  it('initializes with default value', () => {
    const { result } = renderHook(() => useCounter());
    expect(result.current.count).toBe(0);
  });

  it('initializes with custom value', () => {
    const { result } = renderHook(() => useCounter(10));
    expect(result.current.count).toBe(10);
  });

  it('increments count', () => {
    const { result } = renderHook(() => useCounter());

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });

  it('decrements count', () => {
    const { result } = renderHook(() => useCounter(5));

    act(() => {
      result.current.decrement();
    });

    expect(result.current.count).toBe(4);
  });

  it('updates when props change', () => {
    const { result, rerender } = renderHook(({ initialValue }) => useCounter(initialValue), {
      initialProps: { initialValue: 0 },
    });

    expect(result.current.count).toBe(0);

    rerender({ initialValue: 10 });

    expect(result.current.count).toBe(10);
  });
});
```

### Testing Async Hooks

CORRECT:

```typescript
describe('useAsyncData', () => {
  it('loads data', async () => {
    const { result } = renderHook(() => useAsyncData('/api/data'));

    expect(result.current.loading).toBe(true);
    expect(result.current.data).toBeNull();

    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).toEqual({ value: 'test' });
  });

  it('handles errors', async () => {
    server.use(
      http.get('/api/data', () => {
        return new HttpResponse(null, { status: 500 });
      })
    );

    const { result } = renderHook(() => useAsyncData('/api/data'));

    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.error).toBeTruthy();
  });
});
```

## Snapshot Testing

### Use Sparingly

**Only use snapshots for stable data structures, not UI.**

CORRECT:

```typescript
it('serializes config correctly', () => {
  const config = generateConfig({ env: 'production' });

  expect(config).toMatchSnapshot();
});

it('generates correct AST', () => {
  const ast = parseCode('function add(a, b) { return a + b; }');

  expect(ast).toMatchInlineSnapshot(`
    {
      "type": "FunctionDeclaration",
      "name": "add",
      "params": ["a", "b"],
      "body": { "type": "ReturnStatement" }
    }
  `);
});
```

WRONG:

```typescript
// Don't snapshot entire component trees
it('renders correctly', () => {
  const { container } = render(<App />);
  expect(container).toMatchSnapshot();
});
```

## Component Testing Patterns

### Testing Forms

CORRECT:

```typescript
describe('LoginForm', () => {
  it('submits form with email and password', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText('Email'), 'user@example.com');
    await user.type(screen.getByLabelText('Password'), 'password123');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'password123',
    });
  });

  it('displays validation errors', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);

    await user.click(screen.getByRole('button', { name: 'Sign in' }));

    expect(screen.getByText('Email is required')).toBeInTheDocument();
    expect(screen.getByText('Password is required')).toBeInTheDocument();
  });

  it('disables submit button during submission', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn().mockImplementation(
      () => new Promise(resolve => setTimeout(resolve, 1000))
    );

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText('Email'), 'user@example.com');
    await user.type(screen.getByLabelText('Password'), 'password123');

    const submitButton = screen.getByRole('button', { name: 'Sign in' });
    await user.click(submitButton);

    expect(submitButton).toBeDisabled();

    await waitFor(() => {
      expect(submitButton).not.toBeDisabled();
    });
  });
});
```

### Testing Lists and Iteration

CORRECT:

```typescript
describe('TodoList', () => {
  const todos = [
    { id: '1', text: 'Buy milk', completed: false },
    { id: '2', text: 'Walk dog', completed: true },
    { id: '3', text: 'Write tests', completed: false },
  ];

  it('renders all todo items', () => {
    render(<TodoList todos={todos} />);

    expect(screen.getByText('Buy milk')).toBeInTheDocument();
    expect(screen.getByText('Walk dog')).toBeInTheDocument();
    expect(screen.getByText('Write tests')).toBeInTheDocument();
  });

  it('shows completed items as checked', () => {
    render(<TodoList todos={todos} />);

    const walkDog = screen.getByRole('checkbox', { name: /walk dog/i });
    expect(walkDog).toBeChecked();

    const buyMilk = screen.getByRole('checkbox', { name: /buy milk/i });
    expect(buyMilk).not.toBeChecked();
  });

  it('toggles todo completion', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(<TodoList todos={todos} onToggle={onToggle} />);

    await user.click(screen.getByRole('checkbox', { name: /buy milk/i }));

    expect(onToggle).toHaveBeenCalledWith('1');
  });
});
```

### Testing Conditional Rendering

CORRECT:

```typescript
describe('UserProfile', () => {
  it('shows loading state initially', () => {
    render(<UserProfile userId="123" />);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('shows user data after loading', async () => {
    render(<UserProfile userId="123" />);

    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });

    expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
  });

  it('shows error state on failure', async () => {
    server.use(
      http.get('/api/users/:id', () => {
        return new HttpResponse(null, { status: 500 });
      })
    );

    render(<UserProfile userId="123" />);

    await waitFor(() => {
      expect(screen.getByText(/error/i)).toBeInTheDocument();
    });
  });

  it('shows empty state when user not found', async () => {
    server.use(
      http.get('/api/users/:id', () => {
        return new HttpResponse(null, { status: 404 });
      })
    );

    render(<UserProfile userId="123" />);

    await waitFor(() => {
      expect(screen.getByText('User not found')).toBeInTheDocument();
    });
  });
});
```

## Coverage Configuration

### Vitest Coverage Setup

CORRECT vitest.config.ts:

```typescript
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8', // or 'c8'
      reporter: ['text', 'json', 'html', 'lcov'],
      all: true,
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.d.ts',
        '**/*.config.*',
        '**/*.test.{ts,tsx}',
        '**/mockData/**',
        'dist/',
      ],
      lines: 90,
      functions: 90,
      branches: 85,
      statements: 90,
    },
  },
});
```

Run coverage:

```bash
pnpm exec vitest run --coverage
```

## Playwright E2E Testing

### Playwright Configuration

CORRECT playwright.config.ts:

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
  webServer: {
    command: 'pnpm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

### E2E Test Example

CORRECT:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test('successful login redirects to dashboard', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[name="email"]', 'user@example.com');
    await page.fill('input[name="password"]', 'password123');

    await page.click('button[type="submit"]');

    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('h1')).toHaveText('Dashboard');
  });

  test('shows error on invalid credentials', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[name="email"]', 'invalid@example.com');
    await page.fill('input[name="password"]', 'wrongpassword');

    await page.click('button[type="submit"]');

    await expect(page.locator('.error')).toHaveText('Invalid credentials');
  });
});
```

## Summary Testing Checklist

When writing tests, ensure:

1. Use Vitest for unit and integration tests
1. Use React Testing Library for components
1. Use MSW for API mocking
1. Use Playwright for E2E tests
1. Query by role, not test ID
1. Use userEvent, not fireEvent
1. Use waitFor for async operations
1. Test behavior, not implementation
1. Write clear, descriptive test names
1. Mock at network level with MSW
1. Use vi.fn() for function mocks
1. Use vi.spyOn() for method spies
1. Use fake timers for time-based code
1. Configure coverage thresholds
1. Avoid snapshot tests for UI

These patterns ensure reliable, maintainable tests that catch bugs and document behavior.
