#!/usr/bin/env bash
# claude-md.sh — CLAUDE.md managed-section operations.
# Provides marker-based section management with version tracking.
# Content outside markers is NEVER modified.
# Source this file; do not execute directly.
#
# Marker format:
#   <!-- ccfg:begin:section-name v0.1.0 -->
#   ... managed content ...
#   <!-- ccfg:end:section-name -->
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/claude-md.sh"

# Sourcing guard
[[ -n "${_CCFG_CLAUDE_MD_LOADED:-}" ]] && return
_CCFG_CLAUDE_MD_LOADED=1

# Source common.sh for logging
_CCFG_CLAUDE_MD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_CCFG_CLAUDE_MD_DIR}/common.sh"

# ---------------------------------------------------------------------------
# claude_md_has_section <file> <section>
# Check if managed section exists. Returns 0 if found, 1 if not.
# ---------------------------------------------------------------------------
claude_md_has_section() {
	local file="$1"
	local section="$2"

	[[ -f "${file}" ]] || return 1
	grep -q "<!-- ccfg:begin:${section} " "${file}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# claude_md_get_version <file> <section>
# Extract version string from begin marker. Empty output if section not found.
# ---------------------------------------------------------------------------
claude_md_get_version() {
	local file="$1"
	local section="$2"

	[[ -f "${file}" ]] || return 0

	# Match: <!-- ccfg:begin:section-name vX.Y.Z -->
	# Extract the version part (vX.Y.Z)
	sed -n "s/^<!-- ccfg:begin:${section} \(v[^ ]*\) -->/\1/p" "${file}" | head -1
}

# ---------------------------------------------------------------------------
# claude_md_update_section <file> <section> <content> <version>
# Update or insert a managed section.
# - Section doesn't exist → append before user-customization footer
# - Section exists with same version → skip (no-op)
# - Section exists with older version → replace content between markers
# ---------------------------------------------------------------------------
claude_md_update_section() {
	local file="$1"
	local section="$2"
	local content="$3"
	local version="$4"

	if ! claude_md_has_section "${file}" "${section}"; then
		# Section doesn't exist — insert before user-customization footer or append
		local begin_marker="<!-- ccfg:begin:${section} ${version} -->"
		local end_marker="<!-- ccfg:end:${section} -->"
		local full_section
		full_section="$(printf '%s\n\n%s\n\n%s' "${begin_marker}" "${content}" "${end_marker}")"

		if grep -q "^## User Customizations" "${file}" 2>/dev/null; then
			# Insert before the user customizations footer
			local tmpfile
			tmpfile="$(mktemp)" || return 1
			# Use awk to insert before the footer line
			awk -v section="${full_section}" '
                /^## User Customizations/ {
                    print section
                    print ""
                }
                { print }
            ' "${file}" >"${tmpfile}"
			mv "${tmpfile}" "${file}"
		else
			# No footer — append to end of file
			printf '\n%s\n' "${full_section}" >>"${file}"
		fi
		log_info "Added section: ${section} (${version})"
		return 0
	fi

	# Section exists — check version
	local current_version
	current_version="$(claude_md_get_version "${file}" "${section}")"

	if [[ "${current_version}" == "${version}" ]]; then
		log_info "Section unchanged: ${section} (${version})"
		return 0
	fi

	# Different version — replace content between markers
	local begin_marker="<!-- ccfg:begin:${section} ${version} -->"
	local end_marker="<!-- ccfg:end:${section} -->"
	local tmpfile
	tmpfile="$(mktemp)" || return 1

	awk -v begin="${begin_marker}" -v content="${content}" -v end="${end_marker}" \
		-v section="${section}" '
        # Match any version of the begin marker for this section
        $0 ~ "<!-- ccfg:begin:" section " " {
            print begin
            print ""
            print content
            print ""
            print end
            skip = 1
            next
        }
        # Match the end marker — stop skipping
        $0 ~ "<!-- ccfg:end:" section " -->" {
            skip = 0
            next
        }
        # Print lines not inside the old section
        !skip { print }
    ' "${file}" >"${tmpfile}"

	mv "${tmpfile}" "${file}"
	log_info "Updated section: ${section} (${current_version} ${ARROW} ${version})"
}

# ---------------------------------------------------------------------------
# claude_md_create <file> <sections_array>
# Create a new CLAUDE.md with managed sections and a user-customization footer.
# Never overwrites an existing file — use claude_md_update_section instead.
#
# <sections_array> is a newline-delimited string of "section|version|content" entries.
# ---------------------------------------------------------------------------
claude_md_create() {
	local file="$1"
	local sections="$2"

	if [[ -f "${file}" ]]; then
		log_error "File already exists: ${file} — use claude_md_update_section instead"
		return 1
	fi

	local dir
	dir="$(dirname "${file}")"
	if [[ ! -d "${dir}" ]]; then
		mkdir -p "${dir}" || {
			log_error "Cannot create directory: ${dir}"
			return 1
		}
	fi

	# Start with empty file
	: >"${file}"

	# Write each section
	local line
	while IFS= read -r line; do
		[[ -z "${line}" ]] && continue
		local section version content
		section="$(printf '%s' "${line}" | cut -d'|' -f1)"
		version="$(printf '%s' "${line}" | cut -d'|' -f2)"
		content="$(printf '%s' "${line}" | cut -d'|' -f3-)"

		printf '<!-- ccfg:begin:%s %s -->\n\n%s\n\n<!-- ccfg:end:%s -->\n\n' \
			"${section}" "${version}" "${content}" "${section}" >>"${file}"
	done <<<"${sections}"

	# Add user-customization footer
	printf '## User Customizations\n\nAdd your personal preferences below.\n' >>"${file}"

	log_info "Created: ${file}"
}

# ---------------------------------------------------------------------------
# claude_md_validate <file>
# Verify every ccfg:begin has a matching ccfg:end.
# Returns 0 if balanced, 1 with error listing unmatched markers.
# ---------------------------------------------------------------------------
claude_md_validate() {
	local file="$1"

	if [[ ! -f "${file}" ]]; then
		log_error "File not found: ${file}"
		return 1
	fi

	local failed=0

	# Extract all section names from begin markers
	local begin_sections
	begin_sections="$(grep -oP '(?<=<!-- ccfg:begin:)[^ ]+' "${file}" 2>/dev/null | sort)"

	# Extract all section names from end markers
	local end_sections
	end_sections="$(grep -oP '(?<=<!-- ccfg:end:)[^ ]+' "${file}" 2>/dev/null | sed 's/ -->//' | sort)"

	# Find sections with begin but no end
	local orphan_begins
	orphan_begins="$(comm -23 <(printf '%s' "${begin_sections}") <(printf '%s' "${end_sections}"))"
	if [[ -n "${orphan_begins}" ]]; then
		while IFS= read -r section; do
			log_error "Unmatched begin marker: ${section}"
		done <<<"${orphan_begins}"
		failed=1
	fi

	# Find sections with end but no begin
	local orphan_ends
	orphan_ends="$(comm -13 <(printf '%s' "${begin_sections}") <(printf '%s' "${end_sections}"))"
	if [[ -n "${orphan_ends}" ]]; then
		while IFS= read -r section; do
			log_error "Unmatched end marker: ${section}"
		done <<<"${orphan_ends}"
		failed=1
	fi

	if [[ "${failed}" -eq 1 ]]; then
		log_error "CLAUDE.md marker validation failed: ${file}"
		return 1
	fi

	return 0
}
