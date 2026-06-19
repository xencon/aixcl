# Pre-Commit Setup

Local quality gates that run the same checks as CI before every `git commit`.

## Install

```bash
pip install pre-commit
pre-commit install
```

That's it. Hooks run automatically on `git commit` from that point forward.

## What runs

Hooks run at two stages. Commit-time hooks run on every `git commit`; push-time hooks run on `git push` and are reserved for broader or slower checks.

### Commit-time hooks

| Hook | Catches |
|------|---------|
| `trailing-whitespace` | Trailing spaces (excluding markdown) |
| `end-of-file-fixer` | Missing newline at end of file |
| `mixed-line-ending` | CRLF line endings -- converts to LF |
| `check-yaml` | YAML syntax errors |
| `check-merge-conflict` | Unresolved conflict markers |
| `shellcheck` | Shell script issues (`--severity=warning --exclude=SC1091`) |
| `yamllint` | YAML style violations (using `.yamllint.yml`) |
| `gitleaks` | Secret patterns in staged files (uses `.gitleaks.toml` allowlist) |
| `no-non-ascii-punctuation` | Smart quotes, em dashes, ellipsis in markdown |
| `check-ai-elisions` | AI placeholder text standing in for real content |
| `check-generated-files` | Generated files accidentally tracked in git |
| `check-agents` | `.claude/` vs `.opencode/` mirror parity (only when those paths change) |

### Push-time hooks

| Hook | Catches |
|------|---------|
| `check-paths` | Broken relative links in documentation |
| `security-tests` | Security test suite (`tests/security/`) |
| `lib-tests` | Library unit tests (`tests/run-tests.sh --category lib`; only when `lib/` or `tests/` change) |

## Run manually

```bash
# Run commit-time hooks against all files (useful after first install)
pre-commit run --all-files

# Run push-time hooks against all files
pre-commit run --all-files --hook-stage pre-push

# Run a specific hook
pre-commit run shellcheck --all-files
pre-commit run check-paths --hook-stage pre-push

# Skip hooks for a single commit or push (use sparingly)
SKIP=shellcheck git commit -m "..."
SKIP=lib-tests git push
```

## Update hook versions

```bash
pre-commit autoupdate
```

## Uninstall

```bash
pre-commit uninstall
```
