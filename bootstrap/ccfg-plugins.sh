#!/usr/bin/env bash
# ccfg-plugins.sh — Third-party plugin recommendation and installation.
# Detects project languages, looks up recommended plugins from the curated
# registry, presents recommendations interactively, installs selected plugins
# via `claude plugin install`, and updates enabledPlugins in settings.json.
#
# Usage:
#   ccfg-plugins.sh [options]
#   ccfg-plugins.sh --auto
#   ccfg-plugins.sh --list
#   ccfg-plugins.sh --category lsp --dry-run
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
source "${SCRIPT_DIR}/lib/settings.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/registry.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SETTINGS_FILE="${HOME}/.claude/settings.json"

# Valid categories (for --category validation)
VALID_CATEGORIES="lsp general integration skills issue-tracking style"

# ---------------------------------------------------------------------------
# CLI flags (set by parse_args)
# ---------------------------------------------------------------------------
AUTO_MODE=0
LIST_MODE=0
CATEGORY_FILTER=""
DRY_RUN=0
QUIET=0
VERBOSE=0
PROJECT_DIR=""

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
declare -a DETECTED_LANGS=()
declare -a AUTO_KEYS=()
declare -a SUGGEST_KEYS=()
declare -a SELECTED_KEYS=()
declare -a INSTALLED_KEYS=()
declare -a FAILED_KEYS=()
declare -A LSP_CHOICES=()
ERRORS=0
SETTINGS_CHANGED=0

