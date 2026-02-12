#!/usr/bin/env bash
# ccfg-bootstrap.sh — First-time global setup for ccfg plugin marketplace.
# Configures ~/.claude/settings.json (permissions, plugins, thinking) and
# creates ~/.claude/CLAUDE.md with user-level best practices.
#
# Usage:
#   ccfg-bootstrap.sh [options]
#   ccfg-bootstrap.sh --auto
#   ccfg-bootstrap.sh --plugins core,python,docker
#
# See docs/BOOTSTRAP.md for full specification.

set -euo pipefail

# Resolve script directory (follows symlinks via BASH_SOURCE)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$(cd "${SCRIPT_DIR}/../plugins" 2>/dev/null && pwd)" || {
	echo "ERROR: plugins/ directory not found relative to bootstrap script" >&2
	exit 1
}

# Source shared libraries
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/detect.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/settings.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/claude-md.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/backup.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MARKETPLACE_NAME="claude-config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
USER_CLAUDE_TEMPLATE="${TEMPLATE_DIR}/user-claude.md"

SETTINGS_FILE="${HOME}/.claude/settings.json"
CLAUDE_MD_FILE="${HOME}/.claude/CLAUDE.md"

# All available ccfg plugins (directory names under plugins/)
ALL_PLUGINS=(
	ccfg-core
	ccfg-python
	ccfg-golang
	ccfg-typescript
	ccfg-java
	ccfg-rust
	ccfg-csharp
	ccfg-shell
	ccfg-mysql
	ccfg-postgresql
	ccfg-mongodb
	ccfg-redis
	ccfg-sqlite
	ccfg-docker
	ccfg-github-actions
	ccfg-kubernetes
	ccfg-markdown
)

# Map from detect.sh identifiers to plugin names
declare -A LANG_TO_PLUGIN=(
	[python]=ccfg-python
	[golang]=ccfg-golang
	[typescript]=ccfg-typescript
	[javascript]=ccfg-typescript
	[java]=ccfg-java
	[rust]=ccfg-rust
	[csharp]=ccfg-csharp
	[shell]=ccfg-shell
	[mysql]=ccfg-mysql
	[postgresql]=ccfg-postgresql
	[mongodb]=ccfg-mongodb
	[redis]=ccfg-redis
	[sqlite]=ccfg-sqlite
	[docker]=ccfg-docker
	["github-actions"]=ccfg-github-actions
	[kubernetes]=ccfg-kubernetes
	[markdown]=ccfg-markdown
)

# ---------------------------------------------------------------------------
# CLI flags (set by parse_args)
# ---------------------------------------------------------------------------
AUTO_MODE=0
EXPLICIT_PLUGINS=""
SKIP_SETTINGS=0
SKIP_CLAUDE_MD=0
DRY_RUN=0
DIFF_MODE=0
ROLLBACK_MODE=0
UPDATE_MODE=0
STATUS_MODE=0
QUIET=0
VERBOSE=0

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
declare -a SELECTED_PLUGINS=()
CLAUDE_MD_CREATED=0
CLAUDE_MD_UPDATED=0
SETTINGS_CHANGED=0
ERRORS=0

# ---------------------------------------------------------------------------
# usage — print help and exit
# ---------------------------------------------------------------------------
usage() {
	printf '%s\n' \
		"Usage: ccfg-bootstrap.sh [options]" \
		"" \
		"First-time global setup for the ccfg plugin marketplace." \
		"Configures ~/.claude/settings.json and creates ~/.claude/CLAUDE.md." \
		"" \
		"Options:" \
		"  --auto                    Auto-detect, apply defaults, no prompts" \
		"  --plugins <list>          Comma-separated plugins to enable (e.g. core,python,docker)" \
		"  --skip-settings           Only manage CLAUDE.md, skip settings.json" \
		"  --skip-claude-md          Only manage settings.json, skip CLAUDE.md" \
		"  --dry-run                 Preview all changes, apply nothing" \
		"  --diff                    Show diff of what would change" \
		"  --rollback                Restore from most recent backup" \
		"  --update                  Update managed sections to latest version" \
		"  --status                  Show what's currently managed" \
		"  --quiet                   Errors and final summary only" \
		"  --verbose                 Show jq commands and diff output" \
		"  -h, --help                Show this help" \
		""
	exit 0
}

