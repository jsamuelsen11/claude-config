---
name: sharding-strategies
description:
  This skill should be used when planning MongoDB sharding, selecting shard keys, configuring zone
  sharding, or diagnosing sharding performance issues. It provides shard key selection criteria
  covering cardinality, frequency, and monotonicity analysis, hashed vs ranged sharding trade-offs,
  zone sharding patterns for multi-tenancy and data residency, scatter-gather avoidance techniques,
  and chunk management best practices.
version: 0.1.0
---

# Sharding Strategies Skill

This skill defines the conventions, rules, and best practices for MongoDB sharding. Apply these
rules when planning a sharded cluster, selecting shard keys, configuring zone sharding, diagnosing
distribution issues, or reviewing sharding configurations.

---

## Table of Contents

1. [Shard Key Selection Rules](#shard-key-selection-rules)
2. [Hashed vs Ranged Sharding](#hashed-vs-ranged-sharding)
3. [Zone Sharding Patterns](#zone-sharding-patterns)
4. [Scatter-Gather Avoidance](#scatter-gather-avoidance)
5. [Chunk Management Rules](#chunk-management-rules)
6. [Operational Rules](#operational-rules)
7. [Safety Rules](#safety-rules)

---

## Shard Key Selection Rules

### Rule SK-1: High Cardinality Requirement

The shard key must have enough distinct values to distribute data across all current and future
shards. A shard key with low cardinality limits the maximum number of chunks (and therefore shards)
that can hold data.

```javascript
// CORRECT — high cardinality shard key
// userId has millions of distinct values
sh.shardCollection('mydb.userActivity', { userId: 1 });
// Can distribute across any number of shards

// WRONG — low cardinality shard key
// status has only 3-5 values: active, inactive, pending, suspended, deleted
sh.shardCollection('mydb.users', { status: 1 });
// Maximum 5 chunks possible — most shards sit idle
```

**How to evaluate cardinality:**

```javascript
// CORRECT — check cardinality before choosing shard key
const cardinalityCheck = db.orders
  .aggregate([{ $group: { _id: '$candidateField' } }, { $count: 'distinctValues' }])
  .toArray();

print(`Distinct values: ${cardinalityCheck[0].distinctValues}`);
// Rule of thumb: at least 10x the number of planned shards
```

Minimum recommended cardinality:

- For 3 shards: at least 30 distinct values (better: thousands)
- For 10 shards: at least 100 distinct values (better: hundreds of thousands)
- For 50+ shards: thousands of distinct values minimum

### Rule SK-2: Even Frequency Distribution

No single shard key value should represent a disproportionate fraction of the data. Uneven frequency
causes some chunks to be much larger than others, leading to hotspots and jumbo chunks.

```javascript
// CORRECT — analyze frequency before choosing shard key
db.orders.aggregate([
  { $group: { _id: '$customerId', count: { $sum: 1 } } },
  {
    $group: {
      _id: null,
      totalDocuments: { $sum: '$count' },
      distinctKeys: { $sum: 1 },
      maxDocPerKey: { $max: '$count' },
      minDocPerKey: { $min: '$count' },
      avgDocPerKey: { $avg: '$count' },
      stdDevDocPerKey: { $stdDevPop: '$count' },
      p99DocPerKey: {
        $percentile: {
          input: '$count',
          p: [0.99],
          method: 'approximate',
        },
      },
    },
  },
]);
// If maxDocPerKey >> avgDocPerKey, this key has skewed frequency
```

```javascript
// CORRECT — even frequency shard key
// Individual user IDs have roughly similar activity levels
sh.shardCollection('mydb.orders', { customerId: 1, orderDate: 1 });

// WRONG — skewed frequency shard key
// Tenant "mega_corp" has 80% of all data
sh.shardCollection('mydb.orders', { tenantId: 1 });
// Result: one shard holds 80% of data, creating jumbo chunks
```

To fix skewed frequency, add a secondary field to the compound shard key:

```javascript
// CORRECT — compound key adds cardinality within the skewed field
sh.shardCollection('mydb.orders', { tenantId: 1, orderId: 1 });
// mega_corp's data is now splittable across multiple chunks
// because orderId provides sub-division within tenantId
```

### Rule SK-3: Non-Monotonic Growth Pattern

Shard keys that increase or decrease monotonically route all new writes to a single shard — the one
owning the highest (or lowest) range boundary. This creates a write hotspot that negates the
benefits of sharding.

```javascript
// WRONG — monotonically increasing shard key
sh.shardCollection('mydb.events', { timestamp: 1 });
// ALL new inserts go to the chunk owning [<max_timestamp>, MaxKey)
// That shard becomes a bottleneck while others are idle

// WRONG — ObjectId as shard key (starts with timestamp, monotonic)
sh.shardCollection('mydb.logs', { _id: 1 });
// Same hotspot problem: new ObjectIds always land on one shard

// CORRECT — hashed ObjectId distributes writes randomly
sh.shardCollection('mydb.logs', { _id: 'hashed' });
// Writes are evenly distributed across all shards

// CORRECT — compound key with non-monotonic prefix
sh.shardCollection('mydb.events', { deviceId: 1, timestamp: 1 });
// deviceId distributes writes across shards
// timestamp provides range query support within each device
```

**Detecting monotonicity:**

```javascript
// Check if a field is monotonically increasing
db.events.aggregate([{ $sort: { _id: 1 } }, { $limit: 100 }, { $project: { candidateField: 1 } }]);
// If values consistently increase, the field is monotonic
// Common monotonic fields: timestamps, auto-incrementing IDs, ObjectIds
```

### Rule SK-4: Compound Shard Keys Are Usually Better

Compound shard keys provide better distribution and query flexibility than single-field keys. The
prefix field should have good cardinality and non-monotonic growth. The secondary field adds
refinement.

```javascript
// CORRECT — compound shard key
sh.shardCollection('mydb.orders', { customerId: 1, orderDate: 1 });
// Benefits:
// - customerId provides cardinality and write distribution
// - orderDate enables range queries within a customer
// - Queries on { customerId: X } are targeted
// - Queries on { customerId: X, orderDate: range } are targeted

// LESS OPTIMAL — single field shard key
sh.shardCollection('mydb.orders', { customerId: 1 });
// Works but cannot support efficient range queries on orderDate
```

### Rule SK-5: Shard Key Must Support Primary Query Patterns

Choose a shard key that supports your most frequent and critical queries as targeted operations.

```javascript
// Application's primary query: find orders for a customer
db.orders.find({ customerId: custId }).sort({ orderDate: -1 });

// CORRECT — shard key matches primary query
sh.shardCollection('mydb.orders', { customerId: 1, orderDate: 1 });
// Query is targeted to one shard

// WRONG — shard key does not match primary query
sh.shardCollection('mydb.orders', { region: 1, orderId: 1 });
// Query on customerId becomes scatter-gather (hits ALL shards)
```

### Rule SK-6: Immutable Fields Preferred

Shard key fields should be immutable. While MongoDB 4.2+ supports shard key updates, they require
`{ $set: { field: newValue } }` in a transaction and trigger document migration between shards.

```javascript
// CORRECT — immutable shard key fields
sh.shardCollection('mydb.users', { region: 1, userId: 1 });
// region is assigned at creation and never changes
// userId is immutable

// RISKY — mutable shard key field
sh.shardCollection('mydb.users', { tier: 1, userId: 1 });
// If user tier changes (free -> premium), document migrates between shards
// This is slow and creates operational complexity
```

### Shard Key Decision Matrix

| Workload               | Recommended Key                   | Rationale                        |
| ---------------------- | --------------------------------- | -------------------------------- |
| Multi-tenant SaaS      | `{ tenantId: 1, _id: 1 }`         | Tenant isolation + splitability  |
| Time-series + device   | `{ deviceId: 1, timestamp: 1 }`   | Even writes + range queries      |
| Write-heavy, no ranges | `{ _id: "hashed" }`               | Maximum write distribution       |
| User-centric app       | `{ userId: "hashed" }`            | Even distribution, user equality |
| E-commerce orders      | `{ customerId: 1, orderDate: 1 }` | Customer queries + date ranges   |
| Geographic compliance  | `{ region: 1, userId: 1 }`        | Zone sharding + user targeting   |
| IoT sensor data        | `{ sensorId: 1, timestamp: 1 }`   | Sensor targeting + time ranges   |
| Global event log       | `{ eventType: 1, _id: "hashed" }` | Type targeting + even writes     |

---

## Hashed vs Ranged Sharding

### Rule HR-1: Use Hashed Sharding for Write-Heavy, No-Range Workloads

Hashed sharding is optimal when:

- Write distribution is the top priority
- Range queries on the shard key are not needed
- The natural key is monotonically increasing (like ObjectId or timestamp)

```javascript
// CORRECT — hashed sharding for event logs
sh.shardCollection('mydb.events', { _id: 'hashed' });

// Write distribution: ALL shards receive roughly equal write load
// Equality queries: db.events.find({ _id: id }) — targeted (one shard)
// Range queries: db.events.find({ _id: { $gte: a, $lte: b } }) — scatter-gather
```

```javascript
// CORRECT — pre-split chunks for hashed sharding
sh.shardCollection('mydb.events', { _id: 'hashed' }, false, {
  numInitialChunks: 128,
});
// Pre-creates 128 chunks distributed across shards immediately
// Avoids the initial period where all data lands on one shard
```

### Rule HR-2: Use Ranged Sharding for Range-Query Workloads

Ranged sharding is optimal when:

- Range queries on the shard key are frequent and critical
- The shard key is not monotonically increasing
- Zone sharding is required

```javascript
// CORRECT — ranged sharding for multi-tenant with date ranges
sh.shardCollection('mydb.orders', { customerId: 1, orderDate: 1 });

// Range query: targeted
db.orders.find({
  customerId: ObjectId('...'),
  orderDate: { $gte: ISODate('2024-01-01'), $lt: ISODate('2024-04-01') },
});
// Routed to the shard(s) containing this customer's data
```

### Rule HR-3: Compound Hashed Keys for Best of Both (MongoDB 4.4+)

Use a compound shard key with one hashed field to get write distribution on the hashed field and
targeted queries on the ranged field.

```javascript
// CORRECT — compound key with hashed component
sh.shardCollection('mydb.events', { region: 1, eventId: 'hashed' });

// Benefits:
// - Queries on region are targeted (ranged field)
// - eventId hash provides even distribution within regions
// - Zone sharding works on region

// Queries:
db.events.find({ region: 'US' }); // Targeted (ranged prefix)
db.events.find({ region: 'US', eventId: id }); // Targeted (both fields)
db.events.find({ eventId: id }); // Scatter-gather (no prefix)
```

```javascript
// WRONG — multiple hashed fields in compound key
sh.shardCollection('mydb.events', { region: 'hashed', eventId: 'hashed' });
// ERROR: only one hashed field allowed in a compound shard key
```

### Hashed vs Ranged Comparison Table

| Characteristic         | Hashed                        | Ranged                       |
| ---------------------- | ----------------------------- | ---------------------------- |
| Write distribution     | Excellent (random placement)  | Depends on key value pattern |
| Equality queries       | Targeted (one shard)          | Targeted (one shard)         |
| Range queries          | Scatter-gather (all shards)   | Targeted (subset of shards)  |
| Sort on shard key      | Not optimized                 | Optimized                    |
| Zone sharding          | Not supported (single hashed) | Fully supported              |
| Monotonic key handling | Eliminates hotspots           | Creates hotspots             |
| Pre-splitting          | numInitialChunks (automatic)  | Manual splitAt required      |
| Best for               | Write-heavy logs/events       | Range queries, zone sharding |

---

## Zone Sharding Patterns

### Rule ZS-1: Geographic Data Residency

Use zone sharding to ensure data stays within specific geographic boundaries for regulatory
compliance (GDPR, data sovereignty).

```javascript
// CORRECT — geographic zone sharding
// Step 1: Tag shards with zones
sh.addShardTag('shard-eu-1', 'EU');
sh.addShardTag('shard-eu-2', 'EU');
sh.addShardTag('shard-us-1', 'US');
sh.addShardTag('shard-us-2', 'US');
sh.addShardTag('shard-apac-1', 'APAC');

// Step 2: Shard collection with region as first field
sh.shardCollection('mydb.userData', { region: 1, userId: 1 });

// Step 3: Define zone ranges
sh.addTagRange(
  'mydb.userData',
  { region: 'EU', userId: MinKey },
  { region: 'EU', userId: MaxKey },
  'EU'
);
sh.addTagRange(
  'mydb.userData',
  { region: 'US', userId: MinKey },
  { region: 'US', userId: MaxKey },
  'US'
);
sh.addTagRange(
  'mydb.userData',
  { region: 'APAC', userId: MinKey },
  { region: 'APAC', userId: MaxKey },
  'APAC'
);
```

```javascript
// CORRECT — insert with region field for zone routing
db.userData.insertOne({
  region: 'EU',
  userId: ObjectId('...'),
  name: 'Hans Mueller',
  email: 'hans@example.de',
});
// Guaranteed to land on an EU shard

// WRONG — insert without region field
db.userData.insertOne({
  userId: ObjectId('...'),
  name: 'Hans Mueller',
  // Missing region — goes to wrong zone or fails validation
});
```

### Rule ZS-2: Multi-Tenancy Isolation

Use zone sharding to isolate tenant data on dedicated or shared shard groups.

```javascript
// CORRECT — premium tenants on dedicated shards
sh.addShardTag('shard-premium-1', 'premium');
sh.addShardTag('shard-premium-2', 'premium');
sh.addShardTag('shard-standard-1', 'standard');
sh.addShardTag('shard-standard-2', 'standard');
sh.addShardTag('shard-standard-3', 'standard');

sh.shardCollection('mydb.tenantData', { tenantId: 1, _id: 1 });

// Premium tenants get dedicated zone
sh.addTagRange(
  'mydb.tenantData',
  { tenantId: 'ACME', _id: MinKey },
  { tenantId: 'ACME', _id: MaxKey },
  'premium'
);
sh.addTagRange(
  'mydb.tenantData',
  { tenantId: 'GLOBEX', _id: MinKey },
  { tenantId: 'GLOBEX', _id: MaxKey },
  'premium'
);

// All other tenants default to standard zone
// Note: define ranges for standard tenants explicitly, or they may
// end up on any shard. The balancer moves chunks without zone tags
// to balance the cluster, potentially putting standard data on
// premium shards.
```

### Rule ZS-3: Tiered Storage (Hot/Cold Data)

Use zone sharding to place recent data on fast storage and older data on cheaper storage.

```javascript
// CORRECT — hot/cold tiered storage
sh.addShardTag('shard-ssd-1', 'hot');
sh.addShardTag('shard-ssd-2', 'hot');
sh.addShardTag('shard-hdd-1', 'cold');
sh.addShardTag('shard-hdd-2', 'cold');

sh.shardCollection('mydb.auditLogs', { createdAt: 1, _id: 1 });

// Current year on SSD (hot)
sh.addTagRange(
  'mydb.auditLogs',
  { createdAt: ISODate('2024-01-01'), _id: MinKey },
  { createdAt: ISODate('2025-01-01'), _id: MaxKey },
  'hot'
);

// Previous years on HDD (cold)
sh.addTagRange(
  'mydb.auditLogs',
  { createdAt: ISODate('2020-01-01'), _id: MinKey },
  { createdAt: ISODate('2024-01-01'), _id: MaxKey },
  'cold'
);
```

```javascript
// IMPORTANT — automate zone range rotation
// Create a monthly job to update zone boundaries:
//
// 1. Move the cold boundary forward
// 2. Update the hot boundary
// 3. The balancer migrates chunks to the correct zones
//
// Without automation, hot data ages into cold zones never moving to
// cold storage.
```

### Rule ZS-4: Cover the Entire Key Space

Ensure zone ranges cover all possible shard key values. Chunks without a zone assignment are moved
by the balancer for balance, potentially placing them on unintended shards.

```javascript
// CORRECT — full coverage with explicit ranges
sh.addTagRange(
  'mydb.data',
  { region: MinKey, userId: MinKey },
  { region: 'APAC', userId: MinKey },
  'default' // Catch-all for unexpected values
);
sh.addTagRange(
  'mydb.data',
  { region: 'APAC', userId: MinKey },
  { region: 'APAC', userId: MaxKey },
  'APAC'
);
sh.addTagRange(
  'mydb.data',
  { region: 'APAC', userId: MaxKey },
  { region: 'EU', userId: MinKey },
  'default'
);
sh.addTagRange(
  'mydb.data',
  { region: 'EU', userId: MinKey },
  { region: 'EU', userId: MaxKey },
  'EU'
);
// ... and so on for all regions

// WRONG — gaps in zone ranges
// Only defining EU and US zones, leaving APAC data without a zone
// APAC data may land on EU or US shards depending on balancer decisions
```

### Rule ZS-5: Document Zone Assignments

Maintain a clear document of zone assignments, their rationale, and the responsible team for each
zone configuration change.

```javascript
// CORRECT — document zone configuration in version control
// file: sharding/zones.js
//
// Zone Configuration for mydb.userData
// Last updated: 2024-03-15
// Rationale: GDPR compliance requires EU data on EU infrastructure
//
// Zone "EU":
//   Shards: shard-eu-1, shard-eu-2
//   Ranges: region="EU" covers all EU user data
//   Compliance: GDPR Article 44 (data transfers)
//
// Zone "US":
//   Shards: shard-us-1, shard-us-2
//   Ranges: region="US" covers all US user data
//   Compliance: Internal policy
```

---

## Scatter-Gather Avoidance

### Rule SG-1: Include Shard Key in All Frequent Queries

Queries that include the shard key (or its prefix) are routed to specific shards. Queries without
the shard key hit ALL shards.

```javascript
// Shard key: { customerId: 1, orderDate: 1 }

// CORRECT — targeted query (includes shard key prefix)
db.orders.find({ customerId: ObjectId('...') });
// Routed to one or few shards

// CORRECT — targeted query (includes full shard key)
db.orders.find({
  customerId: ObjectId('...'),
  orderDate: { $gte: ISODate('2024-01-01') },
});
// Routed to specific chunk(s)

// WRONG — scatter-gather (no shard key)
db.orders.find({ status: 'pending' });
// Sent to ALL shards, results merged by mongos
// O(N) where N = number of shards
```

### Rule SG-2: Verify Query Routing with explain()

Always verify that critical queries are targeted, not scatter-gather.

```javascript
// CORRECT — check query routing
const plan = db.orders.find({ customerId: ObjectId('...') }).explain('executionStats');

// Targeted query indicators:
// - winningPlan.stage: "SINGLE_SHARD" — query goes to one shard
// - winningPlan.shards: contains only 1-2 shard entries

// Scatter-gather indicators:
// - winningPlan.stage: "SHARD_MERGE" — query goes to all shards
// - winningPlan.shards: contains ALL shard entries
```

### Rule SG-3: Design Secondary Indexes for Non-Shard-Key Queries

For queries that cannot include the shard key, create indexes on each shard to minimize per-shard
execution time.

```javascript
// Shard key: { customerId: 1, orderDate: 1 }
// Occasional query: find orders by email (cannot include shard key)

// CORRECT — create index on each shard for the scatter-gather query
db.orders.createIndex({ 'customer.email': 1 });
// Still scatter-gather, but each shard uses the index = fast per shard

// WRONG — scatter-gather without supporting index
// Each shard performs a collection scan = very slow
```

### Rule SG-4: Use Materialized Views for Cross-Shard Aggregations

If a scatter-gather aggregation is run frequently, pre-compute the results into a materialized view.

```javascript
// Instead of running this scatter-gather query repeatedly:
db.orders.aggregate([
  {
    $group: { _id: '$status', count: { $sum: 1 }, revenue: { $sum: '$total' } },
  },
]);
// This hits ALL shards every time

// CORRECT — materialized view updated on schedule
db.orders.aggregate([
  {
    $group: { _id: '$status', count: { $sum: 1 }, revenue: { $sum: '$total' } },
  },
  { $merge: { into: 'orderStatusSummary', on: '_id', whenMatched: 'replace' } },
]);
// Application reads from unsharded orderStatusSummary collection (fast)
```

### Rule SG-5: Consider mongos Co-Location

Deploy mongos instances alongside application servers to minimize network round trips for
scatter-gather queries.

---

## Chunk Management Rules

### Rule CM-1: Monitor Chunk Distribution Regularly

Uneven chunk distribution indicates potential shard key issues or balancer problems.

```javascript
// CORRECT — check chunk distribution
db.getSiblingDB('config').chunks.aggregate([
  { $match: { ns: 'mydb.orders' } },
  {
    $group: {
      _id: '$shard',
      chunkCount: { $sum: 1 },
    },
  },
  { $sort: { chunkCount: -1 } },
]);

// Healthy distribution: chunk counts within 10% of each other
// Unhealthy: one shard has 2x or more chunks than another
```

### Rule CM-2: Detect and Resolve Jumbo Chunks

Jumbo chunks are chunks that exceed the configured size but cannot be split. They prevent the
balancer from distributing data evenly.

```javascript
// CORRECT — detect jumbo chunks
db.getSiblingDB('config')
  .chunks.find({ jumbo: true })
  .forEach((chunk) => {
    print(`Jumbo chunk on ${chunk.shard}:`);
    print(`  Namespace: ${chunk.ns}`);
    print(`  Range: ${tojson(chunk.min)} -> ${tojson(chunk.max)}`);
  });
```

**Common causes of jumbo chunks:**

1. Single shard key value holds too much data
2. Insufficient cardinality in the shard key
3. Low chunk size configuration with large documents

**Resolution strategies:**

```javascript
// Strategy 1: Split the chunk (if possible)
db.adminCommand({
  split: 'mydb.orders',
  find: { tenantId: 'big_tenant', _id: ObjectId('...') },
});

// Strategy 2: Clear jumbo flag (after resolving root cause)
db.adminCommand({
  clearJumboFlag: 'mydb.orders',
  find: { tenantId: 'big_tenant' },
});

// Strategy 3: Reshard with better key (MongoDB 5.0+)
db.adminCommand({
  reshardCollection: 'mydb.orders',
  key: { tenantId: 1, orderId: 1 }, // Adds cardinality
});
```

### Rule CM-3: Pre-Split Chunks Before Bulk Loading

Before importing large datasets, pre-split chunks to distribute the load evenly across shards.

```javascript
// CORRECT — pre-split for ranged shard key
sh.shardCollection('mydb.users', { region: 1, userId: 1 });

sh.splitAt('mydb.users', { region: 'APAC', userId: MinKey });
sh.splitAt('mydb.users', { region: 'EU', userId: MinKey });
sh.splitAt('mydb.users', { region: 'NA', userId: MinKey });
sh.splitAt('mydb.users', { region: 'SA', userId: MinKey });

// CORRECT — pre-split for hashed shard key (automatic)
sh.shardCollection('mydb.events', { _id: 'hashed' }, false, {
  numInitialChunks: 128,
});
```

```javascript
// WRONG — no pre-splitting before bulk load
sh.shardCollection('mydb.events', { deviceId: 1, timestamp: 1 });
// Immediately load 100 million documents
// All go to one chunk initially, causing migration storms
```

### Rule CM-4: Configure Appropriate Chunk Size

Default chunk size is 128 MB. Adjust based on your workload:

| Chunk Size | Trade-offs                                          |
| ---------- | --------------------------------------------------- |
| 64 MB      | More even distribution, more balancer migrations    |
| 128 MB     | Default, good balance for most workloads            |
| 256 MB     | Fewer migrations, less balancer overhead, less even |

```javascript
// CORRECT — adjust chunk size
use config;
db.settings.updateOne(
  { _id: "chunksize" },
  { $set: { value: 64 } },  // 64 MB
  { upsert: true }
);
```

### Rule CM-5: Monitor Chunk Migrations

Track migration activity to detect performance impacts.

```javascript
// CORRECT — check recent migrations
db.getSiblingDB('config')
  .changelog.find({
    what: { $regex: /moveChunk/ },
  })
  .sort({ time: -1 })
  .limit(20)
  .forEach((entry) => {
    print(`${entry.time}: ${entry.what}`);
    print(`  From: ${entry.details.from} -> To: ${entry.details.to}`);
    if (entry.details.errmsg) {
      print(`  ERROR: ${entry.details.errmsg}`);
    }
  });

// Count successful vs failed migrations in last 24 hours
const yesterday = new Date(Date.now() - 86400000);

const successful = db.getSiblingDB('config').changelog.countDocuments({
  what: 'moveChunk.commit',
  time: { $gte: yesterday },
});

const failed = db.getSiblingDB('config').changelog.countDocuments({
  what: 'moveChunk.error',
  time: { $gte: yesterday },
});

print(`Last 24h: ${successful} successful, ${failed} failed migrations`);
```

---

## Operational Rules

### Rule OP-1: Resharding Requires Planning (MongoDB 5.0+)

`reshardCollection` changes the shard key by performing a full data copy. It requires significant
resources and planning.

```javascript
// CORRECT — planned resharding
// Step 1: Verify MongoDB version supports reshardCollection
db.adminCommand({ buildInfo: 1 }).version;

// Step 2: Estimate storage requirements (temporarily doubles)
const stats = db.orders.stats();
print(`Current data size: ${stats.size / 1048576} MB`);
print(`Estimated temp storage needed: ${stats.size / 524288} MB`);

// Step 3: Schedule during low-traffic period

// Step 4: Create a backup
// mongodump --uri="..." --gzip --archive=pre_reshard_backup.gz

// Step 5: Execute resharding
db.adminCommand({
  reshardCollection: 'mydb.orders',
  key: { customerId: 1, orderId: 1 },
});

// Step 6: Monitor progress
db.adminCommand({ currentOp: true, desc: 'ReshardingCoordinator' });
```

```javascript
// WRONG — resharding without preparation
db.adminCommand({
  reshardCollection: 'mydb.orders',
  key: { customerId: 1, orderId: 1 },
});
// No backup, no storage check, no low-traffic scheduling
// Risk: disk full, extended latency during peak hours
```

### Rule OP-2: Balancer Window Configuration

Configure the balancer to run during off-peak hours to minimize performance impact on the
application.

```javascript
// CORRECT — balancer window for off-peak hours
use config;
db.settings.updateOne(
  { _id: "balancer" },
  {
    $set: {
      activeWindow: {
        start: "02:00",   // 2 AM
        stop: "06:00"     // 6 AM
      }
    }
  },
  { upsert: true }
);
```

### Rule OP-3: Never Disable the Balancer Permanently

Stopping the balancer temporarily for maintenance is acceptable. Leaving it disabled causes
progressive shard imbalance.

```javascript
// CORRECT — temporary balancer stop for maintenance
sh.stopBalancer();
// Perform maintenance (< 4 hours)
sh.startBalancer();

// WRONG — disable and forget
sh.stopBalancer();
// ... months later: massive chunk imbalance
// One shard at 90% capacity, others at 30%
```

### Rule OP-4: Health Check Checklist

Run this checklist weekly for production sharded clusters:

```javascript
// 1. Balancer status
print('Balancer enabled: ' + sh.getBalancerState());
print('Balancer running: ' + sh.isBalancerRunning());

// 2. Chunk distribution per collection
sh.status();

// 3. Jumbo chunk detection
const jumboCount = db.getSiblingDB('config').chunks.countDocuments({ jumbo: true });
print('Jumbo chunks: ' + jumboCount);

// 4. Failed migrations (last 7 days)
const weekAgo = new Date(Date.now() - 604800000);
const failedMigrations = db.getSiblingDB('config').changelog.countDocuments({
  what: 'moveChunk.error',
  time: { $gte: weekAgo },
});
print('Failed migrations (7d): ' + failedMigrations);

// 5. Shard health
db.adminCommand({ listShards: 1 }).shards.forEach((s) => {
  print(`${s._id}: ${s.state} (${s.host})`);
});

// 6. Config server replication health
db.adminCommand({ replSetGetStatus: 1 });
```

### Rule OP-5: Adding and Removing Shards

Always follow the complete procedure for adding or removing shards.

```javascript
// CORRECT — adding a shard
sh.addShard('new-shard-rs/host1:27018,host2:27018,host3:27018');
sh.status(); // Verify
// Optionally assign zones
sh.addShardTag('new-shard-rs', 'standard');
// Balancer will migrate chunks to the new shard automatically
```

```javascript
// CORRECT — removing a shard (complete procedure)
// Step 1: Start draining
db.adminCommand({ removeShard: 'old-shard-rs' });

// Step 2: Monitor until remaining = 0
let status;
do {
  status = db.adminCommand({ removeShard: 'old-shard-rs' });
  print(`Remaining: ${JSON.stringify(status.remaining)}`);
  sleep(10000);
} while (status.state === 'ongoing');

// Step 3: Move any primary databases
db.adminCommand({ movePrimary: 'mydb', to: 'other-shard-rs' });

// Step 4: Final removal
db.adminCommand({ removeShard: 'old-shard-rs' });
// Should report state: "completed"
```

---

## Safety Rules

### Rule SF-1: Never Connect to Production Without Confirmation

Before running any sharding command against a production cluster, display the mongos URI (masking
credentials) and wait for explicit user approval.

```text
WARNING: About to execute sharding commands against:
  mongodb+srv://***:***@prod-cluster.mongodb.net
  Cluster: prod-cluster (3 shards, 9 nodes)

  Please confirm this is the correct target.
```

### Rule SF-2: Shard Key Changes Are Difficult

Changing a shard key requires either:

- `reshardCollection` (MongoDB 5.0+): Full data migration, doubles storage
- Drop and recreate (pre-5.0): Data loss risk without backup

Always verify the shard key choice thoroughly before applying.

### Rule SF-3: Test in Staging Before Production

All sharding strategies, zone configurations, and shard key choices must be tested in a staging
environment that mirrors production data patterns.

### Rule SF-4: Backup Before Resharding or Zone Changes

Always create a full backup before any resharding operation or major zone reconfiguration.

### Rule SF-5: Monitor After Sharding Changes

After any sharding change (new shard, removed shard, zone update, reshard), monitor the cluster for
at least 24 hours for:

- Chunk migration activity
- Query latency changes
- Connection count spikes
- Failed migrations
- Jumbo chunk creation
