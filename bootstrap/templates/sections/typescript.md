## TypeScript Conventions

- Toolchain: strict tsconfig, ESLint (lint), Prettier (format), Vitest or Jest (test)
- Strict mode required: `"strict": true` plus `noUncheckedIndexedAccess`
- Prefer `interface` over `type` for object shapes
- Use `unknown` over `any` — narrow with type guards
- Prefer `const` assertions and literal types for constants
- Use discriminated unions for state modeling
- Imports: named imports, no wildcard `import *`
- Test files: `*.test.ts` or `*.spec.ts`, colocated with source
