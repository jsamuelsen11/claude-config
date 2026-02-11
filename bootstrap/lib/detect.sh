#!/usr/bin/env bash
# detect.sh — Language and tech-stack detection from project files.
# Uses file/directory existence checks; minimal content parsing for docker-compose databases.
# Source this file; do not execute directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/detect.sh"

# Sourcing guard
[[ -n "${_CCFG_DETECT_LOADED:-}" ]] && return
_CCFG_DETECT_LOADED=1

# Source common.sh for logging and output symbols
_CCFG_DETECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_CCFG_DETECT_DIR}/common.sh"

# ---------------------------------------------------------------------------
# _detect_has_file <dir> <filename...>
# Return 0 if any of the named files exist in <dir>.
# ---------------------------------------------------------------------------
_detect_has_file() {
	local dir="$1"
	shift
	local name
	for name in "$@"; do
		[[ -f "${dir}/${name}" ]] && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------
# _detect_has_dir <dir> <dirname...>
# Return 0 if any of the named directories exist in <dir>.
# ---------------------------------------------------------------------------
_detect_has_dir() {
	local dir="$1"
	shift
	local name
	for name in "$@"; do
		[[ -d "${dir}/${name}" ]] && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------
# _detect_has_glob <dir> <pattern> [max_depth]
# Return 0 if any files matching pattern exist (using find with depth limit).
# ---------------------------------------------------------------------------
_detect_has_glob() {
	local dir="$1"
	local pattern="$2"
	local max_depth="${3:-2}"

	# Use find for glob matching with depth control
	[[ -n "$(find "${dir}" -maxdepth "${max_depth}" -name "${pattern}" -print -quit 2>/dev/null)" ]]
}

# ---------------------------------------------------------------------------
# _detect_compose_has_image <dir> <image_pattern>
# Check if any docker-compose file references the given image.
# ---------------------------------------------------------------------------
_detect_compose_has_image() {
	local dir="$1"
	local image_pattern="$2"

	local compose_file
	for compose_file in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
		if [[ -f "${dir}/${compose_file}" ]]; then
			if grep -qE "image:.*${image_pattern}" "${dir}/${compose_file}" 2>/dev/null; then
				return 0
			fi
		fi
	done
	return 1
}

# ---------------------------------------------------------------------------
# _detect_typescript_signals <dir>
# Check for TypeScript-specific signals in a directory with package.json.
# ---------------------------------------------------------------------------
_detect_typescript_signals() {
	local dir="$1"

	# tsconfig.json is a strong signal
	[[ -f "${dir}/tsconfig.json" ]] && return 0

	# Check for typescript in package.json dependencies
	if [[ -f "${dir}/package.json" ]]; then
		if grep -qE '"typescript"' "${dir}/package.json" 2>/dev/null; then
			return 0
		fi
	fi

	return 1
}

# ---------------------------------------------------------------------------
# detect_languages <dir>
# Return space-separated list of detected language/tech identifiers.
# Defaults to current directory if <dir> not provided.
# ---------------------------------------------------------------------------
detect_languages() {
	local dir="${1:-.}"
	local -a detected=()

	# Python
	if _detect_has_file "${dir}" "pyproject.toml" "setup.py" "setup.cfg" "requirements.txt" "Pipfile"; then
		detected+=("python")
	fi

	# Go
	if _detect_has_file "${dir}" "go.mod"; then
		detected+=("golang")
	fi

	# TypeScript vs JavaScript
	if _detect_has_file "${dir}" "package.json"; then
		if _detect_typescript_signals "${dir}"; then
			detected+=("typescript")
		else
			detected+=("javascript")
		fi
	fi

	# Java
	if _detect_has_file "${dir}" "pom.xml" "build.gradle" "build.gradle.kts"; then
		detected+=("java")
	fi

	# Rust
	if _detect_has_file "${dir}" "Cargo.toml"; then
		detected+=("rust")
	fi

	# C#
	if _detect_has_glob "${dir}" "*.csproj" 2 || _detect_has_glob "${dir}" "*.sln" 2; then
		detected+=("csharp")
	fi

	# Shell
	if _detect_has_glob "${dir}" "*.sh" 1 ||
		{ [[ -d "${dir}/scripts" ]] && _detect_has_glob "${dir}/scripts" "*.sh" 1; }; then
		detected+=("shell")
	fi

	# Docker
	if _detect_has_file "${dir}" "Dockerfile" "docker-compose.yml" "docker-compose.yaml" "compose.yml"; then
		detected+=("docker")
	fi

	# Kubernetes
	if _detect_has_dir "${dir}" "k8s" "kubernetes"; then
		detected+=("kubernetes")
	fi

	# GitHub Actions
	if [[ -d "${dir}/.github/workflows" ]]; then
		detected+=("github-actions")
	fi

	# MySQL
	if _detect_compose_has_image "${dir}" "mysql"; then
		detected+=("mysql")
	fi

	# PostgreSQL
	if _detect_compose_has_image "${dir}" "postgres"; then
		detected+=("postgresql")
	fi

	# MongoDB
	if _detect_compose_has_image "${dir}" "mongo"; then
		detected+=("mongodb")
	fi

	# Redis
	if _detect_compose_has_image "${dir}" "redis"; then
		detected+=("redis")
	fi

	# SQLite
	if _detect_has_glob "${dir}" "*.db" 1 ||
		_detect_has_glob "${dir}" "*.sqlite" 1 ||
		_detect_has_glob "${dir}" "*.sqlite3" 1; then
		detected+=("sqlite")
	fi

	# Markdown
	if _detect_has_dir "${dir}" "docs" || _detect_has_file "${dir}" "README.md"; then
		detected+=("markdown")
	fi

	# Output space-separated list
	printf '%s' "${detected[*]}"
}

# ---------------------------------------------------------------------------
# detect_has <dir> <language>
# Check if specific language/tech is detected. Returns 0 if found, 1 if not.
# ---------------------------------------------------------------------------
detect_has() {
	local dir="${1:-.}"
	local language="$2"
	local detected
	detected="$(detect_languages "${dir}")"

	local lang
	for lang in ${detected}; do
		[[ "${lang}" == "${language}" ]] && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------
# detect_summary <dir>
# Print formatted detection results with styled output.
# ---------------------------------------------------------------------------
detect_summary() {
	local dir="${1:-.}"
	local detected
	detected="$(detect_languages "${dir}")"

	if [[ -z "${detected}" ]]; then
		log_info "No languages or technologies detected in: ${dir}"
		return 0
	fi

	printf '  %sDetection%s  %s\n' "${BOLD}" "${RESET}" "${dir}"

	local lang trigger
	for lang in ${detected}; do
		trigger="$(_detect_trigger_file "${dir}" "${lang}")"
		printf '    %s%s%s %-16s %s%s%s\n' \
			"${GREEN}" "${CHECK}" "${RESET}" \
			"${lang}" \
			"${DIM}" "${trigger}" "${RESET}"
	done
}

# ---------------------------------------------------------------------------
# _detect_trigger_file <dir> <language>
# Return the file/directory that triggered detection (for display).
# ---------------------------------------------------------------------------
_detect_trigger_file() {
	local dir="$1"
	local lang="$2"

	case "${lang}" in
	python)
		for f in pyproject.toml setup.py setup.cfg requirements.txt Pipfile; do
			[[ -f "${dir}/${f}" ]] && {
				printf '%s' "${f}"
				return
			}
		done
		;;
	golang)
		printf 'go.mod'
		;;
	typescript)
		[[ -f "${dir}/tsconfig.json" ]] && {
			printf 'tsconfig.json'
			return
		}
		printf 'package.json + typescript'
		;;
	javascript)
		printf 'package.json'
		;;
	java)
		for f in pom.xml build.gradle build.gradle.kts; do
			[[ -f "${dir}/${f}" ]] && {
				printf '%s' "${f}"
				return
			}
		done
		;;
	rust)
		printf 'Cargo.toml'
		;;
	csharp)
		printf '*.csproj / *.sln'
		;;
	shell)
		printf '*.sh files'
		;;
	docker)
		for f in Dockerfile docker-compose.yml docker-compose.yaml compose.yml; do
			[[ -f "${dir}/${f}" ]] && {
				printf '%s' "${f}"
				return
			}
		done
		;;
	kubernetes)
		for d in k8s kubernetes; do
			[[ -d "${dir}/${d}" ]] && {
				printf '%s/' "${d}"
				return
			}
		done
		;;
	github-actions)
		printf '.github/workflows/'
		;;
	mysql)
		printf 'docker-compose: mysql image'
		;;
	postgresql)
		printf 'docker-compose: postgres image'
		;;
	mongodb)
		printf 'docker-compose: mongo image'
		;;
	redis)
		printf 'docker-compose: redis image'
		;;
	sqlite)
		printf '*.db / *.sqlite files'
		;;
	markdown)
		[[ -d "${dir}/docs" ]] && {
			printf 'docs/'
			return
		}
		printf 'README.md'
		;;
	*)
		printf '(unknown)'
		;;
	esac
}
