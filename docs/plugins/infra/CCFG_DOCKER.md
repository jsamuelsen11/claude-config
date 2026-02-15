# Plugin: ccfg-docker

The Docker infrastructure plugin. Provides Dockerfile optimization, Compose architecture, and
container security agents, config validation, project scaffolding, and opinionated conventions for
consistent Docker development. Focuses on multi-stage builds, layer caching, image security, and
Compose patterns. Safety is paramount — never pushes images or interacts with the Docker daemon
without explicit user confirmation.

## Directory Structure

```text
plugins/ccfg-docker/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── dockerfile-specialist.md
│   ├── compose-architect.md
│   └── container-security.md
├── commands/
│   ├── validate.md
│   └── scaffold.md
└── skills/
    ├── docker-conventions/
    │   └── SKILL.md
    ├── compose-patterns/
    │   └── SKILL.md
    └── image-optimization/
        └── SKILL.md
```

## plugin.json

```json
{
  "name": "ccfg-docker",
  "description": "Docker infrastructure plugin: Dockerfile optimization, Compose architecture, container security agents, config validation, and conventions for consistent Docker development",
  "version": "1.0.0",
  "author": {
    "name": "jsamuelsen"
  },
  "repository": "https://github.com/jsamuelsen11/claude-config",
  "license": "MIT",
  "keywords": ["docker", "dockerfile", "compose", "container", "image", "multi-stage", "buildkit"],
  "suggestedPermissions": {
    "allow": [
      "Bash(docker build:*)",
      "Bash(docker compose:*)",
      "Bash(docker ps:*)",
      "Bash(docker images:*)"
    ]
  }
}
```

## Agents (3)

Each agent is an `.md` file in `agents/` with YAML frontmatter defining name, description, available
tools, and model preference, followed by a system prompt.

| Agent                   | Role                                                                                       | Model  |
| ----------------------- | ------------------------------------------------------------------------------------------ | ------ |
| `dockerfile-specialist` | Dockerfile 1.x syntax, multi-stage builds, BuildKit features, layer caching, image size    | sonnet |
| `compose-architect`     | Compose v2+, service design, networking, volumes, healthchecks, profiles, dependencies     | sonnet |
| `container-security`    | Non-root users, minimal base images, no secrets in layers, read-only rootfs, dropping caps | sonnet |

No coverage command — coverage is a code concept, not an infrastructure concept. This is intentional
and differs from language plugins.

## Commands (2)

Each command is an `.md` file in `commands/` with YAML frontmatter for description, argument-hint,
and allowed-tools.

### /ccfg-docker:validate

**Purpose**: Run the full Docker configuration quality gate suite in one command.

**Trigger**: User invokes before building images or reviewing Docker configuration changes.

**Allowed tools**: `Bash(hadolint *), Bash(docker compose config *), Bash(git *), Read, Grep, Glob`

**Argument**: `[--quick]`

**Behavior**:

Full mode (default):

1. **Dockerfile lint**: hadolint-aware if available; otherwise heuristic checks — pinned base image
   tags (no `:latest`), `COPY` over `ADD`, `apt-get` with `--no-install-recommends` + cleanup in
   same layer, multi-stage where applicable, `HEALTHCHECK` presence, instruction ordering (FROM →
   RUN → COPY → CMD)
2. **Compose validation**: service definitions complete, network configuration valid, volume
   declarations correct, `depends_on` with healthcheck conditions, environment variable handling (no
   hardcoded secrets), named networks and volumes over defaults
3. **Security checks**: non-root `USER` directive present, no `--privileged` in compose services, no
   secrets in build args or environment variables, minimal base images preferred
   (alpine/distroless), `COPY --chown` usage where needed
4. **.dockerignore**: presence check, verify `.git/`, `node_modules/`, `.env`, `*.log`, build
   artifacts excluded
5. **Image provenance** (detect-and-skip): if trivy or grype is available, scan Dockerfiles for
   known-vulnerable base images. If SBOM generation tools are available (syft, docker sbom),
   recommend SBOM generation as part of build pipeline. If neither tool is available, skip this gate
   entirely and report as SKIPPED — advisory only, never a hard fail
6. Report pass/fail for each gate with output
7. If any gate fails, show the failures and stop

Quick mode (`--quick`):

