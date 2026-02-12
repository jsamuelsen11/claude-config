#!/usr/bin/env bash
# test-project-init.sh — Test suite for ccfg-project-init.sh
#
# Usage:
#   bash bootstrap/tests/test-project-init.sh
#
# Functions are invoked indirectly via run_test and from test functions
# shellcheck disable=SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_INIT="${SCRIPT_DIR}/../ccfg-project-init.sh"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/sections"

# Source common for colors
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test isolation
TEST_TMPDIR=""

# Override backup directory to avoid polluting real backups
export CCFG_BACKUP_DIR=""

# ──────────────────────────────────────────────────────────────────
# Test Helpers
# ──────────────────────────────────────────────────────────────────

setup_tmpdir() {
	TEST_TMPDIR="$(mktemp -d)"
	# Create isolated backup dir per test
	CCFG_BACKUP_DIR="${TEST_TMPDIR}/.backups"
	mkdir -p "${CCFG_BACKUP_DIR}"
}

teardown_tmpdir() {
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

assert_section_present() {
	local file="$1"
	local section="$2"
	assert_file_contains "${file}" "ccfg:begin:${section}" "Section '${section}' should be present"
	assert_file_contains "${file}" "ccfg:end:${section}" "Section '${section}' end marker should be present"
}

assert_section_absent() {
	local file="$1"
	local section="$2"
	assert_file_not_contains "${file}" "ccfg:begin:${section}" "Section '${section}' should not be present"
}

assert_marker_balanced() {
	local file="$1"
	local begin_count end_count
	begin_count="$(grep -c "ccfg:begin:" "${file}" 2>/dev/null || printf '0')"
	end_count="$(grep -c "ccfg:end:" "${file}" 2>/dev/null || printf '0')"
	if [[ "${begin_count}" -ne "${end_count}" ]]; then
		printf '    %s%s FAIL:%s Markers unbalanced: %d begin, %d end\n' \
			"${RED}" "${CROSS}" "${RESET}" "${begin_count}" "${end_count}"
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
# Fixture Creators
# ──────────────────────────────────────────────────────────────────

create_python_project() {
	local dir="$1"
	printf '[project]\nname = "test"\n' >"${dir}/pyproject.toml"
}

create_golang_project() {
	local dir="$1"
	printf 'module example.com/test\n\ngo 1.22\n' >"${dir}/go.mod"
}

create_typescript_project() {
	local dir="$1"
	printf '{"name":"test","dependencies":{"typescript":"^5.0.0"}}\n' >"${dir}/package.json"
	printf '{"compilerOptions":{"strict":true}}\n' >"${dir}/tsconfig.json"
}

create_javascript_project() {
	local dir="$1"
	printf '{"name":"test","dependencies":{"lodash":"^4.0.0"}}\n' >"${dir}/package.json"
}

create_docker_project() {
	local dir="$1"
	printf 'FROM alpine:3.19\nCMD ["echo","hello"]\n' >"${dir}/Dockerfile"
}

create_multi_project() {
	local dir="$1"
	create_python_project "${dir}"
	create_docker_project "${dir}"
	mkdir -p "${dir}/docs"
	printf '# Test\n' >"${dir}/README.md"
}

# ──────────────────────────────────────────────────────────────────
# Test Cases
# ──────────────────────────────────────────────────────────────────

test_all_templates_exist() {
	local templates=(
		python golang typescript java rust csharp shell docker
		kubernetes github-actions mysql postgresql mongodb redis sqlite markdown
	)
	local t
	for t in "${templates[@]}"; do
		assert_file_exists "${TEMPLATE_DIR}/${t}.md" "Template missing: ${t}.md" || return 1
	done
}

test_auto_python_project() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/CLAUDE.md" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "python" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "## Python Conventions" || return 1
	assert_marker_balanced "${TEST_TMPDIR}/CLAUDE.md" || return 1
}

test_auto_golang_project() {
	create_golang_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/CLAUDE.md" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "golang" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "## Go Conventions" || return 1
}

test_auto_typescript_project() {
	create_typescript_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/CLAUDE.md" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "typescript" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "## TypeScript Conventions" || return 1
}

test_javascript_maps_to_typescript() {
	create_javascript_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/CLAUDE.md" || return 1
	# JavaScript should map to typescript section
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "typescript" || return 1
	# Should NOT have a "javascript" section
	assert_section_absent "${TEST_TMPDIR}/CLAUDE.md" "javascript" || return 1
}

test_auto_multi_language() {
	create_multi_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/CLAUDE.md" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "python" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "docker" || return 1
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "markdown" || return 1
	assert_marker_balanced "${TEST_TMPDIR}/CLAUDE.md" || return 1
}

test_no_detection() {
	# Empty directory — nothing to detect
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1 || true
	assert_file_not_exists "${TEST_TMPDIR}/CLAUDE.md" "CLAUDE.md should not be created for empty project" || return 1
}

test_idempotent() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	# Capture file content after first run
	local first_run
	first_run="$(cat "${TEST_TMPDIR}/CLAUDE.md")"
	# Second run
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	local second_run
	second_run="$(cat "${TEST_TMPDIR}/CLAUDE.md")"
	# Content should be identical
	if [[ "${first_run}" != "${second_run}" ]]; then
		printf '    %s%s FAIL:%s File changed between runs (not idempotent)\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_dry_run_no_files() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --dry-run --quiet >/dev/null 2>&1
	assert_file_not_exists "${TEST_TMPDIR}/CLAUDE.md" "--dry-run should not create CLAUDE.md" || return 1
}

