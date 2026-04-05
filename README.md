![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![ShellCheck](https://github.com/marcantoinedutoit/tep/actions/workflows/lint.yml/badge.svg)
![Bash 4+](https://img.shields.io/badge/Bash-4%2B-green.svg)
![GitHub release](https://img.shields.io/github/v/release/marcantoinedutoit/tep)
![GitHub stars](https://img.shields.io/github/stars/marcantoinedutoit/tep)
![GitHub last commit](https://img.shields.io/github/last-commit/marcantoinedutoit/tep)
![GitHub issues](https://img.shields.io/github/issues/marcantoinedutoit/tep)
![GitHub contributors](https://img.shields.io/github/contributors/marcantoinedutoit/tep)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

Audit & optimize prompt caching for Claude Code. Score /8, zero tokens consumed for the analysis.

<img width="720" height="377" alt="image" src="https://github.com/user-attachments/assets/d431d18f-bad3-470a-926f-ea5800fda4db" />

## Why TEP?
Anthropic's prompt caching offers a 90% cost reduction on cache-read tokens. But without knowing what to cache and where you're burning tokens, that power is wasted.

TEP is a pure observer: it reads Claude Code session data (`~/.claude/projects/`) and your target project's `CLAUDE.md` — without ever modifying the audited repo.

TEP produces:
- A score (0-8) measuring how well your config is optimized for prompt caching
- A detailed `out/RESULT.md` report with metrics, issues, and actionable recommendations
- Session cost analysis from your last Claude Code session (tokens, cache hit rate, estimated cost)
- Historical tracking via `evals/history.jsonl` for longitudinal optimization


## Quick start

	git clone https://github.com/marcantoinedutoit/tep.git
	cd tep
	chmod +x bin/tep
	# Run audit on any project
	./bin/tep audit /path/to/your/project

### Alternative: via pnpm/npx

	pnpm install
	# Via .env (PROJECT_AUDIT_DIR)
	cp .env.example .env
	# Edit .env with your target project path
	pnpm audit
	# Or via argument
	npx tep audit /path/to/your/project

### Windows: configure the shell
Create a `.npmrc` file at the root:

	script-shell="C:\\Program Files\\Git\\bin\\bash.exe"

This lets pnpm run `.sh` scripts via Git Bash.

## Requirements
- Node.js 18+ and pnpm 10+
- Bash 4+ (macOS: `brew install bash`, Linux: usually pre-installed; Windows: Git Bash)
- Standard Unix tools: grep, find, wc, awk
- Optional: `jq` for settings/session JSON parsing
- Claude Code installed and used on at least one project (for session stats)

## What TEP checks
| # | Step | What it does |
|---|------|--------------|
| 0 | Context | Resolve paths, detect OS, preflight checks |
| 1 | Inventory | Detect all Claude Code config files |
| 2 | CLAUDE.md audit | Size, volatile content, cache-friendly order, hardcoded paths |
| 3 | Token budget | Token cost of every config file |
| 4 | Duplicates | Cross-reference `CLAUDE.md` vs skills/agents |
| 5 | Ignore files | `.gitignore` and `.claudeignore` hygiene |
| 6 | Hooks & settings | `settings.json` validation, hooks safety, MCP servers |
| 7 | Session stats | Last session tokens, cache hit rate, cost, top files |
| 8 | Score & recos | 0-8 optimization score + personalized recommendations |
| 9 | History | Append snapshot to `evals/history.jsonl` |
| 10 | Report | Atomic write of `out/RESULT.md` |

## Scoring criteria
| Criterion | Pass condition |
|-----------|---------------|
| `CLAUDE.md` size | < 5,000 tokens |
| No hardcoded paths | Zero `/Users/xxx` or `C:\\Users\\xxx` |
| Cache-friendly order | Stable content before volatile |
| No duplicates | No skill content repeated in `CLAUDE.md` |
| `.gitignore` clean | `MEMORY.md` ignored, skills committed |
| `.claudeignore` present | `.git/` and heavy dirs excluded |
| Hooks safe | No hook modifies `CLAUDE.md` mid-session |
| Cache hit rate | ≥ 70% (auto-pass if no session data) |

## Project structure (v2)

	tep/
	├── bin/tep
	├── scripts/tep.sh
	├── lib/
	│   ├── log.sh
	│   ├── fs.sh
	│   ├── strings.sh
	│   ├── tokens.sh
	│   └── report.sh
	├── steps/
	│   ├── 00-ctx.sh
	│   ├── 01-inventory.sh
	│   ├── 02-claude-md-audit.sh
	│   ├── 03-token-budget.sh
	│   ├── 04-duplicates.sh
	│   ├── 05-ignore-files.sh
	│   ├── 06-settings-hooks.sh
	│   ├── 07-session-stats.sh
	│   ├── 08-score-recos.sh
	│   ├── 09-history.sh
	│   └── 10-render-report.sh
	├── docs/
	│   ├── methodology.md
	│   ├── cli.md
	│   ├── report-format.md
	│   └── troubleshooting.md
	├── evals/
	│   └── history.jsonl
	├── out/
	│   ├── RESULT.md
	│   └── .cache/
	└── examples/
		└── RESULT-example.md

## CLI options

	tep audit <project-path>        # Run full audit
	tep audit <path> --out <dir>    # Custom output directory
	tep audit <path> --no-color     # Disable colored output
	tep --help                      # Show help
	tep --version                   # Show version

## Usage

	# Via .env (PROJECT_AUDIT_DIR)
	pnpm audit
	# Via argument
	./bin/tep audit /path/to/your/project
	# In Claude Code, on the audited project:
	# Read out/RESULT.md and apply the recommendations to optimize caching.

## How it works
TEP is based on how Claude Code prompt caching behaves:
1. System prompt = `CLAUDE.md` + skills + settings → cached by the API
2. Any change invalidates the cache from that point forward
3. Stable content at the top = permanent cache hits
4. Volatile content (dates, TODOs) at the bottom = minimal cache invalidation
5. Smaller config = faster cache creation, cheaper re-creation

See `docs/methodology.md` for the full theory.

## Philosophy: TEP vs target project
| What | Where | Why |
|------|-------|-----|
| Analysis scripts, evals | TEP (this repo) | Observe without polluting |
| Restructured `CLAUDE.md` | Your project | Read at every Claude Code session |
| `.claude/skills/*.md` | Your project | On-demand instructions for caching |
| Session JSONL | No repo (`~/.claude/`) | Local data, never versioned |

## Complementary tools
- `ccusage` — usage reports (included in devDependencies)
- `claude-monitor` / `cmonitor` — real-time monitoring (`pip install claude-monitor`)
- `/cost` — built-in Claude Code command

## Resources
- Anthropic — Prompt Caching: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- Claude Code — Manage costs: https://docs.anthropic.com/en/docs/claude-code/costs
- Claude Code — Monitoring (OpenTelemetry): https://docs.anthropic.com/en/docs/claude-code/monitoring-usage

## Contributing
PRs are welcome. Run `shellcheck lib/*.sh steps/*.sh scripts/*.sh bin/tep` before submitting.

## License
MIT — see [LICENSE](LICENSE).