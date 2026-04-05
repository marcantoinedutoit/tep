#!/usr/bin/env bash
# lib/tokens.sh — Token estimation utilities for TEP
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

[[ -n "${_TEP_TOKENS_LOADED:-}" ]] && return 0
_TEP_TOKENS_LOADED=1

# ─── Token estimation ────────────────────────────────────────
# Anthropic's rough heuristic: ~1.3 tokens per word for English/French.
# This is an approximation — real tokenization depends on the model.
# Override with TEP_TOKEN_RATIO if needed.
TEP_TOKEN_RATIO="${TEP_TOKEN_RATIO:-13}"

# estimate_tokens <word_count>
# Returns: integer token estimate
estimate_tokens() {
	local words="${1:-0}"
	# words * 13 / 10 = words * 1.3 (integer math)
	echo $(( words * TEP_TOKEN_RATIO / 10 ))
}

# ─── Budget inventory ────────────────────────────────────────
# Tracks all config files and their token costs.

# Accumulator (reset in 00-ctx or before step_token_budget)
TEP_TOTAL_CONFIG_TOKENS=0

# Markdown table buffer for RESULT.md
# Format: "| label | lines | chars | ~tokens |"
TEP_TOKEN_TABLE=""

# add_to_inventory <file_path> <display_label>
# Reads file metrics, appends to table, accumulates total.
# Returns 0 if file exists, 1 if not.
add_to_inventory() {
	local file="$1"
	local label="$2"

	[[ ! -f "$file" ]] && return 1

	local lines chars words tokens
	lines=$(count_lines "$file")
	chars=$(count_chars "$file")
	words=$(count_words "$file")
	tokens=$(estimate_tokens "$words")

	TEP_TOTAL_CONFIG_TOKENS=$((TEP_TOTAL_CONFIG_TOKENS + tokens))
	TEP_TOKEN_TABLE+="| ${label} | ${lines} | ${chars} | ~${tokens} |"$'\n'

	log_detail "$label" "${lines} lignes, ~${tokens} tokens"
	return 0
}

# ─── Size verdict ────────────────────────────────────────────
# Returns a human-readable verdict based on token count
# Used for CLAUDE.md specifically
token_size_verdict() {
	local tokens="${1:-0}"

	if [[ $tokens -le 3000 ]]; then
		echo "Excellent — très compact (<3k tokens)"
	elif [[ $tokens -le 5000 ]]; then
		echo "OK — compact (<5k tokens)"
	elif [[ $tokens -le 8000 ]]; then
		echo "Gros (>5k tokens) — marge d'optimisation"
	else
		echo "TRÈS GROS (>8k tokens) — cache inefficace, refactoring urgent"
	fi
}

# ─── Cost estimation (Sonnet pricing) ────────────────────────
# Portable: uses awk instead of bc (available everywhere)
# Input: input_tokens output_tokens cache_read_tokens cache_creation_tokens
# Output: cost in USD (4 decimals)
estimate_cost_usd() {
	local input="${1:-0}"
	local output="${2:-0}"
	local cache_read="${3:-0}"
	local cache_creation="${4:-0}"

	# SC2086-safe: use awk -v to avoid shell injection in awk expressions
	awk -v inp="$input" -v outp="$output" -v cr="$cache_read" -v cc="$cache_creation" \
		'BEGIN { printf "%.4f", inp*3/1e6 + outp*15/1e6 + cr*0.3/1e6 + cc*3.75/1e6 }' \
		2>/dev/null || echo "N/A"
}