# ---------------------------------------------------------------------------
# parse_args — parse CLI flags
# ---------------------------------------------------------------------------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--auto)
			AUTO_MODE=1
			shift
			;;
		--plugins)
			[[ $# -lt 2 ]] && {
				log_error "--plugins requires a comma-separated list"
				exit 1
			}
			EXPLICIT_PLUGINS="$2"
			shift 2
			;;
		--skip-settings)
			SKIP_SETTINGS=1
			shift
			;;
		--skip-claude-md)
			SKIP_CLAUDE_MD=1
			shift
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--diff)
			DIFF_MODE=1
			DRY_RUN=1
			shift
			;;
		--rollback)
			ROLLBACK_MODE=1
			shift
			;;
		--update)
			UPDATE_MODE=1
			shift
			;;
		--status)
			STATUS_MODE=1
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
	printf '\n  %sccfg bootstrap%s v%s\n' "${BOLD}" "${RESET}" "${CCFG_VERSION}"
	printf '  %s\n\n' "$(printf '%0.s=' {1..22})"
}

# ---------------------------------------------------------------------------
# print_preflight — show preflight results
# ---------------------------------------------------------------------------
print_preflight() {
	[[ "${QUIET}" -eq 1 ]] && return 0

	local os arch bash_ver jq_ver
	os="$(detect_os)"
	arch="$(detect_arch)"
	bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
	jq_ver="$(jq --version 2>/dev/null | sed 's/jq-//')"

	printf '  %sPreflight%s\n' "${BOLD}" "${RESET}"
	printf '    %s%s%s bash %s     %s%s%s jq %s     %s%s%s %s %s\n' \
		"${GREEN}" "${CHECK}" "${RESET}" "${bash_ver}" \
		"${GREEN}" "${CHECK}" "${RESET}" "${jq_ver}" \
		"${GREEN}" "${CHECK}" "${RESET}" "${os}" "${arch}"

	if [[ -f "${SETTINGS_FILE}" ]]; then
		printf '    %s%s%s %s found\n' "${GREEN}" "${CHECK}" "${RESET}" "${SETTINGS_FILE}"
	else
		printf '    %s%s%s %s not found (will create)\n' "${YELLOW}" "${DOT}" "${RESET}" "${SETTINGS_FILE}"
	fi
	printf '\n'
}

# ---------------------------------------------------------------------------
# handle_rollback — restore from most recent backup
# ---------------------------------------------------------------------------
handle_rollback() {
	log_quiet ""
	log_quiet "  ${BOLD}Rollback${RESET}"

	if [[ "${SKIP_SETTINGS}" -eq 0 ]]; then
		log_quiet "  ${ARROW} settings.json:"
		if backup_rollback "${SETTINGS_FILE}"; then
			log_quiet "    ${GREEN}${CHECK}${RESET} Restored"
		else
			log_quiet "    ${YELLOW}${DOT}${RESET} No backup available"
		fi
	fi

	if [[ "${SKIP_CLAUDE_MD}" -eq 0 ]]; then
		log_quiet "  ${ARROW} CLAUDE.md:"
		if backup_rollback "${CLAUDE_MD_FILE}"; then
			log_quiet "    ${GREEN}${CHECK}${RESET} Restored"
		else
			log_quiet "    ${YELLOW}${DOT}${RESET} No backup available"
		fi
	fi

	log_quiet ""
}

