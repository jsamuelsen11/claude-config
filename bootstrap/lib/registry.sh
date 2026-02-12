#!/usr/bin/env bash
# registry.sh — Third-party plugin registry for ccfg-plugins.sh.
# Maps languages/categories to recommended third-party Claude Code plugins.
# Source this file; do not execute directly.
#
# Registry format: parallel associative arrays indexed by unique plugin key.
# Key format: <source>/<plugin-name> (e.g. "official/pyright-lsp")
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/registry.sh"

# shellcheck disable=SC2034  # Arrays and constants are exported for consumers.

# Sourcing guard — prevent double-sourcing.
[[ -n "${_CCFG_REGISTRY_LOADED:-}" ]] && return
_CCFG_REGISTRY_LOADED=1

# ---------------------------------------------------------------------------
# Registry version (for update detection)
# ---------------------------------------------------------------------------

export CCFG_REGISTRY_VERSION="1.0.0"

# ---------------------------------------------------------------------------
# Plugin attribute arrays — all indexed by the same key.
# ---------------------------------------------------------------------------

# Plugin install name (used in `claude plugin install <name>@<marketplace>`)
declare -A REG_NAME=()

# Short description (shown in interactive UI)
declare -A REG_DESC=()

# Marketplace name (for install command)
declare -A REG_MARKETPLACE=()

# Category: lsp | general | integration | skills | issue-tracking | style
declare -A REG_CATEGORY=()

# Tier: auto | suggest | info
#   auto    — installed in --auto mode, pre-selected interactively
#   suggest — shown but not pre-selected, skipped in --auto
#   info    — only visible via --list
declare -A REG_TIER=()

# Detection signal: detect.sh language identifier that triggers this plugin.
#   "always"   — no detection required (universal)
#   "frontend" — triggered by frontend file signals (*.tsx, *.vue, etc.)
#   "beads"    — triggered by .beads/ directory
#   <lang-id>  — triggered by language detection (e.g. "python", "rust")
#   ""         — manual-only (no detection trigger)
declare -A REG_DETECT=()

# For LSP plugins: language this LSP serves (for overlap grouping).
# Empty for non-LSP plugins.
declare -A REG_LSP_LANG=()

# For overlapping LSPs: "official" or "community" or "" (no overlap).
declare -A REG_LSP_SOURCE=()

# For overlapping LSPs: "preferred" or "alternative" or "".
declare -A REG_LSP_PREFERENCE=()

# ---------------------------------------------------------------------------
# _reg_add — register a plugin entry
# ---------------------------------------------------------------------------
_reg_add() {
	local key="$1"
	REG_NAME["${key}"]="$2"
	REG_DESC["${key}"]="$3"
	REG_MARKETPLACE["${key}"]="$4"
	REG_CATEGORY["${key}"]="$5"
	REG_TIER["${key}"]="$6"
	REG_DETECT["${key}"]="$7"
	REG_LSP_LANG["${key}"]="${8:-}"
	REG_LSP_SOURCE["${key}"]="${9:-}"
	REG_LSP_PREFERENCE["${key}"]="${10:-}"
}

# ===================================================================
# LSP PLUGINS — DUAL COVERAGE (official + community)
# ===================================================================
# For each language with plugins in both claude-plugins-official and
# claude-code-lsps, both are registered as tier=suggest. The user
# picks one. In --auto mode, overlapping LSPs are skipped entirely.

# --- TypeScript/JavaScript ---
_reg_add "official/typescript-lsp" \
	"typescript-lsp" \
	"TypeScript/JS language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "typescript" \
	"typescript" "official" "preferred"

_reg_add "community/vtsls" \
	"vtsls" \
	"TypeScript/JS language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "typescript" \
	"typescript" "community" "alternative"

# --- Python ---
_reg_add "official/pyright-lsp" \
	"pyright-lsp" \
	"Python type checker and language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "python" \
	"python" "official" "preferred"

_reg_add "community/pyright" \
	"pyright" \
	"Python type checker and language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "python" \
	"python" "community" "alternative"

# --- Go ---
_reg_add "official/gopls-lsp" \
	"gopls-lsp" \
	"Go language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "golang" \
	"golang" "official" "preferred"

