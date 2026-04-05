#!/usr/bin/env bash
# steps/09-history.sh — Append audit snapshot to history.jsonl
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_history() {
	log_header "9/11" "Historique & evals"

	ensure_dir "$TEP_EVALS_DIR"

	# ─── Build snapshot JSON ────────────────────────────────────
	local snapshot

	if "$TEP_HAS_JQ"; then
		# Proper JSON with jq
		snapshot=$(jq -n \
			--arg ts "$TEP_TIMESTAMP" \
			--arg project "$TEP_PROJECT_NAME" \
			--argjson score "$TEP_SCORE" \
			--argjson max_score "$TEP_MAX_SCORE" \
			--argjson tokens "${TEP_CLAUDE_MD_TOKENS:-0}" \
			--argjson total_config "${TEP_TOTAL_CONFIG_TOKENS:-0}" \
			--argjson cache_hit "${TEP_CACHE_HIT_RATE:-0}" \
			--arg cost "${TEP_COST_USD:-N/A}" \
			--argjson duplicates "${TEP_DUPLICATE_RISK:-0}" \
			--argjson hardcoded "${TEP_HARDCODED_COUNT:-0}" \
			--argjson volatile "${TEP_VOLATILE_COUNT:-0}" \
			--argjson hooks_issues "${TEP_HOOKS_ISSUES:-0}" \
			--argjson skills "${TEP_SKILL_COUNT:-0}" \
			--argjson rules "${TEP_RULE_COUNT:-0}" \
			--argjson mcp "${TEP_MCP_COUNT:-0}" \
			--argjson order_ok "${TEP_ORDER_OK:-false}" \
			'{
				timestamp: $ts,
				project: $project,
				score: $score,
				max_score: $max_score,
				claude_md_tokens: $tokens,
				total_config_tokens: $total_config,
				cache_hit_rate: $cache_hit,
				cost_usd: $cost,
				duplicates: $duplicates,
				hardcoded_paths: $hardcoded,
				volatile_types: $volatile,
				hooks_issues: $hooks_issues,
				skills: $skills,
				rules: $rules,
				mcp_servers: $mcp,
				order_ok: $order_ok
			}' 2>/dev/null)
	else
		# Fallback: manual JSON (no jq)
		snapshot=$(printf '{"timestamp":"%s","project":"%s","score":%d,"max_score":%d,"claude_md_tokens":%d,"total_config_tokens":%d,"cache_hit_rate":%d,"cost_usd":"%s","duplicates":%d,"hardcoded_paths":%d,"volatile_types":%d,"hooks_issues":%d,"skills":%d,"rules":%d,"mcp_servers":%d,"order_ok":%s}' \
			"$TEP_TIMESTAMP" "$TEP_PROJECT_NAME" "$TEP_SCORE" "$TEP_MAX_SCORE" \
			"${TEP_CLAUDE_MD_TOKENS:-0}" "${TEP_TOTAL_CONFIG_TOKENS:-0}" \
			"${TEP_CACHE_HIT_RATE:-0}" "${TEP_COST_USD:-N/A}" \
			"${TEP_DUPLICATE_RISK:-0}" "${TEP_HARDCODED_COUNT:-0}" \
			"${TEP_VOLATILE_COUNT:-0}" "${TEP_HOOKS_ISSUES:-0}" \
			"${TEP_SKILL_COUNT:-0}" "${TEP_RULE_COUNT:-0}" \
			"${TEP_MCP_COUNT:-0}" "${TEP_ORDER_OK:-false}")
	fi

	# ─── Append to history ──────────────────────────────────────
	echo "$snapshot" >> "$TEP_HISTORY_FILE"
	log_ok "Snapshot appended to $(basename "$TEP_HISTORY_FILE")"

	# ─── Trend analysis (if previous entries exist) ─────────────
	local entry_count=0
	if file_exists "$TEP_HISTORY_FILE"; then
		entry_count=$(count_lines "$TEP_HISTORY_FILE")
	fi

	local trend_text=""
	if [[ $entry_count -gt 1 ]] && "$TEP_HAS_JQ"; then
		# Compare with previous entry
		local prev_score
		prev_score=$(tail -2 "$TEP_HISTORY_FILE" | head -1 | jq -r '.score // 0' 2>/dev/null || echo 0)

		if [[ $TEP_SCORE -gt $prev_score ]]; then
			trend_text="📈 Score amélioré : $prev_score → $TEP_SCORE"
			log_ok "$trend_text"
		elif [[ $TEP_SCORE -lt $prev_score ]]; then
			trend_text="📉 Score dégradé : $prev_score → $TEP_SCORE"
			log_warn "$trend_text"
		else
			trend_text="➡️ Score stable : $TEP_SCORE"
			log_info "$trend_text"
		fi
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "9" "Historique"
	report_text ""
	report_list_item "Entrées dans l'historique : **$entry_count**"

	if [[ -n "$trend_text" ]]; then
		report_list_item "Tendance : $trend_text"
	fi

	report_list_item "Fichier : \`evals/history.jsonl\`"
	report_text ""

	log_ok "History complete"
	return 0
}