# ---------------------------------------------------------------------------
# handle_status — show current managed state
# ---------------------------------------------------------------------------
handle_status() {
	log_quiet ""
	log_quiet "  ${BOLD}Status${RESET}"
	log_quiet ""

	# Settings
	log_quiet "  ${BOLD}Settings${RESET}  ${SETTINGS_FILE}"
	if [[ -f "${SETTINGS_FILE}" ]]; then
		local enabled_count perm_count thinking
		enabled_count="$(jq '.enabledPlugins // {} | keys | length' "${SETTINGS_FILE}" 2>/dev/null || printf '0')"
		perm_count="$(jq '.permissions.allow // [] | length' "${SETTINGS_FILE}" 2>/dev/null || printf '0')"
		thinking="$(jq '.alwaysThinkingEnabled // "not set"' "${SETTINGS_FILE}" 2>/dev/null || printf 'unknown')"

		log_quiet "    ${DOT} enabledPlugins: ${enabled_count} entries"
		log_quiet "    ${DOT} permissions.allow: ${perm_count} entries"
		log_quiet "    ${DOT} alwaysThinkingEnabled: ${thinking}"

		# Show ccfg-specific plugins
		local ccfg_plugins
		ccfg_plugins="$(jq -r '.enabledPlugins // {} | keys[] | select(contains("@claude-config"))' "${SETTINGS_FILE}" 2>/dev/null)"
		if [[ -n "${ccfg_plugins}" ]]; then
			log_quiet ""
			log_quiet "    ${BOLD}ccfg plugins:${RESET}"
			while IFS= read -r p; do
				log_quiet "      ${GREEN}${CHECK}${RESET} ${p}"
			done <<<"${ccfg_plugins}"
		fi
	else
		log_quiet "    ${YELLOW}${DOT}${RESET} File not found"
	fi

	log_quiet ""

	# CLAUDE.md
	log_quiet "  ${BOLD}CLAUDE.md${RESET}  ${CLAUDE_MD_FILE}"
	if [[ -f "${CLAUDE_MD_FILE}" ]]; then
		if claude_md_has_section "${CLAUDE_MD_FILE}" "best-practices"; then
			local ver
			ver="$(claude_md_get_version "${CLAUDE_MD_FILE}" "best-practices")"
			log_quiet "    ${GREEN}${CHECK}${RESET} best-practices section (${ver})"
		else
			log_quiet "    ${YELLOW}${DOT}${RESET} No managed sections"
		fi
	else
		log_quiet "    ${YELLOW}${DOT}${RESET} File not found"
	fi

	log_quiet ""

	# Backups
	log_quiet "  ${BOLD}Backups${RESET}  ${HOME}/.claude/backups/"
	backup_list "${SETTINGS_FILE}" 2>/dev/null || true
	backup_list "${CLAUDE_MD_FILE}" 2>/dev/null || true
	log_quiet ""
}

# ---------------------------------------------------------------------------
# select_plugins — determine which plugins to enable
# ---------------------------------------------------------------------------
select_plugins() {
	# ccfg-core is always included
	SELECTED_PLUGINS=("ccfg-core")

	if [[ -n "${EXPLICIT_PLUGINS}" ]]; then
		# Explicit list from --plugins flag
		local -a explicit_list=()
		IFS=',' read -ra explicit_list <<<"${EXPLICIT_PLUGINS}"
		local p
		for p in "${explicit_list[@]}"; do
			p="$(printf '%s' "${p}" | tr -d ' ')"
			# Normalize: add ccfg- prefix if missing
			[[ "${p}" != ccfg-* ]] && p="ccfg-${p}"
			# Skip if already in list (core)
			[[ "${p}" == "ccfg-core" ]] && continue
			# Validate plugin exists
			if [[ -d "${PLUGINS_DIR}/${p}" ]]; then
				SELECTED_PLUGINS+=("${p}")
			else
				log_warn "Unknown plugin: ${p} (skipped)"
			fi
		done
		return 0
	fi

	# Auto-detect from current directory
	local detected
	detected="$(detect_languages ".")"

	# Map detected languages to plugins (deduplicate)
	local -A seen=()
	seen["ccfg-core"]=1
	local lang plugin
	for lang in ${detected}; do
		plugin="${LANG_TO_PLUGIN[${lang}]:-}"
		if [[ -n "${plugin}" && -z "${seen[${plugin}]:-}" ]]; then
			SELECTED_PLUGINS+=("${plugin}")
			seen["${plugin}"]=1
		fi
	done

	if [[ "${AUTO_MODE}" -eq 1 ]]; then
		return 0
	fi

	# Interactive selection
	if [[ -t 0 ]]; then
		_interactive_plugin_selection "${detected}"
	fi
}

