# Agent Pitfalls

Common mistakes AI agents make in this repository, with corrections.
Read this if you are starting a session or if something unexpected happened.

## Workflow Pitfalls

### Pitfall: Pushing to the wrong remote

**What happens:** An agent tries to push directly to the canonical repository
(`xencon/aixcl`) instead of the personal fork, and is blocked by branch protection.

**Why:** `origin` is the personal fork (`sbadakhc/aixcl`). Feature branches go
to `origin`. The canonical repository (`xencon/aixcl`) is the `upstream` remote --
PRs target it but direct pushes are blocked by branch protection.

**Fix:**
```bash
git remote -v                              # Check what remotes exist
git push origin issue-<N>/<description>   # Push to personal fork
gh pr create --repo xencon/aixcl ...      # PR targets upstream
```

If `upstream` remote is missing:
```bash
git remote add upstream git@github.com:xencon/aixcl.git
```

Use SSH, not HTTPS -- HTTPS push is blocked for repositories containing
workflow files.

---

### Pitfall: Skipping check-ai-elisions.sh

**What happens:** CI fails on `bash-ci.yml` with an elision or mass-deletion
error after the PR is already open.

**Why:** AI-assisted edits sometimes replace large sections with placeholder
text ("rest of file unchanged", etc.) or truncate files. The check catches
this. Running it locally is faster than waiting for CI.

**Fix:** Run before every commit:
```bash
./scripts/checks/check-ai-elisions.sh --staged
```

For intentional large rewrites, override with:
```bash
AIXCL_ALLOW_MASS_DELETE=1 ./scripts/checks/check-ai-elisions.sh --staged
```
State the intent explicitly in the commit message.

---

### Pitfall: Creating a PR with missing labels or assignee

**What happens:** `pr-validation.yml` CI check fails immediately on PR open.

**Why:** PRs must have at least one `component:*` label AND an assignee set AT
CREATION TIME. The webhook fires on `opened` -- adding them after creation
does not satisfy the check.

**Fix:** Always use:
```bash
gh pr create \
  --assignee sbadakhc \
  --label "component:<name>"
```

---

### Pitfall: Committing non-ASCII characters to markdown

**What happens:** `bash-ci.yml` fails with a non-ASCII character error.

**Why:** The ASCII mandate applies to all markdown files, issues, PRs, and
commit messages. Smart quotes, em dashes, ellipsis characters, and non-breaking
spaces are all rejected.

**Common offenders:**

| Wrong | Right |
|-------|-------|
| `--` (em dash) | `--` (two hyphens) |
| `...` (ellipsis char) | `...` (three dots) |
| `"` `"` (smart quotes) | `"` (straight quote) |
| `'` `'` (smart apostrophes) | `'` (straight apostrophe) |

Check before committing:
```bash
python3 -c "
import sys
with open('file.md', 'rb') as f:
    data = f.read()
non_ascii = [(i, b) for i, b in enumerate(data) if b > 127]
if non_ascii:
    print('Non-ASCII found:', non_ascii[:5])
"
```

---

## Architecture Pitfalls

### Pitfall: Flagging network_mode: host as a security issue

**What happens:** Agent raises `network_mode: host` as a vulnerability and
proposes changing to bridge networking.

**Why this is wrong:** Host networking is a documented, intentional invariant.
AIXCL is a local-first, single-node platform. Bridge networking adds complexity
without security benefit for the target use case.

**Do not open issues or PRs for this.** See:
- `docs/architecture/decisions/001-network-mode-host.md`
- `docs/architecture/governance/00_invariants.md` section 7
- `docs/security/compensating-controls.md`

---

### Pitfall: "Fixing" bootstrap containers to restart: unless-stopped

**What happens:** Agent changes vault-agent-*-bootstrap containers from
`restart: on-failure` to `restart: unless-stopped` because they appear to be
"stopped" and therefore "broken."

**Why this is wrong:** Bootstrap containers are one-shot by design. A stopped
bootstrap container after a successful stack start is CORRECT. The `on-failure`
restart policy means Docker only retries genuine failures.

**Do not change this.** See `docs/architecture/decisions/002-one-shot-bootstrap.md`.

---

### Pitfall: Adding a loop to a bootstrap script

**What happens:** Agent adds `while true; do sleep 30; fetch_password; done`
to a bootstrap script because it "looks incomplete."

