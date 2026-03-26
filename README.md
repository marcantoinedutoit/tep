# TEP — Token Economy Paradigm

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![ShellCheck](https://github.com/MadSaas/tep/actions/workflows/lint.yml/badge.svg)

Audit & optimize prompt caching for **Claude Code CLI**. Score /8, zero tokens consumed for the analysis.

## Why TEP?

Anthropic's prompt caching offers a **90% cost reduction** on cache-read tokens. But without knowing **what** to cache and **where** you're burning tokens, that power is wasted.

TEP is a **pure observer**: it reads Claude Code session data (`~/.claude/projects/`) and your target project's `CLAUDE.md` — without ever modifying the audited repo.

![TEP screenshot](screen.jpg)

## Quick start

```bash
git clone https://github.com/MadSaas/tep.git
cd tep
pnpm install
cp .env.example .env
# Edit .env with your target project path
pnpm tep:audit
```

## Requirements

- **Node.js** 18+ and **pnpm** 10+
- **bash** — Git Bash (Windows), native (Linux/macOS)
- **jq** — for JSON parsing of session JSONL files
- **Claude Code CLI** installed and used on at least one project

### Windows: configure the shell

Create a `.npmrc` file at the root:

```
script-shell="C:\\Program Files\\Git\\bin\\bash.exe"
```

This lets pnpm run `.sh` scripts via Git Bash.

## What TEP does

A single script (`audit-and-optimize.sh`) — 9 steps:

1. **Inventory** of Claude Code files (CLAUDE.md, skills, settings, AGENTS.md...)
2. **CLAUDE.md audit** — token count, sections, volatile content, cache-friendly ordering
3. **Token budget** — total config files read by Claude Code
4. **Duplicates** — CLAUDE.md vs skills/agents
5. **Check .gitignore & .claudeignore**
6. **Hooks & settings** — detect hooks that break the cache
7. **Session stats** — tokens, cost, cache hit rate, top files, top actions
8. **Score /8 + recommendations**
9. **History** — append to `evals/history.jsonl`

Generates `docs/RESULT.md` — a structured report **scannable by Claude Code** for self-optimization.

```bash
# In Claude Code, on the audited project:
Read docs/RESULT.md and apply the recommendations to optimize caching.
```

## Usage

```bash
# Via .env (PROJECT_AUDIT_DIR)
pnpm tep:audit

# Via argument
pnpm tep:audit -- /path/to/project

# Global usage monitoring
pnpm usage
```

## Project structure

```
tep/
├── scripts/
│   └── audit-and-optimize.sh  # Single script: 9 steps → RESULT.md
├── evals/
│   └── history.jsonl           # Score history (JSONL)
├── docs/
│   ├── RESULT.md               # Generated report (scannable by Claude Code)
│   ├── METHODOLOGY.md          # Prompt caching theory
│   └── RESULTS.md              # Output example
├── .claude/skills/
│   └── cache-audit/SKILL.md    # Reusable skill for quick audits
├── .env.example                # Config template
├── package.json                # npm/pnpm scripts
└── README.md
```

## Key metrics

| Metric | Target | Why |
|--------|--------|-----|
| Cache hit rate | > 80% | Anthropic targets > 95% |
| CLAUDE.md size | < 5000 tokens | Beyond that, caching becomes less effective |
| TEP score | 8/8 | All best practices met |
| Volatile content | 0 | TODO/WIP/dates invalidate the cache |

## Philosophy: TEP vs target project

| What | Where | Why |
|------|-------|-----|
| Analysis scripts, evals | **TEP** (this repo) | Observe without polluting |
| Restructured CLAUDE.md | **Your project** | Read at every Claude Code session |
| .claude/skills/*.md | **Your project** | On-demand instructions for caching |
| Session JSONL | **No repo** (`~/.claude/`) | Local data, never versioned |

## Complementary tools

- `ccusage` — usage reports (included in devDependencies)
- `claude-monitor` / `cmonitor` — real-time monitoring (`pip install claude-monitor`)
- `/cost` — built-in Claude Code command

## Resources

- [Anthropic — Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Claude Code — Manage costs](https://docs.anthropic.com/en/docs/claude-code/costs)
- [Claude Code — Monitoring (OpenTelemetry)](https://docs.anthropic.com/en/docs/claude-code/monitoring-usage)

## Contributing

PRs are welcome. Run `shellcheck scripts/audit-and-optimize.sh` before submitting.

## License

MIT — see [LICENSE](LICENSE)
