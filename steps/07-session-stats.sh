#!/usr/bin/env bash
# steps/07-session-stats.sh — Session stats parsing
# Source this file; do not execute directly.

# shellcheck disable=SC2012,SC2034,SC2154  # Cross-file globals + ls -t intentional

step_session_stats() {
	log_header "7/11" "Stats de la dernière session Claude Code"

	# ─── Auto-detect session directory ──────────────────────────
	local session_dir
	session_dir=$(find "$HOME/.claude/projects" -maxdepth 1 -type d -name "*${TEP_PROJECT_NAME}*" 2>/dev/null | head -1)

	local latest=""
	TEP_HAS_SESSION=false

	if [[ -n "$session_dir" ]]; then
		# shellcheck disable=SC2012  # ls -t safe here: controlled dir, .jsonl filenames
		latest=$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1)
		[[ -n "$latest" ]] && TEP_HAS_SESSION=true
	fi

	# ─── Parse session if available ─────────────────────────────
	if "$TEP_HAS_SESSION" && "$TEP_HAS_JQ"; then
		log_info "Session: $(basename "$latest")"

		# Token stats (aggregate across all assistant messages)
		local stats
		stats=$(jq -r 'select(.type=="assistant") | .message.usage // empty' "$latest" 2>/dev/null | \
			jq -s '{
				input: (map(.input_tokens // 0) | add),
				output: (map(.output_tokens // 0) | add),
				cache_read: (map(.cache_read_input_tokens // 0) | add),
				cache_creation: (map(.cache_creation_input_tokens // 0) | add)
			}' 2>/dev/null || echo '{}')

		TEP_INPUT_TOKENS=$(echo "$stats" | jq -r '.input // 0' 2>/dev/null || echo 0)
		TEP_OUTPUT_TOKENS=$(echo "$stats" | jq -r '.output // 0' 2>/dev/null || echo 0)
		TEP_CACHE_READ=$(echo "$stats" | jq -r '.cache_read // 0' 2>/dev/null || echo 0)
		TEP_CACHE_CREATION=$(echo "$stats" | jq -r '.cache_creation // 0' 2>/dev/null || echo 0)

		# Cache hit rate
		local total=$((TEP_INPUT_TOKENS + TEP_CACHE_READ + TEP_CACHE_CREATION))
		if [[ $total -gt 0 ]]; then
			TEP_CACHE_HIT_RATE=$((TEP_CACHE_READ * 100 / total))
		else
			TEP_CACHE_HIT_RATE=0
		fi

		# Cost estimation
		TEP_COST_USD=$(estimate_cost_usd "$TEP_INPUT_TOKENS" "$TEP_OUTPUT_TOKENS" "$TEP_CACHE_READ" "$TEP_CACHE_CREATION")

		log_detail "Input" "$TEP_INPUT_TOKENS"
		log_detail "Output" "$TEP_OUTPUT_TOKENS"
		log_detail "Cache read" "$TEP_CACHE_READ"
		log_detail "Cache write" "$TEP_CACHE_CREATION"
		log_detail "Cache hit rate" "${TEP_CACHE_HIT_RATE}%"
		log_detail "Coût estimé" "\$$TEP_COST_USD"

		# Top files read
		TEP_TOP_FILES=$(jq -r 'select(.type=="assistant") |
			.message.content[]? |
			select(.type=="tool_use" and (.name=="Read" or .name=="View")) |
			.input.file_path // .input.path // "unknown"' "$latest" 2>/dev/null | \
			sort | uniq -c | sort -rn | head -15 || true)

		# Top actions
		TEP_TOP_ACTIONS=$(jq -r 'select(.type=="assistant") |
			.message.content[]? |
			select(.type=="tool_use") |
			.name' "$latest" 2>/dev/null | \
			sort | uniq -c | sort -rn || true)

		if [[ -n "$TEP_TOP_FILES" ]]; then
			log_info "Top fichiers lus :"
			echo "$TEP_TOP_FILES" | head -10 | sed 's/^/      /' >&2
		fi

		# ─── Report section ───────────────────────────────────────
		report_section "7" "Stats dernière session"
		report_table_header "Métrique" "Valeur"
		report_table_row "Session" "\`$(basename "$latest")\`"
		report_table_row "Input tokens" "$TEP_INPUT_TOKENS"
		report_table_row "Output tokens" "$TEP_OUTPUT_TOKENS"
		report_table_row "Cache read" "$TEP_CACHE_READ"
		report_table_row "Cache creation" "$TEP_CACHE_CREATION"
		report_table_row "**Cache hit rate**" "**${TEP_CACHE_HIT_RATE}%**"
		report_table_row "Coût estimé" "\$$TEP_COST_USD"
		report_table_end

		report_subsection "Top 15 fichiers lus"
		report_code "${TEP_TOP_FILES:-Aucune donnée}"

		report_subsection "Top actions (tool calls)"
		report_code "${TEP_TOP_ACTIONS:-Aucune donnée}"

	else
		# ─── Session not available ──────────────────────────────
		local reason=""
		if [[ -z "$session_dir" ]]; then
			reason="Aucun dossier de session trouvé pour '$TEP_PROJECT_NAME'"
		elif [[ -z "$latest" ]]; then
			reason="Aucun .jsonl dans $session_dir"
		elif ! "$TEP_HAS_JQ"; then
			reason="jq non installé"
		fi

		log_warn "$reason"

		report_section "7" "Stats dernière session"
		report_text ""
		report_text "${TEP_MD_WARN} Non disponible : $reason"
		report_text ""
	fi

	log_ok "Session stats complete"
	return 0
}