# ---------------------------------------------------------------------------
# usage — print help and exit
# ---------------------------------------------------------------------------
usage() {
	printf '%s\n' \
		"Usage: ccfg-plugins.sh [options]" \
		"" \
		"Third-party plugin recommendation and installation." \
		"Detects project languages, recommends plugins from the curated registry," \
		"and installs selected plugins via Claude Code's plugin system." \
		"" \
		"Options:" \
		"  --auto                    Install auto-tier only, no prompts" \
		"  --list                    Show full registry without installing" \
		"  --category <cat>          Filter by category (lsp, general, integration, etc.)" \
		"  --dry-run                 Preview install commands, apply nothing" \
		"  --project-dir <path>      Target specific project for detection" \
		"  --quiet                   Errors and final summary only" \
		"  --verbose                 Show detailed operations" \
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
		--list)
			LIST_MODE=1
			shift
			;;
		--category)
			[[ $# -lt 2 ]] && {
				log_error "--category requires a category name"
				exit 1
			}
			CATEGORY_FILTER="$2"
			# Validate category
			local valid=0
			local cat
			for cat in ${VALID_CATEGORIES}; do
				[[ "${cat}" == "${CATEGORY_FILTER}" ]] && {
					valid=1
					break
				}
			done
			if [[ "${valid}" -eq 0 ]]; then
				log_error "Unknown category: ${CATEGORY_FILTER}"
				log_error "Valid categories: ${VALID_CATEGORIES}"
				exit 1
			fi
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--project-dir)
			[[ $# -lt 2 ]] && {
				log_error "--project-dir requires a path"
				exit 1
			}
			PROJECT_DIR="$2"
			shift 2
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
			exit 1
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
# print_header — styled header with version and registry count
# ---------------------------------------------------------------------------
print_header() {
	[[ "${QUIET}" -eq 1 ]] && return 0
	printf '\n  %sccfg plugins%s v%s  %s(%d in registry)%s\n' \
		"${BOLD}" "${RESET}" "${CCFG_VERSION}" \
		"${DIM}" "$(reg_count)" "${RESET}"
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
	printf '    %s%s%s bash %s     %s%s%s jq %s     %s%s%s %s %s\n\n' \
		"${GREEN}" "${CHECK}" "${RESET}" "${bash_ver}" \
		"${GREEN}" "${CHECK}" "${RESET}" "${jq_ver}" \
		"${GREEN}" "${CHECK}" "${RESET}" "${os}" "${arch}"
}

# ---------------------------------------------------------------------------
# resolve_project_dir — resolve and validate project directory
# ---------------------------------------------------------------------------
resolve_project_dir() {
	if [[ -z "${PROJECT_DIR}" ]]; then
		PROJECT_DIR="$(pwd)"
	else
		# Resolve to absolute path
		if [[ ! -d "${PROJECT_DIR}" ]]; then
			log_error "Project directory not found: ${PROJECT_DIR}"
			exit 1
		fi
		PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
	fi
}

# ---------------------------------------------------------------------------
# run_detection — detect languages and supplemental signals
# ---------------------------------------------------------------------------
run_detection() {
	local dir="${PROJECT_DIR}"
	DETECTED_LANGS=()

	# Standard language detection
	local detected
	detected="$(detect_languages "${dir}")"
	local lang
	for lang in ${detected}; do
		DETECTED_LANGS+=("${lang}")
	done

	# Map javascript -> typescript (same LSP serves both)
	local has_js=0
	local has_ts=0
	for lang in "${DETECTED_LANGS[@]}"; do
		[[ "${lang}" == "javascript" ]] && has_js=1
		[[ "${lang}" == "typescript" ]] && has_ts=1
	done
	if [[ "${has_js}" -eq 1 && "${has_ts}" -eq 0 ]]; then
		DETECTED_LANGS+=("typescript")
	fi

	# Supplemental signals for registry (not in detect.sh yet)
	if [[ -n "$(find "${dir}" -maxdepth 2 \( -name '*.tsx' -o -name '*.vue' -o -name '*.svelte' -o -name '*.jsx' \) -print -quit 2>/dev/null)" ]]; then
		DETECTED_LANGS+=("frontend")
	fi

	if [[ -d "${dir}/.beads" ]]; then
		DETECTED_LANGS+=("beads")
	fi

	# "always" is always a detection signal (universal plugins)
	DETECTED_LANGS+=("always")

	# Deduplicate detection signals
	local -A _seen_langs=()
	local -a _unique_langs=()
	local _l
	for _l in "${DETECTED_LANGS[@]}"; do
		if [[ -z "${_seen_langs[${_l}]:-}" ]]; then
			_unique_langs+=("${_l}")
			_seen_langs["${_l}"]=1
		fi
	done
	DETECTED_LANGS=("${_unique_langs[@]}")
}

# ---------------------------------------------------------------------------
# print_detection — show detected languages
# ---------------------------------------------------------------------------
print_detection() {
	[[ "${QUIET}" -eq 1 ]] && return 0

	printf '  %sProject%s  %s\n\n' "${BOLD}" "${RESET}" "${PROJECT_DIR}"

	# Use detect_summary for standard languages
	detect_summary "${PROJECT_DIR}"

	# Show supplemental signals
	local lang
	for lang in "${DETECTED_LANGS[@]}"; do
		case "${lang}" in
		frontend)
			printf '    %s%s%s %-16s %s%s%s\n' \
				"${GREEN}" "${CHECK}" "${RESET}" "frontend" \
				"${DIM}" "*.tsx / *.vue / *.svelte / *.jsx" "${RESET}"
			;;
		beads)
			printf '    %s%s%s %-16s %s%s%s\n' \
				"${GREEN}" "${CHECK}" "${RESET}" "beads" \
				"${DIM}" ".beads/" "${RESET}"
			;;
		esac
	done
	printf '\n'
}

# ---------------------------------------------------------------------------
# _has_detection — check if a signal is in DETECTED_LANGS
# ---------------------------------------------------------------------------
_has_detection() {
	local signal="$1"
	local d
	for d in "${DETECTED_LANGS[@]}"; do
		[[ "${d}" == "${signal}" ]] && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------
# _sort_keys — sort registry keys by (category, tier_order, name)
# ---------------------------------------------------------------------------
_sort_keys() {
	local key
	while IFS= read -r key; do
		[[ -z "${key}" ]] && continue
		local tier_order=2
		case "${REG_TIER[${key}]}" in
		auto) tier_order=1 ;;
		suggest) tier_order=2 ;;
		info) tier_order=3 ;;
		esac
		printf '%s|%d|%s|%s\n' "${REG_CATEGORY[${key}]}" "${tier_order}" "${REG_NAME[${key}]}" "${key}"
	done | sort -t'|' -k1,1 -k2,2n -k3,3 | cut -d'|' -f4
}

