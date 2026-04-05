Référence CLI complète pour TEP v2.

---

## Code

# CLI Reference

## Synopsis

```
tep <command> [options]
```

## Commands

### `tep audit <project-path>`

Run a full audit on the specified project directory.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `<project-path>` | Yes | Path to the project to audit (absolute or relative) |

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--out <dir>` | `tep/out/` | Output directory for RESULT.md |
| `--no-color` | Off | Disable colored terminal output |
| `--verbose` | Off | Show extra debug information |

**Examples:**

```
# Audit current directory
tep audit .
# Audit a specific project
tep audit ~/projects/my-app
# Custom output directory
tep audit . --out ./reports
# CI/CD mode (no colors)
tep audit /path/to/project --no-color
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | All steps completed successfully |
| 1 | One or more steps failed (check RESULT.md) |

### `tep --help`

Show usage information.

### `tep --version`

Print the current TEP version.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|--------|
| `PROJECT_AUDIT_DIR` | Fallback project path (from .env) | — |
| `TEP_NO_COLOR` | Set to `1` to disable colors | — |
| `TEP_VERBOSE` | Set to `1` for extra output | — |
| `TEP_OUT_DIR` | Override output directory | `tep/out/` |
| `TEP_TOKEN_RATIO` | Token/word ratio × 10 (default: 13 = 1.3) | `13` |

## Configuration

TEP looks for a `.env` file in the TEP repo root. This file is optional.

```
# .env.example
PROJECT_AUDIT_DIR=/path/to/default/project
```

## Output

After a successful audit, TEP produces:

1. **`out/RESULT.md`** — Full audit report with score, metrics, and recommendations
2. **`evals/history.jsonl`** — Appended snapshot of this audit's metrics
3. **Terminal output** — Colored summary on stderr

## Progressive Enhancement

TEP adapts to available tools:

| Tool | Required? | What it enables |
|------|-----------|----------------|
| bash 4+ | Recommended | Case conversion, associative arrays |
| grep, find, wc, awk | Yes | Core text analysis |
| jq | No | Enhanced settings.json parsing, session stats, history trends |

Without `jq`, TEP still produces a complete audit — session stats and JSON validation are skipped.

## Installation Methods

### 1. Direct (recommended for dev)
```
git clone https://github.com/marc-music/tep.git
cd tep
chmod +x bin/tep
./bin/tep audit /path/to/project
```

### 2. Symlink
```
chmod +x bin/tep
ln -sf "$(pwd)/bin/tep" /usr/local/bin/tep
tep audit .
```

### 3. npx
```
npm install
npx tep audit .
```
