#!/usr/bin/env bash
# audit-and-optimize.sh — Full audit + report for Claude Code
# Usage: bash scripts/audit-and-optimize.sh [project-path]
# Output: docs/RESULT.md (scannable by Claude Code)

set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC2129  # style-only: multiple appends to RESULT_FILE are acceptable here

# --- Config ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env safely (no `export $(...)` which breaks on spaces)
if [ -f "$SCRIPT_DIR/.env" ]; then
	set -a
	# shellcheck disable=SC1091
	source "$SCRIPT_DIR/.env"
	set +a
fi

PROJECT_DIR="${1:-${PROJECT_AUDIT_DIR:-}}"
OUTPUT_DIR="$SCRIPT_DIR/docs"
RESULT_FILE="$OUTPUT_DIR/RESULT.md"

# --- Terminal styling (portable-ish) ---
# Prefer ASCII markers in terminal output to avoid Windows encoding issues.
OK_MARK='[OK]'
WARN_MARK='[WARN]'
FAIL_MARK='[FAIL]'
INFO_MARK='[INFO]'

# ANSI colors (terminal only)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

log_ok()   { printf '%b\n' "${GREEN}${OK_MARK}${NC} $*"; }
log_warn() { printf '%b\n' "${YELLOW}${WARN_MARK}${NC} $*"; }
log_fail() { printf '%b\n' "${RED}${FAIL_MARK}${NC} $*"; }
log_info() { printf '%b\n' "${BLUE}${INFO_MARK}${NC} $*"; }

# --- Guards ---
if [ -z "${PROJECT_DIR:-}" ]; then
	log_fail "Usage: $0 <project-path>"
	printf '%s\n' "   Or set PROJECT_AUDIT_DIR in .env"
	exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
	log_fail "Directory not found: $PROJECT_DIR"
	exit 1
fi

mkdir -p "$OUTPUT_DIR"

PROJECT_NAME="$(basename -- "$PROJECT_DIR")"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

echo -e "${GREEN}═══ TEP — Audit & Optimize ═══${NC}"
echo -e "Project: ${GREEN}$PROJECT_NAME${NC} ($PROJECT_DIR)"
echo -e "Output: $RESULT_FILE"
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
# 1. INVENTORY (Claude Code configs)
# ============================================================
echo -e "\n${GREEN}[1/9] Claude Code configuration inventory${NC}"

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
CLAUDE_DIR="$PROJECT_DIR/.claude"

HAS_CLAUDE_MD=false; [ -f "$CLAUDE_MD" ] && HAS_CLAUDE_MD=true
HAS_CLAUDE_DIR=false; [ -d "$CLAUDE_DIR" ] && HAS_CLAUDE_DIR=true

# Core well-known files
HAS_SETTINGS=false; [ -f "$CLAUDE_DIR/settings.json" ] && HAS_SETTINGS=true
HAS_SETTINGS_LOCAL=false; [ -f "$CLAUDE_DIR/settings.local.json" ] && HAS_SETTINGS_LOCAL=true
HAS_MEMORY=false; [ -f "$CLAUDE_DIR/MEMORY.md" ] && HAS_MEMORY=true
HAS_AGENTS=false; { [ -f "$CLAUDE_DIR/AGENTS.md" ] || [ -f "$PROJECT_DIR/AGENTS.md" ]; } && HAS_AGENTS=true

# Skills + rules
HAS_SKILLS=false; [ -d "$CLAUDE_DIR/skills" ] && HAS_SKILLS=true
HAS_RULES=false; [ -d "$CLAUDE_DIR/rules" ] && HAS_RULES=true

