#!/usr/bin/env bash
# lib/fs.sh — Filesystem utilities for TEP
# Source this file; do not execute directly.

# shellcheck disable=SC2034,SC2164  # Cross-file globals + cd in subshell intentional

[[ -n "${_TEP_FS_LOADED:-}" ]] && return 0
_TEP_FS_LOADED=1

# ─── OS Detection ────────────────────────────────────────────
# Sets TEP_OS to: linux | macos | windows | wsl | unknown
tep_detect_os() {
	local uname_out
	uname_out="$(uname -s 2>/dev/null || echo 'Unknown')"

	case "$uname_out" in
		Linux*)
			if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
				TEP_OS="wsl"
			else
				TEP_OS="linux"
			fi
			;;
		Darwin*)
			TEP_OS="macos"
			;;
		MINGW*|MSYS*|CYGWIN*)
			TEP_OS="windows"
			;;
		*)
			TEP_OS="unknown"
			;;
	esac
	export TEP_OS
}

# ─── Portable realpath ───────────────────────────────────────
# macOS < 12 may not have realpath; 3-level fallback
tep_realpath() {
	local target="$1"

	if command -v realpath &>/dev/null; then
		realpath -- "$target"
	elif command -v python3 &>/dev/null; then
		python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target"
	else
		# Manual fallback: cd + pwd
		if [[ -d "$target" ]]; then
			(cd -- "$target" && pwd)
		elif [[ -f "$target" ]]; then
			local dir
			dir="$(cd -- "$(dirname -- "$target")" && pwd)"
			echo "${dir}/$(basename -- "$target")"
		else
			echo "$target"  # best effort
		fi
	fi
}

# ─── Safe existence checks ───────────────────────────────────
file_exists() { [[ -f "${1:-}" ]]; }
dir_exists()  { [[ -d "${1:-}" ]]; }
is_readable() { [[ -r "${1:-}" ]]; }

# ─── Directory creation with error logging ───────────────────
ensure_dir() {
	local dir="$1"
	if [[ ! -d "$dir" ]]; then
		mkdir -p "$dir" || {
			log_fail "Cannot create directory: $dir"
			return 1
		}
	fi
}

# ─── Atomic write (stdin → target) ───────────────────────────
# Writes to a temp file in the same dir, then mv.
# Ensures no partial/corrupt output if interrupted.
atomic_write_stdin() {
	local target="$1"
	local target_dir
	target_dir="$(dirname -- "$target")"
	ensure_dir "$target_dir"

	local tmp_file
	tmp_file="$(mktemp "${target_dir}/.tep_tmp.XXXXXX")" || {
		log_fail "Cannot create temp file for: $target"
		return 1
	}

	# Cleanup on any failure
	trap 'rm -f "$tmp_file"' ERR

	cat > "$tmp_file" || {
		rm -f "$tmp_file"
		log_fail "Write failed for: $target"
		return 1
	}

	mv -- "$tmp_file" "$target" || {
		rm -f "$tmp_file"
		log_fail "Atomic mv failed for: $target"
		return 1
	}

	trap - ERR
}

# ─── Dependency check ────────────────────────────────────────
# Usage: tep_require "jq" "warn"   (warn = non-fatal)
#        tep_require "bash" "fail"  (fail = fatal)
tep_require() {
	local cmd="$1"
	local level="${2:-warn}"

	if ! command -v "$cmd" &>/dev/null; then
		if [[ "$level" == "fail" ]]; then
			log_fail "Required command not found: $cmd"
		else
			log_warn "Optional command not found: $cmd (some features disabled)"
		fi
		return 1
	fi
	return 0
}

# ─── jq availability (cached global flag) ────────────────────
TEP_HAS_JQ=false
tep_check_jq() {
	if command -v jq &>/dev/null; then
		TEP_HAS_JQ=true
	else
		TEP_HAS_JQ=false
		log_warn "jq not installed — session stats and JSON validation disabled"
	fi
}