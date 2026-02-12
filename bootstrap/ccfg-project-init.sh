#!/usr/bin/env bash
# ccfg-project-init.sh — Per-project CLAUDE.md and optional local settings setup.
# Detects languages in target project directory, creates/updates ./CLAUDE.md with
# one managed section per detected technology. Optionally scopes plugins to
# ./.claude/settings.local.json.
#
# Usage:
#   ccfg-project-init.sh [options]
#   ccfg-project-init.sh --project-dir ~/my-project --auto
#
# See docs/BOOTSTRAP.md for full specification.

set -euo pipefail

# Resolve script directory (follows symlinks via BASH_SOURCE)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/detect.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/claude-md.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/settings.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
TEMPLATE_DIR="${SCRIPT_DIR}/templates/sections"

# CLI flags (set by parse_args)
PROJECT_DIR=""
AUTO_MODE=0
LOCAL_MODE=0
LOCAL_PLUGINS=""
DRY_RUN=0
UPDATE_MODE=0
QUIET=0
VERBOSE=0

# Runtime state
CLAUDE_MD_FILE=""
SETTINGS_LOCAL_FILE=""
DETECTED_LANGS=""
SELECTED_SECTIONS=()
SECTIONS_ADDED=0
SECTIONS_UPDATED=0
SECTIONS_SKIPPED=0
FILES_CREATED=0
FILES_MODIFIED=0

# ---------------------------------------------------------------------------
# usage — print help and exit
# ---------------------------------------------------------------------------
usage() {
	printf '%s\n' \
		"Usage: ccfg-project-init.sh [options]" \
		"" \
		"Per-project CLAUDE.md setup with language-specific convention sections." \
		"" \
		"Options:" \
		"  --project-dir <path>      Target specific project (default: current directory)" \
		"  --auto                    Auto-detect, apply defaults, no prompts" \
		"  --local                   Scope all detected plugins to project-local settings" \
		"  --local-plugins <list>    Comma-separated plugins to scope locally" \
		"  --dry-run                 Preview changes without writing" \
		"  --update                  Update existing managed sections to latest version" \
		"  --quiet                   Errors and final summary only" \
		"  --verbose                 Show detailed operations" \
		"  -h, --help                Show this help" \
		""
	exit 0
}

# ---------------------------------------------------------------------------
# parse_args — parse CLI flags into global variables
# ---------------------------------------------------------------------------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--project-dir)
			[[ $# -lt 2 ]] && {
				log_error "--project-dir requires a path argument"
				exit 1
			}
			PROJECT_DIR="$2"
			shift 2
			;;
		--auto)
			AUTO_MODE=1
			shift
			;;
		--local)
			LOCAL_MODE=1
			shift
			;;
		--local-plugins)
			[[ $# -lt 2 ]] && {
				log_error "--local-plugins requires a comma-separated list"
				exit 1
			}
			LOCAL_PLUGINS="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--update)
			UPDATE_MODE=1
			shift
			;;
		--quiet)
			QUIET=1
			shift
			;;
		--verbose)
			VERBOSE=1
			shift
			;;
		-h | --help)
			usage
			;;
		*)
			log_error "Unknown option: $1"
			usage
			;;
		esac
	done
}

# ---------------------------------------------------------------------------
# log_quiet — print only when not in quiet mode
# ---------------------------------------------------------------------------
log_quiet() {
	[[ "${QUIET}" -eq 1 ]] && return 0
	printf '%s\n' "$*"
}

# ---------------------------------------------------------------------------
# print_header — styled header with version
# ---------------------------------------------------------------------------
print_header() {
	[[ "${QUIET}" -eq 1 ]] && return 0
	printf '\n  %sccfg project-init%s v%s\n' "${BOLD}" "${RESET}" "${CCFG_VERSION}"
	printf '  %s\n\n' "$(printf '%0.s=' {1..25})"
}

