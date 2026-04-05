
# TEP — Token Economy Paradigm

## Identité
TEP est un outil CLI Bash qui audite et optimise la configuration Claude Code d'un projet.
Il génère un rapport RESULT.md avec un score 0-8 et des recommandations actionnables.
TEP is a **pure observer**: it never modifies the audited repo.

## Architecture (stable)

### Structure
```
bin/tep              → CLI entrypoint (argument parsing)
scripts/[tep.sh](http://tep.sh)       → Orchestrateur (set -euo pipefail, seul fichier)
lib/*.sh             → Bibliothèques (log, fs, strings, tokens, report)
steps/[00-10.sh](http://00-10.sh)       → Steps de l'audit (chacun = 1 fonction step_*)
out/[RESULT.md](http://RESULT.md)        → Rapport généré (gitignored)
evals/history.jsonl  → Historique des audits
```

### Conventions
- Toutes les variables globales préfixées `TEP_`
- Tous les lib/*.sh : guard `[[ -n "${_TEP_X_LOADED:-}" ]] && return 0`
- Tous les steps/*.sh : implémentent `step_<name>()` retournant 0 (ok) ou 1 (fail)
- `set -euo pipefail` UNIQUEMENT dans scripts/tep.sh
- Output → stderr (log), RESULT.md → stdout via report buffer
- Écriture atomique : buffer → tmp → mv

### Dépendances entre libs
```
[log.sh](http://log.sh) ← (rien)
[fs.sh](http://fs.sh) ← [log.sh](http://log.sh)
[strings.sh](http://strings.sh) ← (rien)
[tokens.sh](http://tokens.sh) ← [strings.sh](http://strings.sh), [log.sh](http://log.sh)
[report.sh](http://report.sh) ← [log.sh](http://log.sh), [fs.sh](http://fs.sh)
```

### Source order (orchestrateur)
log → fs → strings → tokens → report → steps/*

## Règles de développement

1. **Portabilité** : Linux, macOS, Git Bash Windows. Pas de bashismes > Bash 4.
2. **Language** : English for code, comments, output. French for docs utilisateur.
3. **Pas de bc** : utiliser awk pour les calculs flottants.
4. **Pas de realpath natif** : utiliser `tep_realpath` (3 fallbacks dans fs.sh).
5. **jq optionnel** : toujours prévoir un fallback grep/awk si jq absent.
6. **Pas de chemins absolus** : tout est relatif à `TEP_SCRIPT_DIR` ou `TEP_PROJECT_DIR`.
7. **Pas de modification de CLAUDE.md par les hooks** : c'est un cache killer.
8. **Never write to the audited repo** : read-only (pure observer).
9. **Never commit `.env`** or user session data.
10. **RESULT.md must be scannable by Claude Code** : markdown tables, clear sections.
11. **Token estimation** : `words × 13 / 10` (~1.3 tokens/word).
12. **Paths in examples** use `/path/to/...` (no real paths).

## Scoring (8 critères)
1. Taille CLAUDE.md < 5k tokens
2. Pas de chemins hardcodés
3. Ordre cache-friendly (stable avant volatile)
4. Pas de doublons skills/CLAUDE.md
5. .gitignore propre
6. .claudeignore présent
7. Hooks safe (pas de modification system prompt)
8. Cache hit rate ≥ 70%

## Contexte courant
<!-- Section volatile — toujours en fin de fichier -->
- Version : 2.0.0
- Dernière modification : refactor modulaire complet (split du script monolithique)
- TODO : tests unitaires, examples/RESULT-example.md, METHODOLOGY.md
