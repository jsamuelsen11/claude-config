---
description: Scan workspace for secrets and vulnerabilities
argument-hint: [--path .] [--fix]
allowed-tools: Bash(git:*), Read, Grep, Glob
---

# Security Check

Scan the workspace for secrets, API keys, hardcoded credentials, and common vulnerability patterns.
Produces a detailed report with severity ratings and remediation guidance.

## Usage

```bash
/security-check [--path .] [--fix]
```

**Options:**

- `--path` - Directory to scan (default: current directory)
- `--fix` - Attempt automatic remediation where safe (experimental)

**Examples:**

```bash
/security-check
/security-check --path src/
/security-check --path . --fix
```

## Scanning Categories

### 1. API Keys and Tokens

Detect exposed credentials for common services:

**AWS Credentials:**

- Pattern: `AKIA[0-9A-Z]{16}`
- Pattern: `aws_access_key_id\s*=\s*[A-Z0-9]{20}`
- Pattern: `aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}`
- Severity: CRITICAL

**GitHub Tokens:**

- Pattern: `ghp_[a-zA-Z0-9]{36}`
- Pattern: `gho_[a-zA-Z0-9]{36}`
- Pattern: `github_pat_[a-zA-Z0-9_]{82}`
- Pattern: `ghs_[a-zA-Z0-9]{36}`
- Severity: CRITICAL

**Slack Tokens:**

- Pattern: `xox[baprs]-[a-zA-Z0-9-]+`
- Severity: HIGH

**OpenAI API Keys:**

- Pattern: `sk-[a-zA-Z0-9]{48}`
- Pattern: `sk-proj-[a-zA-Z0-9]{48}`
- Severity: HIGH

**Stripe Keys:**

- Pattern: `sk_live_[a-zA-Z0-9]{24,}`
- Pattern: `pk_live_[a-zA-Z0-9]{24,}`
- Pattern: `rk_live_[a-zA-Z0-9]{24,}`
- Severity: CRITICAL

**Generic API Keys:**

- Pattern: `api[_-]?key\s*[=:]\s*["'][^"']{16,}["']`
- Pattern: `apikey\s*[=:]\s*["'][^"']{16,}["']`
- Severity: HIGH

**JWT Tokens:**

- Pattern: `eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}`
- Severity: MEDIUM (could be test token)

### 2. Environment Files Committed to Git

Check for `.env` files with real values committed to version control:

**Detection:**

```bash
git ls-files | grep -E '\.env$|\.env\.'
```

**Severity:** HIGH if contains non-placeholder values

**Safe Patterns (OK to commit):**

- `DATABASE_URL=postgresql://user:password@localhost/db` (localhost)
- `API_KEY=your-api-key-here` (placeholder text)
- `SECRET=change-me` (placeholder text)

**Unsafe Patterns (CRITICAL):**

- Real hostnames (non-localhost)
- Long random-looking strings
- Keys matching known patterns

### 3. Private Keys and Certificates

Detect cryptographic private keys:

**Patterns:**

- `-----BEGIN RSA PRIVATE KEY-----`
- `-----BEGIN DSA PRIVATE KEY-----`
- `-----BEGIN EC PRIVATE KEY-----`
- `-----BEGIN OPENSSH PRIVATE KEY-----`
- `-----BEGIN PGP PRIVATE KEY BLOCK-----`
- `-----BEGIN PRIVATE KEY-----`

**Severity:** CRITICAL

**Exceptions:**

- Files in `tests/fixtures/` or `tests/data/` (test keys)
- Files named `*_test.pem` or `*_example.pem`

### 4. Hardcoded Credentials in Config Files

Search configuration files for hardcoded passwords:

**Patterns:**

- `password\s*[=:]\s*["'](?!.*\$\{)(?!.*changeme)(?!.*example)[^"']{8,}["']`
- `passwd\s*[=:]\s*["'][^"']{8,}["']`
- `db_password\s*[=:]\s*["'][^"']{8,}["']`
- `admin_password\s*[=:]\s*["'][^"']{8,}["']`

**File Types to Check:**

- `.json`, `.yaml`, `.yml`, `.xml`, `.toml`, `.ini`
- `.config`, `.conf`, `.properties`

**Severity:** HIGH

**Safe Patterns (exclude):**

- `password: ${PASSWORD}` (environment variable)
- `password: changeme` (placeholder)
- `password: example` (placeholder)

### 5. Known Vulnerable Patterns

Detect common vulnerability patterns in code:

