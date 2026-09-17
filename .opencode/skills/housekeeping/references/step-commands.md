# Housekeeping step commands

Command blocks for each housekeeping step. Run from the repository root.

## Contents

- Status report template and priority ordering (Step 12)
- Common mistakes
- Step 2: Branch hygiene
- Step 3: Issue and PR hygiene
- Step 4: Line endings
- Step 5: Env file integrity
- Step 6: File permissions
- Step 7: Secret scanning
- Step 9: Shellcheck sweep
- Step 10: UPSTREAM-ISSUES.md staleness
- Step 11: Agent scratch/temp file hygiene

## Status report template (Step 12)

Compile the single report as a table, columns `#`, `Step`, `Status`,
`Findings`. Status is one of `clean` / `warning` / `critical` (`critical`
reserved for steps 6-7, which are P1 findings). This file stays ASCII per
repo convention (no skill file uses emoji -- keep it that way); when you
render the report live in chat, show Status as a colored indicator (green
for clean, yellow for warning, red for critical) for readability -- the
color exists only in the rendered output, never in this source file.

| # | Step | Status | Findings |
|---|------|--------|----------|
| 0 | Memory recall | -- | in-progress work / blockers |
| 1 | Mechanical sweep | clean/critical | |
| 2 | Branch hygiene | clean/warning | |
| 3 | Issue/PR hygiene | clean/warning | |
| 4 | Line endings | clean/warning | |
| 5 | Env file integrity | clean/warning | |
| 6 | File permissions | clean/critical | |
| 7 | Secret scanning | clean/critical | |
| 8 | Image pin hygiene | clean/warning | |
| 9 | Shellcheck sweep | clean/warning | |
| 10 | UPSTREAM-ISSUES.md | clean/warning | |
| 11 | Scratch/temp hygiene | clean/warning | |

Follow with a recommended priority order for anything found (critical
findings from steps 6 and 7 are P1; other findings become follow-up issues
before the next release) and **wait for direction**.

## Common Mistakes

- Fixing findings directly on `dev` -- use a housekeeping branch and the
  issue-first workflow (or the documented override) for anything beyond
  branch deletion and fork sync
- Treating a gitleaks finding in a gitignored runtime file as a repo leak --
  allowlist the path in `.gitleaks.toml` instead
- Deleting a remote branch that has an open PR -- check the PR state is
  MERGED first (a closed PR is not a merged PR)
- Running delegated checks in parallel -- the delegation log is
  sequential-only

## Step 2: Branch hygiene

```bash
git fetch --prune origin 2>/dev/null; git fetch --prune upstream 2>/dev/null || true

# Stale merged branches
git branch -r --merged upstream/dev 2>/dev/null \
  | grep -v 'upstream/dev\|upstream/main\|origin/dev\|origin/main\|HEAD' \
  || echo "ok: no stale merged remote branches"

# Fork sync with upstream dev
upstream_ahead=$(git rev-list origin/dev..upstream/dev 2>/dev/null | wc -l | tr -d ' ')
if [ "$upstream_ahead" -gt 0 ]; then
  echo "WARN: origin/dev is $upstream_ahead commit(s) behind upstream/dev"
  echo "  Fix: git checkout dev && git pull upstream dev && git push origin dev"
else
  echo "ok: origin/dev is in sync with upstream/dev"
fi
```

## Step 3: Issue and PR hygiene

```bash
# Open issues missing a required component:* label
gh issue list --repo xencon/aixcl --state open --limit 100 \
  --json number,title,labels,assignees \
  --jq '.[] | select(.labels | map(.name) | any(startswith("component:")) | not)
        | "  #\(.number) \(.title)"'

# Open PRs missing an assignee
gh pr list --repo xencon/aixcl --state open --limit 100 \
  --json number,title,assignees \
  --jq '.[] | select(.assignees | length == 0) | "  #\(.number) \(.title)"'
```

## Step 4: Line endings

```bash
grep -rlP "\r\n" --include="*.md" --include="*.sh" --include="*.yml" \
  --exclude-dir=.git . 2>/dev/null \
  && echo "FAIL: CRLF line endings found" || echo "ok: LF only"
```

## Step 5: Env file integrity (duplicate keys)

