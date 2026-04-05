#!/usr/bin/env bash
# lib/log.sh — Logging utilities for TEP
# Source this file; do not execute directly.
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Guard against double-sourcing
[[ -n "${_TEP_LOG_LOADED:-}" ]] && return 0
_TEP_LOG_LOADED=1

# ─── Color support ───────────────────────────────────────────
# Auto-detect: disable colors if not a TTY, or if TEP_NO_COLOR / NO_COLOR is set.
# Respects https://no-color.org/ convention.
_tep_colors_enabled() {
	[[ -z "${TEP_NO_COLOR:-}" ]] \
		&& [[ -z "${NO_COLOR:-}" ]] \
		&& [[ -t 1 ]] \
		&& [[ -t 2 ]]
}

if _tep_colors_enabled; then
	TEP_RED=$'\033[0;31m'
	TEP_GREEN=$'\033[0;32m'
	TEP_YELLOW=$'\033[1;33m'
	TEP_BLUE=$'\033[0;34m'
	TEP_BOLD=$'\033[1m'
	TEP_NC=$'\033[0m'
else
	TEP_RED=''
	TEP_GREEN=''
	TEP_YELLOW=''
	TEP_BLUE=''
	TEP_BOLD=''
	TEP_NC=''
fi

# ─── ASCII markers (portable, no emoji) ──────────────────────
TEP_OK_MARK='[OK]'
TEP_WARN_MARK='[WARN]'
TEP_FAIL_MARK='[FAIL]'
TEP_INFO_MARK='[INFO]'

# ─── Markdown-safe markers (for RESULT.md output) ────────────
TEP_MD_OK='✅'
TEP_MD_WARN='⚠️'
TEP_MD_FAIL='❌'
TEP_MD_INFO='ℹ️'

# ─── Step context (set by orchestrator before each step) ─────
TEP_CURRENT_STEP=""

# Internal: build prefix from current step
_tep_log_prefix() {
	if [[ -n "${TEP_CURRENT_STEP:-}" ]]; then
		printf '[%s] ' "$TEP_CURRENT_STEP"
	fi
}

# ─── Public logging functions ────────────────────────────────
# All write to stderr so stdout stays clean for pipes/captures.

log_ok() {
	local prefix
	prefix="$(_tep_log_prefix)"
	printf '%b\n' "${TEP_GREEN}${TEP_OK_MARK}${TEP_NC} ${prefix}$*" >&2
}

log_warn() {
	local prefix
	prefix="$(_tep_log_prefix)"
	printf '%b\n' "${TEP_YELLOW}${TEP_WARN_MARK}${TEP_NC} ${prefix}$*" >&2
}

log_fail() {
	local prefix
	prefix="$(_tep_log_prefix)"
	printf '%b\n' "${TEP_RED}${TEP_FAIL_MARK}${TEP_NC} ${prefix}$*" >&2
}

log_info() {
	local prefix
	prefix="$(_tep_log_prefix)"
	printf '%b\n' "${TEP_BLUE}${TEP_INFO_MARK}${TEP_NC} ${prefix}$*" >&2
}

# Section header: [1/11] Title
log_header() {
	local step_num="${1:-}"
	local title="${2:-}"
	printf '\n%b\n' "${TEP_GREEN}[${step_num}] ${title}${TEP_NC}" >&2
}

# Indented key-value: "   CLAUDE.md              : [OK]"
log_detail() {
	local label="$1"
	local value="$2"
	printf '   %-30s : %s\n' "$label" "$value" >&2
}

# Startup banner
log_banner() {
	printf '%b\n' "${TEP_GREEN}═══ TEP — Audit & Optimize ═══${TEP_NC}" >&2
	printf 'Project: %b (%s)\n' "${TEP_GREEN}${TEP_PROJECT_NAME:-unknown}${TEP_NC}" "${TEP_PROJECT_DIR:-unknown}" >&2
	printf 'Output:  %s\n' "${TEP_RESULT_FILE:-unknown}" >&2
	printf '%s\n' '---' >&2
}

# Step summary line: "   TOTAL : ~1234 tokens"
log_summary() {
	local label="$1"
	local value="$2"
	printf '   %b\n' "${TEP_GREEN}${label} : ${value}${TEP_NC}" >&2
}

# Separator line
log_separator() {
	printf '   %s\n' '────────────────────────' >&2
}