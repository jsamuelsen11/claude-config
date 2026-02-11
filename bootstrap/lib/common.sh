#!/usr/bin/env bash
# common.sh — Shared foundation library for ccfg bootstrap scripts.
# Provides logging, colors, unicode symbols, platform detection, and preflight checks.
# Source this file; do not execute directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Sourcing guard — prevent double-sourcing.
[[ -n "${_CCFG_COMMON_LOADED:-}" ]] && return
_CCFG_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

export CCFG_VERSION="0.1.0"

# ---------------------------------------------------------------------------
# Colors — auto-disabled when stdout is not a tty
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
	BOLD=$'\033[1m'
	GREEN=$'\033[0;32m'
	YELLOW=$'\033[0;33m'
	RED=$'\033[0;31m'
	CYAN=$'\033[0;36m'
	DIM=$'\033[2m'
	RESET=$'\033[0m'
else
	BOLD=""
	GREEN=""
	YELLOW=""
	RED=""
	CYAN=""
	DIM=""
	RESET=""
fi

export BOLD GREEN YELLOW RED CYAN DIM RESET

# ---------------------------------------------------------------------------
# Unicode symbols
# ---------------------------------------------------------------------------

export CHECK="✓"
export CROSS="✗"
export ARROW="→"
export DOT="·"
export WARN_SYM="⚠"

# ---------------------------------------------------------------------------
# Logging — INFO/WARN to stdout, ERROR to stderr
# ---------------------------------------------------------------------------

log_info() {
	printf '%s[INFO]%s %s\n' "${GREEN}" "${RESET}" "$*"
}

log_warn() {
	printf '%s[WARN]%s %s\n' "${YELLOW}" "${RESET}" "$*"
}

log_error() {
	printf '%s[ERROR]%s %s\n' "${RED}" "${RESET}" "$*" >&2
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

detect_os() {
	local uname_s
	uname_s="$(uname -s)"
	case "${uname_s}" in
	Linux*) printf 'linux' ;;
	Darwin*) printf 'darwin' ;;
	*)
		log_error "Unsupported OS: ${uname_s}"
		return 1
		;;
	esac
}

detect_arch() {
	local uname_m
	uname_m="$(uname -m)"
	case "${uname_m}" in
	x86_64 | amd64) printf 'x86_64' ;;
	aarch64 | arm64) printf 'arm64' ;;
	*)
		log_error "Unsupported architecture: ${uname_m}"
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Preflight checks — verify runtime requirements
# ---------------------------------------------------------------------------

preflight_check() {
	local failed=0

	# Bash 4+ required (associative arrays, [[ ]])
	if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
		log_error "bash 4+ required (found ${BASH_VERSION})"
		failed=1
	fi

	# jq required
	if ! command -v jq &>/dev/null; then
		log_error "jq is required but not found in PATH"
		log_error "Install: https://jqlang.github.io/jq/download/"
		failed=1
	fi

	# ~/.claude/ must be writable (create if absent)
	local claude_dir="${HOME}/.claude"
	if [[ ! -d "${claude_dir}" ]]; then
		if ! mkdir -p "${claude_dir}" 2>/dev/null; then
			log_error "Cannot create directory: ${claude_dir}"
			failed=1
		fi
	elif [[ ! -w "${claude_dir}" ]]; then
		log_error "No write permission: ${claude_dir}"
		failed=1
	fi

	if [[ "${failed}" -eq 1 ]]; then
		log_error "Preflight checks failed. Aborting."
		return 1
	fi

	return 0
}