_reg_add "community/gopls" \
	"gopls" \
	"Go language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "golang" \
	"golang" "community" "alternative"

# --- Rust ---
_reg_add "official/rust-analyzer-lsp" \
	"rust-analyzer-lsp" \
	"Rust language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "rust" \
	"rust" "official" "preferred"

_reg_add "community/rust-analyzer" \
	"rust-analyzer" \
	"Rust language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "rust" \
	"rust" "community" "alternative"

# --- C/C++ ---
_reg_add "official/clangd-lsp" \
	"clangd-lsp" \
	"C/C++ language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "cpp" \
	"cpp" "official" "preferred"

_reg_add "community/clangd" \
	"clangd" \
	"C/C++ language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "cpp" \
	"cpp" "community" "alternative"

# --- PHP ---
# Community preferred: Intelephense is the industry-standard PHP LSP.
_reg_add "official/php-lsp" \
	"php-lsp" \
	"PHP language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "php" \
	"php" "official" "alternative"

_reg_add "community/intelephense" \
	"intelephense" \
	"PHP language server — Intelephense (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "php" \
	"php" "community" "preferred"

# --- Swift ---
_reg_add "official/swift-lsp" \
	"swift-lsp" \
	"Swift language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "swift" \
	"swift" "official" "preferred"

_reg_add "community/sourcekit-lsp" \
	"sourcekit-lsp" \
	"Swift language server — SourceKit (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "swift" \
	"swift" "community" "alternative"

# --- Kotlin ---
_reg_add "official/kotlin-lsp" \
	"kotlin-lsp" \
	"Kotlin language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "kotlin" \
	"kotlin" "official" "preferred"

_reg_add "community/kotlin-lsp-community" \
	"kotlin-lsp" \
	"Kotlin language server (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "kotlin" \
	"kotlin" "community" "alternative"

# --- C# ---
# Community preferred: OmniSharp is the industry-standard C# LSP.
_reg_add "official/csharp-lsp" \
	"csharp-lsp" \
	"C# language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "csharp" \
	"csharp" "official" "alternative"

_reg_add "community/omnisharp" \
	"omnisharp" \
	"C# language server — OmniSharp (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "csharp" \
	"csharp" "community" "preferred"

# --- Java ---
_reg_add "official/jdtls-lsp" \
	"jdtls-lsp" \
	"Java language server — Eclipse JDT.LS (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "java" \
	"java" "official" "preferred"

_reg_add "community/jdtls" \
	"jdtls" \
	"Java language server — Eclipse JDT.LS (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "java" \
	"java" "community" "alternative"

# --- Lua ---
_reg_add "official/lua-lsp" \
	"lua-lsp" \
	"Lua language server (official)" \
	"claude-plugins-official" \
	"lsp" "suggest" "lua" \
	"lua" "official" "preferred"

_reg_add "community/lua-language-server" \
	"lua-language-server" \
	"Lua language server — sumneko (community)" \
	"claude-code-lsps" \
	"lsp" "suggest" "lua" \
	"lua" "community" "alternative"

# ===================================================================
# LSP PLUGINS — COMMUNITY ONLY (no official equivalent)
# ===================================================================
# Single-source LSPs: tier=auto (installed automatically when detected).

_reg_add "community/bash-language-server" \
	"bash-language-server" \
	"Bash/Shell language server" \
	"claude-code-lsps" \
	"lsp" "auto" "shell" \
	"shell" "" ""

_reg_add "community/clojure-lsp" \
	"clojure-lsp" \
	"Clojure language server" \
	"claude-code-lsps" \
	"lsp" "auto" "clojure" \
	"clojure" "" ""

_reg_add "community/dart-analyzer" \
	"dart-analyzer" \
	"Dart/Flutter language server" \
	"claude-code-lsps" \
	"lsp" "auto" "dart" \
	"dart" "" ""

_reg_add "community/elixir-ls" \
	"elixir-ls" \
	"Elixir language server" \
	"claude-code-lsps" \
	"lsp" "auto" "elixir" \
	"elixir" "" ""