# ---------------------------------------------------------------------------
# _interactive_plugin_selection — prompt user to enable additional plugins
# ---------------------------------------------------------------------------
_interactive_plugin_selection() {
	local detected="$1"

	log_quiet "  ${BOLD}Plugin Selection${RESET}"

	# Show always-included
	log_quiet "    ${GREEN}${CHECK}${RESET} ccfg-core            ${DIM}(always included)${RESET}"

	# Show auto-detected (excluding core)
	local p
	for p in "${SELECTED_PLUGINS[@]}"; do
		[[ "${p}" == "ccfg-core" ]] && continue
		local lang_trigger=""
		for lang in ${detected}; do
			if [[ "${LANG_TO_PLUGIN[${lang}]:-}" == "${p}" ]]; then
				lang_trigger="${lang}"
				break
			fi
		done
		log_quiet "    ${GREEN}${CHECK}${RESET} $(printf '%-20s' "${p}") ${DIM}(${lang_trigger} detected)${RESET}"
	done

	# Show available but not selected
	local -a available=()
	for p in "${ALL_PLUGINS[@]}"; do
		[[ "${p}" == "ccfg-core" ]] && continue
		local already=0
		local sel
		for sel in "${SELECTED_PLUGINS[@]}"; do
			[[ "${sel}" == "${p}" ]] && {
				already=1
				break
			}
		done
		[[ "${already}" -eq 0 ]] && available+=("${p}")
	done

	if [[ "${#available[@]}" -gt 0 ]]; then
		local line=""
		local count=0
		for p in "${available[@]}"; do
			line+="$(printf '%-20s' "${p}")"
			count=$((count + 1))
			if [[ $((count % 3)) -eq 0 ]]; then
				log_quiet "    ${DOT} ${line}"
				line=""
			fi
		done
		[[ -n "${line}" ]] && log_quiet "    ${DOT} ${line}"
	fi

	log_quiet ""
	printf '    Enable additional? [comma-separated or Enter to skip]: '
	local input
	read -r input

	if [[ -n "${input}" ]]; then
		local -a extras=()
		IFS=',' read -ra extras <<<"${input}"
		local ex
		for ex in "${extras[@]}"; do
			ex="$(printf '%s' "${ex}" | tr -d ' ')"
			[[ "${ex}" != ccfg-* ]] && ex="ccfg-${ex}"
			if [[ -d "${PLUGINS_DIR}/${ex}" ]]; then
				SELECTED_PLUGINS+=("${ex}")
			else
				log_warn "Unknown plugin: ${ex} (skipped)"
			fi
		done
	fi

	log_quiet ""
}

# ---------------------------------------------------------------------------
# collect_permissions — gather permissions from all selected plugins
# ---------------------------------------------------------------------------
collect_permissions() {
	local all_perms="[]"
	local p
	for p in "${SELECTED_PLUGINS[@]}"; do
		local plugin_perms
		plugin_perms="$(settings_read_plugin_permissions "${PLUGINS_DIR}/${p}")"
		all_perms="$(printf '%s' "${all_perms}" | jq --argjson new "${plugin_perms}" '. + $new | unique')"
	done
	printf '%s' "${all_perms}"
}

# ---------------------------------------------------------------------------
# build_plugins_json — build enabledPlugins object for selected plugins
# ---------------------------------------------------------------------------
build_plugins_json() {
	local plugins_json="{}"
	local p
	for p in "${SELECTED_PLUGINS[@]}"; do
		plugins_json="$(printf '%s' "${plugins_json}" | jq --arg k "${p}@${MARKETPLACE_NAME}" '. + {($k): true}')"
	done
	printf '%s' "${plugins_json}"
}

