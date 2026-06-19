# Pre-Commit Setup

Local quality gates that run the same checks as CI before every `git commit`.

## Install

```bash
pip install pre-commit
pre-commit install
```

That's it. Hooks run automatically on `git commit` from that point forward.

## What runs

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

## Run manually

```bash
# Run against all files (useful after first install)
pre-commit run --all-files

# Run a specific hook
pre-commit run shellcheck --all-files

# Skip hooks for a single commit (use sparingly)
SKIP=shellcheck git commit -m "..."
```

## Update hook versions

```bash
pre-commit autoupdate
```

## Uninstall

```bash
pre-commit uninstall
```
