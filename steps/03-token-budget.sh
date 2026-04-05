#!/usr/bin/env bash
# steps/03-token-budget.sh — Token budget inventory
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_token_budget() {
	log_header "3/11" "Budget tokens — fichiers de config"

	# Reset accumulators (safety)
	TEP_TOTAL_CONFIG_TOKENS=0
	TEP_TOKEN_TABLE=""

	# ─── Core files ─────────────────────────────────────────────
	add_to_inventory "$TEP_CLAUDE_MD" "CLAUDE.md"

	# AGENTS.md (could be in .claude/ or root)
	if "$TEP_HAS_AGENTS"; then
		local agents_file="${TEP_CLAUDE_DIR}/AGENTS.md"
		[[ ! -f "$agents_file" ]] && agents_file="${TEP_PROJECT_DIR}/AGENTS.md"
		add_to_inventory "$agents_file" "AGENTS.md"
	fi

	# Settings files
	"$TEP_HAS_SETTINGS" && add_to_inventory "${TEP_CLAUDE_DIR}/settings.json" "settings.json"
	"$TEP_HAS_SETTINGS_LOCAL" && add_to_inventory "${TEP_CLAUDE_DIR}/settings.local.json" "settings.local.json"

	# ─── Skills ─────────────────────────────────────────────────
	if "$TEP_HAS_SKILLS"; then
		local skill_files
		skill_files=$(find "${TEP_CLAUDE_DIR}/skills" -type f -name '*.md' 2>/dev/null | sort)
		if [[ -n "$skill_files" ]]; then
			while IFS= read -r sf; do
				local rel_path="${sf#"${TEP_PROJECT_DIR}/"}"
				add_to_inventory "$sf" "$rel_path"
			done <<< "$skill_files"
		fi
	fi

	# ─── Rules ──────────────────────────────────────────────────
	if "$TEP_HAS_RULES"; then
		local rule_files
		rule_files=$(find "${TEP_CLAUDE_DIR}/rules" -type f -name '*.md' 2>/dev/null | sort)
		if [[ -n "$rule_files" ]]; then
			while IFS= read -r rf; do
				local rel_path="${rf#"${TEP_PROJECT_DIR}/"}"
				add_to_inventory "$rf" "$rel_path"
			done <<< "$rule_files"
		fi
	fi

	# ─── Summary ────────────────────────────────────────────────
	log_separator
	log_summary "TOTAL" "~${TEP_TOTAL_CONFIG_TOKENS} tokens de config"

	# ─── Report section ─────────────────────────────────────────
	report_section "3" "Budget tokens (config)"
	report_table_header "Fichier" "Lignes" "Chars" "Est. Tokens"
	# Append pre-built rows
	if [[ -n "$TEP_TOKEN_TABLE" ]]; then
		# Strip trailing newline to avoid blank line breaking the Markdown table
		report_text "${TEP_TOKEN_TABLE%$'\n'}"
	fi
	report_table_row "**TOTAL**" "" "" "**~${TEP_TOTAL_CONFIG_TOKENS}**"
	report_table_end

	log_ok "Token budget complete"
	return 0
}