---
description: Initialize new TypeScript project with strict, production-ready defaults
argument-hint: '<project-name> [--type=react|nextjs|node-api|library]'
allowed-tools: Bash(npm *), Bash(npx *), Bash(pnpm *), Bash(git *), Read, Write, Edit, Glob
---

# TypeScript Project Scaffolding Command

This command initializes a new TypeScript project with strict, production-ready defaults. It creates
a fully configured project with type safety, testing, linting, and formatting pre-configured.

## Command Behavior

### Project Types

#### React Application (--type=react)

Creates a Vite-powered React application with:

- React 18+ with TypeScript
- Vite for fast development and building
- Vitest for unit testing
- React Testing Library for component testing
- ESLint with React rules (flat config)
- Prettier for formatting
- Strict TypeScript configuration
- CSS Modules or Tailwind CSS option

#### Next.js Application (--type=nextjs)

Creates a Next.js application with:

- Next.js 14+ with App Router
- TypeScript configured for Next.js
- Vitest for unit testing
- Playwright for E2E testing
- ESLint Next.js config (flat config when possible)
- Prettier for formatting
- Strict TypeScript configuration
- CSS Modules or Tailwind CSS option

#### Node API Server (--type=node-api)

Creates a Fastify-based API server with:

- Fastify with TypeScript
- TypeScript path aliases
- Vitest for testing
- ESLint with Node.js rules
- Prettier for formatting
- Request/response type safety
- Error handling utilities
- Environment variable validation with Zod

#### Library (--type=library)

Creates a publishable library with:

- tsup for bundling (ESM + CJS)
- Dual package.json exports
- Vitest for testing
- API Extractor for documentation
- Changeset for versioning
- ESLint with library rules
- Prettier for formatting
- Strict TypeScript for library authoring

### Default Project Type

If no `--type` is specified, create a React application as the default.

## Critical Rules

### Strict TypeScript Configuration

**ALWAYS enable these tsconfig options:**

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUncheckedSideEffectImports": true,
    "allowUnusedLabels": false,
    "allowUnreachableCode": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  }
}
```

### Vitest Over Jest

**ALWAYS use Vitest** for new projects because:

- Faster execution (native ESM)
- Better TypeScript support out of the box
- Vite integration for React/Vue projects
- Compatible API with Jest
- Better watch mode performance
- Native ESM and CJS support

### ESLint Flat Config

**ALWAYS use flat config** (eslint.config.js) for ESLint 9+:

```javascript
// eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactPlugin from 'eslint-plugin-react';
import hooksPlugin from 'eslint-plugin-react-hooks';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    files: ['**/*.{ts,tsx}'],
    plugins: {
      react: reactPlugin,
      'react-hooks': hooksPlugin,
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...hooksPlugin.configs.recommended.rules,
    },
  }
);
```

### Package Manager Preference

**ALWAYS prefer pnpm** unless user specifies otherwise:

- Faster installation
- Disk space efficient
- Strict dependency resolution
- Built-in monorepo support
- Better security

## Implementation Steps

### Step 1: Validate Project Name

```bash
# Check if directory already exists
if [ -d "project-name" ]; then
  echo "Error: Directory 'project-name' already exists"
  exit 1
fi
```

Validate project name:

- No spaces
- No uppercase letters (npm convention)
- Valid npm package name characters
- Not a reserved name (node_modules, etc.)

### Step 2: Create Project Directory

```bash
mkdir project-name
cd project-name
```

### Step 3: Initialize Git Repository

```bash
git init
```

Create .gitignore:

```text
# Dependencies
node_modules
.pnpm-store

# Build outputs
dist
build
.next
out

# Testing
coverage
.vitest

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode
.idea
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
pnpm-debug.log*

