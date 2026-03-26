#!/bin/bash
# audit-and-optimize.sh — Full audit + report for Claude Code
# Usage: bash scripts/audit-and-optimize.sh [project-path]
# Output: docs/RESULT.md (scannable by Claude Code)

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC2046
[ -f "$SCRIPT_DIR/.env" ] && export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
PROJECT_DIR="${1:-${PROJECT_AUDIT_DIR:-}}"
OUTPUT_DIR="$SCRIPT_DIR/docs"
RESULT_FILE="$OUTPUT_DIR/RESULT.md"

# --- Colors (terminal only) ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# --- Guards ---
if [ -z "$PROJECT_DIR" ]; then
  echo -e "${RED}❌ Usage: $0 <project-path>${NC}"
  echo "   Or set PROJECT_AUDIT_DIR in .env"
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo -e "${RED}❌ Directory not found: $PROJECT_DIR${NC}"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

PROJECT_NAME=$(basename "$PROJECT_DIR")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

echo -e "${GREEN}═══ TEP — Audit & Optimize ═══${NC}"
echo -e "📂 Project: ${GREEN}$PROJECT_NAME${NC} ($PROJECT_DIR)"
echo -e "📄 Output: $RESULT_FILE"
echo "---"

# ============================================================
# RESULT.MD — Header
# ============================================================
cat > "$RESULT_FILE" << EOF
# TEP Audit Report — $PROJECT_NAME

