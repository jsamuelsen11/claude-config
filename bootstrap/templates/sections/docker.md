## Docker Conventions

- Multi-stage builds for production images
- Pin base image versions (no :latest)
- Use .dockerignore to exclude build artifacts
- One process per container
- COPY before RUN for layer caching
- Non-root USER in final stage