**SQL Injection:**

- Pattern: `execute\([^)]*\+[^)]*\)` (string concatenation in SQL)
- Pattern: `f"SELECT.*{[^}]+}"` (Python f-string in SQL)
- Pattern: `` `SELECT.*\${[^}]+}` `` (JavaScript template in SQL)
- Severity: CRITICAL

**Command Injection:**

- Pattern: `exec\([^)]*\+[^)]*\)`
- Pattern: `shell=True.*\+` (Python subprocess with concatenation)
- Pattern: `eval\([^)]*input\([^)]*\)` (eval with user input)
- Severity: CRITICAL

**Path Traversal:**

- Pattern: `open\([^)]*\+[^)]*\)` (file path concatenation)
- Pattern: `readFile\([^)]*\+[^)]*\)`
- Severity: HIGH

**XSS Vulnerabilities:**

- Pattern: `innerHTML\s*=\s*[^;]*\+` (dynamic HTML in JavaScript)
- Pattern: `dangerouslySetInnerHTML` (React without sanitization)
- Severity: HIGH

**Insecure Random:**

- Pattern: `random\.random\(\)` (Python insecure random for crypto)
- Pattern: `Math\.random\(\)` (JavaScript insecure random for crypto)
- Context required: Only flag if used for tokens/keys
- Severity: MEDIUM

## Scan Process

### Step 1: Initialize Scan

```text
SECURITY SCAN INITIATED

Target: /absolute/path/to/workspace
Scope: All files (respecting .gitignore)
Categories: 5 (Secrets, Env Files, Keys, Credentials, Vulnerabilities)
```

### Step 2: Collect Files

Use Glob to identify files to scan:

```bash
# Get all tracked files
git ls-files

# Get all files if not in git repo
find . -type f
```

**File Type Priorities:**

1. High priority: `.env*`, `.py`, `.js`, `.ts`, `.json`, `.yaml`, `.yml`
2. Medium priority: `.java`, `.go`, `.rb`, `.php`, `.sh`
3. Low priority: `.txt`, `.md`, `.config`
4. Skip: Binary files, images, archives

### Step 3: Pattern Matching

Use Grep with appropriate patterns for each category:

```bash
# Example: Scan for AWS keys
rg -i "AKIA[0-9A-Z]{16}" --type py --type js

# Example: Scan for private keys
rg "BEGIN.*PRIVATE KEY" --type pem
```

### Step 4: Context Analysis

For each finding, read surrounding lines to determine if it's a false positive:

**False Positive Indicators:**

- Comments indicating test/example data
- Variable names containing "example", "test", "mock", "fake"
- Files in `tests/`, `examples/`, `docs/` directories
- Placeholder values like "your-key-here"

### Step 5: Generate Report

Produce structured markdown table with findings:

## Output Format

````markdown
# Security Scan Report

**Scan Date:** 2026-02-08 14:23:45 UTC **Target:** /home/user/project **Files Scanned:** 247
**Findings:** 8 (3 CRITICAL, 2 HIGH, 2 MEDIUM, 1 LOW)

## Executive Summary

Found 3 CRITICAL issues requiring immediate attention:

- 2 hardcoded API keys
- 1 AWS credential in configuration file

## Findings by Severity

### CRITICAL Issues (3)

| File                  | Line | Finding               | Remediation                      |
| --------------------- | ---- | --------------------- | -------------------------------- |
| `src/config/aws.py`   | 12   | AWS Access Key        | Move to environment variable     |
| `src/api/client.js`   | 45   | GitHub Personal Token | Use GitHub App or Actions secret |
| `config/database.yml` | 8    | Database Password     | Use secrets manager              |

---

### HIGH Issues (2)

| File                | Line | Finding            | Remediation                 |
| ------------------- | ---- | ------------------ | --------------------------- |
| `src/auth/token.py` | 78   | Insecure Random    | Use secrets.token_urlsafe() |
| `src/db/queries.py` | 123  | SQL Injection Risk | Use parameterized queries   |

---

### MEDIUM Issues (2)

| File                   | Line | Finding                 | Remediation                |
| ---------------------- | ---- | ----------------------- | -------------------------- |
| `src/api/routes.js`    | 56   | Missing Input Validator | Add schema validation      |
| `src/utils/helpers.py` | 34   | Path Traversal Risk     | Validate and sanitize path |

---

### LOW Issues (1)

| File        | Line | Finding         | Remediation             |
| ----------- | ---- | --------------- | ----------------------- |
| `README.md` | 89   | Example API Key | No action (doc example) |

