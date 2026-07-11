---
name: housekeeping
description: Comprehensive repository health check covering hygiene, security, and code quality
version: 2.0
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "2.0"
---

# Skill: housekeeping

## Purpose

Catch accumulated debt across the repository: broken links, mirror drift,
stale branches, permission problems, secrets, unpinned images, and shell
regressions. The mechanical checks run through `./aixcl checks all`; this
skill adds the checks that need GitHub state or human judgment.

## When to Run

Periodically, or before a release. Each check is independent -- a failure in
one does not block the others.

## Preconditions

- [ ] On branch `dev` or a dedicated housekeeping branch
- [ ] `gh` authenticated (`gh auth status`)
- [ ] No uncommitted changes that would pollute diff checks

## Steps

### Step 1 -- Mechanical Sweep

```bash
./aixcl checks all
```

Covers: documentation paths, mirror parity, elision guard, generated and
dated files (lean policy), ASCII markdown, image pins, profile-vs-contract
reconciliation, yamllint, compose validation, and environment
prerequisites. Fix anything red before continuing.

### Step 2 -- Branch Hygiene (Merged Branches and Fork Sync)

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

- [ ] No merged remote branches outstanding, or owner notified to delete
- [ ] `origin/dev` is in sync with `upstream/dev`, or sync performed

### Step 3 -- Issue and PR Hygiene

Open issues missing a required `component:*` label:

```bash
gh issue list --repo xencon/aixcl --state open --limit 100 \
  --json number,title,labels,assignees \
  --jq '.[] | select(.labels | map(.name) | any(startswith("component:")) | not)
        | "  #\(.number) \(.title)"'
```

Open PRs missing an assignee:

```bash
gh pr list --repo xencon/aixcl --state open --limit 100 \
  --json number,title,assignees \
  --jq '.[] | select(.assignees | length == 0) | "  #\(.number) \(.title)"'
```

- [ ] All open issues have at least one `component:*` label, or flagged for triage
- [ ] All open PRs have an assignee, or flagged for triage

### Step 4 -- Line Endings

```bash
grep -rlP "\r\n" --include="*.md" --include="*.sh" --include="*.yml" \
  --exclude-dir=.git . 2>/dev/null \
  && echo "FAIL: CRLF line endings found" || echo "ok: LF only"
```

- [ ] No CRLF line endings

### Step 5 -- Generated Env File Integrity (Duplicate Keys)

Duplicate keys in `.env.*` or `*.env` files indicate an append bug (e.g. a
setup script running multiple times and stacking entries instead of rewriting).

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

- [ ] No duplicate keys found in any env file

### Step 6 -- File Permissions (Sensitive Files)

Runtime env files must not be world-readable or world-writable. Expected
mode: `600` (owner read/write only). Tracked config files in
`config/profiles/` are excluded -- they contain service names and ports,
not secrets.

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

- [ ] No sensitive runtime env files are world-readable or world-writable
- [ ] Files under `vault/` or `security/` paths checked specifically
- [ ] Note: to check whether a file is tracked in git, use `git ls-files --error-unmatch <file>` -- plain `git ls-files <file>` exits 0 even when the file is not tracked, making `&& echo TRACKED` a false positive.

### Step 7 -- Secret Scanning

Scan tracked files for common secret patterns. If `gitleaks` is installed,
prefer it. Otherwise use grep patterns as a baseline.

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

- [ ] No secrets detected
- [ ] If gitleaks not installed, note it as a tooling gap
- [ ] Note: `--no-git` scans ALL files on disk, including gitignored runtime files (e.g. `pgadmin-servers.json`). Findings in gitignored runtime files belong in the `.gitleaks.toml` `paths` allowlist, not the `commits` allowlist.

### Step 8 -- Container Image Pin Hygiene

Covers compose files AND shell code under `lib/` and `scripts/` -- four
unpinned alpine references hid in shell code because the old sweep only
scanned compose (issue #1726). Legitimate `:latest` uses (locally built
`localhost/` images, ollama model tags) are exempted via `localhost/`
detection or an inline `pin-waiver:` comment.

```bash
./aixcl checks pins
```

- [ ] All container image references are pinned (no `latest`, no bare image names), or carry an explicit `pin-waiver:` comment with a reason

### Step 9 -- Shellcheck Sweep (All Scripts)

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

- [ ] No shellcheck warnings or errors at severity `warning` or above

### Step 10 -- UPSTREAM-ISSUES.md Staleness

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

- [ ] No entries older than 7 days without a corresponding upstream issue
- [ ] Entries that have been filed upstream are removed from the file

## Verification

Record findings after all steps:

```
Step 1  -- Mechanical sweep (aixcl checks all):  [ ] clean  [ ] failures
Step 2  -- Branch hygiene:                       [ ] clean  [ ] stale branches / fork drift
Step 3  -- Issue/PR hygiene:                     [ ] clean  [ ] missing labels/assignees
Step 4  -- Line endings:                         [ ] clean  [ ] CRLF found
Step 5  -- Env file integrity:                   [ ] clean  [ ] duplicates
Step 6  -- File permissions:                     [ ] clean  [ ] overexposed
Step 7  -- Secret scanning:                      [ ] clean  [ ] matches
Step 8  -- Image pin hygiene:                    [ ] clean  [ ] unpinned
Step 9  -- Shellcheck sweep:                     [ ] clean  [ ] warnings
Step 10 -- UPSTREAM-ISSUES.md:                   [ ] clean  [ ] stale entries
```

Any `items found` result should become a follow-up issue before the next
release. Critical findings from steps 6 and 7 should be treated as P1.

## Common Mistakes

- Fixing findings directly on `dev` -- use a housekeeping branch and the
  issue-first workflow (or the documented override) for anything beyond
  branch deletion and fork sync
- Treating a gitleaks finding in a gitignored runtime file as a repo leak --
  allowlist the path in `.gitleaks.toml` instead
- Deleting a remote branch that has an open PR -- check the PR state is
  MERGED first (a closed PR is not a merged PR)