1. **Dockerfile syntax**: Base image pinning (no `:latest`), basic instruction checks
2. **.dockerignore**: Presence check
3. Report pass/fail — skips compose validation, security checks, and full Dockerfile lint for speed

Quick mode is designed for fast iteration — highest-signal checks only, completing in seconds rather
than scanning the full codebase.

**Key rules**:

- Source of truth: repo artifacts only — Dockerfiles, compose files, and .dockerignore. Does not
  interact with the Docker daemon by default. Live checks (image existence, build validation)
  require the `--live` flag and explicit user confirmation before any interaction
- Never suggests disabling checks as fixes — fix the root cause
- Reports all gate results, not just the first failure
- Detect-and-skip: if a check requires a tool that is not available (e.g., hadolint not installed),
  skip that gate and report it as SKIPPED. Suggest installing the missing tool
- hadolint detection: if available, invoke and parse output; if missing, use built-in heuristic
  subset and suggest installing hadolint
- Optional tooling (detect-and-skip): hadolint (Dockerfile lint), docker compose config (compose
  validation), trivy/grype (image scanning with `--live`). If not installed, use heuristic checks
  for the corresponding gate and suggest the missing tool in output
- Checks for presence of conventions document (`docs/infra/docker-conventions.md` or similar).
  Reports SKIPPED if no `docs/` directory exists — never fails on missing documentation structure

### /ccfg-docker:scaffold

**Purpose**: Initialize Dockerfiles, compose configuration, and .dockerignore for projects.

**Trigger**: User invokes when setting up Docker in a new or existing project.

**Allowed tools**: `Bash(git *), Read, Write, Edit, Glob`

**Argument**: `[--type=dockerfile|compose|dockerignore]`

**Behavior**:

**dockerfile** (default):

1. Detect project language/framework from project files (package.json, requirements.txt, go.mod,
   Cargo.toml, pom.xml, etc.)
2. Generate multi-stage Dockerfile appropriate to detected stack:
   - Node.js: build stage (`npm ci`) → production stage (`node:alpine`)
   - Python: build stage (`pip install`) → production stage (`python:slim`)
   - Go: build stage (`go build`) → scratch/distroless
   - Rust: build stage (`cargo build --release`) → debian-slim/scratch
   - Java: build stage (Maven/Gradle) → eclipse-temurin JRE
   - Generic: single-stage with best-practice defaults
3. Include `HEALTHCHECK`, non-root `USER`, proper `LABEL` metadata
4. Use BuildKit syntax by default (`# syntax=docker/dockerfile:1`). Include `--mount=type=cache` for
   package manager caches where applicable
5. Add `.dockerignore` alongside if not present

**compose**:

1. Generate `docker-compose.yml` with detected services
2. Include healthchecks on all services, named networks, named volumes
3. Use environment variable files (`.env`) pattern, not hardcoded values
4. Include `docker-compose.override.yml` for development overrides (bind mounts, debug ports)
5. Use `profiles:` to separate dev-only services (e.g., debug tools, seed scripts)
6. Use `depends_on` with `condition: service_healthy` for startup ordering

**dockerignore**:

1. Generate `.dockerignore` from project context (`.git`, `node_modules`, `.env`, build artifacts,
   test fixtures, documentation)

**Key rules**:

- Language detection is best-effort — never prescribe a stack, respect what the project already uses
- Generated Dockerfiles use pinned image tags with specific versions, never `:latest`
- Never includes real secrets or credentials — placeholder values only
- `.env.example` uses generic placeholder values, never real credentials
- If inside a git repo, verify `.gitignore` includes `.env`
- Scaffold recommends creating a conventions document at `docs/infra/docker-conventions.md`. If the
  project has a `docs/` directory, scaffold offers to create it. If no `docs/` structure exists,
  skip and note in output

## Skills (3)

Skills are auto-invoked by Claude based on context. They use broad trigger descriptions so Claude
activates them when relevant.

### docker-conventions

**Trigger description**: "This skill should be used when working with Docker, writing Dockerfiles,
configuring Docker Compose, building container images, or reviewing Docker configuration."

**Existing repo compatibility**: For existing projects, respect the established conventions. If the
project uses a specific base image or Dockerfile pattern, follow it. If the project uses a specific
compose structure, maintain that pattern. These preferences apply to new Dockerfiles and scaffold
output only.

