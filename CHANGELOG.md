# Changelog

## [2.0.0] - 2026-04-05

### TL;DR
Refactor complet de TEP: passage d’un script monolithique à une architecture modulaire (libs + pipeline d’étapes), avec un vrai CLI, un format de rapport spécifié, et une config/cache hygiene clarifiée.

### Added
- Nouveau CLI `bin/tep` avec parsing d’arguments:
    - `tep audit <project-path>`
    - `--out <dir>`, `--no-color`, `--verbose`, `--help`, `--version`
    - version affichée: `TEP_VERSION="2.0.0"` (dans `bin/tep`)
- Nouvel orchestrateur `scripts/tep.sh`:
    - seul fichier avec `set -euo pipefail`
    - chargement ordonné des libs + chargement auto de `steps/*.sh`
    - exécution séquentielle des steps + gestion critique/non-critique
    - timing global et code de sortie cohérent
- Nouvelle architecture modulaire:
    - `lib/` (utilitaires réutilisables)
    - `steps/` (pipeline d’audit step-by-step)
    - `out/` (output runtime gitignored) + `.cache/`
    - `evals/history.jsonl` pour l’historique
- Documentation v2:
    - `docs/cli.md` (référence CLI complète)
    - `docs/report-format.md` (spécification du format `RESULT.md` + `history.jsonl`)
    - `docs/troubleshooting.md` (FAQ / problèmes connus)
- `CLAUDE.md` v2 “cache-friendly” (contenu stable en haut, zone volatile en bas), incluant conventions, dépendances entre libs, règles de dev, scoring /8

### Changed
- Remplacement du script monolithique `audit-and-optimize.sh` par:
    - `lib/*.sh`: fonctions uniquement (pas d’exécution directe)
    - `steps/*.sh`: chaque step expose `step_<name>()` et retourne un code (0/1)
    - `scripts/tep.sh`: orchestration et politique d’erreur
- Organisation du pipeline en étapes explicites:
    - ctx, inventory, claude-md audit, token budget, duplicates, ignore files, settings/hooks, session stats, score/recos, history, render report
- Chemin de sortie standardisé:
    - rapport principal en `out/RESULT.md` (écriture atomique)
- README v2 réécrit pour refléter la structure modulaire, la CLI (`./bin/tep audit`), et le workflow v2 (au lieu du script unique)

### Improved
- Robustesse/maintenabilité:
    - ordre de source documenté et imposé (log → fs → strings → tokens → report → steps)
    - steps critiques vs non-critiques (rapport partiel même en cas d’échec non critique)
- Portabilité et hygiène:
    - conventions Bash 4+ / Git Bash Windows
    - `.claudeignore` et `.gitignore` intégrés au flow d’audit, et structure `out/` clairement gitignored
- Spécification du rapport:
    - sections normalisées, marqueurs (✅/⚠️/❌/ℹ️), format d’historique JSONL, exemples de requêtes `jq`

### Notes de release (suggestion)
- Version: `v2.0.0`
- Type: “breaking refactor” (structure interne entièrement refondue), mais objectif fonctionnel inchangé: audit + score /8 + recommandations + rapport `RESULT.md`.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-26

### Added
- Full audit script with 9-step analysis (`audit-and-optimize.sh`)
- Score /8 across 8 cache-friendliness criteria
- Session stats parsing (tokens, cost, cache hit rate)
- Top files and tool actions analysis
- History tracking in `evals/history.jsonl`
- Structured `RESULT.md` report scannable by Claude Code
- Reusable `cache-audit` skill for quick audits
- `docs/METHODOLOGY.md` — prompt caching theory and best practices
- Cross-platform support: Git Bash (Windows), bash (Linux), zsh (macOS)
- CI with ShellCheck linting
