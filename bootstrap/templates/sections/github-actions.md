## GitHub Actions Conventions

- Pin action versions to full SHA (not `@v4`, not `@main`)
- Use `permissions` block — principle of least privilege
- Prefer reusable workflows for shared CI logic
- Cache dependencies (actions/cache or setup-\* built-in caching)
- Use `concurrency` to cancel stale workflow runs
- Secrets via `${{ secrets.NAME }}` — never hardcode
- Matrix strategy for cross-platform or multi-version testing
- Set `timeout-minutes` on all jobs
