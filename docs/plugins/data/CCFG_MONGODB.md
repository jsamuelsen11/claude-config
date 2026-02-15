# Plugin: ccfg-mongodb

The MongoDB data plugin. Provides document modeling, aggregation pipeline, and sharding agents,
schema validation, collection scaffolding, and opinionated conventions for consistent MongoDB
development. Focuses on document design, aggregation optimization, sharding strategies, and index
patterns. Safety is paramount — never connects to production databases without explicit user
confirmation.

## Directory Structure

```text
plugins/ccfg-mongodb/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── mongodb-specialist.md
│   ├── aggregation-expert.md
│   └── sharding-specialist.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── mongodb-conventions/
    │   └── SKILL.md
    ├── aggregation-patterns/
    │   └── SKILL.md
    └── sharding-strategies/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-mongodb",
  "description": "MongoDB data plugin: document modeling, aggregation, and sharding agents, schema validation, collection scaffolding, and conventions for consistent MongoDB development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["mongodb", "nosql", "document", "aggregation", "sharding", "atlas"],
  "suggestedPermissions": {
    "allow": []
  }
}
```

## Agents (3)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                 | Role                                                                | Model  |
| --------------------- | ------------------------------------------------------------------- | ------ |
| `mongodb-specialist`  | MongoDB 7+, document modeling, schema validation, BSON types, Atlas | sonnet |
| `aggregation-expert`  | Aggregation pipeline, $lookup, $merge, $out, pipeline optimization  | sonnet |
| `sharding-specialist` | Sharding strategies, shard keys, chunk splitting, zone sharding     | sonnet |

No coverage command — coverage is a code concept, not a database concept. This is intentional and
differs from language plugins.

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-mongodb:validate

**Purpose**: Run the full MongoDB schema quality gate suite in one command.

**Trigger**: User invokes before deploying collection changes or reviewing schema designs.

**Allowed tools**: `Bash(mongosh *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Schema validation**: Check that collections have JSON Schema validators defined. Flag
   collections missing validators. Verify validator rules match documented schema. If both Prisma
   schema and Mongoose models exist, warn about dual-source ambiguity and ask which is
   authoritative. If only one exists, treat it as the canonical source of truth
2. **Index coverage**: Verify compound index ordering follows ESR rule (Equality → Sort → Range).
   Flag queries without supporting indexes. Check for redundant indexes (indexes that are prefixes
   of other compound indexes). Warn about multikey index pitfalls: compound indexes where multiple
   fields are arrays create multiplicative index entries — advisory-only, flag for review, not hard
   fail
3. **Antipattern detection**: Unbounded arrays (arrays that grow without limit), excessive embedding
   (documents approaching 16MB limit), `$where` usage (JavaScript execution, security/performance
   risk), unindexed `$lookup` foreign fields
4. **Naming conventions**: Consistent naming style within project (camelCase or snake_case, not
   mixed). Collection names plural and descriptive
5. Report pass/fail for each gate with output
6. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Naming conventions**: Same as full mode
2. **Validation rule presence**: Flag collections without JSON Schema validators
3. Report pass/fail — skips index analysis and antipattern detection for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — schema definition files, Mongoose models, Prisma schemas,
  and migration scripts. Does not connect to a live database by default. Live DB validation requires
  the `--live` flag and explicit user confirmation before any connection is established
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available, skip that gate and report it as
  SKIPPED
- Checks for presence of conventions document (`docs/db/mongodb-conventions.md` or similar). Reports
  SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-mongodb:scaffold

**Purpose**: Initialize collection setup and connection configuration for MongoDB projects.

**Trigger**: User invokes when setting up MongoDB in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=collection-setup|connection-config]`

**Behavior**:

**collection-setup** (default):

1. Detect project's MongoDB driver/ODM from project files:
   - Mongoose: check package.json for `mongoose` dependency
   - Prisma with MongoDB: check `prisma/schema.prisma` for `provider = "mongodb"`
   - Native driver: check for `mongodb` in package.json, `pymongo` in requirements,
     `go.mongodb.org/mongo-driver` in go.mod
2. If detected, scaffold collection definitions using that tool's conventions:
   - Mongoose: Schema definition files with validators and indexes
   - Prisma: Model definitions in schema.prisma
   - Native: JavaScript/Python collection creation scripts
3. If no tool detected, create tool-agnostic setup:

   ```text
   collections/
   ├── create_collections.js    # mongosh script with validators and indexes
   ├── seed_data.js             # Sample data for development
   └── README.md
   ```

4. Include JSON Schema validators in collection creation scripts
5. Include index definitions alongside collection setup
6. Even when an ODM is detected, offer an optional standalone `scripts/create_indexes.js` for
   environments where ODM index sync is not used (CI, dev onboarding, manual deployments)

**connection-config**:

1. Create `.env.example` with:

   ```text
   MONGODB_URI=mongodb://localhost:27017/dbname
   MONGODB_REPLICA_SET=rs0
   MONGODB_DATABASE=dbname
   ```

