# Contributing to TEP

Thanks for your interest in contributing to TEP!

## How to contribute

1. **Fork** the repository
2. **Create a branch** from `main`: `git checkout -b feat/my-feature`
3. **Make your changes**
4. **Run ShellCheck** before committing:
   ```bash
   shellcheck scripts/audit-and-optimize.sh
   ```
5. **Test** on a project with a `CLAUDE.md`:
   ```bash
   pnpm tep:audit -- /path/to/test-project
   ```
6. **Commit** with a clear message: `feat: add X` / `fix: correct Y`
7. **Open a Pull Request** against `main`

## Code style

- The audit script is a **single bash file** — keep it that way
- Use `#!/bin/bash` (not `#!/bin/sh`)
- All output strings in **English**
- ShellCheck must pass with **zero errors** (warnings are acceptable)
- Use `awk` instead of `bc` for math (more portable)
- Test on Git Bash (Windows) + Linux at minimum

## What to contribute

- Bug fixes (especially cross-platform compatibility)
- New audit criteria (with scoring integration)
- Better session parsing
- Documentation improvements

## What NOT to change

- Don't split the script into multiple files
- Don't add heavy dependencies (keep it bash + jq)
- Don't modify `docs/RESULT.md` manually (it's generated)

## Reporting bugs

Open an issue with:
- Your OS and bash version (`bash --version`)
- Whether `jq` is installed (`jq --version`)
- The step where the script fails
- The error output

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Be kind.
