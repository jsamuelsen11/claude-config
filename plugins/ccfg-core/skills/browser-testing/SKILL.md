---
name: browser-testing
description:
  This skill should be used when testing web UIs, browser automation, end-to-end testing with
  Playwright or Puppeteer, Chrome DevTools debugging, or visual regression testing.
version: 0.1.0
---

# Browser Testing

This skill covers best practices for browser-based testing, including end-to-end testing with
Playwright/Puppeteer, visual regression testing, accessibility testing, and Chrome DevTools
automation.

## Playwright Test Patterns

### Test Structure

Playwright tests should follow a clear arrange-act-assert pattern:

```typescript
import { test, expect } from '@playwright/test';

test('user can log in with valid credentials', async ({ page }) => {
  // Arrange: Navigate to login page
  await page.goto('/login');

  // Act: Fill in form and submit
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Log in' }).click();

  // Assert: Verify redirect and welcome message
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByText('Welcome back')).toBeVisible();
});
```

**Test naming:** Use descriptive names that read like specifications:

- Good: `'user can log in with valid credentials'`
- Good: `'displays error message when email is invalid'`
- Bad: `'test login'`
- Bad: `'testValidation'`

**Test isolation:** Each test should be independent and not rely on state from other tests:

```typescript
test.beforeEach(async ({ page }) => {
  // Reset to known state before each test
  await page.goto('/');
  await resetDatabase(); // If needed
  await clearLocalStorage(); // If needed
});
```

### Element Selection

**Prefer semantic selectors over CSS selectors.** Playwright provides locators that are more
resilient to UI changes:

```typescript
// Best: Role-based selectors (most resilient)
await page.getByRole('button', { name: 'Submit' });
await page.getByRole('textbox', { name: 'Email' });
await page.getByRole('heading', { name: 'Welcome' });

// Good: Label text (semantic and user-focused)
await page.getByLabel('Email address');
await page.getByLabel('Password');

// Good: Test IDs (explicit test hooks)
await page.getByTestId('submit-button');
await page.getByTestId('error-message');

// Avoid: CSS selectors (brittle, implementation-coupled)
await page.locator('.btn-primary');
await page.locator('#submit-btn');
await page.locator('div > form > button:nth-child(3)');
```

**Use data-testid for elements without semantic roles:**

```html
<!-- Good: semantic HTML doesn't need test ID -->
<button type="submit">Submit</button>

<!-- Good: test ID for non-semantic elements -->
<div data-testid="user-profile-card">
  <span data-testid="username">John Doe</span>
</div>
```

**Chain locators to narrow scope:**

```typescript
// Find button within a specific card
const userCard = page.getByTestId('user-card-123');
await userCard.getByRole('button', { name: 'Delete' }).click();

// Find input within a specific form
const loginForm = page.getByRole('form', { name: 'Login' });
await loginForm.getByLabel('Email').fill('user@example.com');
```

### Waiting Strategies

**Playwright auto-waits by default.** Most actions automatically wait for elements to be ready:

```typescript
// Automatically waits for button to be visible and enabled
await page.getByRole('button', { name: 'Submit' }).click();

// Automatically waits for input to be editable
await page.getByLabel('Email').fill('user@example.com');
```

**Explicit waits for specific conditions:**

```typescript
// Wait for element to appear
await page.waitForSelector('[data-testid="success-message"]');

// Wait for navigation
await page.waitForURL('/dashboard');

// Wait for network request
await page.waitForResponse(
  (response) => response.url().includes('/api/users') && response.status() === 200
);

// Wait for element state
await page.getByTestId('spinner').waitFor({ state: 'hidden' });
```

**Wait for multiple conditions:**

```typescript
// Wait for all promises to resolve
await Promise.all([
  page.waitForResponse('/api/user'),
  page.waitForResponse('/api/settings'),
  page.getByRole('button', { name: 'Submit' }).click(),
]);
```

### Assertion Patterns

**Use Playwright's built-in assertions** which automatically retry until the condition is met or
timeout:

```typescript
// Visibility assertions
await expect(page.getByText('Success')).toBeVisible();
await expect(page.getByText('Loading')).toBeHidden();

// Text content assertions
await expect(page.getByRole('heading')).toHaveText('Welcome');
await expect(page.getByTestId('error')).toContainText('Invalid email');

// Attribute assertions
await expect(page.getByRole('button')).toBeDisabled();
await expect(page.getByRole('checkbox')).toBeChecked();
await expect(page.getByRole('link')).toHaveAttribute('href', '/about');

// URL assertions
await expect(page).toHaveURL('/dashboard');
await expect(page).toHaveURL(/\/users\/\d+/);

// Count assertions
await expect(page.getByRole('listitem')).toHaveCount(5);
```

**Soft assertions for non-blocking checks:**

```typescript
test('dashboard displays all widgets', async ({ page }) => {
  await page.goto('/dashboard');

  // Continue test even if these fail
  await expect.soft(page.getByTestId('widget-sales')).toBeVisible();
  await expect.soft(page.getByTestId('widget-traffic')).toBeVisible();
  await expect.soft(page.getByTestId('widget-revenue')).toBeVisible();

  // Critical assertion (will stop test if fails)
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

## Page Object Model

**Create page objects for reusable interactions.** Page objects encapsulate page-specific knowledge
and make tests more maintainable:

```typescript
// pages/login.page.ts
export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.page.getByLabel('Email').fill(email);
    await this.page.getByLabel('Password').fill(password);
    await this.page.getByRole('button', { name: 'Log in' }).click();
  }

  async getErrorMessage() {
    return this.page.getByTestId('error-message').textContent();
  }

  async isLoggedIn() {
    return this.page.getByText('Welcome back').isVisible();
  }
}

// Using the page object
test('user can log in', async ({ page }) => {
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login('user@example.com', 'password123');
  expect(await loginPage.isLoggedIn()).toBe(true);
});
```

**Separate selectors from test logic:**

```typescript
export class DashboardPage {
  // Centralize selectors
  private selectors = {
    heading: () => this.page.getByRole('heading', { name: 'Dashboard' }),
    salesWidget: () => this.page.getByTestId('widget-sales'),
    addButton: () => this.page.getByRole('button', { name: 'Add Widget' }),
  };

  constructor(private page: Page) {}

  async clickAddWidget() {
    await this.selectors.addButton().click();
  }

  async getSalesValue() {
    return this.selectors.salesWidget().textContent();
  }
}
```

**Compose page objects for complex flows:**

```typescript
test('complete checkout flow', async ({ page }) => {
  const cartPage = new CartPage(page);
  const checkoutPage = new CheckoutPage(page);
  const confirmationPage = new ConfirmationPage(page);

  await cartPage.goto();
  await cartPage.proceedToCheckout();

  await checkoutPage.fillShippingInfo({
    name: 'John Doe',
    address: '123 Main St',
  });
  await checkoutPage.fillPaymentInfo({
    cardNumber: '4111111111111111',
    expiry: '12/25',
    cvv: '123',
  });
  await checkoutPage.submitOrder();

  await expect(confirmationPage.orderNumber()).toBeVisible();
});
```

## Screenshot and Visual Regression

### Capture Screenshots at Key States

```typescript
test('login page renders correctly', async ({ page }) => {
  await page.goto('/login');

  // Capture full page screenshot
  await page.screenshot({ path: 'screenshots/login-page.png', fullPage: true });

  // Capture specific element
  await page.getByTestId('login-form').screenshot({
    path: 'screenshots/login-form.png',
  });
});
```

### Compare with Baselines

```typescript
import { test, expect } from '@playwright/test';