# ---------------------------------------------------------------------------
# build_candidate_lists — categorize registry keys into auto/suggest
# ---------------------------------------------------------------------------
build_candidate_lists() {
	AUTO_KEYS=()
	SUGGEST_KEYS=()

	local -a raw_auto=()
	local -a raw_suggest=()
	local key

	for key in $(reg_all_keys); do
		local tier="${REG_TIER[${key}]}"
		local detect="${REG_DETECT[${key}]}"
		local category="${REG_CATEGORY[${key}]}"

		# Category filter
		if [[ -n "${CATEGORY_FILTER}" && "${category}" != "${CATEGORY_FILTER}" ]]; then
			continue
		fi

		# Skip info tier unless --list
		if [[ "${tier}" == "info" && "${LIST_MODE}" -eq 0 ]]; then
			continue
		fi

		# Check if detection matches
		local detected=0
		if [[ "${LIST_MODE}" -eq 1 ]]; then
			# List mode: include all regardless of detection
			detected=1
		elif [[ -n "${detect}" ]]; then
			_has_detection "${detect}" && detected=1
		fi

		[[ "${detected}" -eq 0 ]] && continue

		# Auto-tier with no LSP overlap → auto; everything else → suggest
		if [[ "${tier}" == "auto" ]] && ! reg_is_lsp_overlap "${key}"; then
			raw_auto+=("${key}")
		else
			raw_suggest+=("${key}")
		fi
	done

	# Sort both lists
	if [[ "${#raw_auto[@]}" -gt 0 ]]; then
		while IFS= read -r key; do
			AUTO_KEYS+=("${key}")
		done < <(printf '%s\n' "${raw_auto[@]}" | _sort_keys)
	fi

	if [[ "${#raw_suggest[@]}" -gt 0 ]]; then
		while IFS= read -r key; do
			SUGGEST_KEYS+=("${key}")
		done < <(printf '%s\n' "${raw_suggest[@]}" | _sort_keys)
	fi
}

# ---------------------------------------------------------------------------
# print_recommendations — display full registry (for --list mode)
# ---------------------------------------------------------------------------
print_recommendations() {
	log_quiet "  ${BOLD}Registry${RESET}  ${CCFG_REGISTRY_VERSION}  ($(reg_count) plugins)"
	log_quiet ""

	# Merge and re-sort all keys together for proper grouping
	local -a raw_all=()
	raw_all+=("${AUTO_KEYS[@]}")
	raw_all+=("${SUGGEST_KEYS[@]}")

	if [[ "${#raw_all[@]}" -eq 0 ]]; then
		if [[ -n "${CATEGORY_FILTER}" ]]; then
			log_quiet "  No plugins found for category: ${CATEGORY_FILTER}"
		else
			log_quiet "  No plugins match current detection."
		fi
		return 0
	fi

	local -a all_keys=()
	while IFS= read -r key; do
		all_keys+=("${key}")
	done < <(printf '%s\n' "${raw_all[@]}" | _sort_keys)

	local current_category=""
	local key
	for key in "${all_keys[@]}"; do
		local category="${REG_CATEGORY[${key}]}"
		local tier="${REG_TIER[${key}]}"
		local name="${REG_NAME[${key}]}"
		local desc="${REG_DESC[${key}]}"
		local marketplace="${REG_MARKETPLACE[${key}]}"

		# Print category header on change
		if [[ "${category}" != "${current_category}" ]]; then
			[[ -n "${current_category}" ]] && log_quiet ""
			local cat_count=0
			local k
			for k in "${all_keys[@]}"; do
				[[ "${REG_CATEGORY[${k}]}" == "${category}" ]] && cat_count=$((cat_count + 1))
			done
			log_quiet "  ${BOLD}${category}${RESET} (${cat_count})"
			current_category="${category}"
		fi

		# Tier label
		local tier_label
		case "${tier}" in
		auto) tier_label="${GREEN}auto${RESET}   " ;;
		suggest) tier_label="${YELLOW}suggest${RESET}" ;;
		info) tier_label="${DIM}info${RESET}   " ;;
		*) tier_label="${tier}   " ;;
		esac

		printf '    %s  %-28s %-48s %s%s%s\n' \
			"${tier_label}" "${name}" "${desc}" \
			"${DIM}" "${marketplace}" "${RESET}"
	done

	log_quiet ""
	log_quiet "  $(printf '%0.s─' {1..22})"
	log_quiet "  $(reg_count) plugins in registry. Run without --list to install."
	log_quiet ""
}