# Temporary
.cache
.temp
*.tmp
```

### Step 4: Initialize Package Manager

```bash
# Use pnpm by default
pnpm init
```

Set packageManager field in package.json:

```json
{
  "name": "project-name",
  "version": "0.1.0",
  "type": "module",
  "packageManager": "pnpm@8.15.0"
}
```

## React Application Scaffold

### Step 1: Create with Vite

```bash
pnpm create vite project-name --template react-ts
cd project-name
pnpm install
```

### Step 2: Enhance TypeScript Configuration

Edit tsconfig.json:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUncheckedSideEffectImports": true,
    "allowUnusedLabels": false,
    "allowUnreachableCode": false,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "verbatimModuleSyntax": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### Next.js Step 3: Install Testing Dependencies

```bash
pnpm add -D vitest @vitest/ui @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom
```

### Next.js Step 4: Configure Vitest

Create vitest.config.ts:

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'src/test/', '**/*.d.ts', '**/*.config.*', '**/mockData', 'dist/'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

Create src/test/setup.ts:

```typescript
import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';
import * as matchers from '@testing-library/jest-dom/matchers';

expect.extend(matchers);

afterEach(() => {
  cleanup();
});
```

### Step 5: Install ESLint and Prettier

```bash
pnpm add -D eslint @eslint/js typescript-eslint eslint-plugin-react eslint-plugin-react-hooks eslint-plugin-react-refresh prettier
```

Create eslint.config.js:

```javascript
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactPlugin from 'eslint-plugin-react';
import hooksPlugin from 'eslint-plugin-react-hooks';
import refreshPlugin from 'eslint-plugin-react-refresh';

export default tseslint.config(
  {
    ignores: ['dist', 'node_modules', 'coverage', '.vitest'],
  },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    files: ['**/*.{ts,tsx}'],
    plugins: {
      react: reactPlugin,
      'react-hooks': hooksPlugin,
      'react-refresh': refreshPlugin,
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactPlugin.configs['jsx-runtime'].rules,
      ...hooksPlugin.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
      '@typescript-eslint/consistent-type-imports': [
        'error',
        {
          prefer: 'type-imports',
          fixStyle: 'inline-type-imports',
        },
      ],
    },
  },
  {
    files: ['**/*.{js,cjs,mjs}'],
    ...tseslint.configs.disableTypeChecked,
  }
);
```

Create .prettierrc:

```json
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false
}
```

Create .prettierignore:

```text
dist
build
coverage
node_modules
.vitest
pnpm-lock.yaml
```

### Step 6: Update Package.json Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "validate": "pnpm run typecheck && pnpm run lint && pnpm run test:coverage && pnpm run format:check"
  }
}
```

### Step 7: Create Example Component with Test

Create src/components/Button.tsx:

```typescript
import { type ButtonHTMLAttributes } from 'react';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
}

export function Button({ variant = 'primary', children, ...props }: ButtonProps) {
  return (
    <button
      className={`button button--${variant}`}
      {...props}
    >
      {children}
    </button>
  );
}
```

Create src/components/Button.test.tsx:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Button } from './Button';

describe('Button', () => {
  it('renders children', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: 'Click me' })).toBeInTheDocument();
  });

  it('applies primary variant by default', () => {
    render(<Button>Click me</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveClass('button--primary');
  });

  it('applies secondary variant when specified', () => {
    render(<Button variant="secondary">Click me</Button>);
    const button = screen.getByRole('button');
    expect(button).toHaveClass('button--secondary');
  });
});
```

## Next.js Application Scaffold

### Next.js Step 1: Create with create-next-app

```bash
pnpm create next-app project-name --typescript --eslint --app --src-dir --import-alias "@/*"
cd project-name
```

### Next.js Step 2: Enhance TypeScript Configuration

Edit tsconfig.json to add strict options:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "allowUnusedLabels": false,
    "allowUnreachableCode": false,
    "verbatimModuleSyntax": true
  }
}
```

### Step 3: Install Testing Dependencies

```bash
pnpm add -D vitest @vitest/ui @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom @vitejs/plugin-react
pnpm add -D @playwright/test
```

### Step 4: Configure Vitest

Create vitest.config.ts:

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'src/test/', '**/*.d.ts', '**/*.config.*', 'dist/', '.next/'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### Next.js Step 5: Configure Playwright

