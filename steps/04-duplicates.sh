#!/usr/bin/env bash
# steps/04-duplicates.sh — Duplicate detection (CLAUDE.md vs skills/agents)
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_duplicates() {
	log_header "4/11" "Détection de doublons"

	TEP_DUPLICATE_RISK=0
	TEP_DUPLICATE_DETAILS=""

	# ─── Skills vs CLAUDE.md cross-reference ────────────────────
	if "$TEP_HAS_SKILLS"; then
		local skill_files
		skill_files=$(find "${TEP_CLAUDE_DIR}/skills" -type f -name '*.md' 2>/dev/null)

		if [[ -n "$skill_files" ]]; then
			while IFS= read -r skill; do
				local skill_name
				skill_name=$(basename "$skill" .md)
				local skill_words
				skill_words=$(count_words "$skill")

				# Extract distinctive keywords from first 5 lines
				local skill_keywords
				skill_keywords=$(head -5 "$skill" | grep -oE '[A-Z][a-z]+' 2>/dev/null | sort -u | head -5 | tr '\n' '|' | sed 's/|$//' || true)

				if [[ -n "$skill_keywords" ]]; then
					local matches
					matches=$(grep_count "$skill_keywords" "$TEP_CLAUDE_MD" "-iE")

					if [[ $matches -gt 3 ]]; then
						log_warn "$skill_name ($skill_words mots) — $matches réfs croisées"
						TEP_DUPLICATE_RISK=$((TEP_DUPLICATE_RISK + 1))
						TEP_DUPLICATE_DETAILS+="- **$skill_name** ($skill_words mots) : $matches références croisées dans CLAUDE.md -> doublon probable"$'\n'
					else
						log_ok "$skill_name — pas de doublon"
					fi
				fi
			done <<< "$skill_files"
		else
			log_info ".claude/skills/ vide"
		fi
	else
		log_info "Pas de skills à comparer"
	fi

	# ─── AGENTS.md detection ────────────────────────────────────
	local agents_words=0
	if "$TEP_HAS_AGENTS"; then
		local agents_file="${TEP_CLAUDE_DIR}/AGENTS.md"
		[[ ! -f "$agents_file" ]] && agents_file="${TEP_PROJECT_DIR}/AGENTS.md"
		agents_words=$(count_words "$agents_file")
		log_info "AGENTS.md détecté ($agents_words mots)"
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "4" "Doublons (CLAUDE.md vs skills/agents)"
	report_text ""
	report_list_item "Risques de doublons : **$TEP_DUPLICATE_RISK**"

	if [[ -n "$TEP_DUPLICATE_DETAILS" ]]; then
		report_text "$TEP_DUPLICATE_DETAILS"
	fi

	if "$TEP_HAS_AGENTS"; then
		report_list_item "AGENTS.md présent ($agents_words mots) — attention à ne pas dupliquer"
	fi
	report_text ""

	log_ok "Duplicate detection complete"
	return 0
}