_reg_add "community/gleam" \
	"gleam" \
	"Gleam language server" \
	"claude-code-lsps" \
	"lsp" "auto" "gleam" \
	"gleam" "" ""

_reg_add "community/nixd" \
	"nixd" \
	"Nix language server" \
	"claude-code-lsps" \
	"lsp" "auto" "nix" \
	"nix" "" ""

_reg_add "community/ocaml-lsp" \
	"ocaml-lsp" \
	"OCaml language server" \
	"claude-code-lsps" \
	"lsp" "auto" "ocaml" \
	"ocaml" "" ""

_reg_add "community/solargraph" \
	"solargraph" \
	"Ruby language server — Solargraph" \
	"claude-code-lsps" \
	"lsp" "auto" "ruby" \
	"ruby" "" ""

_reg_add "community/terraform-ls" \
	"terraform-ls" \
	"Terraform language server" \
	"claude-code-lsps" \
	"lsp" "auto" "terraform" \
	"terraform" "" ""

_reg_add "community/yaml-language-server" \
	"yaml-language-server" \
	"YAML language server" \
	"claude-code-lsps" \
	"lsp" "auto" "yaml" \
	"yaml" "" ""

_reg_add "community/zls" \
	"zls" \
	"Zig language server" \
	"claude-code-lsps" \
	"lsp" "auto" "zig" \
	"zig" "" ""

# ===================================================================
# GENERAL PLUGINS — AUTO TIER
# ===================================================================
# High-confidence universal plugins. Installed in --auto mode.

_reg_add "official/context7" \
	"context7" \
	"Up-to-date library documentation retrieval" \
	"claude-plugins-official" \
	"general" "auto" "always" \
	"" "" ""

_reg_add "official/commit-commands" \
	"commit-commands" \
	"Structured git commit workflow" \
	"claude-plugins-official" \
	"general" "auto" "always" \
	"" "" ""

_reg_add "skills/document-skills" \
	"document-skills" \
	"Office document handling (xlsx, docx, pptx, pdf)" \
	"anthropic-agent-skills" \
	"skills" "auto" "always" \
	"" "" ""

# ===================================================================
# GENERAL PLUGINS — SUGGEST TIER
# ===================================================================
# Valuable but requires active selection.

_reg_add "official/code-review" \
	"code-review" \
	"Automated PR review with specialized agents" \
	"claude-plugins-official" \
	"general" "suggest" "always" \
	"" "" ""

_reg_add "official/feature-dev" \
	"feature-dev" \
	"Feature development workflow and code exploration" \
	"claude-plugins-official" \
	"general" "suggest" "always" \
	"" "" ""

_reg_add "official/security-guidance" \
	"security-guidance" \
	"Security vulnerability scanning on file edits" \
	"claude-plugins-official" \
	"general" "suggest" "always" \
	"" "" ""

_reg_add "official/serena" \
	"serena" \
	"Semantic code navigation and persistent memory" \
	"claude-plugins-official" \
	"general" "suggest" "always" \
	"" "" ""

_reg_add "official/greptile" \
	"greptile" \
	"AI-powered code review and codebase search" \
	"claude-plugins-official" \
	"general" "suggest" "always" \
	"" "" ""

_reg_add "official/frontend-design" \
	"frontend-design" \
	"Production-grade frontend UI generation" \
	"claude-plugins-official" \
	"general" "suggest" "frontend" \
	"" "" ""

_reg_add "official/playwright" \
	"playwright" \
	"Browser testing and automation" \
	"claude-plugins-official" \
	"general" "suggest" "frontend" \
	"" "" ""

# ===================================================================
# GENERAL PLUGINS — INFO TIER
# ===================================================================
# Discoverable via --list only.

