#!/usr/bin/env bash
# steps/06-settings-hooks.sh — settings.json + hooks analysis
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2154  # Cross-file globals (sourced context)

step_settings_hooks() {
	log_header "6/11" "Hooks & settings analysis"

	TEP_HOOKS_ISSUES=0
	TEP_HOOK_COUNT=0
	TEP_MCP_COUNT=0
	TEP_FS_HOOK_COUNT=0
	local hooks_details=""
	local fs_hook_files=""

	# ─── A) Filesystem hooks (.claude/hooks/*.sh) ───────────────
	local fs_hook_dir="${TEP_CLAUDE_DIR}/hooks"
	if dir_exists "$fs_hook_dir"; then
		TEP_FS_HOOK_COUNT=$(find "$fs_hook_dir" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
		if [[ $TEP_FS_HOOK_COUNT -gt 0 ]]; then
			fs_hook_files=$(find "$fs_hook_dir" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
			log_ok "Filesystem hooks: $TEP_FS_HOOK_COUNT script(s) in .claude/hooks/"
		else
			log_info ".claude/hooks/ exists but contains no *.sh"
		fi
	else
		log_info "No .claude/hooks/ directory"
	fi

	# ─── B) settings.json hooks (requires jq) ───────────────────
	if "$TEP_HAS_SETTINGS" && "$TEP_HAS_JQ"; then
		local settings_file="${TEP_CLAUDE_DIR}/settings.json"

		# JSON validation
		if jq . "$settings_file" > /dev/null 2>&1; then
			log_ok "settings.json: valid JSON"
		else
			log_fail "settings.json: INVALID JSON!"
			TEP_HOOKS_ISSUES=$((TEP_HOOKS_ISSUES + 1))
			hooks_details+=$'\n- FAIL **settings.json** — invalid JSON, fix syntax'
		fi

		# MCP server count
		TEP_MCP_COUNT=$(jq -r '.mcpServers // {} | keys | length' "$settings_file" 2>/dev/null || echo 0)
		log_detail "MCP servers" "$TEP_MCP_COUNT"

		# Hooks declared in settings.json
		local hook_types
		hook_types=$(jq -r '.hooks // {} | keys[]' "$settings_file" 2>/dev/null || true)

		if [[ -n "$hook_types" ]]; then
			while IFS= read -r hook_type; do
				local cmds
				cmds=$(jq -r ".hooks[\"$hook_type\"][]?.command // empty" "$settings_file" 2>/dev/null || true)
				if [[ -n "$cmds" ]]; then
					local cmd_count
					cmd_count=$(echo "$cmds" | wc -l | tr -d ' ')
					TEP_HOOK_COUNT=$((TEP_HOOK_COUNT + cmd_count))
					log_detail "settings.json hook" "$hook_type ($cmd_count cmd(s))"

					# Cache safety: hooks must NOT modify CLAUDE.md
					if printf '%s\n' "$cmds" | grep -qiE '(CLAUDE\.md|system.prompt|>> *.*CLAUDE|> *.*CLAUDE)'; then
						TEP_HOOKS_ISSUES=$((TEP_HOOKS_ISSUES + 1))
						hooks_details+=$'\n- FAIL Hook **'"$hook_type"'** appears to modify CLAUDE.md/system prompt -> breaks cache'
						log_fail "DANGER: hook $hook_type modifies CLAUDE.md/system prompt!"
					fi
				fi
			done <<< "$hook_types"
		else
			log_info "No hooks configured in settings.json"
		fi

		# Custom instructions length check
		local custom_len
		custom_len=$(jq -r '.customInstructions | length // 0' "$settings_file" 2>/dev/null || echo 0)
		if [[ $custom_len -gt 500 ]]; then
			log_warn "Long customInstructions ($custom_len chars) — check for volatile content"
		fi

	elif "$TEP_HAS_SETTINGS"; then
		log_warn "jq not installed — limited settings.json analysis"
		if grep -q '"hooks"' "${TEP_CLAUDE_DIR}/settings.json" 2>/dev/null; then
			log_detail "hooks key" "detected (install jq for details)"
		fi
	else
		log_info "No settings.json"
	fi

	# ─── Report section ─────────────────────────────────────────
	report_section "6" "Hooks & Settings"
	report_table_header "Item" "Value"
	report_table_row "Filesystem hooks (.claude/hooks/*.sh)" "$TEP_FS_HOOK_COUNT"
	report_table_row "settings.json hooks (commands)" "$TEP_HOOK_COUNT"
	report_table_row "MCP servers" "$TEP_MCP_COUNT"
	report_table_row "Hook issues" "$TEP_HOOKS_ISSUES"
	report_table_end

	if [[ $TEP_FS_HOOK_COUNT -gt 0 ]] && [[ -n "$fs_hook_files" ]]; then
		report_subsection "Filesystem hooks detected (.claude/hooks/*.sh)"
		report_code "$fs_hook_files"
	fi

	if [[ -n "$hooks_details" ]]; then
		report_text "$hooks_details"
		report_text ""
	fi

	if [[ $TEP_MCP_COUNT -gt 5 ]]; then
		report_text "${TEP_MD_WARN} $TEP_MCP_COUNT MCP servers — chaque tool change le préfixe caché. Désactiver ceux non utilisés."
		report_text ""
	fi

	log_ok "Hooks & settings analysis complete"
	return 0
}