# ---------------------------------------------------------------------------
# resolve_project_dir — resolve target directory and set file paths
# ---------------------------------------------------------------------------
resolve_project_dir() {
	if [[ -z "${PROJECT_DIR}" ]]; then
		PROJECT_DIR="$(pwd)"
	fi

	# Resolve to absolute path
	PROJECT_DIR="$(cd "${PROJECT_DIR}" 2>/dev/null && pwd)" || {
		log_error "Cannot access project directory: ${PROJECT_DIR}"
		return 1
	}

	CLAUDE_MD_FILE="${PROJECT_DIR}/CLAUDE.md"
	SETTINGS_LOCAL_FILE="${PROJECT_DIR}/.claude/settings.local.json"
}

# ---------------------------------------------------------------------------
# map_language_to_section — map detect.sh identifiers to template names
# javascript -> typescript (ccfg-typescript covers both)
# ---------------------------------------------------------------------------
map_language_to_section() {
	local lang="$1"
	case "${lang}" in
	javascript) printf 'typescript' ;;
	*) printf '%s' "${lang}" ;;
	esac
}

# ---------------------------------------------------------------------------
# build_section_list — deduplicate mapped sections into SELECTED_SECTIONS
# ---------------------------------------------------------------------------
build_section_list() {
	local -A seen=()
	local lang section

	for lang in ${DETECTED_LANGS}; do
		section="$(map_language_to_section "${lang}")"
		if [[ -z "${seen[${section}]:-}" ]]; then
			SELECTED_SECTIONS+=("${section}")
			seen["${section}"]=1
		fi
	done
}

# ---------------------------------------------------------------------------
# load_template — read template content from file
# ---------------------------------------------------------------------------
load_template() {
	local section="$1"
	local template_file="${TEMPLATE_DIR}/${section}.md"

	if [[ ! -f "${template_file}" ]]; then
		log_warn "No template found for section: ${section}"
		return 1
	fi

	cat "${template_file}"
}

# ---------------------------------------------------------------------------
# interactive_confirm_sections — prompt user to select/deselect sections
# ---------------------------------------------------------------------------
interactive_confirm_sections() {
	# Skip if not a tty (e.g., invoked from slash command)
	if [[ ! -t 0 ]]; then
		return 0
	fi

	printf '\n  %sSections to add:%s\n' "${BOLD}" "${RESET}"
	local idx=1
	local section
	for section in "${SELECTED_SECTIONS[@]}"; do
		printf '    %s[%d]%s %s\n' "${GREEN}" "${idx}" "${RESET}" "${section}"
		idx=$((idx + 1))
	done

	printf '\n  Press Enter to confirm all, or type numbers to exclude (e.g. 2,4): '
	local input
	read -r input

	if [[ -z "${input}" ]]; then
		return 0
	fi

	# Parse exclusion numbers
	local -a exclude_indices=()
	IFS=',' read -ra exclude_indices <<<"${input}"

	# Build filtered list
	local -a filtered=()
	idx=1
	for section in "${SELECTED_SECTIONS[@]}"; do
		local excluded=0
		local ex
		for ex in "${exclude_indices[@]}"; do
			# Trim whitespace
			ex="$(printf '%s' "${ex}" | tr -d ' ')"
			if [[ "${idx}" == "${ex}" ]]; then
				excluded=1
				break
			fi
		done
		if [[ "${excluded}" -eq 0 ]]; then
			filtered+=("${section}")
		fi
		idx=$((idx + 1))
	done

	SELECTED_SECTIONS=("${filtered[@]}")
}

