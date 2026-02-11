## MongoDB Conventions

- Design schemas for query patterns (not for normalization)
- Embed related data that is queried together; reference when data is shared
- Always create indexes for query patterns — use explain() to verify
- Use MongoDB transactions for multi-document operations requiring atomicity
- ObjectId as default \_id — use custom IDs only with good reason
- Validate documents with JSON Schema validators at collection level
- Naming: camelCase for fields, plural collection names
- Avoid unbounded array growth — cap arrays or use bucket pattern
