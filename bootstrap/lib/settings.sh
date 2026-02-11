#!/usr/bin/env bash
# settings.sh — settings.json and settings.local.json manipulation via jq.
# Provides non-destructive merge operations for permissions, plugins, and thinking.
# Source this file; do not execute directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/settings.sh"

# Sourcing guard
[[ -n "${_CCFG_SETTINGS_LOADED:-}" ]] && return
_CCFG_SETTINGS_LOADED=1

# Source common.sh for logging
_CCFG_SETTINGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_CCFG_SETTINGS_DIR}/common.sh"

# ---------------------------------------------------------------------------
# settings_read <file>
# Read and validate settings JSON. Prints contents to stdout.
# Returns 1 if file doesn't exist or contains invalid JSON.
# ---------------------------------------------------------------------------
settings_read() {
	local file="$1"

	if [[ ! -f "${file}" ]]; then
		log_error "Settings file not found: ${file}"
		return 1
	fi

	if ! jq empty "${file}" 2>/dev/null; then
		log_error "Invalid JSON in: ${file}"
		return 1
	fi

	jq '.' "${file}"
}

# ---------------------------------------------------------------------------
# settings_merge_permissions <file> <json_array>
# Union merge into .permissions.allow — add new entries, never remove existing.
# Creates .permissions.allow if absent. Deduplicates.
# <json_array> is a JSON array string, e.g. '["Bash(uv:*)", "Bash(ruff:*)"]'
# ---------------------------------------------------------------------------
settings_merge_permissions() {
	local file="$1"
	local new_perms="$2"

	local current
	current="$(settings_read "${file}")" || return 1

	local merged
	merged="$(printf '%s' "${current}" | jq --argjson new "${new_perms}" \
		'.permissions.allow = ((.permissions.allow // []) + $new | unique)')"

	settings_write "${file}" "${merged}"
}

# ---------------------------------------------------------------------------
# settings_merge_plugins <file> <json_object>
# Merge into .enabledPlugins — add new keys with value true.
# Never set existing keys to false. Never remove keys.
# <json_object> is a JSON object string, e.g. '{"ccfg-core@claude-config": true}'
# ---------------------------------------------------------------------------
settings_merge_plugins() {
	local file="$1"
	local new_plugins="$2"

	local current
	current="$(settings_read "${file}")" || return 1

	local merged
	merged="$(printf '%s' "${current}" | jq --argjson new "${new_plugins}" \
		'.enabledPlugins = ((.enabledPlugins // {}) + $new)')"

	settings_write "${file}" "${merged}"
}

# ---------------------------------------------------------------------------
# settings_set_thinking <file>
# Set .alwaysThinkingEnabled=true ONLY if key is absent.
# If already set (true or false), do not modify.
# ---------------------------------------------------------------------------
settings_set_thinking() {
	local file="$1"

	local current
	current="$(settings_read "${file}")" || return 1

	local merged
	merged="$(printf '%s' "${current}" | jq '.alwaysThinkingEnabled //= true')"

	settings_write "${file}" "${merged}"
}

# ---------------------------------------------------------------------------
# settings_write <file> <json>
# Write JSON to temp file, validate with jq empty, atomic mv to target.
# Original file is untouched if validation fails.
# ---------------------------------------------------------------------------
settings_write() {
	local file="$1"
	local json="$2"

	local dir
	dir="$(dirname "${file}")"

	# Create parent directory if needed
	if [[ ! -d "${dir}" ]]; then
		if ! mkdir -p "${dir}"; then
			log_error "Cannot create directory: ${dir}"
			return 1
		fi
	fi

	# Write to temp file in same directory (for atomic mv on same filesystem)
	local tmpfile
	tmpfile="$(mktemp "${dir}/.ccfg_settings.XXXXXX")"
	if [[ -z "${tmpfile}" ]]; then
		log_error "Cannot create temp file in: ${dir}"
		return 1
	fi

	printf '%s\n' "${json}" >"${tmpfile}"

	# Validate written JSON
	if ! jq empty "${tmpfile}" 2>/dev/null; then
		log_error "Generated JSON is invalid — original file preserved: ${file}"
		rm -f "${tmpfile}"
		return 1
	fi

	# Atomic replace
	if ! mv "${tmpfile}" "${file}"; then
		log_error "Failed to write: ${file}"
		rm -f "${tmpfile}"
		return 1
	fi
}

# ---------------------------------------------------------------------------
# settings_read_plugin_permissions <plugin_dir>
# Read .suggestedPermissions.allow[] from a plugin's plugin.json.
# Returns a JSON array (empty array if field is absent).
# <plugin_dir> is the plugin root, e.g. "plugins/ccfg-python"
# ---------------------------------------------------------------------------
settings_read_plugin_permissions() {
	local plugin_dir="$1"
	local manifest="${plugin_dir}/.claude-plugin/plugin.json"

	if [[ ! -f "${manifest}" ]]; then
		log_warn "Plugin manifest not found: ${manifest}"
		printf '[]'
		return 0
	fi

	jq '.suggestedPermissions.allow // []' "${manifest}" 2>/dev/null || {
		log_warn "Could not read permissions from: ${manifest}"
		printf '[]'
	}
}