> Generated on $TIMESTAMP by \`audit-and-optimize.sh\`
> Project: \`$PROJECT_DIR\`

---

EOF

# ============================================================
# 1. INVENTORY
# ============================================================
echo -e "\n${GREEN}[1/9] Claude Code file inventory${NC}"

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
CLAUDE_DIR="$PROJECT_DIR/.claude"

HAS_CLAUDE_MD=false; [ -f "$CLAUDE_MD" ] && HAS_CLAUDE_MD=true
HAS_CLAUDE_DIR=false; [ -d "$CLAUDE_DIR" ] && HAS_CLAUDE_DIR=true
HAS_SKILLS=false; [ -d "$CLAUDE_DIR/skills" ] && HAS_SKILLS=true
HAS_MEMORY=false; [ -f "$CLAUDE_DIR/MEMORY.md" ] && HAS_MEMORY=true
HAS_SETTINGS=false; [ -f "$CLAUDE_DIR/settings.json" ] && HAS_SETTINGS=true
HAS_AGENTS=false; { [ -f "$CLAUDE_DIR/AGENTS.md" ] || [ -f "$PROJECT_DIR/AGENTS.md" ]; } && HAS_AGENTS=true

SKILL_COUNT=0
$HAS_SKILLS && SKILL_COUNT=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

DOCS_COUNT=0
[ -d "$PROJECT_DIR/docs" ] && DOCS_COUNT=$(find "$PROJECT_DIR/docs" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# Terminal — helper function to avoid quoting issues
status_icon() {
  if $1; then echo "✅"; else echo "$2"; fi
}
status_icon_text() {
  if $1; then echo "✅ $2"; else echo "$3"; fi
}

echo "   CLAUDE.md        : $(status_icon "$HAS_CLAUDE_MD" '❌')"
echo "   .claude/          : $(status_icon "$HAS_CLAUDE_DIR" '❌')"
echo "   .claude/skills/   : $(status_icon_text "$HAS_SKILLS" "$SKILL_COUNT file(s)" '➖')"
echo "   .claude/MEMORY.md : $(status_icon "$HAS_MEMORY" '➖')"
echo "   settings.json     : $(status_icon "$HAS_SETTINGS" '➖')"
echo "   AGENTS.md         : $(status_icon "$HAS_AGENTS" '➖')"
echo "   docs/*.md         : $DOCS_COUNT file(s)"

# Result.md
INV_CLAUDE_MD=$(status_icon_text "$HAS_CLAUDE_MD" 'found' '❌ **MISSING**')
INV_CLAUDE_DIR=$(status_icon "$HAS_CLAUDE_DIR" '❌')
INV_SKILLS=$(status_icon_text "$HAS_SKILLS" "$SKILL_COUNT file(s)" '➖ missing')
INV_MEMORY=$(status_icon "$HAS_MEMORY" '➖ missing')
INV_SETTINGS=$(status_icon "$HAS_SETTINGS" '➖ missing')
INV_AGENTS=$(status_icon "$HAS_AGENTS" '➖ missing')

cat >> "$RESULT_FILE" << EOF
## 1. Inventory

| File | Status |
|------|--------|
| CLAUDE.md | $INV_CLAUDE_MD |
| .claude/ | $INV_CLAUDE_DIR |
| .claude/skills/ | $INV_SKILLS |
| .claude/MEMORY.md | $INV_MEMORY |
| .claude/settings.json | $INV_SETTINGS |
| AGENTS.md | $INV_AGENTS |
| docs/*.md | $DOCS_COUNT file(s) |

EOF

if ! $HAS_CLAUDE_MD; then
  echo -e "${RED}❌ No CLAUDE.md — cannot audit.${NC}"
  echo "" >> "$RESULT_FILE"
  echo "## ❌ STOP — No CLAUDE.md" >> "$RESULT_FILE"
  echo "Create a CLAUDE.md before running the audit." >> "$RESULT_FILE"
  exit 0
fi

# ============================================================
# 2. AUDIT CLAUDE.MD
# ============================================================
echo -e "\n${GREEN}[2/9] CLAUDE.md audit${NC}"

WORDS=$(wc -w < "$CLAUDE_MD" | tr -d ' ')
TOKENS_APPROX=$((WORDS * 13 / 10))
SECTION_COUNT=$(grep -c '^#' "$CLAUDE_MD" 2>/dev/null || echo 0)

# Volatile detection
VOLATILE_LINES=""
if grep -qiE '(TODO|FIXME|WIP|HACK|en cours|current task|in progress)' "$CLAUDE_MD" 2>/dev/null; then
  VOLATILE_LINES=$(grep -niE '(TODO|FIXME|WIP|HACK|en cours|current task|in progress)' "$CLAUDE_MD" 2>/dev/null | head -10)
fi

DATE_LINES=""
if grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$CLAUDE_MD" 2>/dev/null; then
  DATE_LINES=$(grep -nE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$CLAUDE_MD" 2>/dev/null | head -5)
fi

VOLATILE_COUNT=0
[ -n "$VOLATILE_LINES" ] && VOLATILE_COUNT=$((VOLATILE_COUNT + 1))
[ -n "$DATE_LINES" ] && VOLATILE_COUNT=$((VOLATILE_COUNT + 1))

# Cache order
FIRST_VOLATILE_LINE=$(grep -niE '(TODO|FIXME|WIP|en cours|current|contexte courant|current context|volatile)' "$CLAUDE_MD" 2>/dev/null | head -1 | cut -d: -f1 || true)
LAST_HEADING_LINE=$(grep -n '^## ' "$CLAUDE_MD" 2>/dev/null | tail -1 | cut -d: -f1 || true)

ORDER_OK=true
if [ -n "$FIRST_VOLATILE_LINE" ] && [ -n "$LAST_HEADING_LINE" ]; then
  [ "$FIRST_VOLATILE_LINE" -lt "$LAST_HEADING_LINE" ] && ORDER_OK=false
fi

# Sections list
SECTIONS_LIST=$(grep -n '^#' "$CLAUDE_MD" 2>/dev/null | head -30)

# References
REF_COUNT=$(grep -cE '(docs/|skills/|.claude/)' "$CLAUDE_MD" 2>/dev/null || echo 0)

# Hardcoded paths
HARDCODED_PATHS=""
HARDCODED_COUNT=0
HP_RESULTS=$(grep -rnE '(/Users/[a-zA-Z]|/home/[a-zA-Z]|[A-Z]:\\Users|[A-Z]:/Users)' "$CLAUDE_MD" 2>/dev/null || true)
if [ -n "$HP_RESULTS" ]; then
  HARDCODED_COUNT=$(echo "$HP_RESULTS" | wc -l | tr -d ' ')
  HARDCODED_PATHS="$HP_RESULTS"
  echo -e "   ${RED}❌ $HARDCODED_COUNT hardcoded personal path(s)${NC}"
else
  echo "   ✅ No hardcoded paths"
fi
if $HAS_SKILLS; then
  HP_SKILLS=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' -exec grep -lE '(/Users/[a-zA-Z]|/home/[a-zA-Z]|[A-Z]:\\Users|[A-Z]:/Users)' {} \; 2>/dev/null || true)
  if [ -n "$HP_SKILLS" ]; then
    HP_S_COUNT=$(echo "$HP_SKILLS" | wc -l | tr -d ' ')
    HARDCODED_COUNT=$((HARDCODED_COUNT + HP_S_COUNT))
    echo -e "   ${RED}❌ $HP_S_COUNT skill(s) with personal paths${NC}"
  fi
fi

# Size verdict
SIZE_VERDICT="✅ Compact (<5k tokens)"
[ "$TOKENS_APPROX" -gt 5000 ] && SIZE_VERDICT="⚠️ Large (>5k tokens) — room for optimization"
[ "$TOKENS_APPROX" -gt 8000 ] && SIZE_VERDICT="🚨 VERY LARGE (>8k tokens) — cache inefficient"

# Terminal
echo "   📏 $WORDS words ≈ ~$TOKENS_APPROX tokens — $SIZE_VERDICT"
echo "   📑 $SECTION_COUNT sections | $REF_COUNT external refs"
[ "$VOLATILE_COUNT" -gt 0 ] && echo -e "   ${YELLOW}⚠️  $VOLATILE_COUNT type(s) of volatile content detected${NC}"
$ORDER_OK && echo "   ✅ Cache-friendly order OK" || echo -e "   ${RED}❌ Volatile BEFORE stable — bad for caching${NC}"

# Result.md
cat >> "$RESULT_FILE" << EOF
## 2. CLAUDE.md audit

| Metric | Value |
|--------|-------|
| Words | $WORDS |
| Tokens (approx) | ~$TOKENS_APPROX |
| Sections | $SECTION_COUNT |
| External refs | $REF_COUNT |
| Size | $SIZE_VERDICT |
| Volatile content | $VOLATILE_COUNT type(s) detected |
| Cache-friendly order | $(if $ORDER_OK; then echo '✅ OK'; else echo '❌ Volatile before stable'; fi) |
| Hardcoded paths | $(if [ "$HARDCODED_COUNT" -eq 0 ]; then echo '✅ none'; else echo "❌ $HARDCODED_COUNT found"; fi) |

EOF

if [ -n "$VOLATILE_LINES" ]; then
  cat >> "$RESULT_FILE" << EOF
### Volatile content detected
\`\`\`
$VOLATILE_LINES
\`\`\`

EOF
fi

if [ -n "$DATE_LINES" ]; then
  cat >> "$RESULT_FILE" << EOF
### Hardcoded dates
\`\`\`
$DATE_LINES
\`\`\`

EOF
fi

if [ -n "$SECTIONS_LIST" ]; then
  cat >> "$RESULT_FILE" << EOF
### Section structure
\`\`\`
$SECTIONS_LIST
\`\`\`

EOF
fi

if [ -n "$HARDCODED_PATHS" ]; then
  cat >> "$RESULT_FILE" << EOF
### Hardcoded paths detected
\`\`\`
$HARDCODED_PATHS
\`\`\`

EOF
fi

# ============================================================
# 3. DUPLICATES
# ============================================================
echo -e "\n${GREEN}[4/9] Duplicate detection${NC}"

DUPLICATE_RISK=0
DUPLICATE_DETAILS=""

if $HAS_SKILLS; then
  SKILL_FILES=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' 2>/dev/null)
  if [ -n "$SKILL_FILES" ]; then
    while IFS= read -r skill; do
      SKILL_NAME=$(basename "$skill" .md)
      SKILL_WORDS=$(wc -w < "$skill" | tr -d ' ')
      SKILL_KEYWORDS=$(head -5 "$skill" | grep -oE '[A-Z][a-z]+' 2>/dev/null | sort -u | head -5 | tr '\n' '|' | sed 's/|$//' || true)
      if [ -n "$SKILL_KEYWORDS" ]; then
        MATCHES=$(grep -ciE "$SKILL_KEYWORDS" "$CLAUDE_MD" 2>/dev/null || echo 0)
        if [ "$MATCHES" -gt 3 ]; then
          echo -e "   ${YELLOW}⚠️  $SKILL_NAME ($SKILL_WORDS words) — $MATCHES cross-references${NC}"
          DUPLICATE_RISK=$((DUPLICATE_RISK + 1))
          DUPLICATE_DETAILS="$DUPLICATE_DETAILS\n- **$SKILL_NAME** ($SKILL_WORDS words): $MATCHES cross-references in CLAUDE.md → likely duplicate"
        else
          echo "   ✅ $SKILL_NAME — no duplicate"
        fi
      fi
    done <<< "$SKILL_FILES"
  else
    echo "   ℹ️  .claude/skills/ is empty"
  fi
else
  echo "   ℹ️  No skills to compare"
fi

if $HAS_AGENTS; then
  AGENTS_FILE="$CLAUDE_DIR/AGENTS.md"
  [ ! -f "$AGENTS_FILE" ] && AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
  AGENTS_WORDS=$(wc -w < "$AGENTS_FILE" | tr -d ' ')
  echo "   ℹ️  AGENTS.md detected ($AGENTS_WORDS words)"
fi

cat >> "$RESULT_FILE" << EOF
## 4. Duplicates (CLAUDE.md vs skills/agents)

- Duplicate risks: **$DUPLICATE_RISK**
EOF

if [ -n "$DUPLICATE_DETAILS" ]; then
  echo -e "$DUPLICATE_DETAILS" >> "$RESULT_FILE"
fi

$HAS_AGENTS && echo "- AGENTS.md present ($AGENTS_WORDS words) — be careful not to duplicate" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# ============================================================
# 3. TOKEN BUDGET
# ============================================================
echo -e "\n${GREEN}[3/9] Token budget — config files${NC}"

TOTAL_CONFIG_TOKENS=0
TOKEN_TABLE=""

add_to_inventory() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then
    local lines chars words tokens
    lines=$(wc -l < "$file" | tr -d ' ')
    chars=$(wc -c < "$file" | tr -d ' ')
    words=$(wc -w < "$file" | tr -d ' ')
    tokens=$((words * 13 / 10))
    TOTAL_CONFIG_TOKENS=$((TOTAL_CONFIG_TOKENS + tokens))
    TOKEN_TABLE="${TOKEN_TABLE}| ${label} | ${lines} | ${chars} | ~${tokens} |\n"
    echo "   ${label}: ${lines} lines, ~${tokens} tokens"
  fi
}

add_to_inventory "$CLAUDE_MD" "CLAUDE.md"
if $HAS_AGENTS; then
  AGF="$CLAUDE_DIR/AGENTS.md"
  [ ! -f "$AGF" ] && AGF="$PROJECT_DIR/AGENTS.md"
  add_to_inventory "$AGF" "AGENTS.md"
fi
$HAS_SETTINGS && add_to_inventory "$CLAUDE_DIR/settings.json" "settings.json"
[ -f "$CLAUDE_DIR/settings.local.json" ] && add_to_inventory "$CLAUDE_DIR/settings.local.json" "settings.local.json"

if $HAS_SKILLS; then
  SK_LIST=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' 2>/dev/null || true)
  if [ -n "$SK_LIST" ]; then
    while IFS= read -r sf; do
      add_to_inventory "$sf" "${sf#"$PROJECT_DIR"/}"
    done <<< "$SK_LIST"
  fi
fi

if [ -d "$CLAUDE_DIR/rules" ]; then
  RL_LIST=$(find "$CLAUDE_DIR/rules" -type f -name '*.md' 2>/dev/null || true)
  if [ -n "$RL_LIST" ]; then
    while IFS= read -r rf; do
      add_to_inventory "$rf" "${rf#"$PROJECT_DIR"/}"
    done <<< "$RL_LIST"
  fi
fi

echo "   ────────────────────────"
echo -e "   ${GREEN}TOTAL: ~$TOTAL_CONFIG_TOKENS config tokens${NC}"

cat >> "$RESULT_FILE" << EOF
## 3. Token budget (config)

| File | Lines | Chars | Est. Tokens |
|------|------:|------:|------------:|
$(echo -e "$TOKEN_TABLE" | sed '/^$/d')
| **TOTAL** | | | **~$TOTAL_CONFIG_TOKENS** |

EOF

# ============================================================
# 4. GITIGNORE + CLAUDEIGNORE
# ============================================================
echo -e "\n${GREEN}[5/9] Check .gitignore & .claudeignore${NC}"

GITIGNORE="$PROJECT_DIR/.gitignore"
GITIGNORE_ISSUES=0
GITIGNORE_DETAILS=""

if [ -f "$GITIGNORE" ]; then
  if $HAS_MEMORY; then
    if grep -q '.claude/MEMORY.md' "$GITIGNORE" 2>/dev/null; then
      echo "   ✅ .claude/MEMORY.md in .gitignore"
    else
      echo -e "   ${RED}❌ .claude/MEMORY.md NOT in .gitignore${NC}"
      GITIGNORE_ISSUES=$((GITIGNORE_ISSUES + 1))
      GITIGNORE_DETAILS="$GITIGNORE_DETAILS\n- ❌ Add \`.claude/MEMORY.md\` to .gitignore (changes every session)"
    fi
  fi

  if $HAS_SKILLS; then
    if grep -q '.claude/skills' "$GITIGNORE" 2>/dev/null; then
      echo -e "   ${RED}❌ .claude/skills/ in .gitignore (should be committed!)${NC}"
      GITIGNORE_ISSUES=$((GITIGNORE_ISSUES + 1))
      GITIGNORE_DETAILS="$GITIGNORE_DETAILS\n- ❌ Remove \`.claude/skills/\` from .gitignore (skills should be committed)"
    else
      echo "   ✅ .claude/skills/ will be committed"
    fi
  fi
else
  echo -e "   ${YELLOW}⚠️  No .gitignore${NC}"
fi

# .claudeignore check
CLAUDEIGNORE="$PROJECT_DIR/.claudeignore"
CLAUDEIGNORE_ISSUES=0

if [ -f "$CLAUDEIGNORE" ]; then
  echo "   ✅ .claudeignore exists"
  if ! grep -qE '\.git(/|$)' "$CLAUDEIGNORE" 2>/dev/null; then
    echo -e "   ${RED}❌ .git/ NOT in .claudeignore${NC}"
    CLAUDEIGNORE_ISSUES=$((CLAUDEIGNORE_ISSUES + 1))
  else
    echo "   ✅ .git/ in .claudeignore"
  fi
  MISSING_PATS=""
  for pat in node_modules dist build .next __pycache__ target; do
    if [ -d "$PROJECT_DIR/$pat" ] && ! grep -q "$pat" "$CLAUDEIGNORE" 2>/dev/null; then
      MISSING_PATS="$MISSING_PATS $pat"
    fi
  done
  if [ -n "$MISSING_PATS" ]; then
    echo -e "   ${YELLOW}⚠️  Existing directories not ignored:$MISSING_PATS${NC}"
  fi
else
  echo -e "   ${YELLOW}⚠️  No .claudeignore — Claude Code may read unnecessary files${NC}"
  CLAUDEIGNORE_ISSUES=$((CLAUDEIGNORE_ISSUES + 1))
fi

cat >> "$RESULT_FILE" << EOF
## 5. Check .gitignore & .claudeignore

- .gitignore issues: **$GITIGNORE_ISSUES**
- .claudeignore issues: **$CLAUDEIGNORE_ISSUES**
EOF

[ -n "$GITIGNORE_DETAILS" ] && echo -e "$GITIGNORE_DETAILS" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# ============================================================
# 5. HOOKS & SETTINGS (Cache audit check 1)
# ============================================================
echo -e "\n${GREEN}[6/9] Hooks & settings.json analysis${NC}"

HOOKS_ISSUES=0
HOOKS_DETAILS=""
MCP_COUNT=0
HOOK_COUNT=0

if $HAS_SETTINGS && command -v jq &>/dev/null; then
  SETTINGS_FILE="$CLAUDE_DIR/settings.json"

  # JSON validation
  if jq . "$SETTINGS_FILE" > /dev/null 2>&1; then
    echo "   ✅ settings.json: valid JSON"
  else
    echo -e "   ${RED}❌ settings.json: INVALID JSON!${NC}"
    HOOKS_ISSUES=$((HOOKS_ISSUES + 1))
    HOOKS_DETAILS="$HOOKS_DETAILS\n- ❌ **settings.json** — invalid JSON, fix syntax"
  fi

  # MCP tools count
  MCP_COUNT=$(jq -r '.mcpServers // {} | keys | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
  echo "   🔌 MCP servers: $MCP_COUNT"

  # Hooks detection
  HOOK_TYPES=$(jq -r '.hooks // {} | keys[]' "$SETTINGS_FILE" 2>/dev/null || true)
  if [ -n "$HOOK_TYPES" ]; then
    while IFS= read -r hook_type; do
      CMDS=$(jq -r ".hooks[\"$hook_type\"][]?.command // empty" "$SETTINGS_FILE" 2>/dev/null || true)
      if [ -n "$CMDS" ]; then
        HOOK_COUNT=$((HOOK_COUNT + $(echo "$CMDS" | wc -l | tr -d ' ')))
        echo "   📎 $hook_type:"
        echo "$CMDS" | while IFS= read -r cmd; do
          echo "      → $cmd"
        done
        # Check if any hook modifies CLAUDE.md or system prompt
        if echo "$CMDS" | grep -qiE '(CLAUDE\.md|system.prompt|>> *.*CLAUDE|> *.*CLAUDE)'; then
          HOOKS_ISSUES=$((HOOKS_ISSUES + 1))
          HOOKS_DETAILS="$HOOKS_DETAILS\n- ❌ Hook **$hook_type** appears to modify CLAUDE.md/system prompt → breaks the cache!"
          echo -e "      ${RED}⚠️  DANGER: hook modifies CLAUDE.md/system prompt!${NC}"
        fi
      fi
    done <<< "$HOOK_TYPES"
    [ "$HOOK_COUNT" -eq 0 ] && echo "   ℹ️  Hooks declared but no commands"
  else
    echo "   ℹ️  No hooks configured"
  fi

  # Check for dynamic content in settings that could break cache
  if jq -e '.customInstructions // empty' "$SETTINGS_FILE" &>/dev/null 2>&1; then
    CUSTOM_LEN=$(jq -r '.customInstructions | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
    if [ "$CUSTOM_LEN" -gt 500 ]; then
      echo -e "   ${YELLOW}⚠️  Long customInstructions ($CUSTOM_LEN chars) — check for volatile content${NC}"
    fi
  fi

elif $HAS_SETTINGS; then
  echo -e "   ${YELLOW}⚠️  jq not installed — limited settings.json analysis${NC}"
  # Fallback grep
  if grep -q '"hooks"' "$CLAUDE_DIR/settings.json" 2>/dev/null; then
    echo "   📎 Hooks detected (install jq for detailed analysis)"
  fi
else
  echo "   ℹ️  No settings.json"
fi

cat >> "$RESULT_FILE" << EOF
## 6. Hooks & Settings

| Item | Value |
|------|-------|
| MCP servers | $MCP_COUNT |
| Hooks | $HOOK_COUNT command(s) |
| Hook issues | $HOOKS_ISSUES |

EOF

if [ -n "$HOOKS_DETAILS" ]; then
  echo -e "$HOOKS_DETAILS" >> "$RESULT_FILE"
  echo "" >> "$RESULT_FILE"
fi

if [ "$MCP_COUNT" -gt 5 ]; then
  echo "⚠️ $MCP_COUNT MCP servers — each tool change alters the cached prefix. Disable unused ones." >> "$RESULT_FILE"
  echo "" >> "$RESULT_FILE"
fi

# ============================================================
# 6. SESSION STATS (if available)
# ============================================================
echo -e "\n${GREEN}[7/9] Latest Claude Code session stats${NC}"

# Auto-detect session directory
SESSION_DIR=$(find "$HOME/.claude/projects" -maxdepth 1 -type d -name "*${PROJECT_NAME}*" 2>/dev/null | head -1)
LATEST=""
HAS_SESSION=false

if [ -n "$SESSION_DIR" ]; then
  LATEST=$(find "$SESSION_DIR" -maxdepth 1 -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$LATEST" ] && HAS_SESSION=true
fi

if $HAS_SESSION && command -v jq &>/dev/null; then
  echo "   📊 Session: $(basename "$LATEST")"

  # Token stats
  STATS=$(jq -r 'select(.type=="assistant") | .message.usage // empty' "$LATEST" 2>/dev/null | \
    jq -s '{
      input: (map(.input_tokens // 0) | add),
      output: (map(.output_tokens // 0) | add),
      cache_read: (map(.cache_read_input_tokens // 0) | add),
      cache_creation: (map(.cache_creation_input_tokens // 0) | add)
    }' 2>/dev/null || echo '{}')

  INPUT_TOKENS=$(echo "$STATS" | jq -r '.input // 0' 2>/dev/null || echo 0)
  OUTPUT_TOKENS=$(echo "$STATS" | jq -r '.output // 0' 2>/dev/null || echo 0)
  CACHE_READ=$(echo "$STATS" | jq -r '.cache_read // 0' 2>/dev/null || echo 0)
  CACHE_CREATION=$(echo "$STATS" | jq -r '.cache_creation // 0' 2>/dev/null || echo 0)

  TOTAL=$((INPUT_TOKENS + CACHE_READ + CACHE_CREATION))
  if [ "$TOTAL" -gt 0 ]; then
    CACHE_HIT_RATE=$((CACHE_READ * 100 / TOTAL))
  else
    CACHE_HIT_RATE=0
  fi

  # Cost (Sonnet pricing) — awk instead of bc (more portable)
  COST_USD=$(awk "BEGIN { printf \"%.4f\", $INPUT_TOKENS * 3 / 1000000 + $OUTPUT_TOKENS * 15 / 1000000 + $CACHE_READ * 0.3 / 1000000 + $CACHE_CREATION * 3.75 / 1000000 }" 2>/dev/null || echo "N/A")

  echo "   Input: $INPUT_TOKENS | Output: $OUTPUT_TOKENS"
  echo "   Cache read: $CACHE_READ | Cache write: $CACHE_CREATION"
  echo "   Cache hit rate: ${CACHE_HIT_RATE}%"
  echo "   Estimated cost: \$$COST_USD"

  # Top files
  TOP_FILES=$(jq -r 'select(.type=="assistant") |
    .message.content[]? |
    select(.type=="tool_use" and (.name=="Read" or .name=="View")) |
    .input.file_path // .input.path // "unknown"' "$LATEST" 2>/dev/null | \
    sort | uniq -c | sort -rn | head -15 || true)

  # Top actions
  TOP_ACTIONS=$(jq -r 'select(.type=="assistant") |
    .message.content[]? |
    select(.type=="tool_use") |
    .name' "$LATEST" 2>/dev/null | \
    sort | uniq -c | sort -rn || true)

  echo ""
  [ -n "$TOP_FILES" ] && echo "   Top files read:" && echo "$TOP_FILES" | head -10 | sed 's/^/      /'
  [ -n "$TOP_ACTIONS" ] && echo "   Top actions:" && echo "$TOP_ACTIONS" | head -10 | sed 's/^/      /'

  # Result.md
  cat >> "$RESULT_FILE" << EOF
## 7. Latest session stats

| Metric | Value |
|--------|-------|
| Session | \`$(basename "$LATEST")\` |
| Input tokens | $INPUT_TOKENS |
| Output tokens | $OUTPUT_TOKENS |
| Cache read | $CACHE_READ |
| Cache creation | $CACHE_CREATION |
| **Cache hit rate** | **${CACHE_HIT_RATE}%** |
| Estimated cost | \$$COST_USD |

### Top 15 files read
\`\`\`
${TOP_FILES:-No data}
\`\`\`

### Top actions (tool calls)
\`\`\`
${TOP_ACTIONS:-No data}
\`\`\`

EOF

else
  REASON=""
  if [ -z "$SESSION_DIR" ]; then
    REASON="No session directory found for '$PROJECT_NAME'"
    echo -e "   ${YELLOW}⚠️  $REASON${NC}"
    echo "   Available directories:"
    find "$HOME/.claude/projects/" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sed 's/^/      /' || echo "      (none)"
  elif [ -z "$LATEST" ]; then
    REASON="No .jsonl in $SESSION_DIR"
    echo -e "   ${YELLOW}⚠️  $REASON${NC}"
  elif ! command -v jq &>/dev/null; then
    REASON="jq not installed (winget install jqlang.jq)"
    echo -e "   ${YELLOW}⚠️  $REASON${NC}"
  fi

  cat >> "$RESULT_FILE" << EOF
## 7. Latest session stats

⚠️ Not available: $REASON

To get stats:
1. Run a Claude Code session on the project
2. Install \`jq\` if missing
3. Re-run this script

EOF
fi

# ============================================================
# 6. SCORE & RECOMMENDATIONS
# ============================================================
echo -e "\n${GREEN}[8/9] Score & Recommendations${NC}"

SCORE=0
MAX_SCORE=8
RECOS=""

# Criterion 1: Size
if [ "$TOKENS_APPROX" -le 5000 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Reduce CLAUDE.md (<5k tokens)\n- Move heavy sections to \`.claude/skills/\` or \`docs/\`\n- CLAUDE.md = rules + pointers. Details elsewhere.\n- ⚠️ Check that agents don't already have this info\n"
fi

# Criterion 2: Volatile
if [ "$VOLATILE_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Move volatile content to the END of CLAUDE.md\n- TODO, WIP, dates, current tasks → \`## Current context\` section at the very bottom\n- Everything before it stays identical between sessions = permanent cache hit\n"
fi

# Criterion 3: Order
if $ORDER_OK; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Reorder for caching\n1. Identity / role / stack (never changes)\n2. Conventions / rules / commands (rarely changes)\n3. References to docs/skills (rarely changes)\n4. Current context / volatile (changes often) → **at the very bottom**\n"
fi

# Criterion 4: Duplicates
if [ "$DUPLICATE_RISK" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Eliminate duplicates\n- CLAUDE.md should NOT repeat what's in skills or AGENTS.md\n- Principle: CLAUDE.md = rules + pointers to skills\n"
fi

# Criterion 5: .gitignore
if [ "$GITIGNORE_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Fix .gitignore\n- .claude/MEMORY.md → MUST be in .gitignore (changes every session)\n- .claude/skills/ → MUST NOT be ignored (should be committed)\n"
fi

# Criterion 6: Hooks don't modify system prompt
if [ "$HOOKS_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Fix hooks\n- Hooks must NEVER modify CLAUDE.md or the system prompt mid-session\n- Use \`additionalContext\` in the hook's JSON response (injected as \`<system-reminder>\` in messages)\n- Every system prompt modification = full cache invalidation\n"
fi

# Criterion 7: .claudeignore
if [ "$CLAUDEIGNORE_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Create/complete .claudeignore\n- Create a \`.claudeignore\` file at the project root\n- Include \`.git/\`, \`node_modules/\`, \`dist/\`, \`build/\`, and large binaries\n- Every non-ignored file = potentially wasted tokens\n"
fi

# Criterion 8: No hardcoded paths
if [ "$HARDCODED_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n### 💡 Remove hardcoded paths\n- Replace absolute paths (\`/Users/...\`, \`C:\\Users\\...\`) with relative paths\n- These paths only work on your machine and pollute shared files\n"
fi

# Terminal
echo -e "\n   🎯 Cache-friendliness score: ${GREEN}$SCORE/$MAX_SCORE${NC}"
echo "   📏 CLAUDE.md    : ~$TOKENS_APPROX tokens | $SECTION_COUNT sections"
$HAS_SKILLS && echo "   📄 Skills       : $SKILL_COUNT file(s)"
$HAS_AGENTS && echo "   🤖 Agents       : detected"
echo "   ⚠️  Volatile     : $VOLATILE_COUNT issue(s)"
echo "   🔄 Duplicates   : $DUPLICATE_RISK risk(s)"
echo "   📁 .gitignore   : $GITIGNORE_ISSUES issue(s)"
echo "   📎 Hooks        : $HOOKS_ISSUES issue(s) ($HOOK_COUNT hook(s), $MCP_COUNT MCP)"
echo "   🚫 Claudeignore : $CLAUDEIGNORE_ISSUES issue(s)"
echo "   🔗 Hardcoded    : $HARDCODED_COUNT personal path(s)"
$HAS_SESSION && echo "   📊 Cache hit    : ${CACHE_HIT_RATE}%"

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
  echo -e "\n   ${GREEN}🎉 Project is well optimized for caching!${NC}"
fi

# Result.md — Score
cat >> "$RESULT_FILE" << EOF
## 8. Score & Recommendations

| Criterion | Status |
|-----------|--------|
EOF

# Build score lines with helper to avoid quoting issues
score_line() {
  local label="$1" ok="$2" detail="$3"
  if $ok; then echo "| $label | ✅ $detail |"; else echo "| $label | ❌ $detail |"; fi
}

score_line "CLAUDE.md size (<5k tokens)" "$([ "$TOKENS_APPROX" -le 5000 ] && echo true || echo false)" "~$TOKENS_APPROX tokens" >> "$RESULT_FILE"
score_line "Volatile content isolated" "$([ "$VOLATILE_COUNT" -eq 0 ] && echo true || echo false)" "$VOLATILE_COUNT issue(s)" >> "$RESULT_FILE"
score_line "Cache-friendly order" "$ORDER_OK" "$(if $ORDER_OK; then echo 'OK'; else echo 'volatile before stable'; fi)" >> "$RESULT_FILE"
score_line "No duplicates" "$([ "$DUPLICATE_RISK" -eq 0 ] && echo true || echo false)" "$DUPLICATE_RISK risk(s)" >> "$RESULT_FILE"
score_line ".gitignore correct" "$([ "$GITIGNORE_ISSUES" -eq 0 ] && echo true || echo false)" "$GITIGNORE_ISSUES issue(s)" >> "$RESULT_FILE"
score_line "Safe hooks (no system prompt modification)" "$([ "$HOOKS_ISSUES" -eq 0 ] && echo true || echo false)" "$HOOKS_ISSUES issue(s)" >> "$RESULT_FILE"
score_line ".claudeignore configured" "$([ "$CLAUDEIGNORE_ISSUES" -eq 0 ] && echo true || echo false)" "$CLAUDEIGNORE_ISSUES issue(s)" >> "$RESULT_FILE"
score_line "No hardcoded paths" "$([ "$HARDCODED_COUNT" -eq 0 ] && echo true || echo false)" "$HARDCODED_COUNT found" >> "$RESULT_FILE"

cat >> "$RESULT_FILE" << EOF
| **Total score** | **$SCORE/$MAX_SCORE** |

EOF

if $HAS_SESSION; then
  if [ "$CACHE_HIT_RATE" -ge 80 ]; then
    echo "| Cache hit rate | ${CACHE_HIT_RATE}% ✅ |" >> "$RESULT_FILE"
  else
    echo "| Cache hit rate | ${CACHE_HIT_RATE}% ⚠️ target >80% |" >> "$RESULT_FILE"
  fi
  echo "" >> "$RESULT_FILE"
fi

if [ -n "$RECOS" ]; then
  echo -e "$RECOS" >> "$RESULT_FILE"
else
  echo "" >> "$RESULT_FILE"
  echo "✅ **No action required** — project is optimized for caching." >> "$RESULT_FILE"
fi

# Footer
cat >> "$RESULT_FILE" << EOF

---

## Actions for Claude Code

If you're reading this file, here's what to do:

1. **Score < $MAX_SCORE/$MAX_SCORE?** Read the recommendations above and apply them
2. **Cache hit rate < 80%?** CLAUDE.md changes too often — stabilize content at the top
3. **Duplicates detected?** Remove CLAUDE.md sections that already exist in skills or AGENTS.md
4. **Misplaced volatile content?** Move ALL volatile content (TODO, WIP, dates) to a \`## Current context\` section at the end of CLAUDE.md
5. **CLAUDE.md > 5k tokens?** Extract heavy sections to \`.claude/skills/\` — CLAUDE.md keeps only rules and pointers

> Reminder: every CLAUDE.md modification invalidates the cache from that point onward. Stable content at the top = permanent cache hit.
EOF

# ============================================================
# 9. HISTORY
# ============================================================
echo -e "\n${GREEN}[9/9] History${NC}"

mkdir -p "$SCRIPT_DIR/evals"
HISTORY_FILE="$SCRIPT_DIR/evals/history.jsonl"

HIST_ENTRY="{\"date\":\"$(date +%Y-%m-%d)\",\"score\":$SCORE,\"max\":$MAX_SCORE,\"claude_md_tokens\":$TOKENS_APPROX,\"total_config_tokens\":$TOTAL_CONFIG_TOKENS"
$HAS_SESSION && HIST_ENTRY="$HIST_ENTRY,\"cache_hit_rate\":$CACHE_HIT_RATE,\"cost\":\"$COST_USD\""
HIST_ENTRY="$HIST_ENTRY}"

echo "$HIST_ENTRY" >> "$HISTORY_FILE"
echo "   📊 Appended to evals/history.jsonl"

if [ -f "$HISTORY_FILE" ]; then
  HIST_COUNT=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
  echo "   📈 $HIST_COUNT entry(ies) in history"
  if [ "$HIST_COUNT" -gt 1 ]; then
    PREV_SCORE=$(tail -2 "$HISTORY_FILE" | head -1 | sed -n 's/.*"score":\([0-9]*\).*/\1/p' 2>/dev/null || true)
    if [ -n "$PREV_SCORE" ]; then
      if [ "$SCORE" -gt "$PREV_SCORE" ]; then
        echo -e "   ${GREEN}↑ Score improved: $PREV_SCORE/$MAX_SCORE → $SCORE/$MAX_SCORE${NC}"
      elif [ "$SCORE" -lt "$PREV_SCORE" ]; then
        echo -e "   ${RED}↓ Regression: $PREV_SCORE/$MAX_SCORE → $SCORE/$MAX_SCORE${NC}"
      else
        echo "   → Score stable: $SCORE/$MAX_SCORE"
      fi
    fi
  fi
fi

echo -e "\n${GREEN}✅ Report written to: $RESULT_FILE${NC}"
