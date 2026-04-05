#!/usr/bin/env bash
# steps/05-ignore-files.sh — .gitignore & .claudeignore checks
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_ignore_files() {
	log_header "5/11" "Vérification .gitignore & .claudeignore"

	local gitignore="${TEP_PROJECT_DIR}/.gitignore"
	local claudeignore="${TEP_PROJECT_DIR}/.claudeignore"
	TEP_GITIGNORE_ISSUES=0
	TEP_CLAUDEIGNORE_ISSUES=0
	local gitignore_details=""

	# ─── .gitignore checks ──────────────────────────────────────
	if file_exists "$gitignore"; then
		# MEMORY.md should be gitignored (changes every session)
		if "$TEP_HAS_MEMORY"; then
			if grep -q '.claude/MEMORY.md' "$gitignore" 2>/dev/null; then
				log_ok ".claude/MEMORY.md dans .gitignore"
			else
				log_fail ".claude/MEMORY.md PAS dans .gitignore"
				TEP_GITIGNORE_ISSUES=$((TEP_GITIGNORE_ISSUES + 1))
				gitignore_details+=$'\n- FAIL Ajouter `.claude/MEMORY.md` au .gitignore (change à chaque session)'
			fi
		fi

		# skills/ should NOT be gitignored (must be committed)
		if "$TEP_HAS_SKILLS"; then
			if grep -q '.claude/skills' "$gitignore" 2>/dev/null; then
				log_fail ".claude/skills/ dans .gitignore (devrait être commité !)"
				TEP_GITIGNORE_ISSUES=$((TEP_GITIGNORE_ISSUES + 1))
				gitignore_details+=$'\n- FAIL Retirer `.claude/skills/` du .gitignore (les skills doivent être commités)'
			else
				log_ok ".claude/skills/ sera commité"
			fi
		fi
	else
		log_warn "Pas de .gitignore"
	fi

	# ─── .claudeignore checks ───────────────────────────────────
	if file_exists "$claudeignore"; then
		log_ok ".claudeignore existe"

		# .git/ should be in .claudeignore
		if ! grep -qE '^\.git(/|$)' "$claudeignore" 2>/dev/null; then
			log_fail ".git/ PAS dans .claudeignore"
			TEP_CLAUDEIGNORE_ISSUES=$((TEP_CLAUDEIGNORE_ISSUES + 1))
		else
			log_ok ".git/ dans .claudeignore"
		fi

		# Check for common heavy dirs that exist but are not ignored
		local missing_pats=""
		for pat in node_modules dist build .next __pycache__ target vendor; do
			if dir_exists "${TEP_PROJECT_DIR}/${pat}" && ! grep -q "$pat" "$claudeignore" 2>/dev/null; then
				missing_pats+=" $pat"
			fi
		done
		if [[ -n "$missing_pats" ]]; then
			log_warn "Dossiers existants non ignorés :$missing_pats"
		fi
	else
		log_warn "Pas de .claudeignore — Claude Code peut lire des fichiers inutiles"
		TEP_CLAUDEIGNORE_ISSUES=$((TEP_CLAUDEIGNORE_ISSUES + 1))
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "5" "Vérification .gitignore & .claudeignore"
	report_text ""
	report_list_item "Problèmes .gitignore : **$TEP_GITIGNORE_ISSUES**"
	report_list_item "Problèmes .claudeignore : **$TEP_CLAUDEIGNORE_ISSUES**"

	if [[ -n "$gitignore_details" ]]; then
		report_text "$gitignore_details"
	fi
	report_text ""

	log_ok "Ignore files check complete"
	return 0
}