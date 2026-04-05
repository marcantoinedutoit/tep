#!/usr/bin/env bash
# steps/02-claude-md-audit.sh — CLAUDE.md deep analysis
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_claude_md_audit() {
	log_header "2/11" "Audit CLAUDE.md"

	# ─── Size metrics ───────────────────────────────────────────
	local lines words
	lines=$(count_lines "$TEP_CLAUDE_MD")
	words=$(count_words "$TEP_CLAUDE_MD")
	TEP_CLAUDE_MD_WORDS=$words
	TEP_CLAUDE_MD_TOKENS=$(estimate_tokens "$words")

	local size_verdict
	size_verdict=$(token_size_verdict "$TEP_CLAUDE_MD_TOKENS")

	log_detail "$words mots" "~${TEP_CLAUDE_MD_TOKENS} tokens — $size_verdict"

	# ─── Multi-signal extraction (single pass) ─────────────────
	extract_signals "$TEP_CLAUDE_MD"

	log_detail "Sections" "$TEP_SECTION_COUNT"
	log_detail "Réfs externes" "$TEP_REF_COUNT"

	if [[ $TEP_VOLATILE_COUNT -gt 0 ]]; then
		log_warn "$TEP_VOLATILE_COUNT type(s) de contenu volatile détecté(s)"
	fi

	if "$TEP_ORDER_OK"; then
		log_ok "Ordre cache-friendly OK"
	else
		log_fail "Volatile AVANT stable — mauvais pour le cache"
	fi

	# ─── Hardcoded paths ───────────────────────────────────────
	detect_hardcoded_paths "$TEP_CLAUDE_MD"
	local claude_hc_count=$TEP_HARDCODED_COUNT
	local claude_hc_paths="$TEP_HARDCODED_PATHS"

	# Also scan skills if present
	if "$TEP_HAS_SKILLS"; then
		local skills_hc
		skills_hc=$(find "${TEP_CLAUDE_DIR}/skills" -type f -name '*.md' \
			-exec grep -lE '(/Users/[a-zA-Z]|/home/[a-zA-Z]|[A-Z]:\\Users|[A-Z]:/Users)' {} \; 2>/dev/null || true)
		if [[ -n "$skills_hc" ]]; then
			local skills_hc_count
			skills_hc_count=$(echo "$skills_hc" | wc -l | tr -d ' ')
			TEP_HARDCODED_COUNT=$((claude_hc_count + skills_hc_count))
			log_fail "$skills_hc_count skill(s) avec chemins perso"
		fi
	fi

	if [[ $TEP_HARDCODED_COUNT -eq 0 ]]; then
		log_ok "Pas de chemins hardcodés"
	else
		log_fail "$TEP_HARDCODED_COUNT chemin(s) perso hardcodé(s)"
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "2" "Audit CLAUDE.md"
	report_table_header "Métrique" "Valeur"
	report_table_row "Mots" "$words"
	report_table_row "Tokens (approx)" "~${TEP_CLAUDE_MD_TOKENS}"
	report_table_row "Sections" "$TEP_SECTION_COUNT"
	report_table_row "Réfs externes" "$TEP_REF_COUNT"
	report_table_row "Taille" "$size_verdict"
	report_table_row "Contenu volatile" "$TEP_VOLATILE_COUNT type(s) détecté(s)"

	if "$TEP_ORDER_OK"; then
		report_table_row "Ordre cache-friendly" "${TEP_MD_OK} OK"
	else
		report_table_row "Ordre cache-friendly" "${TEP_MD_FAIL} Volatile avant stable"
	fi

	if [[ $TEP_HARDCODED_COUNT -eq 0 ]]; then
		report_table_row "Chemins hardcodés" "${TEP_MD_OK} aucun"
	else
		report_table_row "Chemins hardcodés" "${TEP_MD_FAIL} $TEP_HARDCODED_COUNT trouvé(s)"
	fi
	report_table_end

	# Sub-sections for volatile/dates/structure details
	if [[ -n "$TEP_VOLATILE_LINES" ]]; then
		report_subsection "Contenu volatile détecté"
		report_code "$TEP_VOLATILE_LINES"
	fi

	if [[ -n "$TEP_DATE_LINES" ]]; then
		report_subsection "Dates hardcodées"
		report_code "$TEP_DATE_LINES"
	fi

	if [[ -n "$TEP_SECTIONS_LIST" ]]; then
		report_subsection "Structure des sections"
		report_code "$TEP_SECTIONS_LIST"
	fi

	if [[ -n "$claude_hc_paths" ]]; then
		report_subsection "Chemins hardcodés détectés"
		report_code "$claude_hc_paths"
	fi

	log_ok "CLAUDE.md audit complete"
	return 0
}