# ---------------------------------------------------------------------------
# merge_settings — merge permissions, plugins, and thinking into settings.json
# ---------------------------------------------------------------------------
merge_settings() {
	[[ "${SKIP_SETTINGS}" -eq 1 ]] && return 0

	log_quiet "  ${BOLD}Settings${RESET}  ${SETTINGS_FILE}"

	# Initialize settings.json if absent
	if [[ ! -f "${SETTINGS_FILE}" ]]; then
		if [[ "${DRY_RUN}" -eq 0 ]]; then
			mkdir -p "$(dirname "${SETTINGS_FILE}")"
			printf '{}\n' >"${SETTINGS_FILE}"
		fi
		log_quiet "    ${GREEN}${CHECK}${RESET} Created ${SETTINGS_FILE}"
	fi

	# Backup before modification
	if [[ "${DRY_RUN}" -eq 0 && -f "${SETTINGS_FILE}" ]]; then
		local backup_path
		backup_path="$(backup_create "${SETTINGS_FILE}")"
		if [[ "${VERBOSE}" -eq 1 && -n "${backup_path}" ]]; then
			log_quiet "    ${DIM}${ARROW} Backup: ${backup_path}${RESET}"
		fi
	fi

	# Collect permissions
	local all_perms
	all_perms="$(collect_permissions)"
	local perm_count
	perm_count="$(printf '%s' "${all_perms}" | jq 'length')"

	# Build plugins object
	local plugins_json
	plugins_json="$(build_plugins_json)"
	local plugin_count
	plugin_count="$(printf '%s' "${plugins_json}" | jq 'keys | length')"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		# Show what would change
		local p
		for p in "${SELECTED_PLUGINS[@]}"; do
			log_quiet "    ${CYAN}+ enabledPlugins${RESET}  ${p}@${MARKETPLACE_NAME}"
		done
		if [[ "${perm_count}" -gt 0 ]]; then
			local shown=0
			local perm
			while IFS= read -r perm; do
				shown=$((shown + 1))
				if [[ "${shown}" -le 3 ]]; then
					log_quiet "    ${CYAN}+ permissions${RESET}     ${perm}"
				fi
			done < <(printf '%s' "${all_perms}" | jq -r '.[]')
			local remaining=$((perm_count - 3))
			if [[ "${remaining}" -gt 0 ]]; then
				log_quiet "    ${CYAN}+ permissions${RESET}     +${remaining} more"
			fi
		fi
		log_quiet "    ${CYAN}~ alwaysThinkingEnabled${RESET}  true (if not set)"

		# Show diff if requested
		if [[ "${DIFF_MODE}" -eq 1 && -f "${SETTINGS_FILE}" ]]; then
			log_quiet ""
			log_quiet "  ${BOLD}Diff preview:${RESET}"
			local current merged tmpfile
			current="$(jq '.' "${SETTINGS_FILE}")"
			merged="$(printf '%s' "${current}" |
				jq --argjson perms "${all_perms}" --argjson plugins "${plugins_json}" \
					'.permissions.allow = ((.permissions.allow // []) + $perms | unique) |
                     .enabledPlugins = ((.enabledPlugins // {}) + $plugins) |
                     .alwaysThinkingEnabled //= true')"
			tmpfile="$(mktemp)"
			printf '%s\n' "${merged}" >"${tmpfile}"
			diff -u --label "current" --label "proposed" \
				<(jq --sort-keys '.' "${SETTINGS_FILE}") \
				<(jq --sort-keys '.' "${tmpfile}") || true
			rm -f "${tmpfile}"
		fi
		return 0
	fi

	# Merge permissions
	if [[ "${perm_count}" -gt 0 ]]; then
		[[ "${VERBOSE}" -eq 1 ]] && log_info "Merging ${perm_count} permissions into settings.json"
		settings_merge_permissions "${SETTINGS_FILE}" "${all_perms}"
	fi

	# Merge plugins
	[[ "${VERBOSE}" -eq 1 ]] && log_info "Merging ${plugin_count} plugin entries into settings.json"
	settings_merge_plugins "${SETTINGS_FILE}" "${plugins_json}"

	# Set thinking
	local current_thinking
	current_thinking="$(jq '.alwaysThinkingEnabled // null' "${SETTINGS_FILE}" 2>/dev/null)"
	settings_set_thinking "${SETTINGS_FILE}"

	SETTINGS_CHANGED=1

	# Report
	local p
	for p in "${SELECTED_PLUGINS[@]}"; do
		log_quiet "    ${GREEN}${CHECK}${RESET} enabledPlugins  ${p}@${MARKETPLACE_NAME}"
	done
	if [[ "${perm_count}" -gt 0 ]]; then
		log_quiet "    ${GREEN}${CHECK}${RESET} permissions     ${perm_count} entries merged"
	fi
	if [[ "${current_thinking}" == "null" ]]; then
		log_quiet "    ${GREEN}${CHECK}${RESET} alwaysThinkingEnabled  set to true"
	else
		log_quiet "    ${YELLOW}${DOT}${RESET} alwaysThinkingEnabled  already ${current_thinking}"
	fi
}

# ---------------------------------------------------------------------------
# manage_claude_md — create or update ~/.claude/CLAUDE.md
# ---------------------------------------------------------------------------
manage_claude_md() {
	[[ "${SKIP_CLAUDE_MD}" -eq 1 ]] && return 0

	log_quiet ""
	log_quiet "  ${BOLD}CLAUDE.md${RESET}  ${CLAUDE_MD_FILE}"

	# Load template content
	if [[ ! -f "${USER_CLAUDE_TEMPLATE}" ]]; then
		log_error "Template not found: ${USER_CLAUDE_TEMPLATE}"
		ERRORS=$((ERRORS + 1))
		return 1
	fi

	local template_content
	template_content="$(cat "${USER_CLAUDE_TEMPLATE}")"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		if [[ -f "${CLAUDE_MD_FILE}" ]]; then
			if claude_md_has_section "${CLAUDE_MD_FILE}" "best-practices"; then
				local ver
				ver="$(claude_md_get_version "${CLAUDE_MD_FILE}" "best-practices")"
				if [[ "${ver}" == "v${CCFG_VERSION}" ]]; then
					log_quiet "    ${YELLOW}${DOT}${RESET} best-practices section already at v${CCFG_VERSION}"
				else
					log_quiet "    ${CYAN}~ best-practices section${RESET} (${ver} ${ARROW} v${CCFG_VERSION}) [dry-run]"
				fi
			else
				log_quiet "    ${CYAN}+ best-practices section${RESET} (v${CCFG_VERSION}) [dry-run]"
			fi
		else
			log_quiet "    ${CYAN}+ created${RESET}  best-practices section (v${CCFG_VERSION}) [dry-run]"
		fi
		return 0
	fi

	# Backup existing file
	if [[ -f "${CLAUDE_MD_FILE}" ]]; then
		local backup_path
		backup_path="$(backup_create "${CLAUDE_MD_FILE}")"
		if [[ "${VERBOSE}" -eq 1 && -n "${backup_path}" ]]; then
			log_quiet "    ${DIM}${ARROW} Backup: ${backup_path}${RESET}"
		fi
	fi

	if [[ ! -f "${CLAUDE_MD_FILE}" ]]; then
		# Create new file with managed section
		local section_data="best-practices|v${CCFG_VERSION}|${template_content}"
		claude_md_create "${CLAUDE_MD_FILE}" "${section_data}"
		CLAUDE_MD_CREATED=1
		log_quiet "    ${GREEN}${CHECK}${RESET} created  best-practices section (v${CCFG_VERSION})"
	else
		# Update existing file
		if claude_md_has_section "${CLAUDE_MD_FILE}" "best-practices"; then
			local current_version
			current_version="$(claude_md_get_version "${CLAUDE_MD_FILE}" "best-practices")"
			if [[ "${current_version}" == "v${CCFG_VERSION}" && "${UPDATE_MODE}" -eq 0 ]]; then
				log_quiet "    ${YELLOW}${DOT}${RESET} best-practices section already at v${CCFG_VERSION}"
				return 0
			fi
		fi
		claude_md_update_section "${CLAUDE_MD_FILE}" "best-practices" "${template_content}" "v${CCFG_VERSION}"
		CLAUDE_MD_UPDATED=1

		# Validate markers
		if ! claude_md_validate "${CLAUDE_MD_FILE}" 2>/dev/null; then
			log_error "Marker validation failed after update"
			ERRORS=$((ERRORS + 1))
		fi
	fi
}

# ---------------------------------------------------------------------------
# offer_symlinks — suggest convenience symlinks
# ---------------------------------------------------------------------------
offer_symlinks() {
	[[ "${QUIET}" -eq 1 || "${DRY_RUN}" -eq 1 ]] && return 0

	local bin_dir="${HOME}/.local/bin"

	# Only offer if directory exists and scripts aren't already linked
	if [[ -d "${bin_dir}" ]]; then
		local needs_link=0
		local script
		for script in ccfg-bootstrap ccfg-project-init ccfg-plugins; do
			if [[ ! -L "${bin_dir}/${script}" ]]; then
				needs_link=1
				break
			fi
		done

		if [[ "${needs_link}" -eq 1 && "${AUTO_MODE}" -eq 0 && -t 0 ]]; then
			log_quiet ""
			log_quiet "  ${BOLD}Convenience Symlinks${RESET}"
			log_quiet "    Add to ${bin_dir}? [y/N]: "
			local answer
			read -r answer
			if [[ "${answer}" =~ ^[Yy] ]]; then
				for script in ccfg-bootstrap ccfg-project-init ccfg-plugins; do
					local src="${SCRIPT_DIR}/${script}.sh"
					local dst="${bin_dir}/${script}"
					if [[ -f "${src}" && ! -L "${dst}" ]]; then
						if ln -s "${src}" "${dst}" 2>/dev/null; then
							log_quiet "    ${GREEN}${CHECK}${RESET} ${dst}"
						else
							log_quiet "    ${YELLOW}${DOT}${RESET} Failed: ${dst}"
						fi
					fi
				done
			fi
		fi
	fi
}

# ---------------------------------------------------------------------------
# print_summary — final output with counts
# ---------------------------------------------------------------------------
print_summary() {
	log_quiet ""
	log_quiet "  $(printf '%0.s─' {1..22})"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		log_quiet "  ${BOLD}Dry run complete.${RESET} No files modified."
	else
		local files_updated=0
		[[ "${SETTINGS_CHANGED}" -eq 1 ]] && files_updated=$((files_updated + 1))
		[[ "${CLAUDE_MD_CREATED}" -eq 1 || "${CLAUDE_MD_UPDATED}" -eq 1 ]] && files_updated=$((files_updated + 1))

		log_quiet "  ${BOLD}Done.${RESET} ${files_updated} file(s) updated, ${ERRORS} error(s)."
	fi

	# Prune old backups silently
	if [[ "${DRY_RUN}" -eq 0 ]]; then
		backup_prune "${SETTINGS_FILE}" >/dev/null 2>&1 || true
		backup_prune "${CLAUDE_MD_FILE}" >/dev/null 2>&1 || true
	fi

	log_quiet ""
}

# ---------------------------------------------------------------------------
# cleanup — trap handler for error recovery
# ---------------------------------------------------------------------------
cleanup() {
	local exit_code=$?
	if [[ ${exit_code} -ne 0 ]]; then
		log_error "Bootstrap failed. Your original files are preserved."
		log_error "Run with --rollback to restore from backup."
	fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# main — orchestrate the full bootstrap flow
# ---------------------------------------------------------------------------
main() {
	parse_args "$@"

	# Preflight checks
	preflight_check || exit 1

	# Header
	print_header

	# Handle special modes early
	if [[ "${ROLLBACK_MODE}" -eq 1 ]]; then
		handle_rollback
		exit 0
	fi

	if [[ "${STATUS_MODE}" -eq 1 ]]; then
		handle_status
		exit 0
	fi

	# Preflight display
	print_preflight

	# Plugin selection
	select_plugins

	if [[ "${#SELECTED_PLUGINS[@]}" -eq 0 ]]; then
		log_error "No plugins selected. Nothing to do."
		exit 1
	fi

	# Settings merge
	merge_settings

	# CLAUDE.md management
	manage_claude_md

	# Offer symlinks (interactive only)
	offer_symlinks

	# Summary
	print_summary
}

main "$@"
