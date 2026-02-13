#!/usr/bin/env bash
# test-plugins.sh — Test suite for ccfg-plugins.sh
#
# Usage:
#   bash bootstrap/tests/test-plugins.sh
#
# Tests run in isolated temp directories to avoid touching real settings.
# Functions are invoked indirectly via run_test and from test functions
# shellcheck disable=SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_SCRIPT="${SCRIPT_DIR}/../ccfg-plugins.sh"

# Source common for colors and symbols
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/common.sh"

# Source registry for data access in tests
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/registry.sh"

# Source detect for detection helpers
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/detect.sh"

# Source settings for merge helpers
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/settings.sh"

# Source backup for backup helpers
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/backup.sh"

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

assert_exit_code() {
	local expected="$1"
	local actual="$2"
	local msg="${3:-Expected exit code ${expected}, got ${actual}}"
	if [[ "${expected}" -ne "${actual}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_equals() {
	local expected="$1"
	local actual="$2"
	local msg="${3:-Expected \"${expected}\", got \"${actual}\"}"
	if [[ "${expected}" != "${actual}" ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_contains() {
	local haystack="$1"
	local needle="$2"
	local msg="${3:-Output should contain: ${needle}}"
	if [[ "${haystack}" != *"${needle}"* ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

assert_not_contains() {
	local haystack="$1"
	local needle="$2"
	local msg="${3:-Output should not contain: ${needle}}"
	if [[ "${haystack}" == *"${needle}"* ]]; then
		printf '    %s%s FAIL:%s %s\n' "${RED}" "${CROSS}" "${RESET}" "${msg}"
		return 1
	fi
}

# Mock claude CLI — handles marketplace list and plugin install
mock_claude() {
	export PATH="${TEST_TMPDIR}/bin:${PATH}"
	mkdir -p "${TEST_TMPDIR}/bin"
	cat >"${TEST_TMPDIR}/bin/claude" <<'SCRIPT'
#!/usr/bin/env bash
# Mock claude CLI for testing
if [[ "${1:-}" == "plugin" && "${2:-}" == "marketplace" && "${3:-}" == "list" ]]; then
	# Return all known marketplaces
	printf 'Configured marketplaces:\n\n'
	printf '  ❯ claude-plugins-official\n'
	printf '    Source: GitHub (anthropics/claude-plugins-official)\n\n'
	printf '  ❯ claude-code-lsps\n'
	printf '    Source: GitHub (boostvolt/claude-code-lsps)\n\n'
	printf '  ❯ beads-marketplace\n'
	printf '    Source: GitHub (steveyegge/beads)\n\n'
	printf '  ❯ anthropic-agent-skills\n'
	printf '    Source: GitHub (anthropics/skills)\n\n'
	exit 0
fi
# All other commands succeed silently
exit 0
SCRIPT
	chmod +x "${TEST_TMPDIR}/bin/claude"
}

# Mock claude CLI that reports a missing marketplace
mock_claude_missing_marketplace() {
	export PATH="${TEST_TMPDIR}/bin:${PATH}"
	mkdir -p "${TEST_TMPDIR}/bin"
	cat >"${TEST_TMPDIR}/bin/claude" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "plugin" && "${2:-}" == "marketplace" && "${3:-}" == "list" ]]; then
	# Return only one marketplace — others are missing
	printf 'Configured marketplaces:\n\n'
	printf '  ❯ claude-plugins-official\n'
	printf '    Source: GitHub (anthropics/claude-plugins-official)\n\n'
	exit 0
fi
exit 0
SCRIPT
	chmod +x "${TEST_TMPDIR}/bin/claude"
}

# Mock claude CLI that fails on install
mock_claude_install_fails() {
	export PATH="${TEST_TMPDIR}/bin:${PATH}"
	mkdir -p "${TEST_TMPDIR}/bin"
	cat >"${TEST_TMPDIR}/bin/claude" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "plugin" && "${2:-}" == "marketplace" && "${3:-}" == "list" ]]; then
	printf 'Configured marketplaces:\n\n'
	printf '  ❯ claude-plugins-official\n'
	printf '    Source: GitHub (anthropics/claude-plugins-official)\n\n'
	printf '  ❯ claude-code-lsps\n'
	printf '    Source: GitHub (boostvolt/claude-code-lsps)\n\n'
	printf '  ❯ beads-marketplace\n'
	printf '    Source: GitHub (steveyegge/beads)\n\n'
	printf '  ❯ anthropic-agent-skills\n'
	printf '    Source: GitHub (anthropics/skills)\n\n'
	exit 0
fi
# All install commands fail
if [[ "${1:-}" == "plugin" && "${2:-}" == "install" ]]; then
	exit 1
fi
exit 0
SCRIPT
	chmod +x "${TEST_TMPDIR}/bin/claude"
}

# Create a fake project directory with specific detection signals
create_project() {
	local project_dir="${TEST_TMPDIR}/project"
	mkdir -p "${project_dir}"
	printf '%s' "${project_dir}"
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
# Test Cases: CLI Parsing
# ──────────────────────────────────────────────────────────────────

test_help_exits_zero() {
	local exit_code=0
	"${PLUGINS_SCRIPT}" --help >/dev/null 2>&1 || exit_code=$?
	assert_exit_code 0 "${exit_code}" "--help should exit 0" || return 1
}

test_invalid_category_exits_nonzero() {
	local exit_code=0
	"${PLUGINS_SCRIPT}" --category bogus >/dev/null 2>&1 || exit_code=$?
	if [[ "${exit_code}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s Invalid category should exit non-zero\n' "${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_unknown_option_exits_nonzero() {
	local exit_code=0
	"${PLUGINS_SCRIPT}" --nonexistent >/dev/null 2>&1 || exit_code=$?
	if [[ "${exit_code}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s Unknown option should exit non-zero\n' "${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Detection
# ──────────────────────────────────────────────────────────────────

test_detection_python_project() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/pyproject.toml"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Should detect python and recommend pyright LSP (skipped in auto)
	assert_contains "${output}" "python LSP: skipped" \
		"Python LSP overlap should be noted" || return 1
}

test_detection_supplemental_frontend() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/app.tsx"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --quiet --project-dir "${project_dir}" 2>&1)"
	# In list mode with frontend detected, frontend-design should appear
	assert_contains "${output}" "frontend-design" \
		"Frontend-design should appear when .tsx detected" || return 1
}

test_detection_supplemental_beads() {
	local project_dir
	project_dir="$(create_project)"
	mkdir -p "${project_dir}/.beads"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --quiet --project-dir "${project_dir}" 2>&1)"
	# Beads plugin should appear
	assert_contains "${output}" "beads" \
		"Beads plugin should appear when .beads/ detected" || return 1
}

test_detection_javascript_maps_typescript() {
	local project_dir
	project_dir="$(create_project)"
	# package.json without TypeScript signals = javascript detection
	printf '{"name": "test"}\n' >"${project_dir}/package.json"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# JavaScript should trigger TypeScript LSP overlap note
	assert_contains "${output}" "typescript LSP: skipped" \
		"JavaScript should map to TypeScript LSP detection" || return 1
}

test_detection_nonexistent_dir() {
	local exit_code=0
	"${PLUGINS_SCRIPT}" --project-dir /nonexistent/path >/dev/null 2>&1 || exit_code=$?
	if [[ "${exit_code}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s Non-existent project-dir should fail\n' "${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Candidate List Building
# ──────────────────────────────────────────────────────────────────

test_auto_tier_universal_plugins() {
	# Empty project should still get universal auto-tier plugins
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "context7" \
		"context7 (auto/always) should appear" || return 1
	assert_contains "${output}" "commit-commands" \
		"commit-commands (auto/always) should appear" || return 1
	assert_contains "${output}" "document-skills" \
		"document-skills (auto/always) should appear" || return 1
}

test_auto_mode_skips_suggest_tier() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# code-review is suggest/always — should NOT appear in auto dry-run install list
	assert_not_contains "${output}" "claude plugin install code-review" \
		"Suggest-tier plugins should not be installed in --auto mode" || return 1
}

test_auto_mode_skips_lsp_overlaps() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/pyproject.toml"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Python has both pyright-lsp and pyright — both should be skipped in auto
	assert_not_contains "${output}" "claude plugin install pyright-lsp" \
		"Overlapping LSP should not be installed in --auto" || return 1
	assert_not_contains "${output}" "claude plugin install pyright@" \
		"Overlapping LSP alternative should not be installed in --auto" || return 1
}

test_category_filter_lsp() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/Cargo.toml"
	local output
	output="$("${PLUGINS_SCRIPT}" --category lsp --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Should not include non-LSP auto plugins
	assert_not_contains "${output}" "context7" \
		"Non-LSP plugins should be filtered out with --category lsp" || return 1
}

test_category_filter_general() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --category general --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "context7" \
		"context7 should appear in --category general" || return 1
	assert_contains "${output}" "commit-commands" \
		"commit-commands should appear in --category general" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: List Mode
# ──────────────────────────────────────────────────────────────────

test_list_mode_shows_all_tiers() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --project-dir "${project_dir}" 2>&1)"
	# Should include auto, suggest, and info tier plugins
	assert_contains "${output}" "auto" "Should show auto tier" || return 1
	assert_contains "${output}" "suggest" "Should show suggest tier" || return 1
	assert_contains "${output}" "info" "Should show info tier" || return 1
}

test_list_mode_shows_all_categories() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "general" "Should show general category" || return 1
	assert_contains "${output}" "lsp" "Should show lsp category" || return 1
	assert_contains "${output}" "integration" "Should show integration category" || return 1
	assert_contains "${output}" "style" "Should show style category" || return 1
}

test_list_mode_shows_registry_count() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "78 plugins in registry" \
		"Should show correct registry count" || return 1
}

test_list_mode_exits_zero() {
	local project_dir
	project_dir="$(create_project)"
	local exit_code=0
	"${PLUGINS_SCRIPT}" --list --project-dir "${project_dir}" >/dev/null 2>&1 || exit_code=$?
	assert_exit_code 0 "${exit_code}" "--list should exit 0" || return 1
}

test_list_with_category_filter() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --list --category lsp --project-dir "${project_dir}" 2>&1)"
	# Should only show LSP plugins
	assert_contains "${output}" "lsp" "Should show lsp category" || return 1
	assert_not_contains "${output}" "integration" \
		"Should not show integration with --category lsp" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Dry Run
# ──────────────────────────────────────────────────────────────────

test_dry_run_no_settings_changes() {
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local before
	before="$(cat "${TEST_TMPDIR}/.claude/settings.json")"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --dry-run --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local after
	after="$(cat "${TEST_TMPDIR}/.claude/settings.json")"
	if [[ "${before}" != "${after}" ]]; then
		printf '    %s%s FAIL:%s settings.json was modified during dry-run\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_dry_run_shows_install_commands() {
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "[dry-run]" \
		"Dry-run should show [dry-run] labels" || return 1
	assert_contains "${output}" "claude plugin install" \
		"Dry-run should show install commands" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Installation & Settings
# ──────────────────────────────────────────────────────────────────

test_install_with_mock_claude() {
	mock_claude
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Auto-tier universal plugins should be in enabledPlugins
	assert_json_key "${settings}" \
		'.enabledPlugins["context7@claude-plugins-official"]' "true" \
		"context7 should be enabled after install" || return 1
	assert_json_key "${settings}" \
		'.enabledPlugins["commit-commands@claude-plugins-official"]' "true" \
		"commit-commands should be enabled after install" || return 1
	assert_json_key "${settings}" \
		'.enabledPlugins["document-skills@anthropic-agent-skills"]' "true" \
		"document-skills should be enabled after install" || return 1
}

test_settings_preserves_existing() {
	mock_claude
	# Pre-populate settings with user's own config
	cat >"${TEST_TMPDIR}/.claude/settings.json" <<'JSON'
{
  "enabledPlugins": {
    "my-custom-plugin@my-marketplace": true
  },
  "myCustomSetting": 42
}
JSON
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Existing entries should survive
	assert_json_key "${settings}" \
		'.enabledPlugins["my-custom-plugin@my-marketplace"]' "true" \
		"Existing plugin should be preserved" || return 1
	assert_json_key "${settings}" '.myCustomSetting' "42" \
		"Custom setting should be preserved" || return 1
	# New entries should be added
	assert_json_key "${settings}" \
		'.enabledPlugins["context7@claude-plugins-official"]' "true" \
		"New plugin should be added" || return 1
}

test_settings_idempotent() {
	mock_claude
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local first_settings
	first_settings="$(jq --sort-keys '.' "${TEST_TMPDIR}/.claude/settings.json")"
	# Run again
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local second_settings
	second_settings="$(jq --sort-keys '.' "${TEST_TMPDIR}/.claude/settings.json")"
	if [[ "${first_settings}" != "${second_settings}" ]]; then
		printf '    %s%s FAIL:%s settings.json changed between runs\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_backup_created_on_install() {
	mock_claude
	printf '{"existing": true}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	# Check backup directory has files
	local backup_count
	backup_count="$(find "${CCFG_BACKUP_DIR}" -name "settings_*" -type f 2>/dev/null | wc -l)"
	if [[ "${backup_count}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s No settings backup created\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_settings_auto_created() {
	mock_claude
	# Remove settings.json entirely
	rm -f "${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/.claude/settings.json" \
		"settings.json should be auto-created" || return 1
	assert_json_key "${TEST_TMPDIR}/.claude/settings.json" \
		'.enabledPlugins["context7@claude-plugins-official"]' "true" \
		"context7 should be in auto-created settings" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Non-Interactive Fallback
# ──────────────────────────────────────────────────────────────────

test_non_tty_fallback() {
	# When stdin is not a tty (piped), suggest-tier should be skipped
	mock_claude
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	mkdir -p "${project_dir}/.beads"
	# Pipe to force non-tty
	local output
	output="$(echo "" | "${PLUGINS_SCRIPT}" --quiet --project-dir "${project_dir}" 2>&1)"
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# Auto-tier should be installed
	assert_json_key "${settings}" \
		'.enabledPlugins["context7@claude-plugins-official"]' "true" \
		"Auto-tier should install in non-tty" || return 1
	# Suggest-tier beads should NOT be installed (user can't interact)
	local beads_value
	beads_value="$(jq -r '.enabledPlugins["beads@beads-marketplace"] // "null"' "${settings}" 2>/dev/null)"
	if [[ "${beads_value}" == "true" ]]; then
		printf '    %s%s FAIL:%s Suggest-tier beads should not install in non-tty\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Edge Cases
# ──────────────────────────────────────────────────────────────────

test_empty_project_gets_universal() {
	# Completely empty project should get the 3 universal auto-tier plugins
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "3 plugin(s)" \
		"Empty project should get 3 universal plugins" || return 1
}

test_lsp_single_source_auto_detected() {
	# Shell detection should auto-include bash-language-server (single-source LSP)
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/build.sh"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "bash-language-server" \
		"Single-source LSP should be auto-included" || return 1
}

test_registry_lsp_overlap_langs() {
	# reg_lsp_overlap_langs should return languages with >1 LSP plugin
	local overlap_langs
	overlap_langs="$(reg_lsp_overlap_langs | sort)"
	# Should include python (pyright-lsp + pyright), typescript, etc.
	assert_contains "${overlap_langs}" "python" \
		"Python should be an overlap language" || return 1
	assert_contains "${overlap_langs}" "typescript" \
		"TypeScript should be an overlap language" || return 1
	# Should NOT include shell (single-source)
	assert_not_contains "${overlap_langs}" "shell" \
		"Shell should not be an overlap language" || return 1
}

test_registry_lsp_preferred() {
	# reg_lsp_preferred should return the preferred key for a language
	local preferred
	preferred="$(reg_lsp_preferred "python")"
	assert_equals "official/pyright-lsp" "${preferred}" \
		"Python preferred LSP should be official/pyright-lsp" || return 1
	# PHP is community-preferred (Intelephense)
	preferred="$(reg_lsp_preferred "php")"
	assert_equals "community/intelephense" "${preferred}" \
		"PHP preferred LSP should be community/intelephense" || return 1
}

test_registry_is_lsp_overlap() {
	# reg_is_lsp_overlap should return 0 for overlapping LSP keys
	reg_is_lsp_overlap "official/pyright-lsp" || {
		printf '    %s%s FAIL:%s pyright-lsp should be an overlap\n' "${RED}" "${CROSS}" "${RESET}"
		return 1
	}
	# bash-language-server is single-source, should return 1
	if reg_is_lsp_overlap "community/bash-language-server"; then
		printf '    %s%s FAIL:%s bash-language-server should NOT be an overlap\n' "${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_detection_deduplication() {
	# A project that triggers both javascript and typescript should not duplicate
	local project_dir
	project_dir="$(create_project)"
	printf '{"name": "test"}\n' >"${project_dir}/package.json"
	touch "${project_dir}/app.tsx"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Should still work correctly — no errors from duplicate detection
	assert_contains "${output}" "Dry run complete" \
		"Script should complete successfully with potential duplicates" || return 1
}

test_multiple_languages_detected() {
	# Project with Python + Rust + Docker
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/pyproject.toml"
	touch "${project_dir}/Cargo.toml"
	touch "${project_dir}/Dockerfile"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Should note both LSP overlaps
	assert_contains "${output}" "python LSP: skipped" \
		"Python LSP overlap should be noted" || return 1
	assert_contains "${output}" "rust LSP: skipped" \
		"Rust LSP overlap should be noted" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Per-Language Recommendation Accuracy
# ──────────────────────────────────────────────────────────────────

test_detection_golang_project() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/go.mod"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Go has overlapping LSPs (gopls-lsp vs gopls) — should be noted in auto
	assert_contains "${output}" "golang LSP: skipped" \
		"Go LSP overlap should be noted" || return 1
}

test_detection_java_project() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/pom.xml"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Java has overlapping LSPs (jdtls-lsp vs jdtls)
	assert_contains "${output}" "java LSP: skipped" \
		"Java LSP overlap should be noted" || return 1
}

test_detection_csharp_project() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/App.csproj"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# C# has overlapping LSPs (csharp-lsp vs omnisharp)
	assert_contains "${output}" "csharp LSP: skipped" \
		"C# LSP overlap should be noted" || return 1
}

test_detection_docker_project() {
	local project_dir
	project_dir="$(create_project)"
	touch "${project_dir}/Dockerfile"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	# Docker should be detected (shown in output) and script should complete
	assert_contains "${output}" "docker" \
		"Docker should be detected" || return 1
	assert_contains "${output}" "Dry run complete" \
		"Script should complete with docker detection" || return 1
}

test_detection_kubernetes_project() {
	local project_dir
	project_dir="$(create_project)"
	mkdir -p "${project_dir}/k8s"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "kubernetes" \
		"Kubernetes should be detected" || return 1
	assert_contains "${output}" "Dry run complete" \
		"Script should complete with kubernetes detection" || return 1
}

test_detection_github_actions_project() {
	local project_dir
	project_dir="$(create_project)"
	mkdir -p "${project_dir}/.github/workflows"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)"
	assert_contains "${output}" "github-actions" \
		"GitHub Actions should be detected" || return 1
	assert_contains "${output}" "Dry run complete" \
		"Script should complete with github-actions detection" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Marketplace Availability
# ──────────────────────────────────────────────────────────────────

test_missing_marketplace_error() {
	# When a required marketplace is not configured, script should error
	mock_claude_missing_marketplace
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	local exit_code=0
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --project-dir "${project_dir}" 2>&1)" || exit_code=$?
	# Should fail (anthropic-agent-skills is missing)
	if [[ "${exit_code}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s Should exit non-zero when marketplace is missing\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
	# Should show helpful error with add command
	assert_contains "${output}" "Missing marketplace" \
		"Should mention missing marketplace" || return 1
	assert_contains "${output}" "claude plugin marketplace add" \
		"Should show marketplace add command" || return 1
}

test_missing_marketplace_dry_run_warns() {
	# In dry-run mode, missing marketplace should warn but not abort
	mock_claude_missing_marketplace
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	local exit_code=0
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --dry-run --project-dir "${project_dir}" 2>&1)" || exit_code=$?
	# Should succeed (dry-run doesn't abort on missing marketplace)
	assert_exit_code 0 "${exit_code}" \
		"Dry-run should not abort on missing marketplace" || return 1
	# Should still warn
	assert_contains "${output}" "Missing marketplace" \
		"Dry-run should warn about missing marketplace" || return 1
	assert_contains "${output}" "Dry run complete" \
		"Dry-run should complete normally" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Install Failure Handling
# ──────────────────────────────────────────────────────────────────

test_install_failure_continues() {
	# When claude plugin install fails, script should continue and report
	mock_claude_install_fails
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	local output
	output="$("${PLUGINS_SCRIPT}" --auto --project-dir "${project_dir}" 2>&1)" || true
	# Should report failures
	assert_contains "${output}" "install failed" \
		"Failed installs should be reported" || return 1
	# Should mention number failed in summary
	assert_contains "${output}" "failed" \
		"Summary should mention failures" || return 1
}

test_install_failure_not_in_settings() {
	# Failed installs should NOT be added to enabledPlugins
	mock_claude_install_fails
	printf '{}\n' >"${TEST_TMPDIR}/.claude/settings.json"
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1 || true
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# enabledPlugins should be empty (no successful installs)
	local plugin_count
	plugin_count="$(jq '.enabledPlugins // {} | keys | length' "${settings}" 2>/dev/null)"
	assert_equals "0" "${plugin_count}" \
		"Failed installs should not be in enabledPlugins" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Cases: Already-Installed Idempotency
# ──────────────────────────────────────────────────────────────────

test_already_enabled_idempotent() {
	# Plugins already in enabledPlugins should be preserved without duplication
	mock_claude
	cat >"${TEST_TMPDIR}/.claude/settings.json" <<'JSON'
{
  "enabledPlugins": {
    "context7@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "document-skills@anthropic-agent-skills": true
  }
}
JSON
	local project_dir
	project_dir="$(create_project)"
	"${PLUGINS_SCRIPT}" --auto --quiet --project-dir "${project_dir}" >/dev/null 2>&1
	local settings="${TEST_TMPDIR}/.claude/settings.json"
	# All 3 should still be true (not overwritten or duplicated)
	assert_json_key "${settings}" \
		'.enabledPlugins["context7@claude-plugins-official"]' "true" \
		"context7 should remain enabled" || return 1
	assert_json_key "${settings}" \
		'.enabledPlugins["commit-commands@claude-plugins-official"]' "true" \
		"commit-commands should remain enabled" || return 1
	assert_json_key "${settings}" \
		'.enabledPlugins["document-skills@anthropic-agent-skills"]' "true" \
		"document-skills should remain enabled" || return 1
	# Count should be exactly 3 (no duplicates, no extra keys)
	local plugin_count
	plugin_count="$(jq '.enabledPlugins | keys | length' "${settings}" 2>/dev/null)"
	assert_equals "3" "${plugin_count}" \
		"enabledPlugins count should remain 3" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Runner
# ──────────────────────────────────────────────────────────────────

printf '\n  %sccfg-plugins test suite%s\n' "${BOLD}" "${RESET}"
printf '  %s\n\n' "$(printf '%0.s=' {1..24})"

# CLI parsing
run_test test_help_exits_zero
run_test test_invalid_category_exits_nonzero
run_test test_unknown_option_exits_nonzero

# Detection
run_test test_detection_python_project
run_test test_detection_supplemental_frontend
run_test test_detection_supplemental_beads
run_test test_detection_javascript_maps_typescript
run_test test_detection_nonexistent_dir

# Candidate building
run_test test_auto_tier_universal_plugins
run_test test_auto_mode_skips_suggest_tier
run_test test_auto_mode_skips_lsp_overlaps
run_test test_category_filter_lsp
run_test test_category_filter_general

# List mode
run_test test_list_mode_shows_all_tiers
run_test test_list_mode_shows_all_categories
run_test test_list_mode_shows_registry_count
run_test test_list_mode_exits_zero
run_test test_list_with_category_filter

# Dry run
run_test test_dry_run_no_settings_changes
run_test test_dry_run_shows_install_commands

# Installation & settings
run_test test_install_with_mock_claude
run_test test_settings_preserves_existing
run_test test_settings_idempotent
run_test test_backup_created_on_install
run_test test_settings_auto_created

# Non-interactive
run_test test_non_tty_fallback

# Registry helpers
run_test test_registry_lsp_overlap_langs
run_test test_registry_lsp_preferred
run_test test_registry_is_lsp_overlap

# Per-language recommendation accuracy
run_test test_detection_golang_project
run_test test_detection_java_project
run_test test_detection_csharp_project
run_test test_detection_docker_project
run_test test_detection_kubernetes_project
run_test test_detection_github_actions_project

# Marketplace availability
run_test test_missing_marketplace_error
run_test test_missing_marketplace_dry_run_warns

# Install failure handling
run_test test_install_failure_continues
run_test test_install_failure_not_in_settings

# Already-installed idempotency
run_test test_already_enabled_idempotent

# Edge cases
run_test test_detection_deduplication
run_test test_empty_project_gets_universal
run_test test_lsp_single_source_auto_detected
run_test test_multiple_languages_detected

printf '\n  %s\n' "$(printf '%0.s━' {1..30})"
printf '  Tests: %d run, %s%d passed%s, %s%d failed%s\n\n' \
	"${TESTS_RUN}" \
	"${GREEN}" "${TESTS_PASSED}" "${RESET}" \
	"$([[ ${TESTS_FAILED} -gt 0 ]] && printf '%s' "${RED}" || printf '%s' "${GREEN}")" \
	"${TESTS_FAILED}" "${RESET}"

exit "${TESTS_FAILED}"
