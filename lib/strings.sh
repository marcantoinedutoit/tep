#!/usr/bin/env bash
# lib/strings.sh — String/text utilities for TEP
# Source this file; do not execute directly.

# shellcheck disable=SC2034  # TEP_VOLATILE_*, TEP_SECTION_*, etc. used by sourcing scripts

[[ -n "${_TEP_STRINGS_LOADED:-}" ]] && return 0
_TEP_STRINGS_LOADED=1

# ─── Portable counters ───────────────────────────────────────
# wc output may have leading whitespace on some systems (macOS)

count_lines() { wc -l < "$1" 2>/dev/null | tr -d ' '; }
count_words() { wc -w < "$1" 2>/dev/null | tr -d ' '; }
count_chars() { wc -c < "$1" 2>/dev/null | tr -d ' '; }

# ─── grep wrapper ────────────────────────────────────────────
# Always returns a number, never fails.
# Usage: grep_count "pattern" "file" "-iE"  (optional flags)
grep_count() {
	local pattern="$1"
	local file="$2"
	local flags="${3:-}"

	if [[ -n "$flags" ]]; then
		# shellcheck disable=SC2086  # flags must word-split
		grep -c $flags "$pattern" "$file" 2>/dev/null || echo 0
	else
		grep -c -- "$pattern" "$file" 2>/dev/null || echo 0
	fi
}

# ─── Multi-signal extraction (SINGLE PASS) ───────────────────
# Replaces 6+ separate grep calls on CLAUDE.md with one read loop.
# Performance: O(n) instead of O(6n) on the file.
#
# Sets globals:
#   TEP_VOLATILE_LINES       — matching lines (max 10)
#   TEP_DATE_LINES           — ISO date lines (max 5)
#   TEP_VOLATILE_COUNT       — 0, 1, or 2 (types detected)
#   TEP_SECTION_COUNT        — heading count (^#)
#   TEP_REF_COUNT            — references to docs/ skills/ .claude/
#   TEP_SECTIONS_LIST        — first 30 headings with line numbers
#   TEP_FIRST_VOLATILE_LINE  — line number of first volatile marker
#   TEP_LAST_HEADING_LINE    — line number of last ## heading
#   TEP_ORDER_OK             — true if volatile after stable content

extract_signals() {
	local file="$1"

	# Reset all globals
	TEP_VOLATILE_LINES=""
	TEP_DATE_LINES=""
	TEP_VOLATILE_COUNT=0
	TEP_SECTION_COUNT=0
	TEP_REF_COUNT=0
	TEP_SECTIONS_LIST=""
	TEP_FIRST_VOLATILE_LINE=""
	TEP_LAST_HEADING_LINE=""
	TEP_ORDER_OK=true

	[[ ! -f "$file" ]] && return 1

	local line_num=0
	local volatile_found=false
	local dates_found=false
	local heading_count=0
	local ref_count=0
	local volatile_buf_count=0
	local date_buf_count=0
	local sections_buf=""
	local volatile_buf=""
	local date_buf=""
	local first_volatile=""
	local last_heading=""

	while IFS= read -r line || [[ -n "$line" ]]; do
		line_num=$((line_num + 1))

		# ── Headings ──
		if [[ "$line" == \#* ]]; then
			heading_count=$((heading_count + 1))
			if [[ $heading_count -le 30 ]]; then
				sections_buf+="${line_num}:${line}"$'\n'
			fi
			# Track last ## heading (not # or ###)
			if [[ "$line" == \#\#\ * ]]; then
				last_heading=$line_num
			fi
		fi

		# ── Volatile markers (case-insensitive via bash) ──
		local line_upper
		line_upper="${line^^}"
		if [[ "$line_upper" =~ (TODO|FIXME|WIP|HACK|EN\ COURS|CURRENT\ TASK|AUJOURD) ]]; then
			if ! "$volatile_found"; then
				volatile_found=true
				first_volatile=$line_num
			fi
			if [[ $volatile_buf_count -lt 10 ]]; then
				volatile_buf+="${line_num}:${line}"$'\n'
				volatile_buf_count=$((volatile_buf_count + 1))
			fi
		fi

		# ── ISO dates ──
		if [[ "$line" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
			if ! "$dates_found"; then
				dates_found=true
			fi
			if [[ $date_buf_count -lt 5 ]]; then
				date_buf+="${line_num}:${line}"$'\n'
				date_buf_count=$((date_buf_count + 1))
			fi
		fi

		# ── External references ──
		if [[ "$line" =~ (docs/|skills/|\.claude/) ]]; then
			ref_count=$((ref_count + 1))
		fi

	done < "$file"

	# Assign globals
	TEP_VOLATILE_LINES="$volatile_buf"
	TEP_DATE_LINES="$date_buf"
	TEP_SECTION_COUNT=$heading_count
	TEP_REF_COUNT=$ref_count
	TEP_SECTIONS_LIST="$sections_buf"
	TEP_FIRST_VOLATILE_LINE="$first_volatile"
	TEP_LAST_HEADING_LINE="$last_heading"

	# Count volatile types (0–2)
	TEP_VOLATILE_COUNT=0
	"$volatile_found" && TEP_VOLATILE_COUNT=$((TEP_VOLATILE_COUNT + 1))
	"$dates_found" && TEP_VOLATILE_COUNT=$((TEP_VOLATILE_COUNT + 1))

	# Cache order: volatile should come AFTER last stable heading
	TEP_ORDER_OK=true
	if [[ -n "$first_volatile" ]] && [[ -n "$last_heading" ]]; then
		if [[ "$first_volatile" -lt "$last_heading" ]]; then
			TEP_ORDER_OK=false
		fi
	fi
}

# ─── Hardcoded paths detection ───────────────────────────────
# Sets TEP_HARDCODED_PATHS (text) and TEP_HARDCODED_COUNT (int)
detect_hardcoded_paths() {
	local target="$1"  # file or directory
	local pattern='(/Users/[a-zA-Z]|/home/[a-zA-Z]|[A-Z]:\\Users|[A-Z]:/Users)'

	TEP_HARDCODED_PATHS=""
	TEP_HARDCODED_COUNT=0

	local results
	results=$(grep -rnE "$pattern" "$target" 2>/dev/null || true)

	if [[ -n "$results" ]]; then
		TEP_HARDCODED_PATHS="$results"
		TEP_HARDCODED_COUNT=$(echo "$results" | wc -l | tr -d ' ')
	fi
}