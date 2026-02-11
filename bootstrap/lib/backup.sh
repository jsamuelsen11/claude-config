#!/usr/bin/env bash
# backup.sh — Timestamped backup and restore for ccfg bootstrap scripts.
# Storage: ~/.claude/backups/
# Naming: <basename>_<YYYYMMDD_HHMMSS>.<ext>
# Source this file; do not execute directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"

# Sourcing guard
[[ -n "${_CCFG_BACKUP_LOADED:-}" ]] && return
_CCFG_BACKUP_LOADED=1

# Source common.sh for logging and platform detection
_CCFG_BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_CCFG_BACKUP_DIR}/common.sh"

# Backup storage directory
CCFG_BACKUP_DIR="${HOME}/.claude/backups"

# Default number of backups to retain
CCFG_BACKUP_KEEP=10

# ---------------------------------------------------------------------------
# _backup_ensure_dir
# Create backup directory if absent.
# ---------------------------------------------------------------------------
_backup_ensure_dir() {
	if [[ ! -d "${CCFG_BACKUP_DIR}" ]]; then
		if ! mkdir -p "${CCFG_BACKUP_DIR}"; then
			log_error "Cannot create backup directory: ${CCFG_BACKUP_DIR}"
			return 1
		fi
	fi
}

# ---------------------------------------------------------------------------
# _backup_timestamp
# Portable timestamp: YYYYMMDD_HHMMSS (works on GNU and BSD date)
# ---------------------------------------------------------------------------
_backup_timestamp() {
	date +%Y%m%d_%H%M%S
}

# ---------------------------------------------------------------------------
# _backup_name_parts <file>
# Derive backup name and extension from original file path.
# Prints two lines: name, then extension.
# ---------------------------------------------------------------------------
_backup_name_parts() {
	local file="$1"
	local basename
	basename="$(basename "${file}")"
	local name="${basename%.*}"
	local ext="${basename##*.}"

	# Distinguish user-level vs project-level CLAUDE.md
	if [[ "${basename}" == "CLAUDE.md" ]]; then
		local dir
		dir="$(cd "$(dirname "${file}")" && pwd)"
		if [[ "${dir}" == "${HOME}/.claude" || "${dir}" == "${HOME}/.claude/"* ]]; then
			name="CLAUDE_user"
		else
			name="CLAUDE_project"
		fi
	fi

	printf '%s\n%s' "${name}" "${ext}"
}

# ---------------------------------------------------------------------------
# _backup_pattern <file>
# Return glob pattern that matches backups for the given file.
# ---------------------------------------------------------------------------
_backup_pattern() {
	local file="$1"
	local parts name ext
	parts="$(_backup_name_parts "${file}")"
	name="$(head -1 <<<"${parts}")"
	ext="$(tail -1 <<<"${parts}")"

	printf '%s/%s_*.%s' "${CCFG_BACKUP_DIR}" "${name}" "${ext}"
}

# ---------------------------------------------------------------------------
# _backup_list_files <file>
# List backup files for the given source file, sorted newest first.
# Populates the global array _BACKUP_FILES.
# ---------------------------------------------------------------------------
_backup_list_files() {
	local file="$1"
	local pattern
	pattern="$(_backup_pattern "${file}")"

	_BACKUP_FILES=()
	local entry
	while IFS= read -r entry; do
		[[ -n "${entry}" && -f "${entry}" ]] && _BACKUP_FILES+=("${entry}")
	done < <(compgen -G "${pattern}" | sort -r 2>/dev/null)
}

# ---------------------------------------------------------------------------
# _backup_file_size <file>
# Portable file size in bytes (handles GNU stat and BSD stat).
# ---------------------------------------------------------------------------
_backup_file_size() {
	local file="$1"
	if stat --version &>/dev/null; then
		# GNU stat
		stat -c %s "${file}" 2>/dev/null
	else
		# BSD stat (macOS)
		stat -f %z "${file}" 2>/dev/null
	fi
}

# ---------------------------------------------------------------------------
# backup_create <file>
# Copy file to backup directory with timestamp.
# Returns the backup file path on stdout.
# ---------------------------------------------------------------------------
backup_create() {
	local file="$1"

	if [[ ! -f "${file}" ]]; then
		log_warn "Nothing to backup — file not found: ${file}"
		return 0
	fi

	_backup_ensure_dir || return 1

	local parts name ext timestamp backup_path
	parts="$(_backup_name_parts "${file}")"
	name="$(head -1 <<<"${parts}")"
	ext="$(tail -1 <<<"${parts}")"
	timestamp="$(_backup_timestamp)"
	backup_path="${CCFG_BACKUP_DIR}/${name}_${timestamp}.${ext}"

	if ! cp "${file}" "${backup_path}"; then
		log_error "Failed to create backup: ${backup_path}"
		return 1
	fi

	log_info "Backup created: ${ARROW} ${backup_path}"
	printf '%s' "${backup_path}"
}