# ---------------------------------------------------------------------------
# print_auto_selection — show auto-tier plugins that will be installed
# ---------------------------------------------------------------------------
print_auto_selection() {
	[[ "${QUIET}" -eq 1 ]] && return 0
	[[ "${#AUTO_KEYS[@]}" -eq 0 ]] && return 0

	log_quiet "  ${BOLD}Auto-install${RESET} (${#AUTO_KEYS[@]} plugins):"
	local key
	for key in "${AUTO_KEYS[@]}"; do
		printf '    %s%s%s %-28s %s%s%s\n' \
			"${GREEN}" "${CHECK}" "${RESET}" \
			"${REG_NAME[${key}]}" \
			"${DIM}" "${REG_DESC[${key}]}" "${RESET}"
	done
	log_quiet ""
}

# ---------------------------------------------------------------------------
# handle_lsp_overlaps — present paired LSP choices for detected languages
# ---------------------------------------------------------------------------
handle_lsp_overlaps() {
	# Collect languages with LSP overlaps present in SUGGEST_KEYS
	local -A lsp_langs=()
	local key
	for key in "${SUGGEST_KEYS[@]}"; do
		local lsp_lang="${REG_LSP_LANG[${key}]}"
		if [[ -n "${lsp_lang}" ]]; then
			lsp_langs["${lsp_lang}"]+="${key} "
		fi
	done

	local lang
	for lang in $(printf '%s\n' "${!lsp_langs[@]}" | sort); do
		local keys_str="${lsp_langs[${lang}]}"
		local -a keys=()
		read -ra keys <<<"${keys_str}"
		[[ "${#keys[@]}" -lt 2 ]] && continue

		# Use registry helpers for preferred/alternative ordering
		local preferred alternative
		preferred="$(reg_lsp_preferred "${lang}")"
		alternative="$(reg_lsp_alternative "${lang}")"

		if [[ "${AUTO_MODE}" -eq 1 ]]; then
			# In --auto mode, skip overlapping LSPs entirely
			log_quiet "    ${YELLOW}${DOT}${RESET} ${lang} LSP: skipped (choose interactively)"
			continue
		fi

		# Non-tty fallback
		if [[ ! -t 0 ]]; then
			log_quiet "    ${YELLOW}${DOT}${RESET} ${lang} LSP: skipped (non-interactive)"
			continue
		fi

		# Interactive choice
		log_quiet ""
		log_quiet "    ${BOLD}${lang} LSP${RESET} (choose one):"
		printf '      %s[1]%s %-24s %s%s (recommended)  %s%s\n' \
			"${GREEN}" "${RESET}" "${REG_NAME[${preferred}]}" \
			"${DIM}" "${REG_LSP_SOURCE[${preferred}]}" "${REG_MARKETPLACE[${preferred}]}" "${RESET}"
		printf '      %s[2]%s %-24s %s%s  %s%s\n' \
			"${GREEN}" "${RESET}" "${REG_NAME[${alternative}]}" \
			"${DIM}" "${REG_LSP_SOURCE[${alternative}]}" "${REG_MARKETPLACE[${alternative}]}" "${RESET}"
		printf '      Choice [1]: '
		local choice
		read -r choice
		choice="${choice:-1}"

		if [[ "${choice}" == "2" ]]; then
			LSP_CHOICES["${lang}"]="${alternative}"
		else
			LSP_CHOICES["${lang}"]="${preferred}"
		fi
	done
}

# ---------------------------------------------------------------------------
# interactive_selection — present suggest-tier non-LSP plugins for selection
# ---------------------------------------------------------------------------
interactive_selection() {
	# Skip if auto mode or non-tty
	if [[ "${AUTO_MODE}" -eq 1 ]]; then
		return 0
	fi
	if [[ ! -t 0 ]]; then
		log_quiet "    ${DIM}Non-interactive: suggest-tier plugins skipped${RESET}"
		return 0
	fi

	# Collect non-LSP suggest-tier plugins
	local -a available=()
	local key
	for key in "${SUGGEST_KEYS[@]}"; do
		local lsp_lang="${REG_LSP_LANG[${key}]}"
		# Skip LSP plugins (handled by handle_lsp_overlaps)
		[[ -n "${lsp_lang}" ]] && continue
		available+=("${key}")
	done

	[[ "${#available[@]}" -eq 0 ]] && return 0

	log_quiet "  ${BOLD}Suggested plugins:${RESET}"
	local idx=0
	for key in "${available[@]}"; do
		idx=$((idx + 1))
		printf '    %s[%d]%s %s %-28s %s%s%s\n' \
			"${GREEN}" "${idx}" "${RESET}" "${DOT}" \
			"${REG_NAME[${key}]}" \
			"${DIM}" "${REG_DESC[${key}]}" "${RESET}"
	done

	log_quiet ""
	printf '    Add plugins? [comma-separated numbers or Enter to skip]: '
	local input
	read -r input

	if [[ -n "${input}" ]]; then
		local -a selections=()
		IFS=',' read -ra selections <<<"${input}"
		local sel
		for sel in "${selections[@]}"; do
			sel="$(printf '%s' "${sel}" | tr -d ' ')"
			if [[ "${sel}" =~ ^[0-9]+$ && "${sel}" -ge 1 && "${sel}" -le "${#available[@]}" ]]; then
				local sel_key="${available[$((sel - 1))]}"
				SELECTED_KEYS+=("${sel_key}")
			else
				log_warn "Invalid selection: ${sel} (skipped)"
			fi
		done
	fi

	log_quiet ""
}