# New: catch-all inventory for any .md under .claude/ (future-proof)
CLAUDE_MD_MISC_COUNT=0
if $HAS_CLAUDE_DIR; then
	# Include: .claude/*.md, .claude/**.md (including subfolders)
	CLAUDE_MD_MISC_COUNT=$(find "$CLAUDE_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
fi

SKILL_COUNT=0
$HAS_SKILLS && SKILL_COUNT=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

RULE_COUNT=0
$HAS_RULES && RULE_COUNT=$(find "$CLAUDE_DIR/rules" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

DOCS_COUNT=0
[ -d "$PROJECT_DIR/docs" ] && DOCS_COUNT=$(find "$PROJECT_DIR/docs" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

status_icon() { if "$1"; then echo "$OK_MARK"; else echo "$2"; fi; }
status_icon_text() { if "$1"; then echo "$OK_MARK $2"; else echo "$3"; fi; }

# Emoji-free variants for writing into RESULT.md (Windows-safe even when grepping/printing)
MD_OK='OK'
MD_FAIL='FAIL'

echo "   CLAUDE.md                : $(status_icon "$HAS_CLAUDE_MD" 'FAIL')"
echo "   .claude/                 : $(status_icon "$HAS_CLAUDE_DIR" 'FAIL')"
echo "   .claude/settings.json    : $(status_icon "$HAS_SETTINGS" '-')"
echo "   .claude/settings.local   : $(status_icon "$HAS_SETTINGS_LOCAL" '-')"
echo "   .claude/MEMORY.md        : $(status_icon "$HAS_MEMORY" '-')"
echo "   AGENTS.md                : $(status_icon "$HAS_AGENTS" '-')"
echo "   .claude/skills/*.md      : $(status_icon_text "$HAS_SKILLS" "$SKILL_COUNT file(s)" '-')"
echo "   .claude/rules/*.md       : $(status_icon_text "$HAS_RULES" "$RULE_COUNT file(s)" '-')"
echo "   .claude/**/*.md (total)  : $CLAUDE_MD_MISC_COUNT file(s)"
echo "   docs/*.md                : $DOCS_COUNT file(s)"

cat >> "$RESULT_FILE" << EOF
## 1. Inventory

| File | Status |
|------|--------|
| CLAUDE.md | $(if "$HAS_CLAUDE_MD"; then echo "found"; else echo "${MD_FAIL} **MISSING**"; fi) |
| .claude/ | $(if "$HAS_CLAUDE_DIR"; then echo "${MD_OK}"; else echo "${MD_FAIL}"; fi) |
| .claude/settings.json | $(status_icon "$HAS_SETTINGS" '- missing') |
| .claude/settings.local.json | $(status_icon "$HAS_SETTINGS_LOCAL" '- missing') |
| .claude/MEMORY.md | $(status_icon "$HAS_MEMORY" '- missing') |
| AGENTS.md | $(status_icon "$HAS_AGENTS" '- missing') |
| .claude/skills/ | $(status_icon_text "$HAS_SKILLS" "$SKILL_COUNT file(s)" '- missing') |
| .claude/rules/ | $(status_icon_text "$HAS_RULES" "$RULE_COUNT file(s)" '- missing') |
| .claude/**/*.md (total) | $CLAUDE_MD_MISC_COUNT file(s) |
| docs/*.md | $DOCS_COUNT file(s) |

EOF

if ! "$HAS_CLAUDE_MD"; then
	log_fail "No CLAUDE.md — cannot audit."
	# shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"
	echo "## ${MD_FAIL} STOP — No CLAUDE.md" >> "$RESULT_FILE"
	echo "Create a CLAUDE.md before running the audit." >> "$RESULT_FILE"
	exit 0
fi

# ============================================================
# 2. AUDIT CLAUDE.MD
# ============================================================
echo -e "\n${GREEN}[2/9] Audit CLAUDE.md${NC}"

LINES=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
WORDS=$(wc -w < "$CLAUDE_MD" | tr -d ' ')
TOKENS_APPROX=$((WORDS * 13 / 10))
SECTION_COUNT=$(grep -c '^#' "$CLAUDE_MD" 2>/dev/null || echo 0)

# Volatile detection
VOLATILE_LINES=""
if grep -qiE '(TODO|FIXME|WIP|HACK|en cours|current task|aujourd)' "$CLAUDE_MD" 2>/dev/null; then
  VOLATILE_LINES=$(grep -niE '(TODO|FIXME|WIP|HACK|en cours|current task|aujourd)' "$CLAUDE_MD" 2>/dev/null | head -10)
fi

DATE_LINES=""
if grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$CLAUDE_MD" 2>/dev/null; then
  DATE_LINES=$(grep -nE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$CLAUDE_MD" 2>/dev/null | head -5)
fi

VOLATILE_COUNT=0
[ -n "$VOLATILE_LINES" ] && VOLATILE_COUNT=$((VOLATILE_COUNT + 1))
[ -n "$DATE_LINES" ] && VOLATILE_COUNT=$((VOLATILE_COUNT + 1))

# Cache order
FIRST_VOLATILE_LINE=$(grep -niE '(TODO|FIXME|WIP|en cours|current|contexte courant|volatile)' "$CLAUDE_MD" 2>/dev/null | head -1 | cut -d: -f1 || true)
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
  echo -e "   ${RED}FAIL $HARDCODED_COUNT chemin(s) perso hardcodé(s)${NC}"
else
  echo "   OK Pas de chemins hardcodés"
fi
if $HAS_SKILLS; then
  HP_SKILLS=$(find "$CLAUDE_DIR/skills" -type f -name '*.md' -exec grep -lE '(/Users/[a-zA-Z]|/home/[a-zA-Z]|[A-Z]:\\Users|[A-Z]:/Users)' {} \; 2>/dev/null || true)
  if [ -n "$HP_SKILLS" ]; then
    HP_S_COUNT=$(echo "$HP_SKILLS" | wc -l | tr -d ' ')
    HARDCODED_COUNT=$((HARDCODED_COUNT + HP_S_COUNT))
    echo -e "   ${RED}FAIL $HP_S_COUNT skill(s) avec chemins perso${NC}"
  fi
fi

# Size verdict
SIZE_VERDICT="OK Compact (<5k tokens)"
[ "$TOKENS_APPROX" -gt 5000 ] && SIZE_VERDICT="Gros (>5k tokens) — marge d'optimisation"
[ "$TOKENS_APPROX" -gt 8000 ] && SIZE_VERDICT="TRÈS GROS (>8k tokens) — cache inefficace"

# Terminal
echo "    $WORDS mots ≈ ~$TOKENS_APPROX tokens — $SIZE_VERDICT"
echo "    $SECTION_COUNT sections | $REF_COUNT refs externes"
[ "$VOLATILE_COUNT" -gt 0 ] && echo -e "   ${YELLOW}$VOLATILE_COUNT type(s) de contenu volatile détecté(s)${NC}"
$ORDER_OK && echo "   OK Ordre cache-friendly OK" || echo -e "   ${RED}FAIL Volatile AVANT stable — mauvais pour le cache${NC}"

# Result.md
cat >> "$RESULT_FILE" << EOF
## 2. Audit CLAUDE.md

| Métrique | Valeur |
|----------|--------|
| Mots | $WORDS |
| Tokens (approx) | ~$TOKENS_APPROX |
| Sections | $SECTION_COUNT |
| Refs externes | $REF_COUNT |
| Taille | $SIZE_VERDICT |
| Contenu volatile | $VOLATILE_COUNT type(s) détecté(s) |
| Ordre cache-friendly | $(if $ORDER_OK; then echo "${MD_OK} OK"; else echo "${MD_FAIL} Volatile avant stable"; fi) |
| Chemins hardcodés | $(if [ "$HARDCODED_COUNT" -eq 0 ]; then echo "${MD_OK} aucun"; else echo "${MD_FAIL} $HARDCODED_COUNT trouvé(s)"; fi) |

EOF

if [ -n "$VOLATILE_LINES" ]; then
  cat >> "$RESULT_FILE" << EOF
### Contenu volatile détecté
\`\`\`
$VOLATILE_LINES
\`\`\`

EOF
fi

if [ -n "$DATE_LINES" ]; then
  cat >> "$RESULT_FILE" << EOF
### Dates hardcodées
\`\`\`
$DATE_LINES
\`\`\`

EOF
fi

if [ -n "$SECTIONS_LIST" ]; then
  cat >> "$RESULT_FILE" << EOF
### Structure des sections
\`\`\`
$SECTIONS_LIST
\`\`\`

EOF
fi

if [ -n "$HARDCODED_PATHS" ]; then
  cat >> "$RESULT_FILE" << EOF
### Chemins hardcodés détectés
\`\`\`
$HARDCODED_PATHS
\`\`\`

EOF
fi

# ============================================================
# 3. DOUBLONS
# ============================================================
echo -e "\n${GREEN}[4/9] Détection de doublons${NC}"

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
          echo -e "   ${YELLOW} /!\ $SKILL_NAME ($SKILL_WORDS mots) — $MATCHES refs croisées${NC}"
          DUPLICATE_RISK=$((DUPLICATE_RISK + 1))
          DUPLICATE_DETAILS="$DUPLICATE_DETAILS\n- **$SKILL_NAME** ($SKILL_WORDS mots) : $MATCHES références croisées dans CLAUDE.md -> doublon probable"
        else
          echo "   OK $SKILL_NAME — pas de doublon"
        fi
      fi
    done <<< "$SKILL_FILES"
  else
    echo "  (i)  .claude/skills/ vide"
  fi
else
  echo "   (i) Pas de skills à comparer"
fi

if $HAS_AGENTS; then
  AGENTS_FILE="$CLAUDE_DIR/AGENTS.md"
  [ ! -f "$AGENTS_FILE" ] && AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
  AGENTS_WORDS=$(wc -w < "$AGENTS_FILE" | tr -d ' ')
  echo "   (i)  AGENTS.md détecté ($AGENTS_WORDS mots)"
fi

cat >> "$RESULT_FILE" << EOF
## 4. Doublons (CLAUDE.md vs skills/agents)

- Risques de doublons : **$DUPLICATE_RISK**
EOF

if [ -n "$DUPLICATE_DETAILS" ]; then
  echo -e "$DUPLICATE_DETAILS" >> "$RESULT_FILE"
fi

$HAS_AGENTS && echo "- AGENTS.md présent ($AGENTS_WORDS mots) — attention à ne pas dupliquer" >> "$RESULT_FILE"
# shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"

# ============================================================
# 3. TOKEN BUDGET
# ============================================================
echo -e "\n${GREEN}[3/9] Budget tokens — fichiers de config${NC}"

TOTAL_CONFIG_TOKENS=0
TOKEN_TABLE=""

add_to_inventory() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then
    local lines
	lines=$(wc -l < "$file" | tr -d ' ')
    local chars
	chars=$(wc -c < "$file" | tr -d ' ')
    local words
	words=$(wc -w < "$file" | tr -d ' ')
    local tokens=$((words * 13 / 10))
    TOTAL_CONFIG_TOKENS=$((TOTAL_CONFIG_TOKENS + tokens))
    TOKEN_TABLE="${TOKEN_TABLE}| ${label} | ${lines} | ${chars} | ~${tokens} |\n"
    echo "   ${label} : ${lines} lignes, ~${tokens} tokens"
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
echo -e "   ${GREEN}TOTAL : ~$TOTAL_CONFIG_TOKENS tokens de config${NC}"

cat >> "$RESULT_FILE" << EOF
## 3. Budget tokens (config)

| Fichier | Lignes | Chars | Est. Tokens |
|---------|-------:|------:|------------:|
$(echo -e "$TOKEN_TABLE" | sed '/^$/d')
| **TOTAL** | | | **~$TOTAL_CONFIG_TOKENS** |

EOF

# ============================================================
# 4. GITIGNORE + CLAUDEIGNORE
# ============================================================
echo -e "\n${GREEN}[5/9] Vérification .gitignore & .claudeignore${NC}"

GITIGNORE="$PROJECT_DIR/.gitignore"
GITIGNORE_ISSUES=0
GITIGNORE_DETAILS=""

if [ -f "$GITIGNORE" ]; then
  if $HAS_MEMORY; then
    if grep -q '.claude/MEMORY.md' "$GITIGNORE" 2>/dev/null; then
      echo "   OK .claude/MEMORY.md dans .gitignore"
    else
      echo -e "   ${RED}FAIL .claude/MEMORY.md PAS dans .gitignore${NC}"
      GITIGNORE_ISSUES=$((GITIGNORE_ISSUES + 1))
      GITIGNORE_DETAILS="$GITIGNORE_DETAILS\n- FAIL Ajouter \`.claude/MEMORY.md\` au .gitignore (change à chaque session)"
    fi
  fi

  if $HAS_SKILLS; then
    if grep -q '.claude/skills' "$GITIGNORE" 2>/dev/null; then
      echo -e "   ${RED}FAIL .claude/skills/ dans .gitignore (devrait être commité !)${NC}"
      GITIGNORE_ISSUES=$((GITIGNORE_ISSUES + 1))
      GITIGNORE_DETAILS="$GITIGNORE_DETAILS\n- FAIL Retirer \`.claude/skills/\` du .gitignore (les skills doivent être commités)"
    else
      echo "   OK .claude/skills/ sera commité"
    fi
  fi
else
  echo -e "   ${YELLOW}/!\  Pas de .gitignore${NC}"
fi

# .claudeignore check
CLAUDEIGNORE="$PROJECT_DIR/.claudeignore"
CLAUDEIGNORE_ISSUES=0

if [ -f "$CLAUDEIGNORE" ]; then
  echo "   OK .claudeignore existe"
  if ! grep -qE '\.git(/|$)' "$CLAUDEIGNORE" 2>/dev/null; then
    echo -e "   ${RED}FAIL .git/ PAS dans .claudeignore${NC}"
    CLAUDEIGNORE_ISSUES=$((CLAUDEIGNORE_ISSUES + 1))
  else
    echo "   OK .git/ dans .claudeignore"
  fi
  MISSING_PATS=""
  for pat in node_modules dist build .next __pycache__ target; do
    if [ -d "$PROJECT_DIR/$pat" ] && ! grep -q "$pat" "$CLAUDEIGNORE" 2>/dev/null; then
      MISSING_PATS="$MISSING_PATS $pat"
    fi
  done
  if [ -n "$MISSING_PATS" ]; then
    echo -e "   ${YELLOW}/!\  Dossiers existants non ignorés :$MISSING_PATS${NC}"
  fi
else
  echo -e "   ${YELLOW}/!\  Pas de .claudeignore — Claude Code peut lire des fichiers inutiles${NC}"
  CLAUDEIGNORE_ISSUES=$((CLAUDEIGNORE_ISSUES + 1))
fi

cat >> "$RESULT_FILE" << EOF
## 5. Vérification .gitignore & .claudeignore

- Problèmes .gitignore : **$GITIGNORE_ISSUES**
- Problèmes .claudeignore : **$CLAUDEIGNORE_ISSUES**
EOF

[ -n "$GITIGNORE_DETAILS" ] && echo -e "$GITIGNORE_DETAILS" >> "$RESULT_FILE"
# shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"

# ============================================================
# 5. HOOKS (settings.json + filesystem) & SETTINGS
# ============================================================
echo -e "\n${GREEN}[6/9] Hooks & settings analysis${NC}"

HOOKS_ISSUES=0
HOOKS_DETAILS=""
MCP_COUNT=0
HOOK_COUNT=0

# A) Filesystem hooks: .claude/hooks/*.sh (your case)
HAS_FS_HOOKS=false
FS_HOOK_DIR="$CLAUDE_DIR/hooks"
FS_HOOK_FILES=""
FS_HOOK_COUNT=0
if [ -d "$FS_HOOK_DIR" ]; then
	# Use -print0 to survive weird filenames
	FS_HOOK_COUNT=$(find "$FS_HOOK_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
	if [ "$FS_HOOK_COUNT" -gt 0 ]; then
		HAS_FS_HOOKS=true
		FS_HOOK_FILES=$(find "$FS_HOOK_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
		echo "   OK Filesystem hooks: $FS_HOOK_COUNT script(s) in .claude/hooks/"
		# shellcheck disable=SC2001
	echo "$FS_HOOK_FILES" | sed 's/^/      - /'
	else
		echo "   (i)  .claude/hooks/ exists but contains no *.sh"
	fi
else
	echo "   (i)  No .claude/hooks/ directory"
fi

# B) settings.json hooks (Claude Code config)
if $HAS_SETTINGS && command -v jq &>/dev/null; then
	SETTINGS_FILE="$CLAUDE_DIR/settings.json"

	# JSON validation
	if jq . "$SETTINGS_FILE" > /dev/null 2>&1; then
		echo "   OK settings.json: valid JSON"
	else
		echo -e "   ${RED}FAIL settings.json: INVALID JSON!${NC}"
		HOOKS_ISSUES=$((HOOKS_ISSUES + 1))
		HOOKS_DETAILS="$HOOKS_DETAILS\n- FAIL **settings.json** — invalid JSON, fix syntax"
	fi

	# MCP tools count
	MCP_COUNT=$(jq -r '.mcpServers // {} | keys | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
	echo "    MCP servers: $MCP_COUNT"

	# Hooks declared in settings.json
	HOOK_TYPES=$(jq -r '.hooks // {} | keys[]' "$SETTINGS_FILE" 2>/dev/null || true)
	if [ -n "$HOOK_TYPES" ]; then
		while IFS= read -r hook_type; do
			CMDS=$(jq -r ".hooks[\"$hook_type\"][]?.command // empty" "$SETTINGS_FILE" 2>/dev/null || true)
			if [ -n "$CMDS" ]; then
				HOOK_COUNT=$((HOOK_COUNT + $(echo "$CMDS" | wc -l | tr -d ' ')))
				echo "    settings.json hook: $hook_type"
				echo "$CMDS" | while IFS= read -r cmd; do
					echo "      -> $cmd"
				done

				# Cache safety: never modify CLAUDE.md/system prompt mid-session
				if echo "$CMDS" | grep -qiE '(CLAUDE\.md|system.prompt|>> *.*CLAUDE|> *.*CLAUDE)'; then
					HOOKS_ISSUES=$((HOOKS_ISSUES + 1))
					HOOKS_DETAILS="$HOOKS_DETAILS\n- FAIL Hook **$hook_type** appears to modify CLAUDE.md/system prompt -> breaks cache"
					echo -e "      ${RED}/!\  DANGER: hook modifies CLAUDE.md/system prompt!${NC}"
				fi
			fi
		done <<< "$HOOK_TYPES"
		[ "$HOOK_COUNT" -eq 0 ] && echo "   (i)  Hooks declared but no commands"
	else
		echo "   (i)  No hooks configured in settings.json"
	fi

	# Check for dynamic content in settings that could break cache
	if jq -e '.customInstructions // empty' "$SETTINGS_FILE" &>/dev/null 2>&1; then
		CUSTOM_LEN=$(jq -r '.customInstructions | length' "$SETTINGS_FILE" 2>/dev/null || echo 0)
		if [ "$CUSTOM_LEN" -gt 500 ]; then
			echo -e "   ${YELLOW}/!\  Long customInstructions ($CUSTOM_LEN chars) — check for volatile content${NC}"
		fi
	fi

elif $HAS_SETTINGS; then
	echo -e "   ${YELLOW}/!\  jq not installed — limited settings.json hook analysis${NC}"
	if grep -q '"hooks"' "$CLAUDE_DIR/settings.json" 2>/dev/null; then
		echo "    hooks key detected (install jq for details)"
	else
		echo "   (i)  No hooks key found in settings.json"
	fi
else
	echo "   (i)  No settings.json"
fi

cat >> "$RESULT_FILE" << EOF
## 6. Hooks & Settings

| Item | Value |
|------|-------|
| Filesystem hooks (.claude/hooks/*.sh) | $FS_HOOK_COUNT |
| settings.json hooks (commands) | $HOOK_COUNT |
| MCP servers | $MCP_COUNT |
| Hook issues | $HOOKS_ISSUES |

EOF

if $HAS_FS_HOOKS; then
	cat >> "$RESULT_FILE" << EOF
### Filesystem hooks detected (.claude/hooks/*.sh)
\`\`\`
$FS_HOOK_FILES
\`\`\`

EOF
fi

if [ -n "$HOOKS_DETAILS" ]; then
  echo -e "$HOOKS_DETAILS" >> "$RESULT_FILE"
  # shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"
fi

if [ "$MCP_COUNT" -gt 5 ]; then
  echo "/!\ $MCP_COUNT MCP servers — chaque tool change le préfixe caché. Désactiver ceux non utilisés." >> "$RESULT_FILE"
  # shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"
fi

# ============================================================
# 6. SESSION STATS (si disponible)
# ============================================================
echo -e "\n${GREEN}[7/9] Stats de la dernière session Claude Code${NC}"

# Auto-détection du dossier de session
SESSION_DIR=$(find "$HOME/.claude/projects" -maxdepth 1 -type d -name "*${PROJECT_NAME}*" 2>/dev/null | head -1)
LATEST=""
HAS_SESSION=false

if [ -n "$SESSION_DIR" ]; then
  # shellcheck disable=SC2012
	LATEST=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1)
  [ -n "$LATEST" ] && HAS_SESSION=true
fi

if $HAS_SESSION && command -v jq &>/dev/null; then
  echo "   Session: $(basename "$LATEST")"

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

  # Cost (Sonnet pricing) — awk au lieu de bc (plus portable, dispo partout)
  COST_USD=$(awk "BEGIN { printf \"%.4f\", $INPUT_TOKENS * 3 / 1000000 + $OUTPUT_TOKENS * 15 / 1000000 + $CACHE_READ * 0.3 / 1000000 + $CACHE_CREATION * 3.75 / 1000000 }" 2>/dev/null || echo "N/A")

  echo "   Input: $INPUT_TOKENS | Output: $OUTPUT_TOKENS"
  echo "   Cache read: $CACHE_READ | Cache write: $CACHE_CREATION"
  echo "   Cache hit rate: ${CACHE_HIT_RATE}%"
  echo "   Coût estimé: \$$COST_USD"

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
  [ -n "$TOP_FILES" ] && echo "   Top fichiers lus :" && echo "$TOP_FILES" | head -10 | sed 's/^/      /'
  [ -n "$TOP_ACTIONS" ] && echo "   Top actions :" && echo "$TOP_ACTIONS" | head -10 | sed 's/^/      /'

  # Result.md
  cat >> "$RESULT_FILE" << EOF
## 7. Stats dernière session

| Métrique | Valeur |
|----------|--------|
| Session | \`$(basename "$LATEST")\` |
| Input tokens | $INPUT_TOKENS |
| Output tokens | $OUTPUT_TOKENS |
| Cache read | $CACHE_READ |
| Cache creation | $CACHE_CREATION |
| **Cache hit rate** | **${CACHE_HIT_RATE}%** |
| Coût estimé | \$$COST_USD |

### Top 15 fichiers lus
\`\`\`
${TOP_FILES:-Aucune donnée}
\`\`\`

### Top actions (tool calls)
\`\`\`
${TOP_ACTIONS:-Aucune donnée}
\`\`\`

EOF

else
  REASON=""
  if [ -z "$SESSION_DIR" ]; then
    REASON="Aucun dossier de session trouvé pour '$PROJECT_NAME'"
    echo -e "   ${YELLOW}/!\  $REASON${NC}"
    echo "   Dossiers disponibles :"
    # shellcheck disable=SC2012
	ls "$HOME/.claude/projects/" 2>/dev/null | sed 's/^/      /' || echo "      (aucun)"
  elif [ -z "$LATEST" ]; then
    REASON="Aucun .jsonl dans $SESSION_DIR"
    echo -e "   ${YELLOW}/!\  $REASON${NC}"
  elif ! command -v jq &>/dev/null; then
    REASON="jq non installé (winget install jqlang.jq)"
    echo -e "   ${YELLOW}/!\  $REASON${NC}"
  fi

  cat >> "$RESULT_FILE" << EOF
## 7. Stats dernière session

/!\ Non disponible : $REASON

Pour obtenir les stats :
1. Lancer une session Claude Code sur le projet
2. Installer \`jq\` si manquant
3. Relancer ce script

EOF
fi

# ============================================================
# 6. SCORE & RECOMMANDATIONS
# ============================================================
echo -e "\n${GREEN}[8/9] Score & Recommandations${NC}"

SCORE=0
MAX_SCORE=8
RECOS=""

# Critère 1 : Taille
if [ "$TOKENS_APPROX" -le 5000 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Réduire CLAUDE.md (<5k tokens)\n- Déplacer sections lourdes vers \`.claude/skills/\` ou \`docs/\`\n- CLAUDE.md = règles + pointeurs. Le détail ailleurs.\n- WARN Vérifier que les agents n'ont pas déjà cette info\n"
fi

# Critère 2 : Volatile
if [ "$VOLATILE_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Déplacer le contenu volatile en FIN de CLAUDE.md\n- TODO, WIP, dates, tâche en cours -> section \`## Contexte courant\` tout en bas\n- Tout ce qui précède reste identique entre sessions = cache hit permanent\n"
fi

# Critère 3 : Ordre
if $ORDER_OK; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Réordonner pour le cache\n1. Identité / rôle / stack (ne change jamais)\n2. Conventions / règles / commandes (change rarement)\n3. Références à docs/skills (change rarement)\n4. Contexte courant / volatile (change souvent) -> **tout en bas**\n"
fi

# Critère 4 : Doublons
if [ "$DUPLICATE_RISK" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Éliminer les doublons\n- CLAUDE.md ne doit PAS répéter ce qui est dans skills ou AGENTS.md\n- Principe : CLAUDE.md = règles + pointeurs vers skills\n"
fi

# Critère 5 : .gitignore
if [ "$GITIGNORE_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Corriger .gitignore\n- .claude/MEMORY.md -> DOIT être dans .gitignore (change chaque session)\n- .claude/skills/ -> NE DOIT PAS être ignoré (doit être commité)\n"
fi

# Critère 6 : Hooks ne modifient pas le system prompt
if [ "$HOOKS_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Corriger les hooks\n- Les hooks ne doivent JAMAIS modifier CLAUDE.md ou le system prompt mid-session\n- Utiliser \`additionalContext\` dans la réponse JSON du hook (injecté comme \`<system-reminder>\` en message)\n- Chaque modification du system prompt = invalidation complète du cache\n"
fi

# Critère 7 : .claudeignore
if [ "$CLAUDEIGNORE_ISSUES" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Créer/compléter .claudeignore\n- Créer un fichier \`.claudeignore\` à la racine du projet\n- Inclure \`.git/\`, \`node_modules/\`, \`dist/\`, \`build/\`, et les gros binaires\n- Chaque fichier non ignoré = tokens potentiellement gaspillés\n"
fi

# Critère 8 : Pas de chemins hardcodés
if [ "$HARDCODED_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 1))
else
  RECOS="$RECOS\n###  Supprimer les chemins hardcodés\n- Remplacer les chemins absolus (\`/Users/...\`, \`C:\\Users\\...\`) par des chemins relatifs\n- Ces chemins ne fonctionnent que sur ta machine et polluent les fichiers partagés\n"
fi

# Terminal
echo -e "\n    Score cache-friendliness : ${GREEN}$SCORE/$MAX_SCORE${NC}"
echo "    CLAUDE.md    : ~$TOKENS_APPROX tokens | $SECTION_COUNT sections"
$HAS_SKILLS && echo "    Skills       : $SKILL_COUNT fichier(s)"
$HAS_AGENTS && echo "    Agents       : détecté"
echo "   WARN  Volatile     : $VOLATILE_COUNT problème(s)"
echo "    Doublons     : $DUPLICATE_RISK risque(s)"
echo "    .gitignore   : $GITIGNORE_ISSUES problème(s)"
echo "    Hooks        : $HOOKS_ISSUES problème(s) ($HOOK_COUNT hook(s), $MCP_COUNT MCP)"
echo "    Claudeignore  : $CLAUDEIGNORE_ISSUES problème(s)"
echo "    Hardcoded     : $HARDCODED_COUNT chemin(s) perso"
$HAS_SESSION && echo "    Cache hit    : ${CACHE_HIT_RATE}%"

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
  echo -e "\n   ${GREEN} Projet bien optimisé pour le cache !${NC}"
fi

# Result.md — Score
cat >> "$RESULT_FILE" << EOF
## 8. Score & Recommandations

| Critère | Status |
|---------|--------|
EOF

# Build score lines with helper to avoid quoting issues
score_line() {
  local label="$1" ok="$2" detail="$3"
  if $ok; then echo "| $label | OK $detail |"; else echo "| $label | FAIL $detail |"; fi
}

{
	score_line "Taille CLAUDE.md (<5k tokens)" "$([ "$TOKENS_APPROX" -le 5000 ] && echo true || echo false)" "~$TOKENS_APPROX tokens"
	score_line "Contenu volatile isolé" "$([ "$VOLATILE_COUNT" -eq 0 ] && echo true || echo false)" "$VOLATILE_COUNT problème(s)"
	score_line "Ordre cache-friendly" "$ORDER_OK" "$(if $ORDER_OK; then echo 'OK'; else echo 'volatile avant stable'; fi)"
	score_line "Pas de doublons" "$([ "$DUPLICATE_RISK" -eq 0 ] && echo true || echo false)" "$DUPLICATE_RISK risque(s)"
	score_line ".gitignore correct" "$([ "$GITIGNORE_ISSUES" -eq 0 ] && echo true || echo false)" "$GITIGNORE_ISSUES problème(s)"
	score_line "Hooks safe (pas de modif system prompt)" "$([ "$HOOKS_ISSUES" -eq 0 ] && echo true || echo false)" "$HOOKS_ISSUES problème(s)"
	score_line ".claudeignore configuré" "$([ "$CLAUDEIGNORE_ISSUES" -eq 0 ] && echo true || echo false)" "$CLAUDEIGNORE_ISSUES problème(s)"
	score_line "Pas de chemins hardcodés" "$([ "$HARDCODED_COUNT" -eq 0 ] && echo true || echo false)" "$HARDCODED_COUNT trouvé(s)"
} >> "$RESULT_FILE"

cat >> "$RESULT_FILE" << EOF
| **Score total** | **$SCORE/$MAX_SCORE** |

EOF

if $HAS_SESSION; then
  if [ "$CACHE_HIT_RATE" -ge 80 ]; then
    echo "| Cache hit rate | ${CACHE_HIT_RATE}% OK |" >> "$RESULT_FILE"
  else
    echo "| Cache hit rate | ${CACHE_HIT_RATE}% WARN cible >80% |" >> "$RESULT_FILE"
  fi
  # shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"
fi

if [ -n "$RECOS" ]; then
  echo -e "$RECOS" >> "$RESULT_FILE"
else
  # shellcheck disable=SC2129  # style-only
	echo "" >> "$RESULT_FILE"
  echo "OK **Aucune action requise** — le projet est optimisé pour le cache." >> "$RESULT_FILE"
fi

# Footer
cat >> "$RESULT_FILE" << EOF

---

## Actions pour Claude Code

Si tu lis ce fichier, voici ce que tu dois faire :

1. **Score < $MAX_SCORE/$MAX_SCORE ?** Lis les recommandations ci-dessus et applique-les
2. **Cache hit rate < 80% ?** Le CLAUDE.md change trop souvent — stabilise le contenu en haut du fichier
3. **Doublons détectés ?** Supprime les sections du CLAUDE.md qui sont déjà dans les skills ou AGENTS.md
4. **Volatile mal placé ?** Déplace TOUT le contenu volatile (TODO, WIP, dates) dans une section \`## Contexte courant\` en fin de CLAUDE.md
5. **CLAUDE.md > 5k tokens ?** Extrais les sections lourdes vers \`.claude/skills/\` — le CLAUDE.md ne garde que les règles et les pointeurs

> Rappel : chaque modification du CLAUDE.md invalide le cache à partir du point de modification. Le contenu stable en haut = cache hit permanent.
EOF

# ============================================================
# 9. HISTORIQUE
# ============================================================
echo -e "\n${GREEN}[9/9] Historique${NC}"

mkdir -p "$SCRIPT_DIR/evals"
HISTORY_FILE="$SCRIPT_DIR/evals/history.jsonl"

HIST_ENTRY="{\"date\":\"$(date +%Y-%m-%d)\",\"score\":$SCORE,\"max\":$MAX_SCORE,\"claude_md_tokens\":$TOKENS_APPROX,\"total_config_tokens\":$TOTAL_CONFIG_TOKENS"
$HAS_SESSION && HIST_ENTRY="$HIST_ENTRY,\"cache_hit_rate\":$CACHE_HIT_RATE,\"cost\":\"$COST_USD\""
HIST_ENTRY="$HIST_ENTRY}"

echo "$HIST_ENTRY" >> "$HISTORY_FILE"
echo "    Ajouté dans evals/history.jsonl"

if [ -f "$HISTORY_FILE" ]; then
  HIST_COUNT=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
  echo "    $HIST_COUNT entrée(s) dans l'historique"
  if [ "$HIST_COUNT" -gt 1 ]; then
    PREV_SCORE=$(tail -2 "$HISTORY_FILE" | head -1 | sed -n 's/.*"score":\([0-9]*\).*/\1/p' 2>/dev/null || true)
    if [ -n "$PREV_SCORE" ]; then
      if [ "$SCORE" -gt "$PREV_SCORE" ]; then
        echo -e "   ${GREEN}↑ Score amélioré : $PREV_SCORE/$MAX_SCORE -> $SCORE/$MAX_SCORE${NC}"
      elif [ "$SCORE" -lt "$PREV_SCORE" ]; then
        echo -e "   ${RED}↓ Régression : $PREV_SCORE/$MAX_SCORE -> $SCORE/$MAX_SCORE${NC}"
      else
        echo "   -> Score stable : $SCORE/$MAX_SCORE"
      fi
    fi
  fi
fi

echo -e "\n${GREEN}OK Rapport écrit dans : $RESULT_FILE${NC}"
echo "   Claude Code peut le lire avec : cat docs/RESULT.md"