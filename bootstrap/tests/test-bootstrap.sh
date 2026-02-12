#!/usr/bin/env bash
# test-bootstrap.sh — Test suite for ccfg-bootstrap.sh
#
# Usage:
#   bash bootstrap/tests/test-bootstrap.sh
#
# Tests run in isolated temp directories to avoid touching real settings.
# Functions are invoked indirectly via run_test and from test functions
# shellcheck disable=SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="${SCRIPT_DIR}/../ccfg-bootstrap.sh"
PLUGINS_DIR="$(cd "${SCRIPT_DIR}/../../plugins" && pwd)"

# Source common for colors
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test isolation
TEST_TMPDIR=""

# Save real HOME to restore later
REAL_HOME="${HOME}"

# Override backup directory to avoid polluting real backups
export CCFG_BACKUP_DIR=""

# ──────────────────────────────────────────────────────────────────
# Test Helpers
# ──────────────────────────────────────────────────────────────────

setup_tmpdir() {
	TEST_TMPDIR="$(mktemp -d)"
	# Create isolated .claude dir simulating user home
	mkdir -p "${TEST_TMPDIR}/.claude"
	# Create isolated backup dir
	CCFG_BACKUP_DIR="${TEST_TMPDIR}/.claude/backups"
	mkdir -p "${CCFG_BACKUP_DIR}"
	# Override HOME so scripts target our temp dir
	export HOME="${TEST_TMPDIR}"
}

teardown_tmpdir() {
	export HOME="${REAL_HOME}"
	if [[ -n "${TEST_TMPDIR:-}" && -d "${TEST_TMPDIR}" ]]; then
		rm -rf "${TEST_TMPDIR}"
	fi
}