# ---------------------------------------------------------------------------
# process_sections — load templates and update/create managed sections
# ---------------------------------------------------------------------------
process_sections() {
	local section content

	for section in "${SELECTED_SECTIONS[@]}"; do
		content="$(load_template "${section}")" || {
			SECTIONS_SKIPPED=$((SECTIONS_SKIPPED + 1))
			continue
		}

		[[ "${VERBOSE}" -eq 1 ]] && log_info "Loading template: ${TEMPLATE_DIR}/${section}.md"

		if [[ "${DRY_RUN}" -eq 1 ]]; then
			log_quiet "    ${CYAN}+ ${section} section (v${CCFG_VERSION}) [dry-run]${RESET}"
			continue
		fi

		# Check current state for summary reporting and --update gating
		if claude_md_has_section "${CLAUDE_MD_FILE}" "${section}"; then
			if [[ "${UPDATE_MODE}" -eq 0 ]]; then
				# Without --update: skip existing sections entirely
				SECTIONS_SKIPPED=$((SECTIONS_SKIPPED + 1))
				[[ "${VERBOSE}" -eq 1 ]] && log_info "Skipping existing section: ${section} (use --update to refresh)"
				continue
			fi
			local current_version
			current_version="$(claude_md_get_version "${CLAUDE_MD_FILE}" "${section}")"
			if [[ "${current_version}" == "v${CCFG_VERSION}" ]]; then
				SECTIONS_SKIPPED=$((SECTIONS_SKIPPED + 1))
			else
				SECTIONS_UPDATED=$((SECTIONS_UPDATED + 1))
			fi
		else
			SECTIONS_ADDED=$((SECTIONS_ADDED + 1))
		fi

		# Delegate to claude-md.sh (handles insert/update/skip)
		claude_md_update_section "${CLAUDE_MD_FILE}" "${section}" "${content}" "v${CCFG_VERSION}"
	done
}

# ---------------------------------------------------------------------------
# handle_local_settings — create/update .claude/settings.local.json
# ---------------------------------------------------------------------------
handle_local_settings() {
	[[ "${LOCAL_MODE}" -eq 0 && -z "${LOCAL_PLUGINS}" ]] && return 0

	local settings_dir
	settings_dir="$(dirname "${SETTINGS_LOCAL_FILE}")"

	# Create .claude/ directory if needed
	if [[ ! -d "${settings_dir}" ]]; then
		if [[ "${DRY_RUN}" -eq 0 ]]; then
			mkdir -p "${settings_dir}"
		fi
	fi

	# Initialize settings.local.json if absent
	if [[ ! -f "${SETTINGS_LOCAL_FILE}" ]]; then
		if [[ "${DRY_RUN}" -eq 0 ]]; then
			printf '{}\n' >"${SETTINGS_LOCAL_FILE}"
			FILES_CREATED=$((FILES_CREATED + 1))
		fi
	fi

	# Build plugin JSON object
	local plugins_json="{}"
	if [[ "${LOCAL_MODE}" -eq 1 ]]; then
		# All detected plugins go local
		local section
		for section in "${SELECTED_SECTIONS[@]}"; do
			plugins_json="$(printf '%s' "${plugins_json}" | jq --arg p "ccfg-${section}@claude-config" '. + {($p): true}')"
		done
	elif [[ -n "${LOCAL_PLUGINS}" ]]; then
		# Only specified plugins go local
		local -a local_list=()
		IFS=',' read -ra local_list <<<"${LOCAL_PLUGINS}"
		local p
		for p in "${local_list[@]}"; do
			p="$(printf '%s' "${p}" | tr -d ' ')"
			plugins_json="$(printf '%s' "${plugins_json}" | jq --arg p "ccfg-${p}@claude-config" '. + {($p): true}')"
		done
	fi

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		log_quiet ""
		log_quiet "  ${BOLD}Local Settings${RESET}  ${SETTINGS_LOCAL_FILE} [dry-run]"
		log_quiet "    ${CYAN}+ enabledPlugins:${RESET}"
		printf '%s' "${plugins_json}" | jq -r 'keys[]' | while IFS= read -r key; do
			log_quiet "      ${DOT} ${key}"
		done
		return 0
	fi

	# Backup existing settings.local.json before modification
	if [[ -f "${SETTINGS_LOCAL_FILE}" ]] && [[ "$(cat "${SETTINGS_LOCAL_FILE}")" != "{}" ]]; then
		backup_create "${SETTINGS_LOCAL_FILE}" >/dev/null
	fi

	settings_merge_plugins "${SETTINGS_LOCAL_FILE}" "${plugins_json}"

	log_quiet ""
	log_quiet "  ${BOLD}Local Settings${RESET}  ${SETTINGS_LOCAL_FILE}"
	printf '%s' "${plugins_json}" | jq -r 'keys[]' | while IFS= read -r key; do
		log_quiet "    ${GREEN}${CHECK}${RESET} ${key}"
	done
}