```bash
pnpm exec playwright install
```

Create playwright.config.ts:

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
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'pnpm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

### Next.js Step 6: Update Package.json Scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "validate": "pnpm run typecheck && pnpm run lint && pnpm run test:coverage && pnpm run format:check"
  }
}
```

## Node API Server Scaffold

### Server Step 1: Initialize Project

```bash
mkdir project-name
cd project-name
pnpm init
```

### Step 2: Install Dependencies

```bash
pnpm add fastify @fastify/cors @fastify/helmet zod
pnpm add -D typescript @types/node tsx vitest @vitest/ui eslint @eslint/js typescript-eslint prettier
```

### Step 3: Create TypeScript Configuration

Create tsconfig.json:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2023"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUncheckedSideEffectImports": true,
    "allowUnusedLabels": false,
    "allowUnreachableCode": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### Server Step 4: Create Server Entry Point

Create src/server.ts:

```typescript
import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import { envSchema, type Env } from './config/env.js';

const envResult = envSchema.safeParse(process.env);

if (!envResult.success) {
  console.error('Invalid environment variables:', envResult.error.format());
  process.exit(1);
}

const env: Env = envResult.data;

const server = Fastify({
  logger: {
    level: env.LOG_LEVEL,
  },
});

await server.register(cors, {
  origin: env.CORS_ORIGIN,
});

await server.register(helmet);

server.get('/health', async () => {
  return { status: 'ok' };
});

const start = async () => {
  try {
    await server.listen({ port: env.PORT, host: env.HOST });
    server.log.info(`Server listening on ${env.HOST}:${env.PORT}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
```

Create src/config/env.ts:

```typescript
import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  CORS_ORIGIN: z.string().or(z.boolean()).default(true),
});

export type Env = z.infer<typeof envSchema>;
```

### Step 5: Configure Vitest

Create vitest.config.ts:

```typescript
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'dist/', '**/*.config.*'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### Server Step 6: Configure ESLint

Create eslint.config.js:

```javascript
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist', 'node_modules', 'coverage'],
  },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
    },
  }
);
```

### Server Step 7: Update Package.json

```json
{
  "name": "project-name",
  "version": "0.1.0",
  "type": "module",
  "packageManager": "pnpm@8.15.0",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "validate": "pnpm run typecheck && pnpm run lint && pnpm run test:coverage && pnpm run format:check"
  }
}
```

## Library Scaffold

### Library Step 1: Initialize Project

```bash
mkdir project-name
cd project-name
pnpm init
```

### Library Step 2: Install Dependencies

```bash
pnpm add -D typescript tsup vitest @vitest/ui @changesets/cli prettier eslint @eslint/js typescript-eslint
```

### Library Step 3: Create TypeScript Configuration

Create tsconfig.json:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2023"],
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "allowUnusedLabels": false,
    "allowUnreachableCode": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

### Library Step 4: Configure tsup for Building

Create tsup.config.ts:

```typescript
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['cjs', 'esm'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
});
```

### Library Step 5: Configure Package.json for Publishing

```json
{
  "name": "@scope/project-name",
  "version": "0.1.0",
  "type": "module",
  "packageManager": "pnpm@8.15.0",
  "description": "A TypeScript library",
  "keywords": [],
  "license": "MIT",
  "author": "",
  "repository": {
    "type": "git",
    "url": ""
  },
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": {
        "types": "./dist/index.d.ts",
        "default": "./dist/index.js"
      },
      "require": {
        "types": "./dist/index.d.cts",
        "default": "./dist/index.cjs"
      }
    }
  },
  "files": ["dist"],
  "sideEffects": false,
  "scripts": {
    "build": "tsup",
    "dev": "tsup --watch",
    "test": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "validate": "pnpm run typecheck && pnpm run lint && pnpm run test:coverage && pnpm run format:check",
    "prepublishOnly": "pnpm run validate && pnpm run build",
    "changeset": "changeset",
    "version": "changeset version",
    "release": "pnpm run build && changeset publish"
  }
}
```

### Library Step 6: Initialize Changesets

```bash
pnpm exec changeset init
```

### Library Step 7: Create Example Library Code

Create src/index.ts:

```typescript
export function add(a: number, b: number): number {
  return a + b;
}