assert_file_exists() {
	local file="$1"
	local msg="${2:-File should exist: ${file}}"
	if [[ ! -f "${file}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_file_not_exists() {
	local file="$1"
	local msg="${2:-File should not exist: ${file}}"
	if [[ -f "${file}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_file_contains() {
	local file="$1"
	local pattern="$2"
	local msg="${3:-File should contain: ${pattern}}"
	if ! grep -q "${pattern}" "${file}" 2>/dev/null; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_file_not_contains() {
	local file="$1"
	local pattern="$2"
	local msg="${3:-File should not contain: ${pattern}}"
	if grep -q "${pattern}" "${file}" 2>/dev/null; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_json_key() {
	local file="$1"
	local query="$2"
	local expected="$3"
	local msg="${4:-JSON query ${query} should return ${expected}}"
	local actual
	actual="$(jq -r "${query}" "${file}" 2>/dev/null)"
	if [[ "${actual}" != "${expected}" ]]; then
		printf '    %s%s FAIL:%s %s (got: %s)\n' "${RED}" "${CROSS}" "${RESET}" "${msg}" "${actual}"
		return 1
	fi
}

assert_json_has_key() {
	local file="$1"
	local query="$2"
	local msg="${3:-JSON key should exist: ${query}}"
	jq -e "${query}" "${file}" >/dev/null 2>&1 || {
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	}
}

assert_json_array_contains() {
	local file="$1"
	local query="$2"
	local value="$3"
	local msg="${4:-Array should contain ${value}}"
	local found
	found="$(jq -r "${query}[] | select(. == \"${value}\")" "${file}" 2>/dev/null)"
	if [[ -z "${found}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_exit_code() {
	local expected="$1"
	local actual="$2"
	local msg="${3:-Expected exit code ${expected}, got ${actual}}"
	if [[ "${expected}" -ne "${actual}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

run_test() {
	local test_name="$1"
	TESTS_RUN=$((TESTS_RUN + 1))
	printf '  %s%s%s %s ... ' "${BOLD}" "${ARROW}" "${RESET}" "${test_name}"

	setup_tmpdir

	if "${test_name}" 2>/dev/null; then
		TESTS_PASSED=$((TESTS_PASSED + 1))
		printf '%s%s PASS%s\n' "${GREEN}" "${CHECK}" "${RESET}"
	else
		TESTS_FAILED=$((TESTS_FAILED + 1))
		printf '%s%s FAIL%s\n' "${RED}" "${CROSS}" "${RESET}"
	fi

	teardown_tmpdir
}

# ──────────────────────────────────────────────────────────────────
# Test Cases
# ──────────────────────────────────────────────────────────────────

test_clean_install_creates_settings() {
	# Start with empty settings.json
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Should have enabledPlugins with core
	assert_json_key "${settings}" '.enabledPlugins["ccfg-core@claude-config"]' "true" \
		"ccfg-core should be enabled" || return 1
	# Should have alwaysThinkingEnabled
	assert_json_key "${settings}" '.alwaysThinkingEnabled' "true" \
		"alwaysThinkingEnabled should be true" || return 1
}

test_clean_install_creates_claude_md() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local claude_md="${TEST_TMPDIR}/.claude/CLAUDE.md"
	assert_file_exists "${claude_md}" "CLAUDE.md should be created" || return 1
	assert_file_contains "${claude_md}" "ccfg:begin:best-practices" \
		"Should have best-practices section" || return 1
	assert_file_contains "${claude_md}" "ccfg:end:best-practices" \
		"Should have closing marker" || return 1
	assert_file_contains "${claude_md}" "User Customizations" \
		"Should have user customizations footer" || return 1
}

test_permissions_merged_from_plugin() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,python --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Core permissions
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(git:*)" \
		"git permission from core should be merged" || return 1
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(bd:*)" \
		"bd permission from core should be merged" || return 1
	# Python permissions
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(uvx ruff:*)" \
		"ruff permission from python should be merged" || return 1
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(uv run pytest:*)" \
		"pytest permission from python should be merged" || return 1
}

test_multiple_plugins() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,python,docker,shell --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# All four plugins should be enabled
	assert_json_key "${settings}" '.enabledPlugins["ccfg-core@claude-config"]' "true" || return 1
	assert_json_key "${settings}" '.enabledPlugins["ccfg-python@claude-config"]' "true" || return 1
	assert_json_key "${settings}" '.enabledPlugins["ccfg-docker@claude-config"]' "true" || return 1
	assert_json_key "${settings}" '.enabledPlugins["ccfg-shell@claude-config"]' "true" || return 1
	# Docker permissions
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(docker build:*)" || return 1
	# Shell permissions
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(shellcheck:*)" || return 1
}

test_existing_settings_preserved() {
	# Pre-populate settings with user's own config
	cat >"${TEST_TMPDIR}/.claude/settings.json" <<'JSON'
{
  "enabledPlugins": {
    "my-custom-plugin@my-marketplace": true
  },
  "permissions": {
    "allow": ["Bash(my-custom:*)"]
  },
  "myCustomSetting": 42
}
JSON
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Existing plugin should still be there
	assert_json_key "${settings}" '.enabledPlugins["my-custom-plugin@my-marketplace"]' "true" \
		"Existing plugin should be preserved" || return 1
	# Existing permission should still be there
	assert_json_array_contains "${settings}" '.permissions.allow' "Bash(my-custom:*)" \
		"Existing permission should be preserved" || return 1
	# Custom setting should survive
	assert_json_key "${settings}" '.myCustomSetting' "42" \
		"Custom setting should be preserved" || return 1
	# New ccfg entries should be added
	assert_json_key "${settings}" '.enabledPlugins["ccfg-core@claude-config"]' "true" || return 1
}

test_thinking_not_overwritten() {
	# User explicitly set alwaysThinkingEnabled to false
	cat >"${TEST_TMPDIR}/.claude/settings.json" <<'JSON'
{
  "alwaysThinkingEnabled": false
}
JSON
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Should NOT overwrite user's explicit false
	assert_json_key "${settings}" '.alwaysThinkingEnabled' "false" \
		"User's alwaysThinkingEnabled=false should be preserved" || return 1
}

test_idempotent() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,python --quiet >/dev/null 2>&1
	local first_settings first_claude_md
	first_settings="$(jq --sort-keys '.' "${TEST_TMPDIR}/.claude/settings.json")"
	first_claude_md="$(cat "${TEST_TMPDIR}/.claude/CLAUDE.md")"
	# Run again
	"${BOOTSTRAP}" --auto --plugins core,python --quiet >/dev/null 2>&1
	local second_settings second_claude_md
	second_settings="$(jq --sort-keys '.' "${TEST_TMPDIR}/.claude/settings.json")"
	second_claude_md="$(cat "${TEST_TMPDIR}/.claude/CLAUDE.md")"
	if [[ "${first_settings}" != "${second_settings}" ]]; then
		printf '    %s%s FAIL:%s settings.json changed between runs\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
	if [[ "${first_claude_md}" != "${second_claude_md}" ]]; then
		printf '    %s%s FAIL:%s CLAUDE.md changed between runs\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_dry_run_no_changes() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local before
	before="$(cat "${TEST_TMPDIR}/.claude/settings.json")"
	"${BOOTSTRAP}" --auto --plugins core,python --dry-run --quiet >/dev/null 2>&1
	local after
	after="$(cat "${TEST_TMPDIR}/.claude/settings.json")"
	# Settings should be unchanged
	if [[ "${before}" != "${after}" ]]; then
		printf '    %s%s FAIL:%s settings.json was modified during dry-run\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
	# CLAUDE.md should not exist
	assert_file_not_exists "${TEST_TMPDIR}/.claude/CLAUDE.md" \
		"CLAUDE.md should not be created in dry-run" || return 1
}

test_skip_settings() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --skip-settings --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Settings should be unchanged (still empty object)
	local content
	content="$(cat "${settings}")"
	if [[ "${content}" != "{}" ]]; then
		printf '    %s%s FAIL:%s settings.json was modified with --skip-settings\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
	# CLAUDE.md should be created
	assert_file_exists "${TEST_TMPDIR}/.claude/CLAUDE.md" "CLAUDE.md should still be created" || return 1
}

test_skip_claude_md() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --skip-claude-md --quiet >/dev/null 2>&1
	# Settings should be modified
	assert_json_key "${TEST_TMPDIR}/.claude/settings.json" \
		'.enabledPlugins["ccfg-core@claude-config"]' "true" || return 1
	# CLAUDE.md should NOT be created
	assert_file_not_exists "${TEST_TMPDIR}/.claude/CLAUDE.md" \
		"CLAUDE.md should not be created with --skip-claude-md" || return 1
}

test_backup_created() {
	# Create initial settings
	printf '{"existing": true}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	# Check backup directory has files
	local backup_count
	backup_count="$(find "${CCFG_BACKUP_DIR}" -name "settings_*" -type f 2>/dev/null | wc -l)"
	if [[ "${backup_count}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s No settings backup created\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_rollback() {
	# Create initial settings and run bootstrap
	printf '{"original": true}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	# Settings should now have ccfg entries
	assert_json_key "${TEST_TMPDIR}/.claude/settings.json" \
		'.enabledPlugins["ccfg-core@claude-config"]' "true" \
		"Should have ccfg entries after bootstrap" || return 1
	# Rollback
	"${BOOTSTRAP}" --rollback --quiet >/dev/null 2>&1
	# Settings should be back to original
	assert_json_key "${TEST_TMPDIR}/.claude/settings.json" '.original' "true" \
		"Should be restored to original after rollback" || return 1
}

test_status_runs_without_error() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local exit_code=0
	"${BOOTSTRAP}" --status --quiet >/dev/null 2>&1 || exit_code=$?
	assert_exit_code 0 "${exit_code}" "Status mode should exit 0" || return 1
}

test_core_always_included() {
	# Even when specifying only python, core should be included
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins python --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	assert_json_key "${settings}" '.enabledPlugins["ccfg-core@claude-config"]' "true" \
		"ccfg-core should always be included" || return 1
	assert_json_key "${settings}" '.enabledPlugins["ccfg-python@claude-config"]' "true" \
		"ccfg-python should also be included" || return 1
}

test_unknown_plugin_skipped() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,nonexistent --quiet >/dev/null 2>&1 || true
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Core should still work
	assert_json_key "${settings}" '.enabledPlugins["ccfg-core@claude-config"]' "true" \
		"Core should still be enabled despite unknown plugin" || return 1
	# Nonexistent should NOT be in settings
	assert_file_not_contains "${settings}" "nonexistent" \
		"Nonexistent plugin should not appear in settings" || return 1
}

test_permissions_deduplicated() {
	# Run twice — permissions should not have duplicates
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,python --quiet >/dev/null 2>&1
	"${BOOTSTRAP}" --auto --plugins core,python --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Count occurrences of a specific permission
	local count
	count="$(jq '[.permissions.allow[] | select(. == "Bash(git:*)")] | length' "${settings}")"
	if [[ "${count}" -ne 1 ]]; then
		printf '    %s%s FAIL:%s Permission duplicated: Bash(git:*) appears %d times\n' \
			"${RED}" "${CROSS}" "${RESET}" "${count}"
		return 1
	fi
}

test_claude_md_best_practices_content() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local claude_md="${TEST_TMPDIR}/.claude/CLAUDE.md"
	# Check key sections from the template
	assert_file_contains "${claude_md}" "Code Quality" || return 1
	assert_file_contains "${claude_md}" "Incremental Validation" || return 1
	assert_file_contains "${claude_md}" "Git Workflow" || return 1
	assert_file_contains "${claude_md}" "Security" || return 1
	assert_file_contains "${claude_md}" "Task Discipline" || return 1
}

test_existing_claude_md_preserved() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	# Pre-create CLAUDE.md with user content
	cat >"${TEST_TMPDIR}/.claude/CLAUDE.md" <<'CONTENT'
# My Personal Rules

These are my custom rules.

## User Customizations

My custom stuff here.
CONTENT
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	local claude_md="${TEST_TMPDIR}/.claude/CLAUDE.md"
	# User content should survive
	assert_file_contains "${claude_md}" "My Personal Rules" \
		"Custom heading should be preserved" || return 1
	assert_file_contains "${claude_md}" "My custom stuff here" \
		"User customizations content should be preserved" || return 1
	# Managed section should be added
	assert_file_contains "${claude_md}" "ccfg:begin:best-practices" || return 1
}

test_settings_json_auto_created() {
	# Remove settings.json entirely
	rm -f "${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/.claude/settings.json" \
		"settings.json should be auto-created" || return 1
	assert_json_key "${TEST_TMPDIR}/.claude/settings.json" \
		'.enabledPlugins["ccfg-core@claude-config"]' "true" || return 1
}

test_data_plugin_empty_permissions() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	"${BOOTSTRAP}" --auto --plugins core,mysql --quiet >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# MySQL should be enabled
	assert_json_key "${settings}" '.enabledPlugins["ccfg-mysql@claude-config"]' "true" || return 1
	# Permissions should only come from core (not mysql, which has empty perms)
	local perm_count
	perm_count="$(jq '.permissions.allow | length' "${settings}")"
	local core_count
	core_count="$(jq '.suggestedPermissions.allow | length' "${PLUGINS_DIR}/ccfg-core/.claude-plugin/plugin.json")"
	if [[ "${perm_count}" -ne "${core_count}" ]]; then
		printf '    %s%s FAIL:%s Expected %d permissions (core only), got %d\n' \
			"${RED}" "${CROSS}" "${RESET}" "${core_count}" "${perm_count}"
		return 1
	fi
}

# ──────────────────────────────────────────────────────────────────
# Test Runner
# ──────────────────────────────────────────────────────────────────

printf '\n  %sccfg-bootstrap test suite%s\n' "${BOLD}" "${RESET}"
printf '  %s\n\n' "$(printf '%0.s=' {1..26})"

run_test test_clean_install_creates_settings
run_test test_clean_install_creates_claude_md
run_test test_permissions_merged_from_plugin
run_test test_multiple_plugins
run_test test_existing_settings_preserved
run_test test_thinking_not_overwritten
run_test test_idempotent
run_test test_dry_run_no_changes
run_test test_skip_settings
run_test test_skip_claude_md
run_test test_backup_created
run_test test_rollback
run_test test_status_runs_without_error
run_test test_core_always_included
run_test test_unknown_plugin_skipped
run_test test_permissions_deduplicated
run_test test_claude_md_best_practices_content
run_test test_existing_claude_md_preserved
run_test test_settings_json_auto_created
run_test test_data_plugin_empty_permissions

printf '\n  %s\n' "$(printf '%0.s━' {1..30})"
printf '  Tests: %d run, %s%d passed%s, %s%d failed%s\n\n' \
	"${TESTS_RUN}" \
	"${GREEN}" "${TESTS_PASSED}" "${RESET}" \
	"$([[ ${TESTS_FAILED} -gt 0 ]] && printf '%s' "${RED}" || printf '%s' "${GREEN}")" \
	"${TESTS_FAILED}" "${RESET}"

exit "${TESTS_FAILED}"