test('dashboard matches baseline', async ({ page }) => {
  await page.goto('/dashboard');

  // Visual comparison (fails if pixels differ beyond threshold)
  await expect(page).toHaveScreenshot('dashboard.png', {
    maxDiffPixels: 100, // Allow up to 100 pixels difference
  });
});
```

### Handle Dynamic Content

**Mask elements that change frequently:**

```typescript
test('article page visual test', async ({ page }) => {
  await page.goto('/article/123');

  await expect(page).toHaveScreenshot({
    // Mask elements with dynamic content
    mask: [
      page.getByTestId('published-date'),
      page.getByTestId('view-count'),
      page.getByTestId('advertisement'),
    ],
  });
});
```

**Hide animations before capturing:**

```typescript
test('modal visual test', async ({ page }) => {
  await page.goto('/');

  // Disable animations to prevent flaky visual tests
  await page.addStyleTag({
    content: `
      *, *::before, *::after {
        animation-duration: 0s !important;
        transition-duration: 0s !important;
      }
    `,
  });

  await page.getByRole('button', { name: 'Open Modal' }).click();
  await expect(page.getByRole('dialog')).toHaveScreenshot('modal.png');
});
```

### Threshold Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixels: 100, // Global threshold
      threshold: 0.2, // 20% difference allowed
    },
  },
});

// Override per test
test('hero section visual', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByTestId('hero')).toHaveScreenshot('hero.png', {
    maxDiffPixelRatio: 0.05, // Allow 5% difference for this specific test
  });
});
```

## Chrome DevTools Protocol

### Network Request Interception

**Capture network requests:**

```typescript
test('tracks API calls', async ({ page }) => {
  const requests: string[] = [];

  page.on('request', (request) => {
    if (request.url().includes('/api/')) {
      requests.push(request.url());
    }
  });

  await page.goto('/dashboard');

  expect(requests).toContain('https://api.example.com/api/users');
  expect(requests).toContain('https://api.example.com/api/settings');
});
```

**Verify request headers:**

```typescript
test('sends authentication header', async ({ page }) => {
  page.on('request', (request) => {
    if (request.url().includes('/api/protected')) {
      expect(request.headers()['authorization']).toBe('Bearer token123');
    }
  });

  await page.goto('/protected-page');
});
```

### Performance Profiling

**Measure page load performance:**

```typescript
test('page loads within performance budget', async ({ page }) => {
  const startTime = Date.now();
  await page.goto('/');
  const loadTime = Date.now() - startTime;

  expect(loadTime).toBeLessThan(3000); // 3 second budget
});
```

**Collect performance metrics:**

```typescript
test('performance metrics', async ({ page }) => {
  await page.goto('/');

  const metrics = await page.evaluate(() => {
    const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    return {
      domContentLoaded: navigation.domContentLoadedEventEnd - navigation.fetchStart,
      loadComplete: navigation.loadEventEnd - navigation.fetchStart,
      firstPaint: performance.getEntriesByType('paint')[0]?.startTime,
    };
  });

  expect(metrics.domContentLoaded).toBeLessThan(2000);
  expect(metrics.loadComplete).toBeLessThan(5000);
});
```

### Console Log Capture

**Capture console errors:**

```typescript
test('page has no console errors', async ({ page }) => {
  const errors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });

  await page.goto('/');

  expect(errors).toHaveLength(0);
});
```

### Coverage Collection

**Collect code coverage:**

```typescript
test('collect coverage', async ({ page }) => {
  await page.coverage.startJSCoverage();
  await page.goto('/');
  await page.getByRole('button', { name: 'Submit' }).click();
  const coverage = await page.coverage.stopJSCoverage();

  let totalBytes = 0;
  let usedBytes = 0;

  for (const entry of coverage) {
    totalBytes += entry.text.length;
    for (const range of entry.ranges) {
      usedBytes += range.end - range.start - 1;
    }
  }

  const coveragePercentage = (usedBytes / totalBytes) * 100;
  console.log(`Code coverage: ${coveragePercentage.toFixed(2)}%`);
});
```

## Network Mocking

### Intercept and Mock API Responses

```typescript
test('displays user profile from mocked API', async ({ page }) => {
  // Intercept API call and return mock data
  await page.route('/api/user/profile', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
      }),
    });
  });

  await page.goto('/profile');
  await expect(page.getByText('Test User')).toBeVisible();
});
```

### Simulate Errors and Slow Networks