test_existing_claude_md_preserved() {
	create_python_project "${TEST_TMPDIR}"
	# Pre-create CLAUDE.md with custom user content
	cat >"${TEST_TMPDIR}/CLAUDE.md" <<'CONTENT'
# My Custom Project Rules

This is my custom content that must be preserved.

## User Customizations

My personal notes here.
CONTENT
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	# User content should survive
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "My Custom Project Rules" \
		"Custom heading should be preserved" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "my custom content that must be preserved" \
		"Custom content should be preserved" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "My personal notes here" \
		"User customizations content should be preserved" || return 1
	# Section should also be added
	assert_section_present "${TEST_TMPDIR}/CLAUDE.md" "python" || return 1
}

test_user_customizations_footer() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "## User Customizations" \
		"Footer heading should be present" || return 1
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "project-specific conventions" \
		"Footer body should mention project-specific" || return 1
}

test_backup_created() {
	create_python_project "${TEST_TMPDIR}"
	# Create initial CLAUDE.md
	printf '# Existing\n' >"${TEST_TMPDIR}/CLAUDE.md"
	# Sleep briefly to ensure timestamp resolution
	sleep 1
	# Record timestamp just before running
	local marker_file="${TEST_TMPDIR}/.before_marker"
	touch "${marker_file}"
	# Run project-init (should backup existing file)
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	# Check that a new CLAUDE_project backup was created after our marker
	local backup_dir="${HOME}/.claude/backups"
	if [[ ! -d "${backup_dir}" ]]; then
		printf '    %s%s FAIL:%s Backup directory does not exist\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
	local new_backups
	new_backups="$(find "${backup_dir}" -name "CLAUDE_project_*" -newer "${marker_file}" -print 2>/dev/null | wc -l)"
	if [[ "${new_backups}" -eq 0 ]]; then
		printf '    %s%s FAIL:%s No new backup file created after marker\n' \
			"${RED}" "${CROSS}" "${RESET}"
		return 1
	fi
}

test_marker_validation() {
	create_multi_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	assert_marker_balanced "${TEST_TMPDIR}/CLAUDE.md" || return 1
	# Count: should have 3 sections (python, docker, markdown)
	local begin_count
	begin_count="$(grep -c "ccfg:begin:" "${TEST_TMPDIR}/CLAUDE.md")"
	if [[ "${begin_count}" -ne 3 ]]; then
		printf '    %s%s FAIL:%s Expected 3 sections, found %d\n' \
			"${RED}" "${CROSS}" "${RESET}" "${begin_count}"
		return 1
	fi
}

