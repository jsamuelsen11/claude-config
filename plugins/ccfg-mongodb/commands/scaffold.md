---
description: >
  Scaffold MongoDB collection setup with JSON Schema validators and index definitions, or generate
  connection configuration with environment variable templates. Detects existing ODM/driver
  (Mongoose, Prisma MongoDB, native drivers) and generates compatible artifacts.
argument-hint: '[collection-setup|connection-config] [--collection <name>]'
allowed-tools: Bash(git *), Read, Write, Edit, Glob
---

# MongoDB Scaffold Command

This command generates MongoDB collection definitions, JSON Schema validators, index configurations,
seed data templates, and connection configuration files. It detects the project's existing MongoDB
tooling and generates compatible artifacts.

---

## Table of Contents

1. [Execution Modes](#execution-modes)
2. [Core Principles](#core-principles)
3. [collection-setup Mode](#collection-setup-mode)
4. [connection-config Mode](#connection-config-mode)
5. [ODM/Driver Detection](#odmdriver-detection)
6. [Safety Rules](#safety-rules)

---

## Execution Modes

### collection-setup (Default)

Generates collection definitions with validators, indexes, and optional seed data. Detects the
project's ODM/driver and generates compatible files.

```bash
/scaffold
/scaffold collection-setup
/scaffold collection-setup --collection users
/scaffold collection-setup --collection orders --with-seed
```

### connection-config

Generates connection configuration templates with environment variables.

```bash
/scaffold connection-config
```

---

## Core Principles

### Principle 1: Never Include Real Credentials

All generated files must use placeholders or environment variable references. Never include actual
passwords, connection strings, or API keys.

```javascript
// CORRECT — environment variable reference
const uri = process.env.MONGODB_URI;

// CORRECT — placeholder in .env.example
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>

// WRONG — real credentials
const uri = "mongodb+srv://admin:p4ssw0rd@prod-cluster.mongodb.net/mydb";
```

### Principle 2: Respect Existing Tools

If the project already uses Mongoose, generate Mongoose schemas. If it uses Prisma with MongoDB,
generate Prisma model additions. Never introduce a competing tool.

### Principle 3: Detect Before Generate

Always scan the project for existing patterns before generating new files. Match the existing code
style, directory structure, and naming conventions.

### Principle 4: Never Overwrite Without Confirmation

Before writing to any existing file, show the user what will change and ask for confirmation. Only
create new files or append to existing ones.

### Principle 5: Include Validators and Indexes

Every scaffolded collection must include:

- JSON Schema validator (or equivalent ODM validation)
- Appropriate indexes based on likely query patterns
- Required fields specification
- BSON type annotations

---

## collection-setup Mode

### Detection Phase

Before generating any files, detect the project's MongoDB stack:

```text
Step 1: Scan for ODM/Driver indicators
  - package.json dependencies: mongoose, @prisma/client, mongodb, mongoist
  - Python: requirements.txt or pyproject.toml: pymongo, motor, mongoengine
  - Go: go.mod: go.mongodb.org/mongo-driver
  - Existing model/schema files in the project

Step 2: Detect directory structure
  - src/models/          (common Mongoose location)
  - prisma/schema.prisma (Prisma location)
  - src/db/              (common native driver location)
  - lib/                 (various)

Step 3: Detect naming convention
  - camelCase vs snake_case for collection names
  - Singular vs plural model file names
  - File extension preference (.js vs .ts)
```

### Mongoose Scaffold

When Mongoose is detected, generate a Mongoose schema file.

#### Template: Mongoose Model

```javascript
// src/models/{CollectionName}.js

const mongoose = require("mongoose");
const { Schema } = mongoose;

/**
 * {CollectionName} Schema
 *
 * @description {Brief description of the collection's purpose}
 * @collection {collectionNames}
 */
const {collectionName}Schema = new Schema(
  {
    // === Required Fields ===

    /**
     * @description {Field description}
     * @required
     * @index
     */
    name: {
      type: String,
      required: [true, "{CollectionName} name is required"],
      trim: true,
      minlength: [1, "Name must be at least 1 character"],
      maxlength: [200, "Name cannot exceed 200 characters"],
      index: true,
    },

    /**
     * @description Status of the {collectionName}
     * @required
     * @enum {string}
     */
    status: {
      type: String,
      required: true,
      enum: {
        values: ["active", "inactive", "archived"],
        message: "Status must be active, inactive, or archived",
      },
      default: "active",
      index: true,
    },

    // === Optional Fields ===

    description: {
      type: String,
      maxlength: [2000, "Description cannot exceed 2000 characters"],
    },

    metadata: {
      type: Map,
      of: Schema.Types.Mixed,
    },

    tags: {
      type: [String],
      validate: {
        validator: function (v) {
          return v.length <= 20;
        },
        message: "Cannot have more than 20 tags",
      },
      index: true,
    },

    // === References ===

    createdBy: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt
    collection: "{collectionNames}", // Explicit collection name

    // JSON Schema validator (applied at MongoDB level)
    // This provides an additional layer of validation beyond Mongoose
    autoIndex: process.env.NODE_ENV !== "production",
  }
);

// === Indexes ===

// Compound index for common query pattern: find by status, sort by createdAt
{collectionName}Schema.index({ status: 1, createdAt: -1 });

// Text index for search
{collectionName}Schema.index(
  { name: "text", description: "text" },
  { weights: { name: 10, description: 1 } }
);

// === Instance Methods ===

/**
 * Archive this {collectionName}
 * @returns {Promise<Document>}
 */
{collectionName}Schema.methods.archive = function () {
  this.status = "archived";
  return this.save();
};

// === Static Methods ===

/**
 * Find active {collectionNames} by creator
 * @param {ObjectId} userId - The creator's user ID
 * @returns {Promise<Document[]>}
 */
{collectionName}Schema.statics.findActiveByCreator = function (userId) {
  return this.find({ createdBy: userId, status: "active" })
    .sort({ createdAt: -1 })
    .lean();
};

// === Middleware ===

{collectionName}Schema.pre("save", function (next) {
  // Pre-save hook logic
  next();
});

// === Virtual Fields ===

{collectionName}Schema.virtual("isActive").get(function () {
  return this.status === "active";
});

// Ensure virtuals are included in JSON output
{collectionName}Schema.set("toJSON", { virtuals: true });
{collectionName}Schema.set("toObject", { virtuals: true });

module.exports = mongoose.model("{CollectionName}", {collectionName}Schema);
```

### Prisma MongoDB Scaffold

When Prisma with MongoDB provider is detected, generate a Prisma model.

#### Template: Prisma Model Addition

```prisma
// Add to prisma/schema.prisma

model {CollectionName} {
  id          String   @id @default(auto()) @map("_id") @db.ObjectId
  name        String
  status      String   @default("active")
  description String?
  tags        String[] @default([])
  createdBy   String   @db.ObjectId
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  // Relations
  creator User @relation(fields: [createdBy], references: [id])

  // Indexes
  @@index([status, createdAt(sort: Desc)])
  @@index([createdBy])
  @@index([tags])

  // Collection mapping
  @@map("{collectionNames}")
}
```

### Native Driver Scaffold (Node.js)

When the native MongoDB driver is detected (no ODM), generate setup scripts.

#### Template: Collection Setup Script

```javascript
// src/db/collections/{collectionNames}.js

/**
 * {CollectionName} Collection Setup
 *
 * Creates the {collectionNames} collection with JSON Schema validation
 * and required indexes.
 *
 * Usage:
 *   node src/db/collections/{collectionNames}.js
 *   # or import and call setup{CollectionName}Collection(db)
 */

/**
 * JSON Schema validator for the {collectionNames} collection
 */
const {collectionName}Validator = {
  $jsonSchema: {
    bsonType: "object",
    title: "{CollectionName} Validation",
    required: ["name", "status", "createdBy", "createdAt"],
    properties: {
      _id: {
        bsonType: "objectId",
      },
      name: {
        bsonType: "string",
        minLength: 1,
        maxLength: 200,
        description: "Name is required and must be 1-200 characters",
      },
      status: {
        bsonType: "string",
        enum: ["active", "inactive", "archived"],
        description: "Status must be one of the allowed values",
      },
      description: {
        bsonType: "string",
        maxLength: 2000,
      },
      tags: {
        bsonType: "array",
        items: { bsonType: "string", maxLength: 50 },
        maxItems: 20,
        uniqueItems: true,
      },
      createdBy: {
        bsonType: "objectId",
        description: "Reference to the creating user",
      },
      createdAt: {
        bsonType: "date",
      },
      updatedAt: {
        bsonType: "date",
      },
    },
    additionalProperties: false,
  },
};

/**
 * Index definitions for the {collectionNames} collection
 */
const {collectionName}Indexes = [
  {
    key: { name: 1 },
    name: "{collectionNames}_name",
  },
  {
    key: { status: 1 },
    name: "{collectionNames}_status",
  },
  {
    key: { status: 1, createdAt: -1 },
    name: "{collectionNames}_status_createdAt_desc",
  },
  {
    key: { createdBy: 1 },
    name: "{collectionNames}_createdBy",
  },
  {
    key: { tags: 1 },
    name: "{collectionNames}_tags",
  },
  {
    key: { name: "text", description: "text" },
    name: "{collectionNames}_text_search",
    weights: { name: 10, description: 1 },
  },
];

/**
 * Create the {collectionNames} collection with validator and indexes
 * @param {import('mongodb').Db} db - MongoDB database instance
 */
async function setup{CollectionName}Collection(db) {
  console.log('Setting up "{collectionNames}" collection...');

  // Create collection with validator
  try {
    await db.createCollection("{collectionNames}", {
      validator: {collectionName}Validator,
      validationLevel: "strict",
      validationAction: "error",
    });
    console.log('  Collection "{collectionNames}" created');
  } catch (error) {
    if (error.codeName === "NamespaceExists") {
      console.log('  Collection "{collectionNames}" already exists, updating validator...');
      await db.command({
        collMod: "{collectionNames}",
        validator: {collectionName}Validator,
        validationLevel: "strict",
        validationAction: "error",
      });
      console.log("  Validator updated");
    } else {
      throw error;
    }
  }

  // Create indexes
  const collection = db.collection("{collectionNames}");
  for (const indexDef of {collectionName}Indexes) {
    const { key, ...options } = indexDef;
    try {
      await collection.createIndex(key, options);
      console.log(`  Index created: ${options.name || JSON.stringify(key)}`);
    } catch (error) {
      if (error.codeName === "IndexOptionsConflict") {
        console.log(`  Index exists with different options: ${options.name}`);
      } else {
        throw error;
      }
    }
  }

  console.log('  "{collectionNames}" setup complete');
}

module.exports = {
  {collectionName}Validator,
  {collectionName}Indexes,
  setup{CollectionName}Collection,
};
```

### Native Driver Scaffold (Python)

When PyMongo or Motor is detected, generate a Python setup module.

#### Template: Python Collection Setup

```python
# src/db/collections/{collection_names}.py

"""
{CollectionName} Collection Setup

Creates the {collection_names} collection with JSON Schema validation
and required indexes.

Usage:
    python -m src.db.collections.{collection_names}
    # or import and call setup_{collection_name}_collection(db)
"""

from datetime import datetime, timezone
from typing import Any

from pymongo.database import Database
from pymongo.errors import CollectionInvalid, OperationFailure


# JSON Schema validator
{COLLECTION_NAME}_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "title": "{CollectionName} Validation",
        "required": ["name", "status", "created_by", "created_at"],
        "properties": {
            "_id": {"bsonType": "objectId"},
            "name": {
                "bsonType": "string",
                "minLength": 1,
                "maxLength": 200,
                "description": "Name is required and must be 1-200 characters",
            },
            "status": {
                "bsonType": "string",
                "enum": ["active", "inactive", "archived"],
                "description": "Status must be one of the allowed values",
            },
            "description": {
                "bsonType": "string",
                "maxLength": 2000,
            },
            "tags": {
                "bsonType": "array",
                "items": {"bsonType": "string", "maxLength": 50},
                "maxItems": 20,
                "uniqueItems": True,
            },
            "created_by": {
                "bsonType": "objectId",
                "description": "Reference to the creating user",
            },
            "created_at": {"bsonType": "date"},
            "updated_at": {"bsonType": "date"},
        },
        "additionalProperties": False,
    }
}

# Index definitions
{COLLECTION_NAME}_INDEXES: list[dict[str, Any]] = [
    {"key": [("name", 1)], "name": "{collection_names}_name"},
    {"key": [("status", 1)], "name": "{collection_names}_status"},
    {
        "key": [("status", 1), ("created_at", -1)],
        "name": "{collection_names}_status_created_at_desc",
    },
    {"key": [("created_by", 1)], "name": "{collection_names}_created_by"},
    {"key": [("tags", 1)], "name": "{collection_names}_tags"},
]


def setup_{collection_name}_collection(db: Database) -> None:
    """Create the {collection_names} collection with validator and indexes."""
    print(f'Setting up "{collection_names}" collection...')

    # Create collection with validator
    try:
        db.create_collection(
            "{collection_names}",
            validator={COLLECTION_NAME}_VALIDATOR,
            validationLevel="strict",
            validationAction="error",
        )
        print(f'  Collection "{collection_names}" created')
    except CollectionInvalid:
        print(f'  Collection "{collection_names}" exists, updating validator...')
        db.command(
            "collMod",
            "{collection_names}",
            validator={COLLECTION_NAME}_VALIDATOR,
            validationLevel="strict",
            validationAction="error",
        )
        print("  Validator updated")

    # Create indexes
    collection = db["{collection_names}"]
    for index_def in {COLLECTION_NAME}_INDEXES:
        key = index_def["key"]
        options = {k: v for k, v in index_def.items() if k != "key"}
        try:
            collection.create_index(key, **options)
            print(f"  Index created: {options.get('name', key)}")
        except OperationFailure as e:
            if "IndexOptionsConflict" in str(e):
                print(f"  Index exists with different options: {options.get('name')}")
            else:
                raise

    print(f'  "{collection_names}" setup complete')
```

### Native Driver Scaffold (Go)

When the Go MongoDB driver is detected, generate a Go setup file.

#### Template: Go Collection Setup

```go
// internal/db/collections/{collectionnames}.go

package collections

import (
	"context"
	"fmt"
	"log"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// {CollectionName}Validator defines the JSON Schema validator for the
// {collectionNames} collection.
var {CollectionName}Validator = bson.M{
	"$jsonSchema": bson.M{
		"bsonType": "object",
		"title":    "{CollectionName} Validation",
		"required": bson.A{"name", "status", "createdBy", "createdAt"},
		"properties": bson.M{
			"_id":       bson.M{"bsonType": "objectId"},
			"name":      bson.M{"bsonType": "string", "minLength": 1, "maxLength": 200},
			"status":    bson.M{"bsonType": "string", "enum": bson.A{"active", "inactive", "archived"}},
			"createdBy": bson.M{"bsonType": "objectId"},
			"createdAt": bson.M{"bsonType": "date"},
			"updatedAt": bson.M{"bsonType": "date"},
		},
		"additionalProperties": false,
	},
}

// Setup{CollectionName}Collection creates the {collectionNames} collection
// with validators and indexes.
func Setup{CollectionName}Collection(ctx context.Context, db *mongo.Database) error {
	collName := "{collectionNames}"
	log.Printf("Setting up %q collection...", collName)

	// Create collection with validator
	opts := options.CreateCollection().
		SetValidator({CollectionName}Validator).
		SetValidationLevel("strict").
		SetValidationAction("error")

	err := db.CreateCollection(ctx, collName, opts)
	if err != nil {
		// Collection may already exist
		if mongo.IsDuplicateKeyError(err) {
			log.Printf("  Collection %q already exists", collName)
		} else {
			return fmt.Errorf("create collection %s: %w", collName, err)
		}
	}

	// Create indexes
	coll := db.Collection(collName)
	indexes := []mongo.IndexModel{
		{Keys: bson.D{{Key: "name", Value: 1}}},
		{Keys: bson.D{{Key: "status", Value: 1}, {Key: "createdAt", Value: -1}}},
		{Keys: bson.D{{Key: "createdBy", Value: 1}}},
		{Keys: bson.D{{Key: "tags", Value: 1}}},
	}

	names, err := coll.Indexes().CreateMany(ctx, indexes)
	if err != nil {
		return fmt.Errorf("create indexes on %s: %w", collName, err)
	}
	for _, name := range names {
		log.Printf("  Index created: %s", name)
	}

	log.Printf("  %q setup complete", collName)
	return nil
}
```

### Tool-Agnostic Fallback

When no specific ODM/driver is detected, generate tool-agnostic mongosh scripts in a `collections/`
directory.

#### Directory Structure

```text
collections/
├── README.md
├── create_collections.js
├── seed_data.js
└── scripts/
    └── create_indexes.js (optional, offered to user)
```

#### Template: create_collections.js

```javascript
// collections/create_collections.js
//
// MongoDB Collection Setup Script
//
// Usage:
//   mongosh mongodb://localhost:27017/mydb create_collections.js
//   mongosh "mongodb+srv://..." create_collections.js
//
// This script creates collections with JSON Schema validators.
// It is idempotent — safe to run multiple times.

print("=== MongoDB Collection Setup ===\n");

// --- {collectionNames} collection ---

print('Creating "{collectionNames}" collection...');

const {collectionName}Validator = {
  $jsonSchema: {
    bsonType: "object",
    title: "{CollectionName} Validation",
    required: ["name", "status", "createdAt"],
    properties: {
      _id: { bsonType: "objectId" },
      name: {
        bsonType: "string",
        minLength: 1,
        maxLength: 200,
        description: "Name is required"
      },
      status: {
        bsonType: "string",
        enum: ["active", "inactive", "archived"],
        description: "Status must be one of the allowed values"
      },
      description: {
        bsonType: "string",
        maxLength: 2000
      },
      tags: {
        bsonType: "array",
        items: { bsonType: "string", maxLength: 50 },
        maxItems: 20,
        uniqueItems: true
      },
      createdBy: { bsonType: "objectId" },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" }
    },
    additionalProperties: false
  }
};

try {
  db.createCollection("{collectionNames}", {
    validator: {collectionName}Validator,
    validationLevel: "strict",
    validationAction: "error"
  });
  print('  Created "{collectionNames}"');
} catch (e) {
  if (e.codeName === "NamespaceExists") {
    print('  "{collectionNames}" already exists, updating validator...');
    db.runCommand({
      collMod: "{collectionNames}",
      validator: {collectionName}Validator,
      validationLevel: "strict",
      validationAction: "error"
    });
    print("  Validator updated");
  } else {
    throw e;
  }
}

// Create indexes
print("  Creating indexes...");
db.{collectionNames}.createIndex({ name: 1 });
db.{collectionNames}.createIndex({ status: 1, createdAt: -1 });
db.{collectionNames}.createIndex({ createdBy: 1 });
db.{collectionNames}.createIndex({ tags: 1 });
db.{collectionNames}.createIndex(
  { name: "text", description: "text" },
  { weights: { name: 10, description: 1 }, name: "{collectionNames}_text" }
);

print('  "{collectionNames}" setup complete\n');

// Repeat for additional collections...

print("=== Setup Complete ===");
```

#### Template: seed_data.js

```javascript
// collections/seed_data.js
//
// MongoDB Seed Data Script
//
// Usage:
//   mongosh mongodb://localhost:27017/mydb seed_data.js
//
// WARNING: This script inserts sample data for development/testing.
// Do NOT run against production databases.

print("=== MongoDB Seed Data ===\n");
print("WARNING: This inserts sample data. Do not run in production.\n");

// --- {collectionNames} seed data ---

const {collectionName}Seeds = [
  {
    name: "Sample {CollectionName} 1",
    status: "active",
    description: "This is a sample {collectionName} for development",
    tags: ["sample", "development"],
    createdBy: ObjectId(),
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Sample {CollectionName} 2",
    status: "active",
    description: "Another sample {collectionName}",
    tags: ["sample"],
    createdBy: ObjectId(),
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Archived {CollectionName}",
    status: "archived",
    description: "This {collectionName} has been archived",
    tags: ["archived", "sample"],
    createdBy: ObjectId(),
    createdAt: new Date(Date.now() - 86400000 * 30), // 30 days ago
    updatedAt: new Date()
  }
];

print('Seeding "{collectionNames}"...');
const result = db.{collectionNames}.insertMany({collectionName}Seeds);
print(`  Inserted ${result.insertedIds.length} documents`);

print("\n=== Seeding Complete ===");
```

#### Template: scripts/create_indexes.js (Optional)

```javascript
// collections/scripts/create_indexes.js
//
// Standalone Index Creation Script
//
// Usage:
//   mongosh mongodb://localhost:27017/mydb scripts/create_indexes.js
//
// This script creates or updates indexes for all collections.
// It is safe to run multiple times (createIndex is idempotent).

print("=== MongoDB Index Creation ===\n");

// --- {collectionNames} indexes ---
print('Creating indexes for "{collectionNames}"...');

db.{collectionNames}.createIndex(
  { name: 1 },
  { name: "{collectionNames}_name" }
);

db.{collectionNames}.createIndex(
  { status: 1, createdAt: -1 },
  { name: "{collectionNames}_status_createdAt_desc" }
);

db.{collectionNames}.createIndex(
  { createdBy: 1 },
  { name: "{collectionNames}_createdBy" }
);

db.{collectionNames}.createIndex(
  { tags: 1 },
  { name: "{collectionNames}_tags" }
);

db.{collectionNames}.createIndex(
  { name: "text", description: "text" },
  { weights: { name: 10, description: 1 }, name: "{collectionNames}_text" }
);

print("  Done\n");

// --- List all indexes for verification ---
print("=== Verifying Indexes ===\n");

const collections = db.getCollectionNames().filter(
  n => !n.startsWith("system.")
);

for (const collName of collections) {
  const indexes = db.getCollection(collName).getIndexes();
  print(`${collName}: ${indexes.length} indexes`);
  indexes.forEach(idx => {
    print(`  ${idx.name}: ${JSON.stringify(idx.key)}`);
  });
}

print("\n=== Index Creation Complete ===");
```

---

## connection-config Mode

Generate connection configuration templates for the detected environment.

### .env.example

```bash
# .env.example
#
# MongoDB Connection Configuration
# Copy this file to .env and fill in your values.
# NEVER commit the .env file to version control.

# --- Connection URI ---
# Atlas:     mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>
# Local:     mongodb://localhost:27017/<database>
# Replica:   mongodb://host1:27017,host2:27017,host3:27017/<database>?replicaSet=<name>
MONGODB_URI=mongodb://localhost:27017/mydb

# --- Database Name ---
# Override the database name from the URI (optional)
MONGODB_DATABASE=mydb

# --- Replica Set ---
# Required for transactions and change streams on self-managed deployments
# Not needed for Atlas (configured automatically)
MONGODB_REPLICA_SET=

# --- Connection Pool ---
# Maximum number of connections in the pool
MONGODB_POOL_SIZE_MAX=50
# Minimum number of connections in the pool
MONGODB_POOL_SIZE_MIN=5

# --- Timeouts (milliseconds) ---
MONGODB_CONNECT_TIMEOUT=10000
MONGODB_SOCKET_TIMEOUT=45000
MONGODB_SERVER_SELECTION_TIMEOUT=30000

# --- Read/Write Concerns ---
# Read preference: primary, primaryPreferred, secondary, secondaryPreferred, nearest
MONGODB_READ_PREFERENCE=primaryPreferred
# Read concern level: local, available, majority, linearizable, snapshot
MONGODB_READ_CONCERN=majority
# Write concern: 0, 1, majority
MONGODB_WRITE_CONCERN=majority
# Write concern timeout (milliseconds)
MONGODB_WRITE_CONCERN_TIMEOUT=5000

# --- TLS/SSL ---
# Set to true for Atlas or when TLS is required
MONGODB_TLS=false
# Path to CA certificate file (self-managed with custom CA)
MONGODB_TLS_CA_FILE=
# Path to client certificate file (for x.509 authentication)
MONGODB_TLS_CERT_FILE=

# --- Authentication ---
# Auth mechanism: SCRAM-SHA-256, MONGODB-X509, MONGODB-AWS
MONGODB_AUTH_MECHANISM=SCRAM-SHA-256
# Auth source database (usually "admin")
MONGODB_AUTH_SOURCE=admin
```

### Node.js Connection Template

When Node.js is detected, also generate a connection module.

```javascript
// src/db/connection.js

const { MongoClient } = require('mongodb');

/**
 * MongoDB connection configuration from environment variables
 */
const config = {
  uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/mydb',
  database: process.env.MONGODB_DATABASE || 'mydb',
  options: {
    maxPoolSize: parseInt(process.env.MONGODB_POOL_SIZE_MAX || '50', 10),
    minPoolSize: parseInt(process.env.MONGODB_POOL_SIZE_MIN || '5', 10),
    connectTimeoutMS: parseInt(process.env.MONGODB_CONNECT_TIMEOUT || '10000', 10),
    socketTimeoutMS: parseInt(process.env.MONGODB_SOCKET_TIMEOUT || '45000', 10),
    serverSelectionTimeoutMS: parseInt(process.env.MONGODB_SERVER_SELECTION_TIMEOUT || '30000', 10),
    retryWrites: true,
    retryReads: true,
    readPreference: process.env.MONGODB_READ_PREFERENCE || 'primaryPreferred',
    readConcern: { level: process.env.MONGODB_READ_CONCERN || 'majority' },
    writeConcern: {
      w: process.env.MONGODB_WRITE_CONCERN || 'majority',
      wtimeout: parseInt(process.env.MONGODB_WRITE_CONCERN_TIMEOUT || '5000', 10),
    },
  },
};

let _client = null;
let _db = null;

/**
 * Get the MongoDB client (singleton)
 * @returns {Promise<MongoClient>}
 */
async function getClient() {
  if (!_client) {
    _client = new MongoClient(config.uri, config.options);
    await _client.connect();
    console.log('MongoDB connected successfully');
  }
  return _client;
}

/**
 * Get the default database
 * @returns {Promise<import('mongodb').Db>}
 */
async function getDb() {
  if (!_db) {
    const client = await getClient();
    _db = client.db(config.database);
  }
  return _db;
}

/**
 * Close the MongoDB connection
 */
async function closeConnection() {
  if (_client) {
    await _client.close();
    _client = null;
    _db = null;
    console.log('MongoDB connection closed');
  }
}

// Handle process termination
process.on('SIGINT', async () => {
  await closeConnection();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await closeConnection();
  process.exit(0);
});

module.exports = { getClient, getDb, closeConnection, config };
```

### Python Connection Template

When Python is detected, generate a Python connection module.

```python
# src/db/connection.py

"""
MongoDB Connection Module

Provides a singleton MongoClient with configuration from environment variables.
"""

import os
import atexit

from pymongo import MongoClient
from pymongo.database import Database


class MongoDBConfig:
    """MongoDB connection configuration from environment variables."""

    uri: str = os.getenv("MONGODB_URI", "mongodb://localhost:27017/mydb")
    database: str = os.getenv("MONGODB_DATABASE", "mydb")
    max_pool_size: int = int(os.getenv("MONGODB_POOL_SIZE_MAX", "50"))
    min_pool_size: int = int(os.getenv("MONGODB_POOL_SIZE_MIN", "5"))
    connect_timeout_ms: int = int(os.getenv("MONGODB_CONNECT_TIMEOUT", "10000"))
    socket_timeout_ms: int = int(os.getenv("MONGODB_SOCKET_TIMEOUT", "45000"))
    server_selection_timeout_ms: int = int(
        os.getenv("MONGODB_SERVER_SELECTION_TIMEOUT", "30000")
    )
    read_preference: str = os.getenv("MONGODB_READ_PREFERENCE", "primaryPreferred")
    w: str = os.getenv("MONGODB_WRITE_CONCERN", "majority")


_client: MongoClient | None = None


def get_client() -> MongoClient:
    """Get the MongoDB client (singleton)."""
    global _client
    if _client is None:
        config = MongoDBConfig()
        _client = MongoClient(
            config.uri,
            maxPoolSize=config.max_pool_size,
            minPoolSize=config.min_pool_size,
            connectTimeoutMS=config.connect_timeout_ms,
            socketTimeoutMS=config.socket_timeout_ms,
            serverSelectionTimeoutMS=config.server_selection_timeout_ms,
            retryWrites=True,
            retryReads=True,
            w=config.w,
        )
    return _client


def get_db() -> Database:
    """Get the default database."""
    client = get_client()
    return client[MongoDBConfig.database]


def close_connection() -> None:
    """Close the MongoDB connection."""
    global _client
    if _client is not None:
        _client.close()
        _client = None


atexit.register(close_connection)
```

### .gitignore Additions

When generating connection config, check `.gitignore` and suggest additions.

```gitignore
# MongoDB
.env
.env.local
.env.*.local
*.pem
*.key
```

---

## ODM/Driver Detection

### Detection Priority

1. **package.json** (Node.js)
   - `mongoose` -> Mongoose scaffold
   - `@prisma/client` + `prisma/schema.prisma` with `mongodb` -> Prisma scaffold
   - `mongodb` (without mongoose/prisma) -> Native Node.js scaffold

2. **requirements.txt / pyproject.toml** (Python)
   - `pymongo` or `motor` -> Native Python scaffold
   - `mongoengine` -> MongoEngine scaffold

3. **go.mod** (Go)
   - `go.mongodb.org/mongo-driver` -> Native Go scaffold

4. **No detection** -> Tool-agnostic mongosh scripts

### Detection Output

```text
Detected MongoDB stack:
  Runtime:  Node.js (package.json found)
  ODM:      Mongoose 8.x
  Location: src/models/
  Style:    camelCase collection names, singular model files
  TypeScript: Yes (.ts files detected)

Generating Mongoose TypeScript schema...
```

---

## Safety Rules

### Rule 1: Never Include Real Credentials

All generated files must use environment variables or clearly marked placeholders. The scaffold
command must never prompt for or accept real database credentials.

### Rule 2: Never Overwrite Existing Files

Before writing any file, check if it already exists. If it does:

- Show a diff of what would change
- Ask the user for confirmation
- Offer to create a `.new` variant instead

### Rule 3: Validate Generated Schemas

After generating schema files, run a basic syntax check:

- For JavaScript: Verify the file parses correctly
- For TypeScript: Verify types are valid
- For Prisma: Suggest running `npx prisma format`

### Rule 4: Include README When Using Fallback

When generating tool-agnostic scripts in `collections/`, always include a README.md explaining how
to use the scripts.

### Rule 5: Respect .gitignore

Never generate files in locations that are gitignored. If the target directory is in `.gitignore`,
warn the user.

### Rule 6: Check for Conflicting ODMs

If both Mongoose and Prisma MongoDB are detected, warn the user before generating scaffolds for
either.

```text
WARNING: Both Mongoose and Prisma MongoDB detected.
  Generating for: Mongoose (detected as primary ODM based on model count)
  If you prefer Prisma, run: /scaffold collection-setup --odm prisma
```

### Rule 7: Idempotent Scripts

All generated setup scripts must be idempotent — safe to run multiple times without side effects.
Use `try/catch` for collection creation and `createIndex` (which is inherently idempotent).