# ---------------------------------------------------------------------------
# backup_list <file>
# List available backups for the given file, sorted newest first.
# Prints timestamp and size for each backup.
# ---------------------------------------------------------------------------
backup_list() {
	local file="$1"

	_backup_list_files "${file}"

	if [[ "${#_BACKUP_FILES[@]}" -eq 0 ]]; then
		log_info "No backups found for: $(basename "${file}")"
		return 0
	fi

	local backup_file
	for backup_file in "${_BACKUP_FILES[@]}"; do
		local size bname
		size="$(_backup_file_size "${backup_file}")"
		bname="$(basename "${backup_file}")"
		printf '  %s %s (%s bytes)\n' "${DOT}" "${bname}" "${size:-?}"
	done
}

# ---------------------------------------------------------------------------
# backup_restore <file> [timestamp]
# Restore specific backup. If no timestamp, restore most recent.
# Creates a safety backup of current file before restoring.
# ---------------------------------------------------------------------------
backup_restore() {
	local file="$1"
	local timestamp="${2:-}"
	local match=""

	_backup_list_files "${file}"

	if [[ "${#_BACKUP_FILES[@]}" -eq 0 ]]; then
		log_error "No backups available for: $(basename "${file}")"
		return 1
	fi

	if [[ -n "${timestamp}" ]]; then
		# Find specific backup matching timestamp
		local entry
		for entry in "${_BACKUP_FILES[@]}"; do
			if [[ "${entry}" == *"${timestamp}"* ]]; then
				match="${entry}"
				break
			fi
		done
		if [[ -z "${match}" ]]; then
			log_error "No backup found matching timestamp: ${timestamp}"
			return 1
		fi
	else
		# Most recent backup
		match="${_BACKUP_FILES[0]}"
	fi

	# Safety backup of current file before restoring
	if [[ -f "${file}" ]]; then
		log_info "Creating safety backup before restore..."
		backup_create "${file}" >/dev/null || return 1
	fi

	if ! cp "${match}" "${file}"; then
		log_error "Failed to restore from: ${match}"
		return 1
	fi

	log_info "Restored: $(basename "${match}") ${ARROW} ${file}"
}

# ---------------------------------------------------------------------------
# backup_rollback <file>
# Convenience wrapper: backup current, restore previous.
# ---------------------------------------------------------------------------
backup_rollback() {
	local file="$1"

	_backup_list_files "${file}"

	if [[ "${#_BACKUP_FILES[@]}" -lt 1 ]]; then
		log_error "No backups to rollback to for: $(basename "${file}")"
		return 1
	fi

	# Safety backup current state
	log_info "Creating safety backup before rollback..."
	backup_create "${file}" >/dev/null || return 1

	# Re-scan after safety backup was created
	_backup_list_files "${file}"

	if [[ "${#_BACKUP_FILES[@]}" -lt 2 ]]; then
		log_error "Only one backup exists — nothing to rollback to"
		return 1
	fi

	# Index 0 is the safety backup just created; index 1 is the previous state
	local restore_from="${_BACKUP_FILES[1]}"
	if ! cp "${restore_from}" "${file}"; then
		log_error "Failed to rollback from: ${restore_from}"
		return 1
	fi

	log_info "Rolled back: $(basename "${restore_from}") ${ARROW} ${file}"
}

# ---------------------------------------------------------------------------
# backup_prune <file> [keep]
# Retain only N most recent backups (default: CCFG_BACKUP_KEEP=10).
# Delete older ones.
# ---------------------------------------------------------------------------
backup_prune() {
	local file="$1"
	local keep="${2:-${CCFG_BACKUP_KEEP}}"

	_backup_list_files "${file}"

	if [[ "${#_BACKUP_FILES[@]}" -le "${keep}" ]]; then
		return 0
	fi

	local count=0
	local backup_file
	for backup_file in "${_BACKUP_FILES[@]}"; do
		count=$((count + 1))
		if [[ "${count}" -gt "${keep}" ]]; then
			rm -f "${backup_file}"
			log_info "Pruned old backup: $(basename "${backup_file}")"
		fi
	done
}