```typescript
test('handles API error gracefully', async ({ page }) => {
  // Simulate 500 error
  await page.route('/api/data', (route) => {
    route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'Internal Server Error' }),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByText('Failed to load data')).toBeVisible();
});

test('handles slow network', async ({ page }) => {
  // Simulate slow response
  await page.route('/api/data', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 5000)); // 5s delay
    route.fulfill({
      status: 200,
      body: JSON.stringify({ data: 'slow response' }),
    });
  });

  await page.goto('/dashboard');
  // Verify loading state appears
  await expect(page.getByTestId('loading-spinner')).toBeVisible();
});
```

### Record and Replay Network Traffic

```typescript
// Record mode: capture real API responses
test('record API responses', async ({ page }) => {
  const responses = new Map();

  page.on('response', async (response) => {
    if (response.url().includes('/api/')) {
      responses.set(response.url(), await response.json());
    }
  });

  await page.goto('/dashboard');

  // Save responses to file
  fs.writeFileSync('fixtures/dashboard-api.json', JSON.stringify(Array.from(responses.entries())));
});

// Replay mode: use captured responses
test('replay API responses', async ({ page }) => {
  const fixtures = JSON.parse(fs.readFileSync('fixtures/dashboard-api.json', 'utf-8'));

  await page.route('/api/**', (route) => {
    const response = fixtures.find(([url]) => route.request().url().includes(url));
    if (response) {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(response[1]),
      });
    } else {
      route.continue();
    }
  });

  await page.goto('/dashboard');
});
```

## Accessibility Testing

### Automated a11y Checks with axe-core

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage has no accessibility violations', async ({ page }) => {
  await page.goto('/');

  const results = await new AxeBuilder({ page }).analyze();

  expect(results.violations).toEqual([]);
});

test('check specific component for a11y', async ({ page }) => {
  await page.goto('/login');

  const results = await new AxeBuilder({ page })
    .include('#login-form') // Only check specific element
    .exclude('.advertisement') // Exclude third-party content
    .analyze();

  expect(results.violations).toEqual([]);
});
```

### Keyboard Navigation Testing

```typescript
test('form is keyboard accessible', async ({ page }) => {
  await page.goto('/contact');

  // Tab through form fields
  await page.keyboard.press('Tab'); // Focus on first field
  await page.keyboard.type('John Doe');

  await page.keyboard.press('Tab'); // Next field
  await page.keyboard.type('john@example.com');

  await page.keyboard.press('Tab'); // Submit button
  await page.keyboard.press('Enter'); // Submit

  await expect(page.getByText('Thank you')).toBeVisible();
});

test('modal can be closed with Escape', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Open Modal' }).click();

  await expect(page.getByRole('dialog')).toBeVisible();

  await page.keyboard.press('Escape');

  await expect(page.getByRole('dialog')).toBeHidden();
});
```

### Screen Reader Compatibility

```typescript
test('buttons have accessible labels', async ({ page }) => {
  await page.goto('/');

  // Check for aria-label or visible text
  const deleteButton = page.getByRole('button', { name: 'Delete item' });
  await expect(deleteButton).toHaveAttribute('aria-label', 'Delete item');

  // Icons should have accessible names
  const closeButton = page.getByRole('button', { name: 'Close' });
  await expect(closeButton).toBeVisible();
});

test('form inputs have labels', async ({ page }) => {
  await page.goto('/signup');

  // All inputs should be associated with labels
  await expect(page.getByLabel('Email address')).toBeVisible();
  await expect(page.getByLabel('Password')).toBeVisible();
  await expect(page.getByLabel('Confirm password')).toBeVisible();
});
```

### WCAG Compliance Validation

```typescript
test('meets WCAG 2.1 Level AA', async ({ page }) => {
  await page.goto('/');

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa']) // WCAG 2.1 Level AA
    .analyze();

  expect(results.violations).toEqual([]);
});
```

## Mobile Viewport Testing

### Configure Mobile Viewports

```typescript
import { test, devices } from '@playwright/test';

test('mobile viewport', async ({ page }) => {
  // Use predefined device
  await page.setViewportSize(devices['iPhone 13'].viewport);

  await page.goto('/');
  await expect(page.getByTestId('mobile-menu')).toBeVisible();
});

