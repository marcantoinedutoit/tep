# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

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
