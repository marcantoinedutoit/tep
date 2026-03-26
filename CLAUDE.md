# CLAUDE.md — TEP (Token Economy Paradigm)

## Project

Prompt cache audit tool for Claude Code CLI. A single bash script (`scripts/audit-and-optimize.sh`) analyzes a target project and generates `docs/RESULT.md` (score /8 + recommendations).

TEP is a **pure observer**: it never modifies the audited repo.

## Stack

- Bash (main script ~800 lines)
- Node.js / pnpm (runner only)
- jq (JSON parsing of sessions)
- No framework, no build step

## Commands

```bash
pnpm tep:audit              # Audit the project defined in .env
pnpm tep:audit -- /path     # Audit a specific project
pnpm usage                  # Global Claude Code usage (ccusage)
```

## Key structure

- `scripts/audit-and-optimize.sh` — Monolithic script, 9 sequential steps
- `docs/RESULT.md` — Generated report (overwritten each run)
- `evals/history.jsonl` — Score history (append JSONL)
- `.claude/skills/cache-audit/SKILL.md` — Reusable skill for quick audits
- `.env` — Local config (`PROJECT_AUDIT_DIR=...`), never committed

## Conventions

- Language: **English** (code, docs, comments, output)
- The script must remain **a single file** (no splitting into modules)
- Compatibility: Git Bash (Windows), bash (Linux), zsh (macOS)
- Max score: 8 criteria, each worth 1 point
- Token estimation: `words × 13 / 10`
- RESULT.md must be **scannable by Claude Code** (markdown tables, clear sections)

## Rules

- Never write to the audited repo (read-only)
- Never commit `.env` or user session data
- `docs/RESULT.md` is a generic example (no personal data)
- Paths in examples use `/path/to/...` (no real paths)