# ---------------------------------------------------------------------------
# print_summary — final output with counts
# ---------------------------------------------------------------------------
print_summary() {
	[[ "${QUIET}" -eq 1 && "${SECTIONS_ADDED}" -eq 0 && "${SECTIONS_UPDATED}" -eq 0 ]] && return 0

	local total_changes=$((SECTIONS_ADDED + SECTIONS_UPDATED))

	log_quiet ""
	log_quiet "  $(printf '%0.s─' {1..22})"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		log_quiet "  ${BOLD}Dry run complete.${RESET} No files modified."
	elif [[ "${total_changes}" -eq 0 && "${FILES_CREATED}" -eq 0 ]]; then
		log_quiet "  ${BOLD}Already up to date.${RESET} No changes needed."
	else
		local file_count=$((FILES_CREATED + FILES_MODIFIED))
		log_quiet "  ${BOLD}Done.${RESET} ${file_count} file(s) touched, ${SECTIONS_ADDED} section(s) added, ${SECTIONS_UPDATED} updated, ${SECTIONS_SKIPPED} unchanged."
	fi
	log_quiet ""
}

# ---------------------------------------------------------------------------
# cleanup — trap handler for error recovery
# ---------------------------------------------------------------------------
cleanup() {
	local exit_code=$?
	if [[ ${exit_code} -ne 0 ]]; then
		log_error "project-init failed. Your original files are preserved."
		if [[ -n "${CLAUDE_MD_FILE:-}" && -f "${CLAUDE_MD_FILE}" ]]; then
			log_error "Run: $(basename "${BASH_SOURCE[0]}") --project-dir '$(dirname "${CLAUDE_MD_FILE}")' to retry."
		fi
	fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# main — orchestrate the full flow
# ---------------------------------------------------------------------------
main() {
	parse_args "$@"

	# Preflight checks
	preflight_check || exit 1

	# Header
	print_header

	# Resolve project directory
	resolve_project_dir || exit 1
	log_quiet "  ${BOLD}Project${RESET}  ${PROJECT_DIR}"

	# Detect languages
	DETECTED_LANGS="$(detect_languages "${PROJECT_DIR}")"

	if [[ -z "${DETECTED_LANGS}" ]]; then
		log_quiet ""
		log_info "No languages or technologies detected in: ${PROJECT_DIR}"
		log_info "Nothing to do."
		exit 0
	fi

	# Display detection results
	log_quiet ""
	detect_summary "${PROJECT_DIR}"

	# Build deduplicated section list
	build_section_list

	# Interactive confirmation (skipped in --auto mode or non-tty)
	if [[ "${AUTO_MODE}" -eq 0 ]]; then
		interactive_confirm_sections
	fi

	# No sections selected
	if [[ "${#SELECTED_SECTIONS[@]}" -eq 0 ]]; then
		log_info "No sections selected. Nothing to do."
		exit 0
	fi

	# CLAUDE.md operations
	log_quiet ""
	log_quiet "  ${BOLD}CLAUDE.md${RESET}  ${CLAUDE_MD_FILE}"

	# Backup existing CLAUDE.md before modification
	if [[ -f "${CLAUDE_MD_FILE}" && "${DRY_RUN}" -eq 0 ]]; then
		backup_create "${CLAUDE_MD_FILE}" >/dev/null
		FILES_MODIFIED=1
	fi

	# Create CLAUDE.md if it doesn't exist
	if [[ ! -f "${CLAUDE_MD_FILE}" && "${DRY_RUN}" -eq 0 ]]; then
		printf '## User Customizations\n\nAdd your project-specific conventions below.\n' >"${CLAUDE_MD_FILE}"
		FILES_CREATED=1
	fi

	# Process sections (add/update managed content)
	process_sections

	# Validate marker balance
	if [[ "${DRY_RUN}" -eq 0 && -f "${CLAUDE_MD_FILE}" ]]; then
		claude_md_validate "${CLAUDE_MD_FILE}" || {
			log_error "Marker validation failed after update"
		}
	fi

	# Handle local settings if requested
	handle_local_settings

	# Prune old backups
	if [[ "${DRY_RUN}" -eq 0 ]]; then
		backup_prune "${CLAUDE_MD_FILE}" >/dev/null 2>&1 || true
	fi

	# Summary
	print_summary
}

main "$@"