**Dockerfile best practices**:

- Instruction ordering: FROM → ARG → RUN (install deps) → COPY (source) → RUN (build) →
  CMD/ENTRYPOINT
- Layer caching: put least-changing layers first, combine related RUN commands, clean up in same
  layer (`apt-get install && apt-get clean && rm -rf /var/lib/apt/lists/*`)
- Multi-stage builds: separate build environment from runtime, copy only artifacts needed at
  runtime, use named stages for clarity
- BuildKit features: `--mount=type=cache` for package manager caches, `--mount=type=secret` for
  build-time secrets, `--mount=type=ssh` for private repo access
- Always specify `WORKDIR` — avoid relying on default `/`
- Use `COPY` over `ADD` unless extracting tarballs or fetching URLs
- Use `exec` form for CMD/ENTRYPOINT: `CMD ["node", "server.js"]` not `CMD node server.js`

**Base image rules**:

- Use official images from Docker Hub or verified publishers
- Prefer minimal variants: `alpine` for small size, `slim` for Debian compatibility, `distroless`
  for maximum security
- Pin to specific version tags: `node:20.11-alpine` not `node:latest` or `node:20`
- Consider multi-platform: `--platform=linux/amd64,linux/arm64` for cross-architecture support
- Use digest pinning for reproducibility in production: `node:20.11-alpine@sha256:...`

**.dockerignore rules**:

- Every project with a Dockerfile must have a `.dockerignore`
- Always exclude: `.git/`, `node_modules/`, `.env`, `*.log`, `.DS_Store`, `*.md` (except README if
  needed), test fixtures, CI/CD config
- Mirror `.gitignore` patterns where applicable, then add Docker-specific exclusions

### compose-patterns

**Trigger description**: "This skill should be used when designing Docker Compose services,
configuring networking, managing volumes, or setting up multi-container applications."

**Contents**:

- **Service design**: one process per container, use restart policies (`unless-stopped` for
  production, `no` for dev), sidecar pattern for log collectors/proxies, init containers via
  `depends_on` ordering
- **Networking**: use named networks (not default bridge), network aliases for service discovery,
  explicit port mapping (host:container), separate frontend/backend networks for isolation
- **Volume management**: named volumes for persistent data (databases, uploads), bind mounts for
  development only (source code), tmpfs for ephemeral/sensitive data, volume drivers for cloud
  storage
- **Health checks**: define `healthcheck` on every service, use appropriate interval/timeout/retries
  (start conservative: 30s interval, 10s timeout, 3 retries), use `depends_on` with
  `condition: service_healthy` for startup ordering
- **Profiles**: use `profiles:` to group optional services (debug tools, seed data, monitoring
  stacks). Dev services get `profiles: [dev]`, activated with `--profile dev`. Keeps production
  compose clean while providing rich dev environments
- **Environment management**: use `.env` files for variable substitution, `env_file:` directive for
  service-specific config, `docker-compose.override.yml` for development overrides (auto-loaded),
  never hardcode secrets in compose files

### image-optimization

**Trigger description**: "This skill should be used when optimizing Docker image size, improving
build performance, implementing caching strategies, or hardening container security."

**Contents**:

- **Layer minimization**: combine related `RUN` commands with `&&`, clean up package manager caches
  in the same layer, use multi-stage builds to separate build dependencies from runtime, remove
  temporary files before the layer commits
- **Size reduction**: use minimal base images (alpine, slim, distroless, scratch for static
  binaries), strip debug symbols from compiled binaries, exclude dev dependencies from production
  images, use `.dockerignore` to prevent unnecessary files from entering build context
- **Build caching**: order instructions from least-changing to most-changing (OS deps → language
  deps → source code → build), use BuildKit cache mounts (`--mount=type=cache,target=/root/.cache`)
  for package manager caches, leverage CI/CD layer caching (`--cache-from`, `--cache-to` with
  registry or local backend)
- **Security hardening**: run as non-root user (`USER 1001:1001`), use read-only rootfs where
  possible (`--read-only`), drop all capabilities and add back only what's needed, set
  `no-new-privileges`, scan images for CVEs (Trivy, Grype), never embed secrets in layers (use build
  secrets or runtime injection)
