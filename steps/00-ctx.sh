#!/usr/bin/env bash
# steps/00-ctx.sh — Context initialization & preflight
# Source this file; do not execute directly.
# Must be sourced FIRST, before any other step.

# shellcheck disable=SC1091,SC2034,SC2154  # Cross-file globals (sourced context)

step_ctx() {
	log_header "0/11" "Context initialization & preflight"

	# ─── Resolve TEP_SCRIPT_DIR (root of the TEP repo) ──────────
	# This is set by the orchestrator before sourcing steps.
	if [[ -z "${TEP_SCRIPT_DIR:-}" ]]; then
		log_fail "TEP_SCRIPT_DIR not set — must be set by orchestrator"
		return 1
	fi

	# ─── Load .env safely ───────────────────────────────────────
	if [[ -f "${TEP_SCRIPT_DIR}/.env" ]]; then
		set -a
		# shellcheck disable=SC1091
		source "${TEP_SCRIPT_DIR}/.env"
		set +a
		log_ok ".env loaded"
	else
		log_info "No .env file found (using CLI args or defaults)"
	fi

	# ─── Resolve project directory ──────────────────────────────
	# Priority: CLI argument > PROJECT_AUDIT_DIR from .env > abort
	if [[ -z "${TEP_PROJECT_DIR:-}" ]]; then
		TEP_PROJECT_DIR="${PROJECT_AUDIT_DIR:-}"
	fi

	if [[ -z "${TEP_PROJECT_DIR:-}" ]]; then
		log_fail "No project path specified."
		log_fail "Usage: tep audit <project-path>"
		log_fail "   Or set PROJECT_AUDIT_DIR in .env"
		return 1
	fi

	# Validate project dir exists
	if ! dir_exists "$TEP_PROJECT_DIR"; then
		log_fail "Project directory not found: $TEP_PROJECT_DIR"
		return 1
	fi

	# Resolve to absolute path
	TEP_PROJECT_DIR="$(tep_realpath "$TEP_PROJECT_DIR")"
	TEP_PROJECT_NAME="$(basename -- "$TEP_PROJECT_DIR")"

	# ─── Output directory ───────────────────────────────────────
	# Default: out/ in TEP repo. Override with --out <dir>
	TEP_OUT_DIR="${TEP_OUT_DIR:-${TEP_SCRIPT_DIR}/out}"
	ensure_dir "$TEP_OUT_DIR"

	TEP_RESULT_FILE="${TEP_OUT_DIR}/RESULT.md"
	TEP_TMP_FILE="${TEP_OUT_DIR}/.tep_result.tmp"

	# ─── Timestamp ──────────────────────────────────────────────
	TEP_TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

	# ─── OS detection ───────────────────────────────────────────
	tep_detect_os
	log_info "OS detected: ${TEP_OS}"

	# ─── Dependency checks (preflight) ──────────────────────────
	local preflight_ok=true

	# Required
	tep_require "grep" "fail" || preflight_ok=false
	tep_require "find" "fail" || preflight_ok=false
	tep_require "wc" "fail"   || preflight_ok=false
	tep_require "awk" "fail"  || preflight_ok=false

	if ! "$preflight_ok"; then
		log_fail "Missing required dependencies — cannot continue"
		return 1
	fi

	# Optional (progressive enhancement)
	tep_check_jq  # sets TEP_HAS_JQ

	# Bash version check (need 4+ for ${var^^} and associative arrays)
	if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
		log_warn "Bash ${BASH_VERSION} detected — version 4+ recommended"
		log_warn "Some features (case conversion) may not work"
	fi

	# ─── Project-scoped paths ───────────────────────────────────
	TEP_CLAUDE_MD="${TEP_PROJECT_DIR}/CLAUDE.md"
	TEP_CLAUDE_DIR="${TEP_PROJECT_DIR}/.claude"

	# ─── Inventory flags (initialized, set by step_inventory) ───
	TEP_HAS_CLAUDE_MD=false
	TEP_HAS_CLAUDE_DIR=false
	TEP_HAS_SETTINGS=false
	TEP_HAS_SETTINGS_LOCAL=false
	TEP_HAS_MEMORY=false
	TEP_HAS_AGENTS=false
	TEP_HAS_SKILLS=false
	TEP_HAS_RULES=false
	TEP_SKILL_COUNT=0
	TEP_RULE_COUNT=0
	TEP_CLAUDE_MD_MISC_COUNT=0
	TEP_DOCS_COUNT=0

	# ─── Audit metrics (initialized, set by later steps) ────────
	TEP_CLAUDE_MD_WORDS=0
	TEP_CLAUDE_MD_TOKENS=0
	TEP_DUPLICATE_RISK=0
	TEP_DUPLICATE_DETAILS=""
	TEP_GITIGNORE_ISSUES=0
	TEP_CLAUDEIGNORE_ISSUES=0
	TEP_HOOKS_ISSUES=0
	TEP_HOOK_COUNT=0
	TEP_MCP_COUNT=0
	TEP_FS_HOOK_COUNT=0
	TEP_SCORE=0
	TEP_MAX_SCORE=8
	TEP_RECOS=""

	# ─── Session stats (initialized, set by step_session_stats) ─
	TEP_HAS_SESSION=false
	TEP_INPUT_TOKENS=0
	TEP_OUTPUT_TOKENS=0
	TEP_CACHE_READ=0
	TEP_CACHE_CREATION=0
	TEP_CACHE_HIT_RATE=0
	TEP_COST_USD="N/A"
	TEP_TOP_FILES=""
	TEP_TOP_ACTIONS=""

	# ─── Evals path ─────────────────────────────────────────────
	TEP_EVALS_DIR="${TEP_SCRIPT_DIR}/evals"
	TEP_HISTORY_FILE="${TEP_EVALS_DIR}/history.jsonl"

	# ─── Banner ─────────────────────────────────────────────────
	log_banner

	# ─── Initialize report buffer (before any step writes) ─────
	report_init

	log_ok "Context initialized"
	return 0
}