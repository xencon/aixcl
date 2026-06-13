# Agent Pitfalls

Common mistakes AI agents make in this repository, with corrections.
Read this if you are starting a session or if something unexpected happened.

## Workflow Pitfalls

### Pitfall: Pushing to the wrong remote

**What happens:** `git push origin issue-<N>/...` is blocked or pushes to the
wrong repository.

**Why:** `origin` is the upstream repository (`xencon/aixcl`). Direct pushes
to `origin` are blocked by branch protection. Feature branches go to the
personal fork (`sbadakhc/aixcl`), which is the `fork` remote.

**Fix:**
```bash
git remote -v                          # Check what remotes exist
git push fork issue-<N>/<description>  # Always push to fork
gh pr create --repo xencon/aixcl ...   # PR targets origin
```

If `fork` remote is missing:
```bash
git remote add fork git@github.com:sbadakhc/aixcl.git
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

See `.claude/skills/cut-release/SKILL.md` for the full release workflow.
