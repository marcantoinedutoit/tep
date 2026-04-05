#!/usr/bin/env bash
# steps/08-score-recos.sh — Scoring & recommendations
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_score_recos() {
	log_header "8/11" "Score & recommandations"

	TEP_SCORE=0
	TEP_MAX_SCORE=8
	TEP_RECOS=""

	# ─── Helper: add score point ────────────────────────────────
	local score_table=""
	_score() {
		local label="$1"
		local is_ok="$2"  # true or false
		local detail="$3"
		local reco="${4:-}"

		local status_icon
		if "$is_ok"; then
			TEP_SCORE=$((TEP_SCORE + 1))
			status_icon="${TEP_MD_OK}"
			log_ok "$label: $detail"
		else
			status_icon="${TEP_MD_FAIL}"
			log_fail "$label: $detail"
			if [[ -n "$reco" ]]; then
				TEP_RECOS+="- $reco"$'\n'
			fi
		fi
		score_table+="| $label | $status_icon $detail |"$'\n'
	}

	# ─── 8 scoring criteria ─────────────────────────────────────

	# 1. CLAUDE.md size (< 5000 tokens)
	local size_ok=false
	[[ ${TEP_CLAUDE_MD_TOKENS:-0} -le 5000 ]] && size_ok=true
	_score "Taille CLAUDE.md" "$size_ok" "~${TEP_CLAUDE_MD_TOKENS} tokens" \
		"Réduire CLAUDE.md à <5k tokens. Extraire les sections lourdes vers .claude/skills/"

	# 2. No hardcoded paths
	local hc_ok=false
	[[ ${TEP_HARDCODED_COUNT:-0} -eq 0 ]] && hc_ok=true
	_score "Chemins hardcodés" "$hc_ok" "$TEP_HARDCODED_COUNT trouvé(s)" \
		"Remplacer tous les chemins absolus (/Users/xxx, C:\\Users\\xxx) par des chemins relatifs"

	# 3. Cache-friendly order
	local order_ok="${TEP_ORDER_OK:-false}"
	_score "Ordre cache-friendly" "$order_ok" "Stable avant volatile" \
		"Déplacer le contenu volatile (TODO, WIP, dates) en fin de CLAUDE.md dans ## Contexte courant"

	# 4. No duplicates
	local dup_ok=false
	[[ ${TEP_DUPLICATE_RISK:-0} -eq 0 ]] && dup_ok=true
	_score "Pas de doublons" "$dup_ok" "${TEP_DUPLICATE_RISK} risque(s)" \
		"Supprimer du CLAUDE.md le contenu déjà présent dans les skills"

	# 5. .gitignore clean
	local gi_ok=false
	[[ ${TEP_GITIGNORE_ISSUES:-0} -eq 0 ]] && gi_ok=true
	_score ".gitignore clean" "$gi_ok" "${TEP_GITIGNORE_ISSUES} problème(s)" \
		"Ajouter .claude/MEMORY.md au .gitignore; retirer .claude/skills/ si présent"

	# 6. .claudeignore present & clean
	local ci_ok=false
	[[ ${TEP_CLAUDEIGNORE_ISSUES:-0} -eq 0 ]] && ci_ok=true
	_score ".claudeignore" "$ci_ok" "${TEP_CLAUDEIGNORE_ISSUES} problème(s)" \
		"Créer/compléter .claudeignore avec .git/, node_modules/, dist/, etc."

	# 7. No hook issues
	local hooks_ok=false
	[[ ${TEP_HOOKS_ISSUES:-0} -eq 0 ]] && hooks_ok=true
	_score "Hooks safe" "$hooks_ok" "${TEP_HOOKS_ISSUES} problème(s)" \
		"Corriger les hooks qui modifient CLAUDE.md mid-session (cache killer)"

	# 8. Cache hit rate (>= 70% if session available, auto-pass if not)
	local cache_ok=false
	if "${TEP_HAS_SESSION:-false}"; then
		[[ ${TEP_CACHE_HIT_RATE:-0} -ge 70 ]] && cache_ok=true
		_score "Cache hit rate" "$cache_ok" "${TEP_CACHE_HIT_RATE}%" \
			"Cache hit rate < 70%. Le CLAUDE.md change trop souvent ou est mal structuré."
	else
		cache_ok=true
		_score "Cache hit rate" "$cache_ok" "N/A (pas de session)" ""
	fi

	# ─── Summary ────────────────────────────────────────────────
	log_separator
	log_summary "Score" "$TEP_SCORE / $TEP_MAX_SCORE"

	if [[ $TEP_SCORE -eq $TEP_MAX_SCORE ]]; then
		log_ok "Configuration optimale ! 🎉"
	elif [[ $TEP_SCORE -ge 6 ]]; then
		log_info "Bonne base — quelques ajustements possibles"
	else
		log_warn "Score faible — recommandations à appliquer"
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "8" "Score & Recommandations"
	report_table_header "Critère" "Résultat"
	if [[ -n "$score_table" ]]; then
		# Strip trailing newline to avoid blank line breaking the Markdown table
		report_text "${score_table%$'\n'}"
	fi
	report_table_row "**TOTAL**" "**$TEP_SCORE / $TEP_MAX_SCORE**"
	report_table_end

	if [[ -n "$TEP_RECOS" ]]; then
		report_subsection "Recommandations"
		report_text "$TEP_RECOS"
	else
		report_text ""
		report_text "${TEP_MD_OK} Aucune recommandation — configuration optimale."
		report_text ""
	fi

	log_ok "Score & recommendations complete"
	return 0
}