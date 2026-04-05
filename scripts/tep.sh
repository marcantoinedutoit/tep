#!/usr/bin/env bash
# scripts/tep.sh — TEP Orchestrator
# Main entry point for the audit pipeline.
# Usage: Called by bin/tep after argument parsing.
#
# This is the ONLY file that sets -euo pipefail.
# All other files are sourced and rely on return codes.

# shellcheck disable=SC1090,SC2034,SC2164  # Dynamic source + cross-file globals + cd in subshell

set -euo pipefail

# ─── Resolve script directory (portable) ─────────────────────
# Works even with symlinks (bin/tep → scripts/tep.sh)
TEP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEP_SCRIPT_DIR

# ─── Source libraries (order matters) ────────────────────────
# log.sh first (everything depends on logging)
# fs.sh second (os detection, file checks)
# strings.sh third (text analysis, depends on nothing)
# tokens.sh fourth (depends on strings + log)
# report.sh last (depends on log + fs)
source "${TEP_SCRIPT_DIR}/lib/log.sh"
source "${TEP_SCRIPT_DIR}/lib/fs.sh"
source "${TEP_SCRIPT_DIR}/lib/strings.sh"
source "${TEP_SCRIPT_DIR}/lib/tokens.sh"
source "${TEP_SCRIPT_DIR}/lib/report.sh"

# ─── Source all steps ────────────────────────────────────────
for step_file in "${TEP_SCRIPT_DIR}"/steps/*.sh; do
	[[ -f "$step_file" ]] && source "$step_file"
done

# ─── Timing ──────────────────────────────────────────────────
TEP_START_TIME=$(date +%s)

# ─── Step runner ─────────────────────────────────────────────
# Runs a step function, handles errors, tracks step index.
TEP_CURRENT_STEP=0
TEP_FAILED_STEPS=0

run_step() {
	local step_func="$1"
	local critical="${2:-false}"  # true = abort on failure

	TEP_CURRENT_STEP=$((TEP_CURRENT_STEP + 1))

	if "$step_func"; then
		return 0
	else
		local rc=$?
		TEP_FAILED_STEPS=$((TEP_FAILED_STEPS + 1))

		if "$critical"; then
			log_fail "Critical step '$step_func' failed (rc=$rc) — aborting"
			# Still render what we have
			report_text ""
			report_text "## ❌ Audit interrompu"
			report_text "Step critique échoué : \`$step_func\` (code $rc)"
			report_finalize "${TEP_RESULT_FILE:-${TEP_SCRIPT_DIR}/out/RESULT.md}"
			return 1
		else
			log_warn "Step '$step_func' failed (rc=$rc) — continuing"
			return 0
		fi
	fi
}

# ─── Pipeline execution ─────────────────────────────────────
# Critical steps: ctx and inventory (no point continuing without them)
# Non-critical: everything else (partial report is still valuable)

run_step step_ctx        true  || exit 1
run_step step_inventory  true  || {
	# Inventory failed (no CLAUDE.md) — render partial report and exit
	step_render_report 2>/dev/null || true
	exit 1
}

# Non-critical steps (continue on failure)
run_step step_claude_md_audit false
run_step step_token_budget    false
run_step step_duplicates      false
run_step step_ignore_files    false
run_step step_settings_hooks  false
run_step step_session_stats   false
run_step step_score_recos     false
run_step step_history         false
run_step step_render_report   false

# ─── Timing summary ──────────────────────────────────────────
end_time=$(date +%s)
elapsed=$((end_time - TEP_START_TIME))

log_separator
log_summary "Duration" "${elapsed}s"

if [[ $TEP_FAILED_STEPS -gt 0 ]]; then
	log_warn "$TEP_FAILED_STEPS step(s) failed — check report"
	exit 1
else
	log_ok "All steps completed successfully"
	exit 0
fi