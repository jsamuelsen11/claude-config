#!/bin/sh
# secret-scan.sh — PostToolUse hook for Write/Edit
# Scans file content for leaked secrets (API keys, passwords, private keys).
# Input: $1 = path to tool output file
# Exit: non-zero if secrets detected

set -e

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
	exit 0
fi

FOUND=0

check_pattern() {
	pattern="$1"
	label="$2"
	if grep -qE "$pattern" "$FILE" 2>/dev/null; then
		match=$(grep -nE "$pattern" "$FILE" 2>/dev/null | head -5)
		echo "WARNING: Potential $label detected:" >&2
		echo "$match" >&2
		echo "" >&2
		FOUND=1
	fi
}

# AWS access key IDs
check_pattern 'AKIA[0-9A-Z]{16}' "AWS Access Key ID"

# AWS secret access keys (base64-like, 40 chars)
check_pattern 'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}' "AWS Secret Access Key"

# OpenAI / Anthropic API keys
check_pattern 'sk-[a-zA-Z0-9]{32,}' "API key (sk-...)"

# GitHub tokens (classic and fine-grained)
check_pattern 'gh[pousr]_[A-Za-z0-9_]{36,}' "GitHub token"

# GitHub classic personal access tokens
check_pattern 'github_pat_[A-Za-z0-9_]{22,}' "GitHub personal access token"

# Slack tokens
check_pattern 'xox[baprs]-[0-9a-zA-Z-]{10,}' "Slack token"

# Generic password assignments
check_pattern 'password\s*[=:]\s*["\x27][^"\x27]{4,}' "hardcoded password"

# Generic secret assignments
check_pattern 'secret\s*[=:]\s*["\x27][^"\x27]{4,}' "hardcoded secret"

# Generic API key assignments
check_pattern 'api_key\s*[=:]\s*["\x27][^"\x27]{4,}' "hardcoded API key"

# Private keys (RSA, EC, DSA, OpenSSH)
check_pattern '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' "private key"

# Connection strings with embedded credentials
check_pattern '://[^:@/\s]+:[^:@/\s]+@[^/\s]+' "connection string with credentials"

# Stripe keys
check_pattern 'sk_live_[0-9a-zA-Z]{24,}' "Stripe live secret key"
check_pattern 'rk_live_[0-9a-zA-Z]{24,}' "Stripe live restricted key"

# SendGrid API key
check_pattern 'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}' "SendGrid API key"

# Twilio auth token
check_pattern 'SK[0-9a-fA-F]{32}' "Twilio API key"

if [ "$FOUND" -eq 1 ]; then
	echo "SECRET SCAN FAILED: Potential secrets found in output." >&2
	echo "Review the warnings above and remove any real credentials." >&2
	exit 1
fi

exit 0