2. Add connection configuration snippet appropriate to detected driver/ODM
3. Ensure `.env` is in `.gitignore` (add entry if missing)

**Key rules**:

- Driver/ODM detection is best-effort — never prescribe a tool, respect what the project already
  uses
- Never generates actual database credentials in config files — always placeholder values
- Collection creation scripts include JSON Schema validators by default
- If inside a git repo, verify `.gitignore` includes `.env`
- Scaffold recommends creating a conventions document at `docs/db/mongodb-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### mongodb-conventions

**Trigger description**: "This skill should be used when working on MongoDB databases, designing
document schemas, creating collections, or reviewing MongoDB code."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses Mongoose with a specific schema pattern, follow it. If the project uses snake_case
field names, continue with that convention. These preferences apply to new collections and scaffold
output only.

**Document modeling rules**:

- **Embed vs reference decision tree**:
  - Embed when: data is always accessed together, child documents are few and bounded, no need to
    access children independently
  - Reference when: data is accessed independently, arrays would grow unbounded, many-to-many
    relationships, document would exceed 16MB
  - Hybrid: embed frequently accessed fields, reference the full document for detailed views
- Use JSON Schema validators on all collections — enforce structure at the database level
- Use `_id` with `ObjectId` by default. Custom `_id` values are fine for natural keys (e.g., ISO
  country codes)
- Use `createdAt`/`updatedAt` timestamps on all documents (most ODMs handle this automatically)
- Keep documents under 1MB as a soft limit (16MB hard limit). If approaching limits, restructure

**BSON type rules**:

- Use `Date` (ISODate) for timestamps, never strings
- Use `Decimal128` for financial/precise decimal values, never `Double`
- Use `ObjectId` for references between collections
- Use `Binary` for binary data, with appropriate subtypes
- Use TTL indexes for automatic document expiry (e.g., sessions, logs)

**Collection design rules**:

- Collection names: plural, descriptive, camelCase or snake_case (consistent within project)
- Field names: camelCase (MongoDB convention) or snake_case (consistent within project)
- Avoid deeply nested documents (>3 levels) — flatten or use references
- Use discriminator patterns (a `type` field) for polymorphic collections instead of separate
  collections for each subtype

### aggregation-patterns

**Trigger description**: "This skill should be used when writing MongoDB aggregation pipelines,
using $lookup, $group, $merge, or optimizing pipeline performance."

**Contents**:

- **Pipeline stage ordering**: Place `$match` as early as possible to reduce documents flowing
  through pipeline. Place `$project`/`$addFields` before `$group` to reduce per-document size. Use
  `$limit` early when possible
- **$lookup vs app-side joins**: Use `$lookup` for server-side joins when data is in the same
  cluster. Prefer app-side joins when: crossing database boundaries, need fine-grained caching,
  lookup collection is small and cacheable
- **$facet**: Use for computing multiple aggregations in a single pipeline pass. Each facet
  sub-pipeline runs independently on the same input. Useful for dashboards (counts, averages,
  distributions in one query)
- **$merge for materialized views**: Use `$merge` to write aggregation results to a collection. Run
  on schedule for expensive aggregations. Use `whenMatched: "replace"` for full refresh,
  `whenMatched: "merge"` for incremental updates
- **Pipeline optimization tips**:
  - `$match` + `$sort` at the beginning can use indexes
  - Avoid `$unwind` on large arrays — restructure document model instead
  - Use `$group` with `$accumulator` for complex custom aggregations
  - `$project` with inclusion is faster than exclusion (only send needed fields)
- **$out vs $merge**: Prefer `$merge` over `$out` — `$merge` can update existing documents and
  create the output collection if it doesn't exist, while `$out` replaces the entire collection
  atomically

### sharding-strategies

**Trigger description**: "This skill should be used when planning MongoDB sharding, selecting shard
keys, configuring zone sharding, or diagnosing sharding performance issues."

**Contents**:

- **Shard key selection criteria**:
  - **Cardinality**: High cardinality (many unique values) enables even data distribution. Avoid
    low-cardinality fields (e.g., `status` with 5 values)
  - **Frequency**: Uniform frequency prevents hot spots. Avoid fields where most documents share the
    same value
  - **Monotonicity**: Non-monotonic keys distribute writes evenly. Monotonic keys (ObjectId,
    timestamps) concentrate writes on one shard. Use hashed shard keys for monotonic fields
- **Hashed vs ranged sharding**: Hashed provides even write distribution but poor range query
  performance. Ranged enables efficient range queries but can create hot spots. Choose based on
  primary access pattern
- **Zone sharding for multi-tenancy**: Assign tenant ID ranges to specific shards/zones. Ensures
  tenant data locality. Useful for data residency requirements (geographic compliance)
- **Scatter-gather avoidance**: Queries that include the shard key are targeted to a single shard.
  Queries without the shard key scatter to all shards. Design shard keys to match the most common
  query patterns
- **Chunk management**: Monitor chunk distribution with `sh.status()`. Large chunk imbalance
  indicates poor shard key choice. Jumbo chunks (can't be split) indicate shard key cardinality
  issues