# ---------------------------------------------------------------------------
# finalize_selection — merge all sources into SELECTED_KEYS
# ---------------------------------------------------------------------------
finalize_selection() {
	# Start with auto keys (always included)
	local -a merged=()
	local -A seen=()
	local key

	for key in "${AUTO_KEYS[@]}"; do
		if [[ -z "${seen[${key}]:-}" ]]; then
			merged+=("${key}")
			seen["${key}"]=1
		fi
	done

	# Add LSP choices
	for key in "${LSP_CHOICES[@]}"; do
		if [[ -n "${key}" && -z "${seen[${key}]:-}" ]]; then
			merged+=("${key}")
			seen["${key}"]=1
		fi
	done

	# Add interactively selected keys (already in SELECTED_KEYS from interactive_selection)
	for key in "${SELECTED_KEYS[@]}"; do
		if [[ -z "${seen[${key}]:-}" ]]; then
			merged+=("${key}")
			seen["${key}"]=1
		fi
	done

	SELECTED_KEYS=("${merged[@]}")
}

# ---------------------------------------------------------------------------
# print_selection_summary — show final selection before install
# ---------------------------------------------------------------------------
print_selection_summary() {
	[[ "${QUIET}" -eq 1 ]] && return 0
	[[ "${#SELECTED_KEYS[@]}" -eq 0 ]] && return 0

	log_quiet "  ${BOLD}Selection Summary${RESET} (${#SELECTED_KEYS[@]} plugins):"
	local key
	for key in "${SELECTED_KEYS[@]}"; do
		local source_label="auto"
		# Check if from LSP choice
		local lsp_lang="${REG_LSP_LANG[${key}]}"
		if [[ -n "${lsp_lang}" && -n "${LSP_CHOICES[${lsp_lang}]:-}" ]]; then
			source_label="selected"
		fi
		# Check if from interactive selection (not in AUTO_KEYS and not LSP)
		local in_auto=0
		local ak
		for ak in "${AUTO_KEYS[@]}"; do
			[[ "${ak}" == "${key}" ]] && {
				in_auto=1
				break
			}
		done
		if [[ "${in_auto}" -eq 0 && -z "${lsp_lang}" ]]; then
			source_label="selected"
		fi

		printf '    %s%s%s %-28s %-16s %s%s%s\n' \
			"${GREEN}" "${CHECK}" "${RESET}" \
			"${REG_NAME[${key}]}" \
			"${REG_CATEGORY[${key}]}" \
			"${DIM}" "${source_label}" "${RESET}"
	done
	log_quiet ""
}