Duplicate keys in `.env.*` or `*.env` files indicate an append bug (e.g. a
setup script running multiple times and stacking entries instead of
rewriting).

```bash
for f in $(find . \( -name ".env*" -o -name "*.env" \) \
           -not -path "./.git/*" -not -name "*.example" -type f); do
  dupes=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$f" \
          | cut -d= -f1 | sort | uniq -d)
  if [ -n "$dupes" ]; then
    echo "DUPLICATE KEYS in $f: $dupes"
  else
    echo "ok: $f"
  fi
done
```

## Step 6: File permissions (sensitive files)

Runtime env files must not be world-readable or world-writable. Expected
mode: `600`. Tracked config files in `config/profiles/` are excluded -- they
contain service names and ports, not secrets.

```bash
find . \( -name ".env" -o -name ".env.*" -o -name "*.key" \
          -o -name "*.token" -o -name "*.pem" -o -name "*.crt" \) \
  -not -path "./.git/*" \
  -not -path "./config/profiles/*" \
  -not -name "*.example" \
  -type f \
  | while read -r f; do
      perms=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%OLp" "$f" 2>/dev/null)
      if echo "$perms" | grep -qE "[1-7]$"; then
        echo "WORLD-READABLE or WRITABLE: $f ($perms) -- run: chmod 600 $f"
      else
        echo "ok: $f ($perms)"
      fi
    done
```

Note: to check whether a file is tracked in git, use
`git ls-files --error-unmatch <file>` -- plain `git ls-files <file>` exits 0
even when the file is not tracked, making `&& echo TRACKED` a false positive.

## Step 7: Secret scanning

```bash
if command -v gitleaks > /dev/null 2>&1; then
  gitleaks detect --source . --no-git 2>&1 | tail -20
else
  grep -rEn \
    "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_\-]{20,}|sk-[A-Za-z0-9]{40,}|xoxb-[A-Za-z0-9\-]+|VAULT_TOKEN=[A-Za-z0-9.\-]{20,})" \
    --include="*.md" --include="*.yml" --include="*.yaml" \
    --include="*.sh" --include="*.json" --include="*.env*" \
    --exclude-dir=.git . 2>/dev/null \
    && echo "FAIL: potential secrets found above" || echo "ok: no common secret patterns matched"
fi
```

Note: `--no-git` scans ALL files on disk, including gitignored runtime files
(e.g. `pgadmin-servers.json`). Findings in gitignored runtime files belong in
the `.gitleaks.toml` `paths` allowlist, not the `commits` allowlist.

## Step 9: Shellcheck sweep

```bash
issues=$(find . -name "*.sh" -not -path "./.git/*" \
  | xargs shellcheck --severity=warning --exclude=SC1091 2>&1)
if [ -n "$issues" ]; then
  echo "$issues" | head -40
  echo "FAIL: shellcheck issues found"
else
  echo "ok: all scripts clean"
fi
```

## Step 10: UPSTREAM-ISSUES.md staleness

```bash
if [ -f UPSTREAM-ISSUES.md ]; then
  echo "UPSTREAM-ISSUES.md exists -- review entries manually:"
  grep -E "^##|^- " UPSTREAM-ISSUES.md | head -30
  echo ""
  echo "File last modified: $(git log -1 --format='%ar' -- UPSTREAM-ISSUES.md)"
else
  echo "ok: UPSTREAM-ISSUES.md does not exist"
fi
```

## Step 11: Agent scratch/temp file hygiene

Verification work (podman test harnesses, permission/capability checks)
leaves temporary artifacts outside the repository tree. Detection only --
review what is found before deleting anything.

```bash
# Stray /tmp directories from prior harness/verification runs (adjust the
# glob to match your own session's naming convention if it differs)
find /tmp -maxdepth 1 \( -iname "aixcl-harness-*" -o -iname "*-harness-*" \) 2>/dev/null

# Lingering podman test containers/volumes from harness runs
podman ps -a --filter "name=harness" --format "{{.Names}}" 2>&1
podman volume ls --filter "name=harness" --format "{{.Name}}" 2>&1

# This session's scratchpad directory -- safe to clear once every draft's
# real content has landed on GitHub (issue/PR bodies, once filed, live
# there; the local draft file is disposable afterward)
ls -la "$CLAUDE_SCRATCHPAD_DIR" 2>/dev/null || true
```
