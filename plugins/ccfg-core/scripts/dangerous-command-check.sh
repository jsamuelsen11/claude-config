#!/bin/sh
# dangerous-command-check.sh — PreToolUse hook for Bash
# Warns before destructive or dangerous shell commands.
# Input: $1 = path to tool input file (JSON with "command" field)
# Exit: non-zero if dangerous command detected

set -e

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
	exit 0
fi

# Extract the command field from the JSON input.
# The tool input file is JSON with a "command" key.
# Use sed for POSIX compatibility (no grep -P).
CMD=$(sed -n 's/.*"command"\s*:\s*"\([^"]*\)".*/\1/p' "$FILE" 2>/dev/null | head -1)

if [ -z "$CMD" ]; then
	exit 0
fi

FOUND=0

warn() {
	label="$1"
	echo "DANGER: $label" >&2
	echo "Command: $CMD" >&2
	echo "" >&2
	FOUND=1
}

# Catastrophic deletion
case "$CMD" in
*"rm -rf /"* | *"rm -rf ~"*)
	warn "Catastrophic recursive deletion detected"
	;;
esac

# Force push to main/master
if echo "$CMD" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+-f'; then
	if echo "$CMD" | grep -qE '\b(main|master)\b'; then
		warn "Force push to main/master branch"
	fi
fi

# Git reset --hard (data loss)
if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
	warn "git reset --hard can cause data loss"
fi

# Database destruction
if echo "$CMD" | grep -qiE 'DROP\s+(TABLE|DATABASE)'; then
	warn "SQL DROP statement detected"
fi

# Insecure permissions
if echo "$CMD" | grep -qE 'chmod\s+777'; then
	warn "chmod 777 sets insecure world-writable permissions"
fi

# Piped remote execution
if echo "$CMD" | grep -qE 'curl\s.*\|\s*(sh|bash)|wget\s.*\|\s*(sh|bash)'; then
	warn "Piping remote content to shell (untrusted execution)"
fi

# Truncate important files
if echo "$CMD" | grep -qE '>\s*/etc/|>\s*/dev/sd'; then
	warn "Redirecting output to system path"
fi

if [ "$FOUND" -eq 1 ]; then
	echo "DANGEROUS COMMAND CHECK FAILED." >&2
	echo "Review the warnings above. Approve manually to proceed." >&2
	exit 1
fi

exit 0