# ---------------------------------------------------------------------------
# check_marketplaces — verify required marketplaces are configured
# Returns 0 if all present, 1 if any missing (with helpful instructions).
# In --dry-run mode, warns but returns 0 (does not block).
# ---------------------------------------------------------------------------
check_marketplaces() {
	[[ "${#SELECTED_KEYS[@]}" -eq 0 ]] && return 0

	# Skip if claude CLI not available (install_plugins will catch this)
	if ! command -v claude &>/dev/null; then
		return 0
	fi

	# Collect required marketplaces from selection
	local -A required=()
	local key
	for key in "${SELECTED_KEYS[@]}"; do
		local mp="${REG_MARKETPLACE[${key}]}"
		[[ -n "${mp}" ]] && required["${mp}"]=1
	done

	# Get configured marketplaces
	local mp_output
	mp_output="$(claude plugin marketplace list 2>/dev/null)" || {
		log_warn "Could not check marketplace availability"
		return 0
	}

	# Parse configured marketplace names from output
	local -A configured=()
	local line
	while IFS= read -r line; do
		# Lines like "  ❯ claude-plugins-official"
		local name
		name="$(printf '%s' "${line}" | sed -n 's/^[[:space:]]*[❯>][[:space:]]*//p')"
		[[ -n "${name}" ]] && configured["${name}"]=1
	done <<<"${mp_output}"

	# Check each required marketplace
	local missing=0
	local mp
	for mp in "${!required[@]}"; do
		if [[ -z "${configured[${mp}]:-}" ]]; then
			missing=$((missing + 1))
			local repo
			repo="$(reg_marketplace_repo "${mp}")"
			if [[ "${DRY_RUN}" -eq 1 ]]; then
				log_quiet "    ${YELLOW}${WARN_SYM}${RESET} Missing marketplace: ${mp}"
				if [[ -n "${repo}" ]]; then
					log_quiet "      Run: ${CYAN}claude plugin marketplace add ${repo}${RESET}"
				fi
			else
				log_error "Missing marketplace: ${mp}"
				if [[ -n "${repo}" ]]; then
					log_error "Run: claude plugin marketplace add ${repo}"
				fi
			fi
		fi
	done

	if [[ "${missing}" -gt 0 ]]; then
		if [[ "${DRY_RUN}" -eq 1 ]]; then
			log_quiet ""
			return 0
		fi
		log_error "${missing} required marketplace(s) not configured. Add them and re-run."
		ERRORS=$((ERRORS + 1))
		return 1
	fi

	return 0
}

# ---------------------------------------------------------------------------
# install_plugins — run claude plugin install for each selected key
# ---------------------------------------------------------------------------
install_plugins() {
	[[ "${#SELECTED_KEYS[@]}" -eq 0 ]] && {
		log_quiet "  No plugins selected for installation."
		return 0
	}

	# Preflight: check claude CLI
	if [[ "${DRY_RUN}" -eq 0 ]]; then
		if ! command -v claude &>/dev/null; then
			log_error "claude CLI is required but not found in PATH"
			log_error "Install: https://docs.anthropic.com/claude-code/installation"
			ERRORS=$((ERRORS + 1))
			return 1
		fi
	fi

	local total="${#SELECTED_KEYS[@]}"
	local current=0

	log_quiet "  ${BOLD}Installing${RESET}  ${total} plugin(s)"

	local key
	for key in "${SELECTED_KEYS[@]}"; do
		current=$((current + 1))
		local name="${REG_NAME[${key}]}"
		local marketplace="${REG_MARKETPLACE[${key}]}"

		if [[ "${DRY_RUN}" -eq 1 ]]; then
			log_quiet "    ${CYAN}[${current}/${total}]${RESET} claude plugin install ${name}@${marketplace} ${DIM}[dry-run]${RESET}"
			continue
		fi

		local -a install_cmd=(claude plugin install "${name}@${marketplace}")
		if command -v timeout &>/dev/null; then
			install_cmd=(timeout 60 "${install_cmd[@]}")
		fi
		if "${install_cmd[@]}" >/dev/null 2>&1; then
			log_quiet "    ${GREEN}${CHECK}${RESET} [${current}/${total}] ${name}@${marketplace}"
			INSTALLED_KEYS+=("${key}")
		else
			log_quiet "    ${RED}${CROSS}${RESET} [${current}/${total}] ${name}@${marketplace} (install failed)"
			FAILED_KEYS+=("${key}")
			ERRORS=$((ERRORS + 1))
		fi
	done
	log_quiet ""
}