test('custom viewport', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 667 });

  await page.goto('/');
});
```

### Test Responsive Breakpoints

```typescript
const viewports = [
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1920, height: 1080 },
];

for (const viewport of viewports) {
  test(`layout works on ${viewport.name}`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto('/');

    await expect(page).toHaveScreenshot(`homepage-${viewport.name}.png`);
  });
}
```

### Touch Event Simulation

```typescript
test('swipe gesture on mobile', async ({ page }) => {
  await page.setViewportSize(devices['iPhone 13'].viewport);
  await page.goto('/gallery');

  // Simulate swipe
  await page.touchscreen.tap(200, 300);
  await page.touchscreen.swipe({ x: 200, y: 300 }, { x: 50, y: 300 });

  // Verify next image is shown
  await expect(page.getByTestId('image-2')).toBeVisible();
});
```

### Orientation Testing

```typescript
test('supports landscape orientation', async ({ browser }) => {
  const context = await browser.newContext({
    ...devices['iPhone 13'],
    // Rotate to landscape
    viewport: { width: 844, height: 390 },
  });

  const page = await context.newPage();
  await page.goto('/');

  await expect(page.getByTestId('landscape-layout')).toBeVisible();
});
```

## Best Practices

### Isolate Tests (No Shared State)

```typescript
// Bad: Tests depend on execution order
test('create user', async ({ page }) => {
  await createUser('test@example.com');
});

test('login as user', async ({ page }) => {
  await login('test@example.com'); // Fails if previous test didn't run
});

// Good: Each test is independent
test('create user', async ({ page }) => {
  await createUser('test1@example.com');
});

test('login as user', async ({ page }) => {
  await createUser('test2@example.com'); // Creates its own user
  await login('test2@example.com');
});
```

### Use Fixtures for Setup/Teardown

```typescript
// fixtures/authenticated-user.ts
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    // Setup: login before test
    await page.goto('/login');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Log in' }).click();
    await page.waitForURL('/dashboard');

    // Use the authenticated page in test
    await use(page);

    // Teardown: cleanup after test
    await page.getByRole('button', { name: 'Logout' }).click();
  },
});

// Using the fixture
test('authenticated user can view profile', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/profile');
  await expect(authenticatedPage.getByText('My Profile')).toBeVisible();
});
```

### Retry Flaky Assertions, Not Entire Tests

```typescript
// Bad: Retry entire test
test('data loads', async ({ page }) => {
  await page.goto('/dashboard');
  await page.reload(); // Manual retry
  await expect(page.getByText('Dashboard')).toBeVisible();
});

// Good: Let Playwright's auto-wait handle it
test('data loads', async ({ page }) => {
  await page.goto('/dashboard');
  // Automatically retries until visible or timeout
  await expect(page.getByText('Dashboard')).toBeVisible({ timeout: 10000 });
});
```

### Parallelize Test Suites

```typescript
// playwright.config.ts
export default defineConfig({
  workers: 4, // Run 4 tests in parallel
  fullyParallel: true,
});

// Disable parallel for specific tests
test.describe.configure({ mode: 'serial' });

test('step 1', async ({ page }) => {
  // Runs first
});

test('step 2', async ({ page }) => {
  // Runs after step 1
});
```

### Use Meaningful Test Names

```typescript
// Bad
test('test 1', async ({ page }) => {});
test('login works', async ({ page }) => {});

// Good
test('user with valid credentials can log in successfully', async ({ page }) => {});
test('displays error message when password is incorrect', async ({ page }) => {});
test('redirects to two-factor auth when 2FA is enabled', async ({ page }) => {});
```

## Summary

Browser testing is most effective when:

- Tests are focused, isolated, and independent
- Selectors are semantic and resilient to changes
- Visual regression catches unintended UI changes
- Accessibility is validated automatically
- Network behavior is controlled and predictable
- Tests run fast and in parallel
- Failures are easy to diagnose and reproduce

Follow these patterns to build a reliable, maintainable browser test suite.
