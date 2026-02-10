---
description: >
  Run MongoDB schema quality gate suite checking JSON Schema validators, index coverage using the
  ESR rule, antipattern detection for unbounded arrays and excessive embedding, and naming
  convention consistency. Full mode runs all checks; quick mode runs naming conventions and
  validation rule presence only.
argument-hint: '[--quick]'
allowed-tools: Bash(mongosh *), Bash(git *), Read, Grep, Glob
---

# MongoDB Validate Command

This command runs a comprehensive quality gate suite against MongoDB schema definitions, collection
configurations, and query patterns found in the repository. It operates on repository artifacts by
default and never connects to a live database unless the `--live` flag is explicitly provided.

---

## Table of Contents

1. [Execution Modes](#execution-modes)
2. [Core Principles](#core-principles)
3. [Schema Validation Checks](#schema-validation-checks)
4. [Index Coverage Checks](#index-coverage-checks)
5. [Antipattern Detection](#antipattern-detection)
6. [Naming Convention Checks](#naming-convention-checks)
7. [Output Format](#output-format)
8. [Detect and Skip](#detect-and-skip)

---

## Execution Modes

### Full Mode (default)

Run all checks:

1. Schema validation (JSON Schema validators present and correct)
2. Index coverage (ESR rule compliance, redundant indexes, multikey pitfalls)
3. Antipattern detection (unbounded arrays, excessive embedding, $where, etc.)
4. Naming convention consistency

```bash
/validate
```

### Quick Mode

Run only lightweight checks:

1. Naming convention consistency
2. Validation rule presence (do validators exist, not their correctness)

```bash
/validate --quick
```

### Live Mode

Connect to a running MongoDB instance to validate actual collection state. Requires explicit
`--live` flag and user confirmation of the connection string.

```bash
/validate --live
```

**WARNING**: Live mode connects to a database. Before proceeding, display the connection string
(masking credentials) and wait for explicit user confirmation.

---

## Core Principles

### Principle 1: Repository Artifacts Only (Default)

By default, this command analyzes only files in the repository. It scans for:

- Mongoose schema definitions (`mongoose.Schema`, `new Schema`)
- Prisma MongoDB schema files (`schema.prisma` with `provider = "mongodb"`)
- Native driver collection setup scripts (`createCollection`, `createIndex`)
- Migration files (`.js`, `.ts` files in `migrations/` directories)
- Seed files and fixture files
- JSON Schema validator definitions
- mongosh scripts (`.js` files with `db.` calls)

It does NOT connect to any database unless `--live` is explicitly specified.

### Principle 2: Detect and Skip

When a check encounters a file or pattern it cannot parse or understand, it must skip that check and
report it rather than failing or producing false positives.

```text
SKIP: Could not parse schema definition in src/models/legacy.js (line 42)
      Reason: Non-standard schema pattern detected
      Action: Manual review recommended
```

### Principle 3: Never Suggest Disabling Checks

When a check fails, provide guidance on fixing the issue. Never suggest disabling the validation
check, suppressing the warning, or removing the validator.

```text
# CORRECT output:
FAIL: Collection "orders" missing JSON Schema validator
      Fix: Add a validator using db.createCollection() or db.runCommand({ collMod: ... })
      See: agents/mongodb-specialist.md#json-schema-validators

# WRONG output:
FAIL: Collection "orders" missing JSON Schema validator
      Fix: Add // @validate-ignore to suppress this warning
```

### Principle 4: Prisma + Mongoose Dual-Source Warning

If the project uses both Prisma with MongoDB provider AND Mongoose, emit a warning about potential
schema definition conflicts.

```text
WARN: Dual ODM detected (Prisma MongoDB + Mongoose)
      Both define schema structure for MongoDB collections.
      Ensure schema definitions are synchronized between:
        - prisma/schema.prisma
        - src/models/*.js (Mongoose schemas)
      Conflicting schemas can cause validation errors at runtime.
```

---

## Schema Validation Checks

These checks verify that collections have proper JSON Schema validators defined in the repository
artifacts.

### Check SV-1: Validator Presence

Every collection that receives writes should have a JSON Schema validator.

**Scan targets:**

- `db.createCollection("name", { validator: ... })` calls
- `db.runCommand({ collMod: "name", validator: ... })` calls
- Mongoose schema definitions (which enforce validation at the application level)
- Prisma model definitions with `@db.ObjectId`, `@map`, etc.

```javascript
// PASS — collection has a validator
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['email', 'name'],
      properties: {
        email: { bsonType: 'string' },
        name: { bsonType: 'string' },
      },
    },
  },
});
```

```javascript
// FAIL — collection created without validator
db.createCollection('users');
// No validator defined anywhere in the codebase for "users"
```

### Check SV-2: Required Fields

Validators should specify `required` arrays for mandatory fields.

```javascript
// PASS — required fields defined
{
  $jsonSchema: {
    bsonType: "object",
    required: ["email", "name", "role", "createdAt"],
    properties: { /* ... */ }
  }
}

// FAIL — no required fields
{
  $jsonSchema: {
    bsonType: "object",
    properties: {
      email: { bsonType: "string" },
      name: { bsonType: "string" }
    }
    // Missing: required array
  }
}
```

### Check SV-3: BSON Type Correctness

Validators should use `bsonType` instead of `type` for MongoDB-specific types.

```javascript
// PASS — uses bsonType
{
  bsonType: 'objectId';
}
{
  bsonType: 'date';
}
{
  bsonType: 'decimal';
}

// FAIL — uses JSON Schema type for MongoDB-specific types
{
  type: 'string';
} // Acceptable for strings
{
  type: 'object';
} // Should use bsonType: "object"
```

### Check SV-4: Validation Level and Action

Validators should specify `validationLevel` and `validationAction`.

```javascript
// PASS — explicit validation level and action
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      /* ... */
    },
  },
  validationLevel: 'strict',
  validationAction: 'error',
});

// WARN — validation level defaults not explicitly set
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      /* ... */
    },
  },
  // validationLevel defaults to "strict" (OK but implicit)
  // validationAction defaults to "error" (OK but implicit)
});
```

### Check SV-5: Mongoose Schema Completeness

For Mongoose schemas, check that field types and required flags are set.

```javascript
// PASS — Mongoose schema with types and required
const userSchema = new Schema({
  email: { type: String, required: true, unique: true },
  name: {
    first: { type: String, required: true },
    last: { type: String, required: true },
  },
  role: { type: String, enum: ['admin', 'editor', 'viewer'], required: true },
  createdAt: { type: Date, default: Date.now },
});

// FAIL — Mongoose schema with loose types
const userSchema = new Schema({
  email: String, // No required flag
  name: Schema.Types.Mixed, // Mixed type — no validation
  data: {}, // Empty object — no validation
});
```

---

## Index Coverage Checks

### Check IC-1: ESR Rule Compliance

For compound indexes, verify that fields follow the Equality-Sort-Range order.

**Scan targets:**

- `createIndex()` calls paired with common query patterns
- Mongoose schema `index()` definitions
- Prisma `@@index` directives

```javascript
// PASS — ESR order
db.users.createIndex({ status: 1, lastName: 1, createdAt: 1 });
// Matches query: find({ status: "active" }).sort({ lastName: 1 })
//                with createdAt range filter

// FAIL — Range before Sort
db.users.createIndex({ status: 1, createdAt: 1, lastName: 1 });
// If sort is on lastName, this index cannot optimize the sort
```

### Check IC-2: Redundant Index Detection

Identify indexes that are prefixes of other indexes.

```javascript
// FAIL — redundant index
db.orders.createIndex({ customerId: 1 }); // Redundant
db.orders.createIndex({ customerId: 1, orderDate: -1 }); // Covers above

// Output:
// WARN: Redundant index detected on "orders"
//       Index { customerId: 1 } is a prefix of { customerId: 1, orderDate: -1 }
//       The compound index serves both query patterns.
//       Consider dropping the single-field index to save storage and RAM.
```

### Check IC-3: Missing Index for Common Patterns

Detect query patterns without supporting indexes.

**Scan for queries in:**

- `.find()`, `.findOne()`, `.findOneAndUpdate()` calls
- `.aggregate()` pipelines with `$match` stages
- `.sort()` calls

```javascript
// FAIL — sort on unindexed field
db.products.find({ category: 'electronics' }).sort({ price: -1 });
// No index on { category: 1, price: -1 } found

// Output:
// WARN: Potential missing index for query in src/services/products.js:42
//       Query pattern: find({ category }) sort({ price: -1 })
//       Suggested index: { category: 1, price: -1 }
```

### Check IC-4: Multikey Index Pitfalls

Warn about compound indexes that might include multiple array fields.

```javascript
// FAIL — potential multikey conflict
db.products.createIndex({ tags: 1, variants: 1 });
// If both tags and variants are arrays, this index cannot be created

// Output:
// WARN: Potential multikey conflict on "products"
//       Index { tags: 1, variants: 1 } will fail if both fields
//       contain arrays in any document. MongoDB does not allow
//       compound multikey indexes on multiple array fields.
```

### Check IC-5: Index Count Advisory

Warn when a collection has more than 10 indexes.

```javascript
// WARN — too many indexes
// Output:
// WARN: Collection "products" has 14 indexes defined
//       Excessive indexes increase write latency and storage usage.
//       Review index usage with db.products.aggregate([{ $indexStats: {} }])
//       and drop unused indexes.
```

---

## Antipattern Detection

### Check AP-1: Unbounded Arrays

Detect array fields that can grow without limit.

**Detection heuristics:**

- `$push` without `$slice` in update operations
- `$addToSet` on fields that represent user-generated content
- Schema fields typed as arrays without `maxItems`
- Arrays used for relationships (followerIds, commentIds) without bounds

```javascript
// FAIL — unbounded array growth
db.users.updateOne({ _id: userId }, { $push: { followers: newFollowerId } });
// No $slice — followers array grows without limit

// Output:
// FAIL: Unbounded array growth detected in src/services/users.js:87
//       Field: followers (via $push without $slice)
//       Risk: Document size approaching 16 MB limit over time
//       Fix: Use $push with $slice, or move to a separate collection:
//         db.users.updateOne(
//           { _id: userId },
//           { $push: { followers: { $each: [newFollowerId], $slice: -1000 } } }
//         );
//       Or: Reference pattern with a "followers" collection
```

```javascript
// PASS — bounded array with $slice
db.users.updateOne(
  { _id: userId },
  {
    $push: {
      recentActivity: {
        $each: [newActivity],
        $slice: -50, // Keep only last 50 entries
      },
    },
  }
);
```

### Check AP-2: Excessive Embedding Size

Detect embedded documents or arrays that could approach the 16 MB limit.

**Detection heuristics:**

- Embedding patterns with many fields in nested objects
- Arrays of objects with large sub-document schemas
- Patterns where both parent and child have substantial data

```javascript
// FAIL — embedding large sub-documents
const orderSchema = new Schema({
  customer: {
    /* 20 fields */
  },
  items: [
    {
      product: {
        /* 30 fields including description, specs, images */
      },
      quantity: Number,
      price: Number,
    },
  ],
  shipping: {
    /* 15 fields */
  },
  billing: {
    /* 15 fields */
  },
  history: [
    {
      /* unlimited status changes */
    },
  ],
});

// Output:
// WARN: Potential excessive embedding in src/models/order.js
//       Embedded fields: customer (20 fields), items.product (30 fields),
//       shipping (15 fields), billing (15 fields), history (unbounded array)
//       Estimated document size could exceed 2 MB for large orders.
//       Consider: Use extended reference pattern for customer and product,
//       move history to a separate collection.
```

### Check AP-3: $where Usage

`$where` allows arbitrary JavaScript execution and cannot use indexes.

```javascript
// FAIL — $where detected
db.users.find({
  $where: function () {
    return this.firstName + ' ' + this.lastName === 'Jane Doe';
  },
});

// Output:
// FAIL: $where operator detected in src/queries/users.js:23
//       $where executes JavaScript for every document (no index usage).
//       Performance: O(N) collection scan with JS overhead.
//       Fix: Use standard query operators:
//         db.users.find({ firstName: "Jane", lastName: "Doe" })
//       Or add a computed field:
//         db.users.find({ fullName: "Jane Doe" })
```

### Check AP-4: Unindexed $lookup

Detect `$lookup` stages where the foreign field might not be indexed.

```javascript
// FAIL — $lookup on potentially unindexed field
db.orders.aggregate([
  {
    $lookup: {
      from: 'products',
      localField: 'items.sku',
      foreignField: 'sku',
      as: 'productDetails',
    },
  },
]);
// No index found for products.sku in the codebase

// Output:
// WARN: Potentially unindexed $lookup in src/aggregations/orders.js:15
//       $lookup from "products" on foreignField "sku"
//       No index definition found for products.sku
//       Without an index, this causes a collection scan for each
//       input document. Add: db.products.createIndex({ sku: 1 })
```

### Check AP-5: Missing Error Handling in Transactions

Detect transaction usage without proper error handling and retry logic.

```javascript
// FAIL — transaction without error handling
const session = client.startSession();
session.startTransaction();
await collection.updateOne({ _id: id1 }, { $set: data1 }, { session });
await collection.updateOne({ _id: id2 }, { $set: data2 }, { session });
await session.commitTransaction();
session.endSession();

// Output:
// WARN: Transaction without error handling in src/services/transfer.js:34
//       No try/catch around transaction operations.
//       No retry logic for TransientTransactionError or
//       UnknownTransactionCommitResult.
//       Fix: Wrap in try/catch with retry logic.
//       See: agents/mongodb-specialist.md#transactions
```

### Check AP-6: Raw String ObjectId Comparisons

Detect comparisons of ObjectId fields using string values.

```javascript
// FAIL — string comparison with ObjectId field
db.orders.find({ customerId: '64a1b2c3d4e5f6a7b8c9d0e1' });

// Output:
// WARN: String used where ObjectId expected in src/queries/orders.js:12
//       Field "customerId" appears to be an ObjectId based on schema,
//       but query uses a string value.
//       Fix: Use ObjectId("64a1b2c3d4e5f6a7b8c9d0e1")
```

### Check AP-7: Date Strings Instead of ISODate

Detect date fields stored or queried as strings.

```javascript
// FAIL — date stored as string
db.events.insertOne({
  name: 'conference',
  date: '2024-03-15', // String, not ISODate
});

// Output:
// WARN: Date stored as string in src/seed/events.js:8
//       Field "date" uses string "2024-03-15" instead of ISODate
//       String dates cannot use date operators ($gt, $lt) correctly
//       Fix: Use ISODate("2024-03-15T00:00:00Z")
```

### Check AP-8: Decimal Values as Doubles

Detect financial or monetary values stored as regular numbers.

```javascript
// FAIL — money as double
const productSchema = new Schema({
  price: { type: Number }, // Double, not Decimal128
  tax: { type: Number },
});

// Output:
// WARN: Potential precision issue in src/models/product.js:3
//       Field "price" uses Number (IEEE 754 double)
//       For monetary values, use Decimal128:
//         price: { type: Schema.Types.Decimal128 }
//       Or in mongosh: NumberDecimal("19.99")
```

---

## Naming Convention Checks

### Check NC-1: Collection Name Style Consistency

All collection names in the project should use the same style.

```javascript
// FAIL — mixed naming styles
db.userProfiles; // camelCase
db.order_items; // snake_case
db.PaymentHistory; // PascalCase

// Output:
// FAIL: Inconsistent collection naming convention
//       Found styles:
//         camelCase:  userProfiles, orderItems (5 collections)
//         snake_case: order_items, payment_logs (2 collections)
//         PascalCase: PaymentHistory (1 collection)
//       Dominant style: camelCase (5/8 collections)
//       Fix: Rename snake_case and PascalCase collections to camelCase:
//         order_items -> orderItems
//         payment_logs -> paymentLogs
//         PaymentHistory -> paymentHistory
```

### Check NC-2: Plural Collection Names

Collection names should use plural nouns.

```javascript
// FAIL — singular collection names
db.user; // Should be: users
db.order; // Should be: orders
db.product; // Should be: products

// PASS — plural collection names
db.users;
db.orders;
db.products;
```

### Check NC-3: Descriptive Names

Collection names should be descriptive, not abbreviated.

```javascript
// FAIL — abbreviated names
db.usr; // Should be: users
db.ord; // Should be: orders
db.txn; // Should be: transactions

// PASS — descriptive names
db.users;
db.orders;
db.transactions;
db.orderLineItems;
```

### Check NC-4: Field Name Consistency

Fields within a collection should use consistent naming (camelCase or snake_case, not mixed).

```javascript
// FAIL — mixed field names in one schema
{
  firstName: "Jane",       // camelCase
  last_name: "Doe",        // snake_case
  EmailAddress: "j@ex.com" // PascalCase
}

// Output:
// FAIL: Inconsistent field naming in "users" collection
//       camelCase: firstName, createdAt, updatedAt (3 fields)
//       snake_case: last_name, phone_number (2 fields)
//       PascalCase: EmailAddress (1 field)
//       Fix: Standardize to camelCase (dominant style)
```

### Check NC-5: Index Name Convention

Custom index names should be descriptive and follow a consistent pattern.

```javascript
// PASS — descriptive index names
db.orders.createIndex(
  { customerId: 1, orderDate: -1 },
  { name: 'orders_customerId_orderDate_desc' }
);

// WARN — default auto-generated names are acceptable but custom names
// improve operational clarity
db.orders.createIndex({ customerId: 1, orderDate: -1 });
// Auto-generated name: customerId_1_orderDate_-1
```

---

## Output Format

### Summary Header

```text
╔══════════════════════════════════════════════════════════╗
║           MongoDB Quality Gate Results                   ║
║           Mode: full | Date: 2024-03-15                  ║
╚══════════════════════════════════════════════════════════╝
```

### Section Results

```text
── Schema Validation ──────────────────────────────────────
  PASS  SV-1  users          Validator present (JSON Schema)
  PASS  SV-1  orders         Validator present (Mongoose)
  FAIL  SV-1  events         No validator found
  PASS  SV-2  users          Required fields defined
  WARN  SV-3  orders         Uses type instead of bsonType for _id
  SKIP  SV-5  legacy.js      Could not parse non-standard schema

── Index Coverage ─────────────────────────────────────────
  PASS  IC-1  users          ESR rule: { status, lastName, createdAt }
  FAIL  IC-2  orders         Redundant: { customerId } covered by compound
  WARN  IC-3  products       Missing index for sort({ price: -1 })
  PASS  IC-4  products       No multikey conflicts detected
  WARN  IC-5  products       14 indexes (threshold: 10)

── Antipattern Detection ──────────────────────────────────
  FAIL  AP-1  users.js:87    Unbounded $push on followers
  WARN  AP-2  order.js       Potential excessive embedding
  FAIL  AP-3  users.js:23    $where operator detected
  WARN  AP-4  orders.js:15   Unindexed $lookup on products.sku
  WARN  AP-5  transfer.js:34 Transaction without error handling

── Naming Conventions ─────────────────────────────────────
  FAIL  NC-1  Mixed styles   camelCase(5) snake_case(2) PascalCase(1)
  FAIL  NC-2  Singular       user, order, product
  PASS  NC-3  Descriptive    All names are descriptive
  FAIL  NC-4  users          Mixed field naming styles
```

### Summary Footer

```text
── Summary ────────────────────────────────────────────────
  Total checks:  24
  Passed:        10  (42%)
  Failed:         8  (33%)
  Warnings:       5  (21%)
  Skipped:        1  (4%)

  Critical issues requiring attention:
  1. AP-1: Unbounded array growth on users.followers
  2. AP-3: $where operator in users query
  3. NC-1: Mixed naming conventions across collections
```

---

## Detect and Skip

### File Detection Strategy

The validate command detects MongoDB-related files using the following priority order:

1. **Mongoose schemas**: Files matching `**/models/**/*.{js,ts}` or containing `mongoose.Schema`,
   `new Schema(`
2. **Prisma MongoDB**: `schema.prisma` files with `provider = "mongodb"`
3. **Native driver scripts**: Files containing `db.createCollection`, `db.collection`, `MongoClient`
4. **Migration files**: Files in `**/migrations/**` directories
5. **Seed/fixture files**: Files in `**/seeds/**` or `**/fixtures/**`
6. **mongosh scripts**: `.js` files containing `db.` prefixed calls

### Skip Conditions

Skip a check when:

- The file cannot be parsed (syntax errors, non-standard patterns)
- The check depends on runtime information not available statically
- The file uses a pattern the validator does not recognize
- The file is generated code (e.g., Prisma client output)

```text
SKIP: IC-1  migrations/001_legacy.js
      Reason: Dynamic index definition using variable field names
      Action: Manual review recommended

SKIP: SV-5  src/models/dynamic.js
      Reason: Schema defined using spread operator with external config
      Action: Verify schema completeness manually
```

### Ignoring False Positives

If a check produces a false positive, the user should add a comment annotation to suppress it for
that specific line:

```javascript
// mongodb-validate-ignore: AP-1 — followers array is bounded by application logic
db.users.updateOne({ _id: userId }, { $push: { followers: newFollowerId } });
```

The validate command recognizes `mongodb-validate-ignore: <CHECK-ID>` comments and skips the
specified check for the annotated code.

---

## Live Mode Checks

When `--live` is specified, additional checks are performed against the running database. These
checks require a connection and cannot be performed on repository artifacts alone.

### Safety Prerequisite

Before any live check, the command MUST:

1. Display the connection URI with credentials masked
2. Show the target database name
3. List the operations that will be performed (all are read-only)
4. Wait for explicit user confirmation

```text
Live mode connection:
  URI: mongodb+srv://***:***@cluster.example.net
  Database: mydb
  Operations: listCollections, collStats, indexStats, validate
  All operations are read-only.

  Confirm (yes/no):
```

### Check LV-1: Collection Validator Sync

Compare validators defined in repository artifacts with those actually applied on the live
collections.

```text
FAIL: LV-1  Validator mismatch on "users"
      Repository defines: required = ["email", "name", "role", "status"]
      Database has:        required = ["email", "name", "role"]
      Missing required:    "status" (defined in repo but not in DB)
      Action: Run db.runCommand({ collMod: "users", validator: ... })
```

### Check LV-2: Index Sync

Compare indexes defined in repository artifacts with those existing on the live database.

```text
WARN: LV-2  Index defined in repo but missing in DB
      Collection: orders
      Missing index: { customerId: 1, orderDate: -1 }
      Source: src/db/collections/orders.js:45

WARN: LV-2  Index exists in DB but not in repo
      Collection: orders
      Extra index: { legacyField: 1 }
      Action: Consider dropping unused index or documenting it
```

### Check LV-3: Collection Stats

Check collection sizes and document counts for potential issues.

```text
WARN: LV-3  Large collection without sharding
      Collection: events
      Document count: 45,000,000
      Data size: 12.4 GB
      Action: Consider sharding or archival strategy

WARN: LV-3  Large average document size
      Collection: orders
      Avg document size: 4.2 MB
      Threshold: 2 MB
      Action: Review embedded data for potential extraction
```

### Check LV-4: Unused Indexes

Use `$indexStats` to identify indexes that have not been used.

```text
WARN: LV-4  Unused index detected
      Collection: products
      Index: { legacyCode: 1 }
      Operations since last restart: 0
      Last used: never
      Action: Consider dropping to save storage and write overhead
```

### Check LV-5: Slow Query Detection

Check the profiler or currentOp for slow queries that indicate missing indexes.

```text
WARN: LV-5  Slow queries detected (profiler level 1, slowms: 100)
      Collection: orders
      Pattern: find({ email: "..." }) — 450ms avg, 23 occurrences
      Execution: COLLSCAN (no index)
      Fix: db.orders.createIndex({ email: 1 })
```

---

## Error Handling

### Graceful Degradation

When individual checks fail, the command continues with remaining checks and reports failures in the
summary.

```text
── Error Report ───────────────────────────────────────────
  ERR   SV-1  src/models/broken.js
        Error: SyntaxError at line 42 (unexpected token)
        Action: Fix syntax error, then re-run validate

  ERR   IC-2  Could not parse index definitions
        Error: Mixed CommonJS/ESM in src/db/indexes.js
        Action: Use consistent module system
```

### Exit Codes

| Code | Meaning                                 |
| ---- | --------------------------------------- |
| 0    | All checks passed                       |
| 1    | One or more checks failed (FAIL)        |
| 2    | Only warnings and skips (no failures)   |
| 3    | Command execution error (parse failure) |

### Timeout Handling

For live mode checks, each database operation has a 30-second timeout. If a check times out, it is
marked as SKIP with the reason.

```text
SKIP: LV-4  Index stats for "events"
      Reason: Operation timed out after 30 seconds
      Action: Collection may be too large for stats aggregation.
              Run db.events.aggregate([{ $indexStats: {} }]) manually.
```

---

## Configuration

### .mongodb-validate.json

Projects can include a configuration file to customize validation behavior.

```json
{
  "naming": {
    "collectionStyle": "camelCase",
    "fieldStyle": "camelCase"
  },
  "thresholds": {
    "maxIndexesPerCollection": 10,
    "maxNestingDepth": 3,
    "maxArraySize": 500,
    "maxDocumentSizeMB": 2
  },
  "ignore": {
    "collections": ["_migrations", "system.*"],
    "checks": ["NC-5"],
    "files": ["src/legacy/**"]
  },
  "live": {
    "timeoutMs": 30000,
    "slowQueryThresholdMs": 100
  }
}
```

When a `.mongodb-validate.json` file is present in the project root, the validate command uses its
settings. Otherwise, defaults are applied.

### Default Thresholds

| Setting                 | Default | Description                      |
| ----------------------- | ------- | -------------------------------- |
| maxIndexesPerCollection | 10      | Warn above this count            |
| maxNestingDepth         | 3       | Fail above this depth            |
| maxArraySize            | 500     | Warn for unbounded arrays        |
| maxDocumentSizeMB       | 2       | Warn for large documents         |
| slowQueryThresholdMs    | 100     | Profiler threshold for live mode |
