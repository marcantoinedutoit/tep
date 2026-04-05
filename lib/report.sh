#!/usr/bin/env bash
# lib/report.sh — RESULT.md report builder for TEP
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

[[ -n "${_TEP_REPORT_LOADED:-}" ]] && return 0
_TEP_REPORT_LOADED=1

# ─── Report buffer ───────────────────────────────────────────
# All report_* functions append to this buffer.
# 10-render-report.sh flushes it to TEP_RESULT_FILE.
TEP_REPORT_BUF=""

# ─── Append helper ───────────────────────────────────────────
_report_append() {
	TEP_REPORT_BUF+="$1"$'\n'
}

# ─── Initialize report ───────────────────────────────────────
report_init() {
	TEP_REPORT_BUF=""
	_report_append "# TEP Audit Report — ${TEP_PROJECT_NAME:-unknown}"
	_report_append ""
	_report_append "> Generated on ${TEP_TIMESTAMP:-$(date '+%Y-%m-%d %H:%M')} by \`tep audit\`"
	_report_append "> Project: \`${TEP_PROJECT_DIR:-unknown}\`"
	_report_append ""
	_report_append "---"
	_report_append ""
}

# ─── Section header ──────────────────────────────────────────
# report_section "1" "Inventory"
report_section() {
	local num="$1"
	local title="$2"
	_report_append "## ${num}. ${title}"
	_report_append ""
}

# ─── Subsection ──────────────────────────────────────────────
report_subsection() {
	local title="$1"
	_report_append "### ${title}"
	_report_append ""
}

# ─── Table construction ──────────────────────────────────────
# report_table_header "Col1" "Col2" "Col3"
report_table_header() {
	local header="|"
	local separator="|"
	for col in "$@"; do
		header+=" ${col} |"
		separator+="------|"  
	done
	_report_append "$header"
	_report_append "$separator"
}

# report_table_row "val1" "val2" "val3"
report_table_row() {
	local row="|"
	for val in "$@"; do
		row+=" ${val} |"
	done
	_report_append "$row"
}

# End table (just adds a blank line)
report_table_end() {
	_report_append ""
}

# ─── Free-form text ──────────────────────────────────────────
report_text() {
	_report_append "$1"
}

# report_list_item "- Some bullet point"
report_list_item() {
	_report_append "- $1"
}

# ─── Code block ──────────────────────────────────────────────
# report_code "content" ["language"]
report_code() {
	local content="$1"
	local lang="${2:-}"
	_report_append "\`\`\`${lang}"
	_report_append "$content"
	_report_append "\`\`\`"
	_report_append ""
}

# ─── Score line helper ───────────────────────────────────────
# report_score_line "Taille CLAUDE.md" true "~1200 tokens"
report_score_line() {
	local label="$1"
	local is_ok="$2"  # true or false
	local detail="$3"

	local status
	if "$is_ok"; then
		status="${TEP_MD_OK} OK"
	else
		status="${TEP_MD_FAIL} FAIL"
	fi
	report_table_row "$label" "$status $detail"
}

# ─── Separator ───────────────────────────────────────────────
report_separator() {
	_report_append ""
	_report_append "---"
	_report_append ""
}

# ─── Actions footer ──────────────────────────────────────────
# Standard "what to do next" section for Claude Code
report_actions_footer() {
	local max_score="${1:-8}"
	_report_append ""
	_report_append "---"
	_report_append ""
	_report_append "## Actions pour Claude Code"
	_report_append ""
	_report_append "Si tu lis ce fichier, voici ce que tu dois faire :"
	_report_append ""
	_report_append "1. **Score < ${max_score}/${max_score} ?** Lis les recommandations ci-dessus et applique-les"
	_report_append "2. **Cache hit rate < 80% ?** Le CLAUDE.md change trop souvent — stabilise le contenu en haut du fichier"
	_report_append "3. **Doublons détectés ?** Supprime les sections du CLAUDE.md qui sont déjà dans les skills ou AGENTS.md"
	_report_append "4. **Volatile mal placé ?** Déplace TOUT le contenu volatile (TODO, WIP, dates) dans une section \`## Contexte courant\` en fin de CLAUDE.md"
	_report_append "5. **CLAUDE.md > 5k tokens ?** Extrais les sections lourdes vers \`.claude/skills/\` — le CLAUDE.md ne garde que les règles et les pointeurs"
	_report_append ""
	_report_append "> Rappel : chaque modification du CLAUDE.md invalide le cache à partir du point de modification. Le contenu stable en haut = cache hit permanent."
}

# ─── Finalize: flush buffer to file ──────────────────────────
# Uses atomic_write_stdin from lib/fs.sh
report_finalize() {
	local target="${1:-${TEP_RESULT_FILE:-}}"

	if [[ -z "$target" ]]; then
		log_fail "No target file for report finalization"
		return 1
	fi

	# Use printf instead of echo to avoid interpreting -n/-e/-E flags
	printf '%s\n' "$TEP_REPORT_BUF" | atomic_write_stdin "$target"
	log_ok "Report written to: $target"
}