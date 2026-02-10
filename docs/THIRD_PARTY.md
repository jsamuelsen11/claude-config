# Third-Party Plugins and MCP Servers

Recommended third-party tools that complement the ccfg plugin marketplace. These provide
capabilities that ccfg plugins reference or that enhance the overall Claude Code development
experience.

## Official Claude Code Plugins

These are maintained in
[claude-plugins-official](https://github.com/anthropics/claude-plugins-official) and installed
separately from this marketplace.

### Context7

Up-to-date documentation retrieval for any programming library.

- **What it does**: Fetches current docs and code examples so Claude always has accurate API
  references, even for recently released versions
- **Install**: `claude plugin install context7@claude-plugins-official`
- **When to use**: Any project where you need accurate, current library documentation

### Serena

Semantic code navigation, refactoring, and persistent memory.

- **What it does**: Provides LSP-powered symbol search, cross-reference navigation, and a knowledge
  graph memory that persists across sessions
- **Install**: `claude plugin install serena@claude-plugins-official`
- **When to use**: Large codebases where semantic understanding of symbol relationships matters

### Greptile

AI-powered code review and codebase search.

- **What it does**: Reviews pull requests for bugs, security issues, and style violations; provides
  deep codebase search with natural language queries
- **Install**: `claude plugin install greptile@claude-plugins-official`
- **When to use**: Team workflows with PR reviews, or when searching across large repositories

## MCP Servers Bundled in ccfg Plugins

These MCP servers are already configured in ccfg plugin `.mcp.json` files and activate automatically
when the parent plugin is installed.

### GitHub MCP

Bundled in **ccfg-core**.

- **Package**: `@modelcontextprotocol/server-github`
- **What it does**: GitHub API access for repositories, PRs, issues, and reviews
- **Requires**: `GITHUB_TOKEN` environment variable
- **Configured in**: `plugins/ccfg-core/.mcp.json`

### Playwright MCP

Bundled in **ccfg-typescript**.

- **Package**: `@anthropic-ai/mcp-server-playwright`
- **What it does**: Browser automation for testing web applications — screenshots, interactions,
  assertions
- **Configured in**: `plugins/ccfg-typescript/.mcp.json`

### SQLite MCP

Bundled in **ccfg-sqlite**.

- **Package**: `@anthropic/mcp-sqlite`
- **What it does**: Direct SQLite database access for queries and schema inspection
- **Configured in**: `plugins/ccfg-sqlite/.mcp.json`

## Community Picks

Well-maintained MCP servers from the broader ecosystem that pair well with development workflows.

### Filesystem

- **Package**: `@modelcontextprotocol/server-filesystem`
- **What it does**: Secure file system operations — read, write, search, and manage files with
  scoped directory access
- **Install**: `npx -y @modelcontextprotocol/server-filesystem /path/to/allowed/directory`
- **When to use**: Sandboxed environments where Claude needs explicit file access permissions

### Memory

- **Package**: `@modelcontextprotocol/server-memory`
- **What it does**: Persistent knowledge graph that remembers information across chat sessions
- **Install**: `npx -y @modelcontextprotocol/server-memory`
- **When to use**: Long-running projects where session continuity and architectural context
  preservation matter

### PostgreSQL

- **Package**: `@modelcontextprotocol/server-postgres`
- **What it does**: Read-only PostgreSQL access with schema inspection and query execution
- **Install**: `npx -y @modelcontextprotocol/server-postgres postgresql://localhost/mydb`
- **When to use**: Database-driven development where Claude needs to understand your schema and
  data. Complements the ccfg-postgresql plugin's conventions with live database access

### Brave Search

- **Package**: `@modelcontextprotocol/server-brave-search`
- **What it does**: Web search via Brave Search API for real-time documentation and API research
- **Install**: `npx -y @modelcontextprotocol/server-brave-search`
- **When to use**: Researching current library docs, error messages, or technical solutions without
  leaving the editor

### Supabase

- **Package**: `@supabase/mcp-server-supabase`
- **What it does**: Full Supabase integration — table design, migrations, SQL queries, database
  branching, and TypeScript type generation
- **Install**: `npx -y @supabase/mcp-server-supabase --access-token=<your-token>`
- **When to use**: Full-stack development with Supabase backends

## Further Resources

- [MCP Server Registry](https://github.com/modelcontextprotocol/servers) — Official collection of
  reference MCP servers
- [Claude Code Plugins Docs](https://code.claude.com/docs/en/plugins) — How to create and install
  plugins
- [Claude Plugins Official](https://github.com/anthropics/claude-plugins-official) — Anthropic's
  curated plugin marketplace