---

## Detailed Findings

### [CRITICAL] AWS Access Key

**File:** `src/config/aws.py:12`

**Finding:**

```python
aws_access_key_id = "AKIAIOSFODNN7EXAMPLE"
```
````

**Impact:** Exposed AWS credentials can lead to unauthorized access to AWS resources, data breaches,
and unexpected billing charges.

**Remediation:**

1. Rotate the exposed key immediately in AWS IAM console
2. Move credential to environment variable:

   ```python
   import os
   aws_access_key_id = os.environ.get("AWS_ACCESS_KEY_ID")
   ```

3. Add to `.env` (and ensure `.env` is in `.gitignore`):

   ```text
   AWS_ACCESS_KEY_ID=<new-key>
   ```

4. Consider using AWS IAM roles instead of access keys
5. Scan git history and purge if previously committed

**References:**

- [AWS Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [git-secrets tool](https://github.com/awslabs/git-secrets)

---

### [HIGH] SQL Injection Risk

**File:** `src/db/queries.py:123`

**Finding:**

```python
cursor.execute(f"SELECT * FROM users WHERE email = '{user_email}'")
```

**Impact:** SQL injection allows attackers to execute arbitrary SQL commands, potentially reading,
modifying, or deleting data.

**Remediation:**

Use parameterized queries:

```python
cursor.execute("SELECT * FROM users WHERE email = %s", (user_email,))
```

**References:**

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [Python DB-API parameterization](https://www.python.org/dev/peps/pep-0249/)

---

## Summary Statistics

| Severity  | Count | % of Total |
| --------- | ----- | ---------- |
| CRITICAL  | 3     | 37.5%      |
| HIGH      | 2     | 25.0%      |
| MEDIUM    | 2     | 25.0%      |
| LOW       | 1     | 12.5%      |
| **Total** | **8** | **100%**   |

## Recommended Actions

### Immediate (within 24 hours)

1. Rotate all exposed CRITICAL credentials
2. Remove hardcoded secrets from code
3. Add secrets to `.gitignore`
4. Scan git history for previous commits

### Short-term (within 1 week)

1. Implement secrets management solution (AWS Secrets Manager, HashiCorp Vault)
2. Fix HIGH severity vulnerabilities
3. Add pre-commit hooks to prevent future secret commits
4. Audit environment variable usage

### Long-term (within 1 month)

1. Security training for development team
2. Implement automated security scanning in CI/CD
3. Regular security audits
4. Establish secrets rotation policy

## Tools to Prevent Future Issues

- **git-secrets**: Prevent committing secrets (AWS Labs)
- **pre-commit**: Run checks before commits
- **truffleHog**: Scan git history for secrets
- **detect-secrets**: Yelp's secret detection tool
- **gitleaks**: Fast secret scanner

## False Positives

The following findings were evaluated and determined to be safe:

- `tests/fixtures/test_key.pem`: Test fixture, not real key
- `docs/examples/api.md`: Documentation example with placeholder

---

Generated with Claude Code Security Scanner

```text

## Automatic Remediation (--fix)

When `--fix` flag is provided, attempt safe automatic fixes:

### Safe Fixes

1. **Add to .gitignore:**
   - Add `.env` if not present
   - Add common secret file patterns

2. **Comment Out Hardcoded Secrets:**
   - Add `# SECURITY: Remove this hardcoded credential` comment
   - Leave in place for manual review

3. **Generate .env.example:**
   - Create template with placeholder values
   - Document required environment variables

### Unsafe Fixes (Manual Only)

- Rotating actual credentials (requires API access)
- Refactoring code (could break functionality)
- Removing secrets from git history (use `git filter-repo`)

## Best Practices

### Regular Scanning

- Run before every commit
- Integrate into pre-commit hooks
- Include in CI/CD pipeline
- Schedule weekly full scans

### Secret Management

- Use environment variables for all secrets
- Never commit `.env` files with real values
- Use secrets management services (Vault, AWS Secrets Manager)
- Rotate secrets regularly
- Use minimal privilege principles

### Prevention

- Install git-secrets or similar tools
- Enable branch protection with required checks
- Code review checklist includes security
- Security training for all developers

## Notes

- Scan time depends on repository size (typically 10-60 seconds)
- Some patterns may produce false positives (review context)
- Binary files are automatically skipped
- Respects `.gitignore` by default
- Does not modify files without `--fix` flag
- For sensitive repos, review report before sharing
```
