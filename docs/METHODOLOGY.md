# TEP Methodology — Prompt Caching

## How Anthropic's prompt cache works

Claude Code sends a full prompt on every turn: system prompt + tools + CLAUDE.md + session context + messages. **Prompt caching** reuses already-processed tokens when the beginning of the prompt is identical to the previous turn.

**Cost reduction**: cache-read tokens cost **90% less** than regular input tokens.

## Cache hit condition

The cache works by **exact prefix matching**: if the first N tokens are identical to the previous turn, they are served from cache. As soon as a single token differs, everything after it is recomputed.

Direct consequence: **stable content must be at the top, volatile content at the bottom**.

## The 8 TEP criteria

### 1. CLAUDE.md size < 5000 tokens
An oversized CLAUDE.md wastes cache budget. Heavy sections should be extracted to `.claude/skills/` (loaded on demand).

### 2. No volatile content
Markers like `TODO`, `FIXME`, `WIP`, dynamic dates invalidate the cache on every change. They must be isolated at the end of the file or removed.

### 3. Cache-friendly ordering
CLAUDE.md should follow this order:
1. Project identity (stable)
2. Tech stack (stable)
3. Code conventions (stable)
4. Commands (semi-stable)
5. Current context (volatile) — **always last**

### 4. No duplicates
If information exists in a skill or AGENTS.md, it should not be repeated in CLAUDE.md.

### 5. Correct .gitignore
- `MEMORY.md` must be ignored (local data)
- `.claude/skills/` must **not** be ignored (shared via git)

### 6. Safe hooks
Hooks must not dynamically modify the system prompt (timestamps, full git status), as this invalidates the cache on every turn.

### 7. .claudeignore configured
Prevents Claude Code from reading unnecessary files (node_modules, logs, IDE files).

### 8. No hardcoded paths
Absolute paths in CLAUDE.md only work on one machine.

## Cache hit rate

| Rate | Verdict |
|------|---------|
| > 95% | Excellent (Anthropic's target) |
| > 80% | Good (TEP's target) |
| 50-80% | Needs optimization |
| < 50% | Structural issue |

## Cost per token (Claude Sonnet)

| Type | Price / 1M tokens |
|------|-------------------|
| Input | $3.00 |
| Output | $15.00 |
| Cache read | $0.30 |
| Cache creation | $3.75 |

## Sources

- [Anthropic — Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Claude Code — Manage costs](https://docs.anthropic.com/en/docs/claude-code/costs)