**Why this is wrong:** The original design had this loop and it was removed
(issue #1338) specifically because it held the Vault root token in a long-lived
container environment. The one-shot exit is intentional.

**Do not add loops to scripts in `scripts/vault/bootstrap-*.sh`.**

---

### Pitfall: Calling docker or podman directly instead of docker_utils.sh

**What happens:** `docker ps` works on the developer machine but fails in CI
or on a Podman setup.

**Why:** The platform supports both Docker and rootless Podman. `lib/core/docker_utils.sh`
detects which runtime is available and provides wrapper functions.

**Fix:** Source `docker_utils.sh` and use its functions instead of calling
`docker` or `podman` directly in scripts under `lib/`.

---

### Pitfall: Iterating app services by index instead of using _app_resolve_start_order

**What happens:** Services start in manifest order, ignoring `depends_on`, causing
dependent services to start before their dependencies.

**Why:** The `_app_resolve_start_order()` function in `app.sh` implements Kahn's
topological sort. Bypassing it breaks the dependency ordering guarantee.

**Do not replace the start order loop with `seq 0 $((count-1))`.**
See `docs/architecture/decisions/004-topological-sort-depends-on.md`.

---

## Vault Pitfalls

### Pitfall: GPG decrypt fails with "not a tty" in agent/CI context

**What happens:** `gpg --decrypt .security/vault-root-token.gpg` fails because
there is no TTY for pinentry.

**Fix:** Set `VAULT_TOKEN` in the environment before running CLI commands:
```bash
export VAULT_TOKEN=<token-value>
./aixcl stack start --profile sys
```

This is the documented escape hatch. See
`docs/architecture/decisions/003-vault-token-escape-hatch.md`.

---

### Pitfall: Using tty command for TTY detection

**What happens:** `GPG_TTY=$(tty)` sets `GPG_TTY` to the literal string
`"not a tty"` in non-interactive sessions, which breaks GPG.

**Fix:** Use POSIX file descriptor test:
```bash
if [ ! -t 0 ]; then
    # No TTY available
fi
```

The `tty` command prints to stdout, which corrupts variable assignment in
non-interactive contexts.

---

## Versioning Pitfall

### Pitfall: Using a version number from a previous session

**What happens:** Agent uses `v1.1.28` (or any hardcoded version) when the
current version is actually higher.

**Fix:** Always compute the version at the start of a release session:
```bash
CURRENT=$(git tag --sort=-v:refname | head -1)
PATCH=$(echo "$CURRENT" | sed 's/v1\.1\.//')
NEXT="v1.1.$((PATCH + 1))"
echo "Current: $CURRENT  Next: $NEXT"
```

See `.claude/skills/release/SKILL.md` for the full release workflow.

---

## GPG Pitfalls

### Pitfall: GPG signing is human-only

**What happens:** Agent attempts to commit with a GPG signature but fails because
the agent has no TTY available for pinentry. The commit may appear to succeed due
to cached passphrase in gpg-agent, but cannot be reliably automated.

**Why:** The working pattern is: agent stages changes and provides the exact
`git commit` command; the human runs it. An agent-invoked commit CAN succeed if
the gpg-agent passphrase cache is warm from a recent human commit, but must never
be relied on.

**Fix:** Agent-staged changes should be followed by human verification:
```bash
# Agent staging commands:
git add <files>
# Then provide exact command for human to run:
git commit -m "chore: update"
```

---

## Pre-commit Pitfalls

### Pitfall: Pre-commit hook re-staging

**What happens:** When a commit fails on trailing-whitespace or end-of-file fixers,
the hook has already fixed the files in the working tree -- the staged copy is
the stale, unfixed version. Retrying with `--no-verify` commits that stale
content and skips every other hook.

**Why:** Pre-commit hooks modify the working tree with automatic fixes before
rejection. Files that had such fixes applied must be re-staged with `git add`
rather than bypassing validation.

**Fix:** After auto-fix failures, use:
```bash
# Re-stage affected files and retry without --no-verify
git add <affected files>
git commit -m "your message here"
```

---

## PR Pitfalls

### Pitfall: Closed vs merged PRs

**What happens:** A human says "PR merged" but it was only closed, not merged.
The agent proceeds to delete the branch or close the issue prematurely.
The agent does not verify PR state.

**Why:** GitHub distinguishes between MERGED and CLOSED state. When a PR is
closed without merging (e.g., via a "wip" or cancel workflow), it still appears
as if it was merged to a human who didn't check the actual Git state.

**Fix:** Always check the PR state before deleting branches or closing issues:
```bash
gh pr view <N> --json state   # Should show MERGED, not CLOSED
```

If a branch was deleted prematurely:
```bash
git log --all --oneline | grep "<commit subject>"   # find the orphaned SHA
git branch <branch-name> <sha>                      # recreate the branch
git push origin <branch-name>                       # restore it on the fork
gh pr reopen <N> --repo xencon/aixcl                # reopen the PR
```

---

### Pitfall: Force-push race on open PRs

**What happens:** After force-pushing a PR branch, GitHub may merge the pre-push
commit instead of the latest commit if confirmation isn't obtained.

**Why:** Force-pushes change the branch history. If a human merges before checking
the current HEAD OID in the PR against the local repository to confirm they match,
the pre-push commit gets merged instead of the intended changes.

**Fix:** After force-pushing, verify consistency:
```bash
# Confirm your local commit matches PR HEAD
LOCAL_HEAD=$(git rev-parse HEAD)
PR_HEAD=$(gh pr view <N> --json headRefOid --jq '.headRefOid')
if [ "$LOCAL_HEAD" = "$PR_HEAD" ]; then
    echo "Local and PR HEAD match - safe to merge"
else
    echo "Mismatch! Local:$LOCAL_HEAD PR:$PR_HEAD"
fi
```