_reg_add "official/ralph-loop" \
	"ralph-loop" \
	"Autonomous iterative development loops" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/firecrawl" \
	"firecrawl" \
	"Web scraping and crawling for LLM-ready content" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/pr-review-toolkit" \
	"pr-review-toolkit" \
	"Comprehensive PR review agents" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/code-simplifier" \
	"code-simplifier" \
	"Code clarity and complexity reduction" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/hookify" \
	"hookify" \
	"Custom hook creation for behavior prevention" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/plugin-dev" \
	"plugin-dev" \
	"Claude Code plugin development toolkit" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/claude-code-setup" \
	"claude-code-setup" \
	"Tailored automation recommendations" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/claude-md-management" \
	"claude-md-management" \
	"CLAUDE.md maintenance and knowledge tracking" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/agent-sdk-dev" \
	"agent-sdk-dev" \
	"Anthropic Agent SDK development kit" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/playground" \
	"playground" \
	"Interactive HTML playgrounds with live preview" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

_reg_add "official/superpowers" \
	"superpowers" \
	"Brainstorming, debugging, and TDD techniques" \
	"claude-plugins-official" \
	"general" "info" "" \
	"" "" ""

# ===================================================================
# STYLE PLUGINS — INFO TIER
# ===================================================================
# Change Claude's output behavior. Personal preference.

_reg_add "official/explanatory-output-style" \
	"explanatory-output-style" \
	"Educational insights about implementation choices" \
	"claude-plugins-official" \
	"style" "info" "" \
	"" "" ""

_reg_add "official/learning-output-style" \
	"learning-output-style" \
	"Interactive learning mode at decision points" \
	"claude-plugins-official" \
	"style" "info" "" \
	"" "" ""

# ===================================================================
# INTEGRATION PLUGINS — INFO TIER
# ===================================================================
# External service integrations. Require accounts/API keys.

_reg_add "official/github" \
	"github" \
	"GitHub API integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/gitlab" \
	"gitlab" \
	"GitLab API integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/linear" \
	"linear" \
	"Linear issue tracking integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/asana" \
	"asana" \
	"Asana project management integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/slack" \
	"slack" \
	"Slack messaging integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/figma" \
	"figma" \
	"Figma design platform integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/notion" \
	"notion" \
	"Notion workspace integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/sentry" \
	"sentry" \
	"Sentry error monitoring integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/vercel" \
	"vercel" \
	"Vercel deployment platform integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/stripe" \
	"stripe" \
	"Stripe payments integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/firebase" \
	"firebase" \
	"Google Firebase backend integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/supabase" \
	"supabase" \
	"Supabase backend integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/pinecone" \
	"pinecone" \
	"Pinecone vector database integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/posthog" \
	"posthog" \
	"PostHog analytics integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/circleback" \
	"circleback" \
	"CircleBack meeting intelligence integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/coderabbit" \
	"coderabbit" \
	"CodeRabbit AI code review integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/huggingface-skills" \
	"huggingface-skills" \
	"HuggingFace model hub integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/sonatype-guide" \
	"sonatype-guide" \
	"Sonatype dependency security intelligence" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/atlassian" \
	"atlassian" \
	"Jira and Confluence integration" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

_reg_add "official/laravel-boost" \
	"laravel-boost" \
	"Laravel development toolkit" \
	"claude-plugins-official" \
	"integration" "info" "" \
	"" "" ""

# ===================================================================
# SKILLS — INFO TIER
# ===================================================================

_reg_add "skills/example-skills" \
	"example-skills" \
	"Example skills (algorithmic art, brand guidelines, etc.)" \
	"anthropic-agent-skills" \
	"skills" "info" "" \
	"" "" ""

# ===================================================================
# ISSUE TRACKING — SUGGEST TIER
# ===================================================================

_reg_add "beads/beads" \
	"beads" \
	"AI-supervised issue tracker for coding workflows" \
	"beads-marketplace" \
	"issue-tracking" "suggest" "beads" \
	"" "" ""

# ===================================================================
# Registry query functions
# ===================================================================

# reg_all_keys — return all registered plugin keys (one per line)
reg_all_keys() {
	printf '%s\n' "${!REG_NAME[@]}"
}

# reg_keys_by_tier <tier> — return keys matching the given tier
reg_keys_by_tier() {
	local tier="$1"
	local key
	for key in "${!REG_TIER[@]}"; do
		[[ "${REG_TIER[${key}]}" == "${tier}" ]] && printf '%s\n' "${key}"
	done
}