test_section_content_matches_template() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	# Extract the template content
	local template_content
	template_content="$(cat "${TEMPLATE_DIR}/python.md")"
	# Check that each line of the template is in the CLAUDE.md
	local line
	while IFS= read -r line; do
		[[ -z "${line}" ]] && continue
		if ! grep -qF -- "${line}" "${TEST_TMPDIR}/CLAUDE.md"; then
			printf '    %s%s FAIL:%s Template line not found in CLAUDE.md: %s\n' \
				"${RED}" "${CROSS}" "${RESET}" "${line}"
			return 1
		fi
	done <<<"${template_content}"
}

test_update_mode() {
	create_python_project "${TEST_TMPDIR}"
	# First run
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --quiet >/dev/null 2>&1
	# Manually change the version marker to simulate old version
	sed -i 's/v0\.1\.0/v0.0.1/g' "${TEST_TMPDIR}/CLAUDE.md"
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "v0.0.1" "Version should be changed to v0.0.1" || return 1
	# Run with --update — should refresh the section
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --update --quiet >/dev/null 2>&1
	# Version should be updated back to current
	assert_file_contains "${TEST_TMPDIR}/CLAUDE.md" "v${CCFG_VERSION}" \
		"Version should be updated to v${CCFG_VERSION}" || return 1
}

test_local_settings() {
	create_python_project "${TEST_TMPDIR}"
	"${PROJECT_INIT}" --project-dir "${TEST_TMPDIR}" --auto --local --quiet >/dev/null 2>&1
	assert_file_exists "${TEST_TMPDIR}/.claude/settings.local.json" \
		"settings.local.json should be created" || return 1
	assert_file_contains "${TEST_TMPDIR}/.claude/settings.local.json" "ccfg-python@claude-config" \
		"Python plugin should be in local settings" || return 1
}

test_project_dir_flag() {
	local subdir="${TEST_TMPDIR}/subproject"
	mkdir -p "${subdir}"
	create_golang_project "${subdir}"
	# Run from a different directory, targeting subproject
	"${PROJECT_INIT}" --project-dir "${subdir}" --auto --quiet >/dev/null 2>&1
	assert_file_exists "${subdir}/CLAUDE.md" "CLAUDE.md should be in targeted directory" || return 1
	assert_section_present "${subdir}/CLAUDE.md" "golang" || return 1
	# Should NOT create CLAUDE.md in the parent
	assert_file_not_exists "${TEST_TMPDIR}/CLAUDE.md" "CLAUDE.md should not be in parent" || return 1
}

# ──────────────────────────────────────────────────────────────────
# Test Runner
# ──────────────────────────────────────────────────────────────────

printf '\n  %sccfg-project-init test suite%s\n' "${BOLD}" "${RESET}"
printf '  %s\n\n' "$(printf '%0.s=' {1..30})"

run_test test_all_templates_exist
run_test test_auto_python_project
run_test test_auto_golang_project
run_test test_auto_typescript_project
run_test test_javascript_maps_to_typescript
run_test test_auto_multi_language
run_test test_no_detection
run_test test_idempotent
run_test test_dry_run_no_files
run_test test_existing_claude_md_preserved
run_test test_user_customizations_footer
run_test test_backup_created
run_test test_marker_validation
run_test test_section_content_matches_template
run_test test_update_mode
run_test test_local_settings
run_test test_project_dir_flag

printf '\n  %s\n' "$(printf '%0.s━' {1..30})"
printf '  Tests: %d run, %s%d passed%s, %s%d failed%s\n\n' \
	"${TESTS_RUN}" \
	"${GREEN}" "${TESTS_PASSED}" "${RESET}" \
	"$([[ ${TESTS_FAILED} -gt 0 ]] && printf '%s' "${RED}" || printf '%s' "${GREEN}")" \
	"${TESTS_FAILED}" "${RESET}"

exit "${TESTS_FAILED}"
