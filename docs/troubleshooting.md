Guide de dépannage TEP — problèmes courants et solutions.

---

## Code


# Troubleshooting

## Common Issues

### "No project path specified"

**Cause:** You ran `tep audit` without a path argument and `PROJECT_AUDIT_DIR` is not set.

**Fix:**
```
tep audit .                        # Current directory
tep audit /path/to/your/project    # Explicit path
```

Or create a `.env` file in the TEP repo:
```
PROJECT_AUDIT_DIR=/path/to/your/project
```

### "No CLAUDE.md found — cannot audit"

**Cause:** The target project doesn't have a `CLAUDE.md` file.

**Fix:** Create a `CLAUDE.md` in your project root. TEP can't audit a project that doesn't use Claude Code configuration.

### "jq not installed — limited analysis"

**Cause:** `jq` is not available on your system.

**Impact:** Session stats (step 7), JSON validation, and history trends are skipped.

**Fix:**
```
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Windows (Git Bash)
choco install jq

# or download from https://jqlang.github.io/jq/download/
```

### "Bash version 3.x detected"

**Cause:** macOS ships with Bash 3.2 (2007).

**Impact:** Case conversion (`${var^^}`) and associative arrays don't work.

**Fix:**
```
brew install bash
# Then either:
# 1. Use the new bash: /opt/homebrew/bin/bash bin/tep audit .
# 2. Add /opt/homebrew/bin/bash to /etc/shells and change default
```

### Empty RESULT.md

**Cause:** Usually a critical step failed before the report could be written.

**Fix:**
1. Check terminal output (stderr) for error messages
2. Run with `--verbose` for more details
3. Verify the project path exists and is readable

### "Permission denied" on bin/tep

**Fix:**
```
chmod +x bin/tep
```

### Session stats show "N/A"

**Cause:** TEP looks for session files in `~/.claude/projects/*<project_name>*/`.

**Possible reasons:**
1. No Claude Code session has been run for this project
2. The project directory name doesn't match (TEP uses `basename` of the project path)
3. Claude Code stores sessions in a different location

**Workaround:** Session stats are informational only — the audit score still works without them.

### Cache hit rate is 0%

**Cause:** This can happen if:
1. It was the first message in a new session (cache hasn't been created yet)
2. The CLAUDE.md changed between messages (cache invalidation)
3. The jq query didn't match any usage data

**Fix:** Run a few messages in Claude Code first, then re-audit. The cache builds up over multiple exchanges.

### Score seems unfair

The scoring system is designed for common configurations. Some criteria might not apply to your setup:

- **Cache hit rate auto-passes** if no session data is available
- **Hardcoded paths** only flags `/Users/xxx` and `C:\Users\xxx` patterns
- **Duplicates** uses a heuristic (>3 keyword matches) that may have false positives

If a criterion is consistently irrelevant, consider it a known limitation.

## Getting Help

1. Check the terminal output with `--verbose`
2. Open an issue: https://github.com/marc-music/tep/issues
3. Include: OS, Bash version (`bash --version`), jq availability, and the error message