# ---------------------------------------------------------------------------
# update_settings — merge enabledPlugins into settings.json
# ---------------------------------------------------------------------------
update_settings() {
	[[ "${#INSTALLED_KEYS[@]}" -eq 0 ]] && return 0
	[[ "${DRY_RUN}" -eq 1 ]] && return 0

	log_quiet "  ${BOLD}Settings${RESET}  ${SETTINGS_FILE}"

	# Initialize settings.json if absent
	if [[ ! -f "${SETTINGS_FILE}" ]]; then
		mkdir -p "$(dirname "${SETTINGS_FILE}")"
		printf '{}\n' >"${SETTINGS_FILE}"
		log_quiet "    ${GREEN}${CHECK}${RESET} Created ${SETTINGS_FILE}"
	fi

	# Backup before modification
	local backup_path
	backup_path="$(backup_create "${SETTINGS_FILE}")"
	if [[ "${VERBOSE}" -eq 1 && -n "${backup_path}" ]]; then
		log_quiet "    ${DIM}${ARROW} Backup: ${backup_path}${RESET}"
	fi

	# Build plugins JSON
	local plugins_json="{}"
	local key
	for key in "${INSTALLED_KEYS[@]}"; do
		local entry="${REG_NAME[${key}]}@${REG_MARKETPLACE[${key}]}"
		plugins_json="$(printf '%s' "${plugins_json}" | jq --arg k "${entry}" '. + {($k): true}')"
	done

	settings_merge_plugins "${SETTINGS_FILE}" "${plugins_json}"
	SETTINGS_CHANGED=1

	local count
	count="$(printf '%s' "${plugins_json}" | jq 'keys | length')"
	log_quiet "    ${GREEN}${CHECK}${RESET} enabledPlugins: ${count} entries merged"
	log_quiet ""
}

# ---------------------------------------------------------------------------
# print_summary — final output with counts
# ---------------------------------------------------------------------------
print_summary() {
	log_quiet "  $(printf '%0.s─' {1..22})"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		log_quiet "  ${BOLD}Dry run complete.${RESET} No plugins installed, no files modified."
	else
		local installed="${#INSTALLED_KEYS[@]}"
		local failed="${#FAILED_KEYS[@]}"
		local files_updated=0
		[[ "${SETTINGS_CHANGED}" -eq 1 ]] && files_updated=1

		log_quiet "  ${BOLD}Done.${RESET} ${installed} installed, ${failed} failed, ${files_updated} file(s) updated."

		# Report failures
		if [[ "${failed}" -gt 0 ]]; then
			log_quiet ""
			log_quiet "  ${RED}Failed:${RESET}"
			local key
			for key in "${FAILED_KEYS[@]}"; do
				log_quiet "    ${RED}${CROSS}${RESET} ${REG_NAME[${key}]}@${REG_MARKETPLACE[${key}]}"
			done
		fi
	fi

	# Prune old backups silently
	if [[ "${DRY_RUN}" -eq 0 ]]; then
		backup_prune "${SETTINGS_FILE}" >/dev/null 2>&1 || true
	fi

	log_quiet ""
}

# ---------------------------------------------------------------------------
# cleanup — trap handler for error recovery
# ---------------------------------------------------------------------------
cleanup() {
	local exit_code=$?
	if [[ ${exit_code} -ne 0 ]]; then
		log_error "Plugin installation failed."
		log_error "Your original files are preserved."
	fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# main — orchestrate the full plugin recommendation and install flow
# ---------------------------------------------------------------------------
main() {
	parse_args "$@"

	# Preflight checks
	preflight_check || exit 1

	# Header
	print_header

	# Preflight display
	print_preflight

	# Resolve project directory
	resolve_project_dir

	# Detect languages
	run_detection

	# Show detection results
	print_detection

	# Build candidate lists from registry
	build_candidate_lists

	# List mode: show registry and exit
	if [[ "${LIST_MODE}" -eq 1 ]]; then
		print_recommendations
		exit 0
	fi

	# Check if anything to recommend
	if [[ "${#AUTO_KEYS[@]}" -eq 0 && "${#SUGGEST_KEYS[@]}" -eq 0 ]]; then
		log_quiet "  No plugins match current detection."
		if [[ -n "${CATEGORY_FILTER}" ]]; then
			log_quiet "  Try removing --category filter or run with --list to see all."
		fi
		log_quiet ""
		exit 0
	fi

	# Show auto-tier selection
	print_auto_selection

	# Handle LSP overlap choices
	handle_lsp_overlaps

	# Interactive suggest-tier selection
	interactive_selection

	# Finalize: merge all selected keys
	finalize_selection

	# Show selection summary
	print_selection_summary

	# Verify required marketplaces are configured
	check_marketplaces || {
		print_summary
		exit 1
	}

	# Install selected plugins
	install_plugins

	# Update settings.json with installed plugins
	update_settings

	# Summary
	print_summary
}

main "$@"
