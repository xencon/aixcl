# CONTEXT: scripts/hooks/

Git hooks installed into `.git/hooks/` (see
`docs/developer/pre-commit-setup.md`). These run on the developer's
machine before a commit is created.

## Contents

| File | Purpose |
|------|---------|
| `pre-commit` | Runs shellcheck (`--severity=warning --exclude=SC1091`, mirroring CI) on staged shell scripts; skips gracefully when shellcheck is not installed |

## Key Facts

- Hooks run BEFORE GPG signing. If a commit fails and GPG never prompted,
  a hook failed -- it is not a signing problem.
- The separate `pre-commit` framework (`.pre-commit-config.yaml`) may
  auto-fix files (e.g. trailing whitespace); fixes land in the worktree,
  not the index. Re-stage with `git add` and retry the commit.
- Never bypass a failing hook with `--no-verify` -- fix the finding; CI
  runs the same checks and will fail anyway.

## Agent Guidance

**You MAY:**
- Keep hook settings mirroring CI exactly (same shellcheck flags)
- Add hooks that mirror an existing CI check

**You MUST NOT:**
- Add a hook check that CI does not enforce (local-only failures confuse contributors)
- Weaken severity or add exclusions that diverge from `security.yml`

## Cross-References

- `docs/developer/pre-commit-setup.md` -- installation guide
- `.claude/rules/ci-checks.md` / `.opencode/rules/ci-checks.md` -- the pre-commit checklist agents follow
- `.github/workflows/security.yml` -- CI shellcheck settings this hook mirrors
