## Redis Conventions

- Set TTL on all cache keys — never store data without expiration
- Key naming: `service:entity:id:field` (colon-delimited hierarchy)
- Use appropriate data structures: Strings, Hashes, Sorted Sets, Streams
- Pipeline commands to reduce round trips for bulk operations
- Use SCAN instead of KEYS in production (KEYS blocks the server)
- Connection pooling: reuse connections, set max pool size
- Memory policy: configure maxmemory and eviction policy
- Lua scripts for atomic multi-step operations
