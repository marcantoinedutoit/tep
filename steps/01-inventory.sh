#!/usr/bin/env bash
# steps/01-inventory.sh — Claude Code configuration inventory
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_inventory() {
	log_header "1/11" "Claude Code configuration inventory"

	# ─── Core files detection ───────────────────────────────────
	file_exists "$TEP_CLAUDE_MD"                          && TEP_HAS_CLAUDE_MD=true
	dir_exists  "$TEP_CLAUDE_DIR"                         && TEP_HAS_CLAUDE_DIR=true
	file_exists "${TEP_CLAUDE_DIR}/settings.json"          && TEP_HAS_SETTINGS=true
	file_exists "${TEP_CLAUDE_DIR}/settings.local.json"    && TEP_HAS_SETTINGS_LOCAL=true
	file_exists "${TEP_CLAUDE_DIR}/MEMORY.md"              && TEP_HAS_MEMORY=true

	# AGENTS.md can be in .claude/ or project root
	if file_exists "${TEP_CLAUDE_DIR}/AGENTS.md" || file_exists "${TEP_PROJECT_DIR}/AGENTS.md"; then
		TEP_HAS_AGENTS=true
	fi

	# Skills + rules directories
	dir_exists "${TEP_CLAUDE_DIR}/skills" && TEP_HAS_SKILLS=true
	dir_exists "${TEP_CLAUDE_DIR}/rules"  && TEP_HAS_RULES=true

	# ─── Counts (single find per directory) ─────────────────────
	if "$TEP_HAS_CLAUDE_DIR"; then
		TEP_CLAUDE_MD_MISC_COUNT=$(find "$TEP_CLAUDE_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
	fi

	if "$TEP_HAS_SKILLS"; then
		TEP_SKILL_COUNT=$(find "${TEP_CLAUDE_DIR}/skills" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
	fi

	if "$TEP_HAS_RULES"; then
		TEP_RULE_COUNT=$(find "${TEP_CLAUDE_DIR}/rules" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
	fi

	if dir_exists "${TEP_PROJECT_DIR}/docs"; then
		TEP_DOCS_COUNT=$(find "${TEP_PROJECT_DIR}/docs" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
	fi

	# ─── Terminal output ────────────────────────────────────────
	_si() { if "$1"; then echo "$TEP_OK_MARK"; else echo "${2:--}"; fi; }

	log_detail "CLAUDE.md"                "$(_si "$TEP_HAS_CLAUDE_MD" FAIL)"
	log_detail ".claude/"                 "$(_si "$TEP_HAS_CLAUDE_DIR" FAIL)"
	log_detail ".claude/settings.json"    "$(_si "$TEP_HAS_SETTINGS" '-')"
	log_detail ".claude/settings.local"   "$(_si "$TEP_HAS_SETTINGS_LOCAL" '-')"
	log_detail ".claude/MEMORY.md"        "$(_si "$TEP_HAS_MEMORY" '-')"
	log_detail "AGENTS.md"                "$(_si "$TEP_HAS_AGENTS" '-')"

	if "$TEP_HAS_SKILLS"; then
		log_detail ".claude/skills/*.md" "${TEP_OK_MARK} ${TEP_SKILL_COUNT} file(s)"
	else
		log_detail ".claude/skills/*.md" "-"
	fi

	if "$TEP_HAS_RULES"; then
		log_detail ".claude/rules/*.md" "${TEP_OK_MARK} ${TEP_RULE_COUNT} file(s)"
	else
		log_detail ".claude/rules/*.md" "-"
	fi

	log_detail ".claude/**/*.md (total)" "${TEP_CLAUDE_MD_MISC_COUNT} file(s)"
	log_detail "docs/*.md"               "${TEP_DOCS_COUNT} file(s)"

	# ─── Report section ─────────────────────────────────────────
	report_section "1" "Inventory"
	report_table_header "File" "Status"

	_report_status() {
		if "$1"; then echo "${TEP_MD_OK} found"; else echo "${TEP_MD_FAIL} **MISSING**"; fi
	}
	_report_status_opt() {
		if "$1"; then echo "${TEP_MD_OK}"; else echo "- missing"; fi
	}

	report_table_row "CLAUDE.md"              "$(_report_status "$TEP_HAS_CLAUDE_MD")"
	report_table_row ".claude/"               "$(_report_status_opt "$TEP_HAS_CLAUDE_DIR")"
	report_table_row ".claude/settings.json"  "$(_report_status_opt "$TEP_HAS_SETTINGS")"
	report_table_row ".claude/settings.local" "$(_report_status_opt "$TEP_HAS_SETTINGS_LOCAL")"
	report_table_row ".claude/MEMORY.md"      "$(_report_status_opt "$TEP_HAS_MEMORY")"
	report_table_row "AGENTS.md"              "$(_report_status_opt "$TEP_HAS_AGENTS")"

	if "$TEP_HAS_SKILLS"; then
		report_table_row ".claude/skills/" "${TEP_MD_OK} ${TEP_SKILL_COUNT} file(s)"
	else
		report_table_row ".claude/skills/" "- missing"
	fi

	if "$TEP_HAS_RULES"; then
		report_table_row ".claude/rules/" "${TEP_MD_OK} ${TEP_RULE_COUNT} file(s)"
	else
		report_table_row ".claude/rules/" "- missing"
	fi

	report_table_row ".claude/**/*.md (total)" "${TEP_CLAUDE_MD_MISC_COUNT} file(s)"
	report_table_row "docs/*.md" "${TEP_DOCS_COUNT} file(s)"
	report_table_end

	# ─── Gate: abort if no CLAUDE.md ────────────────────────────
	if ! "$TEP_HAS_CLAUDE_MD"; then
		log_fail "No CLAUDE.md found — cannot audit."
		report_text ""
		report_text "## ${TEP_MD_FAIL} STOP — No CLAUDE.md"
		report_text "Create a CLAUDE.md before running the audit."
		return 1
	fi

	log_ok "Inventory complete"
	return 0
}