# reg_keys_by_detect <signal> — return keys triggered by a detection signal
reg_keys_by_detect() {
	local signal="$1"
	local key
	for key in "${!REG_DETECT[@]}"; do
		[[ "${REG_DETECT[${key}]}" == "${signal}" ]] && printf '%s\n' "${key}"
	done
}

# reg_keys_by_category <category> — return keys matching the given category
reg_keys_by_category() {
	local category="$1"
	local key
	for key in "${!REG_CATEGORY[@]}"; do
		[[ "${REG_CATEGORY[${key}]}" == "${category}" ]] && printf '%s\n' "${key}"
	done
}

# reg_lsp_languages — return unique LSP language identifiers
reg_lsp_languages() {
	local key
	local -A seen=()
	for key in "${!REG_LSP_LANG[@]}"; do
		local lang="${REG_LSP_LANG[${key}]}"
		if [[ -n "${lang}" && -z "${seen[${lang}]:-}" ]]; then
			printf '%s\n' "${lang}"
			seen["${lang}"]=1
		fi
	done
}

# reg_lsp_pair <lang> — return keys for all LSP plugins serving a language
reg_lsp_pair() {
	local lang="$1"
	local key
	for key in "${!REG_LSP_LANG[@]}"; do
		[[ "${REG_LSP_LANG[${key}]}" == "${lang}" ]] && printf '%s\n' "${key}"
	done
}

# reg_lsp_overlap_langs — return languages with >1 LSP plugin (one per line)
reg_lsp_overlap_langs() {
	local key
	local -A count=()
	for key in "${!REG_LSP_LANG[@]}"; do
		local lang="${REG_LSP_LANG[${key}]}"
		[[ -n "${lang}" ]] && count["${lang}"]=$((${count["${lang}"]:-0} + 1))
	done
	local lang
	for lang in "${!count[@]}"; do
		[[ "${count[${lang}]}" -gt 1 ]] && printf '%s\n' "${lang}"
	done
}

# reg_lsp_preferred <lang> — return the preferred key for a language with
# overlapping LSPs. Returns the key with preference="preferred", or the first
# key found if none is marked.
reg_lsp_preferred() {
	local lang="$1"
	local key first=""
	for key in "${!REG_LSP_LANG[@]}"; do
		[[ "${REG_LSP_LANG[${key}]}" != "${lang}" ]] && continue
		[[ -z "${first}" ]] && first="${key}"
		[[ "${REG_LSP_PREFERENCE[${key}]}" == "preferred" ]] && {
			printf '%s' "${key}"
			return 0
		}
	done
	printf '%s' "${first}"
}

# reg_lsp_alternative <lang> — return the alternative key for a language with
# overlapping LSPs. Returns the key with preference="alternative", or the first
# non-preferred key found.
reg_lsp_alternative() {
	local lang="$1"
	local key first=""
	for key in "${!REG_LSP_LANG[@]}"; do
		[[ "${REG_LSP_LANG[${key}]}" != "${lang}" ]] && continue
		[[ -z "${first}" ]] && first="${key}"
		[[ "${REG_LSP_PREFERENCE[${key}]}" == "alternative" ]] && {
			printf '%s' "${key}"
			return 0
		}
	done
	printf '%s' "${first}"
}

# reg_is_lsp_overlap <key> — return 0 if this key's language has >1 LSP plugin.
reg_is_lsp_overlap() {
	local key="$1"
	local lsp_lang="${REG_LSP_LANG[${key}]}"
	[[ -z "${lsp_lang}" ]] && return 1
	local k lsp_count=0
	for k in "${!REG_LSP_LANG[@]}"; do
		[[ "${REG_LSP_LANG[${k}]}" == "${lsp_lang}" ]] && lsp_count=$((lsp_count + 1))
	done
	[[ "${lsp_count}" -gt 1 ]]
}

# reg_install_cmd <key> — return the claude plugin install command
reg_install_cmd() {
	local key="$1"
	printf 'claude plugin install %s@%s' \
		"${REG_NAME[${key}]}" "${REG_MARKETPLACE[${key}]}"
}

# reg_count — return total number of registered plugins
reg_count() {
	printf '%d\n' "${#REG_NAME[@]}"
}