export function subtract(a: number, b: number): number {
  return a - b;
}
```

Create src/index.test.ts:

```typescript
import { describe, it, expect } from 'vitest';
import { add, subtract } from './index.js';

describe('add', () => {
  it('adds two positive numbers', () => {
    expect(add(2, 3)).toBe(5);
  });

  it('adds negative numbers', () => {
    expect(add(-2, -3)).toBe(-5);
  });
});

describe('subtract', () => {
  it('subtracts two positive numbers', () => {
    expect(subtract(5, 3)).toBe(2);
  });

  it('subtracts negative numbers', () => {
    expect(subtract(-5, -3)).toBe(-2);
  });
});
```

## Common Configuration Files

### EditorConfig

Create .editorconfig:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
```

### VSCode Settings

Create .vscode/settings.json:

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "never"
  },
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true
}
```

Create .vscode/extensions.json:

```json
{
  "recommendations": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode", "vitest.explorer"]
}
```

## Post-Scaffold Steps

### Final Step 1: Install Dependencies

```bash
pnpm install
```

### Final Step 2: Run Initial Validation

```bash
pnpm run validate
```

### Final Step 3: Create Initial Commit

```bash
git add .
git commit -m "chore: initialize project with TypeScript scaffolding"
```

### Final Step 4: Display Success Message

```text
========================================
Project scaffolded successfully!
========================================

Project: project-name
Type: [react|nextjs|node-api|library]
Package Manager: pnpm
Location: /absolute/path/to/project-name

Features:
  ✓ TypeScript with strict mode
  ✓ Vitest for testing
  ✓ ESLint with flat config
  ✓ Prettier for formatting
  ✓ Git initialized
  [Type-specific features]

Next steps:

1. Navigate to your project:
   cd project-name

2. Start development:
   pnpm run dev

3. Run tests:
   pnpm test

4. Validate code quality:
   pnpm run validate

========================================
```

## Additional Options and Customization

### CSS Framework Options

Offer to install CSS frameworks:

```bash
# Tailwind CSS
pnpm add -D tailwindcss postcss autoprefixer
pnpm exec tailwindcss init -p

# CSS Modules (already included in Vite/Next.js)

# Styled Components
pnpm add styled-components
pnpm add -D @types/styled-components
```

### Additional Tooling

Offer optional tools:

1. **Husky for Git hooks**

```bash
pnpm add -D husky lint-staged
pnpm exec husky init
```

1. **Commitlint for commit messages**

```bash
pnpm add -D @commitlint/cli @commitlint/config-conventional
```

1. **Type-safe environment variables**

```bash
pnpm add zod
# Already configured in node-api template
```

## Error Handling

### Project Already Exists

```text
Error: Directory 'project-name' already exists

Please choose a different name or remove the existing directory:
  rm -rf project-name
```

### Invalid Project Name

```text
Error: Invalid project name 'My Project'

Project names must:
  - Be lowercase
  - Contain only letters, numbers, hyphens, and underscores
  - Start with a letter or number

Suggested: my-project
```

### Package Manager Not Found

```text
Error: pnpm is not installed

Install pnpm:
  npm install -g pnpm

Or use a different package manager:
  scaffold my-project --pm=npm
```

## Summary

The scaffold command creates production-ready TypeScript projects with:

1. Strict TypeScript configuration for maximum type safety
2. Modern ESLint flat config with strict rules
3. Vitest for fast, TypeScript-native testing
4. Prettier for consistent formatting
5. Project-specific best practices
6. Complete test examples
7. Validation scripts for quality assurance
8. Git repository initialization
9. Package manager configuration
10. VSCode settings for optimal developer experience

All projects follow TypeScript best practices with no compromises on type safety or code quality.
