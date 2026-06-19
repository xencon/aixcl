---
name: housekeeping
description: Comprehensive repository health check covering hygiene, security, and code quality
version: 1.1
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "1.1"
---

# Skill: housekeeping

Run this skill periodically or before a release to catch accumulated debt
across the repository. Each check is independent -- a failure in one does
not block the others. Work through them in order and record findings.

## Pre-Flight

```bash
# Confirm tooling available
command -v gh && echo "gh: ok" || echo "gh: not found -- skip checks 4b, 5"
command -v shellcheck && echo "shellcheck: ok" || echo "shellcheck: not found -- skip check 11"
command -v gitleaks && echo "gitleaks: ok" || echo "gitleaks: not found -- fallback to grep patterns"
```

- [ ] On branch `dev` or a dedicated housekeeping branch
- [ ] `gh` authenticated (`gh auth status`)
- [ ] No uncommitted changes that would pollute diff checks

---

## Check 1 -- Lean Policy (Dated Docs and Reports)

Flag any file with a date pattern in its name or under `docs/operations/` or
`docs/reference/` that has not been modified within 7 days. Operations reports
must be current; stale ones should be deleted, not archived.

```bash
# Files with date patterns in name (e.g. 2024-01-15-report.md)
find docs/ -name "*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*" -not -path "*/.git/*"

# Files in operations or reference dirs not touched in 7 days
find docs/operations/ docs/reference/ -name "*.md" -mtime +7 -not -path "*/.git/*" 2>/dev/null
```

- [ ] No dated-name files found, or flagged ones deleted
- [ ] No stale operations/reference docs older than 7 days, or flagged ones deleted

---

## Check 2 -- Mirror Parity (.claude/ vs .opencode/)

Rules and skills must be byte-identical between `.claude/` and `.opencode/`.
Any diff is a bug.

```bash
bash scripts/checks/check-agents.sh
```

If `check-agents.sh` is unavailable, verify manually:

```bash
for f in ci-checks.md formatting.md security.md workflow.md discussions.md; do
  diff ".claude/rules/$f" ".opencode/rules/$f" && echo "$f: ok" || echo "$f: MISMATCH"
done
for skill in add-service cut-release workflow-guard housekeeping; do
  diff ".claude/skills/$skill/SKILL.md" ".opencode/skills/$skill/SKILL.md" 2>/dev/null \
    && echo "$skill: ok" || echo "$skill: MISMATCH or missing"
done
```

- [ ] All rules files match
- [ ] All skill files match

---

## Check 3 -- Broken Relative Links

```bash
bash scripts/checks/check-paths.sh
```

- [ ] No broken relative links reported

---

## Check 4 -- Branch Hygiene (Merged Branches and Fork Sync)

List remote branches already merged into `dev` that have not been deleted,
and check whether the personal fork is in sync with upstream. Fork drift
accumulates quickly with frequent releases -- catch it here before it causes
merge conflicts on the next branch.

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

---

## Check 5 -- Issue and PR Hygiene (requires `gh`)

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

---

## Check 6 -- Pre-Commit Sanity (ASCII, CRLF, Elision)

Run as a whole-repo sweep, not just staged files.

```bash
# Non-ASCII punctuation in markdown
grep -rlP "[\x{2013}\x{2014}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}]" \
  --include="*.md" --exclude-dir=.git . 2>/dev/null \
  && echo "FAIL: non-ASCII punctuation found" || echo "ok: ASCII clean"

# CRLF line endings
grep -rlP "\r\n" --include="*.md" --include="*.sh" --include="*.yml" \
  --exclude-dir=.git . 2>/dev/null \
  && echo "FAIL: CRLF line endings found" || echo "ok: LF only"

# Elision check on all committed files (not just staged)
./scripts/checks/check-ai-elisions.sh 2>/dev/null || \
  ./scripts/checks/check-ai-elisions.sh --staged
```

- [ ] No non-ASCII punctuation in markdown files
- [ ] No CRLF line endings
- [ ] No AI elision placeholder text

---

## Check 7 -- Generated Env File Integrity (Duplicate Keys)

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

---

## Check 8 -- File Permissions (Sensitive Files)

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

---

## Check 9 -- Secret Scanning

Scan tracked files for common secret patterns. If `gitleaks` is installed,
prefer it. Otherwise use grep patterns as a baseline.

```bash
# Preferred: gitleaks (if available)
if command -v gitleaks > /dev/null 2>&1; then
  gitleaks detect --source . --no-git 2>&1 | tail -20
else
  # Baseline grep patterns for common secret formats
  grep -rEn \
    "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_\-]{20,}|sk-[A-Za-z0-9]{40,}|xoxb-[A-Za-z0-9\-]+|VAULT_TOKEN=[A-Za-z0-9.\-]{20,})" \
    --include="*.md" --include="*.yml" --include="*.yaml" \
    --include="*.sh" --include="*.json" --include="*.env*" \
    --exclude-dir=.git . 2>/dev/null \
    && echo "FAIL: potential secrets found above" || echo "ok: no common secret patterns matched"
fi
```

- [ ] No secrets detected in tracked files
- [ ] If gitleaks not installed, note it as a tooling gap

---

## Check 10 -- Docker Image Pin Hygiene

All images in compose files must be pinned to a specific version tag.
`latest` or untagged images are a reproducibility and supply chain risk.

```bash
# Flag :latest tags and bare image names with no tag (no colon after final slash)
grep -hn "image:" services/docker-compose*.yml | grep -v "#" | \
  grep -E "image:\s+(\S+:latest\s*$|\S*/[^:]+\s*$|[^/:]+\s*$)" \
  && echo "FAIL: unpinned image tags found above" || echo "ok: all images pinned"
```

- [ ] All images in all compose files use pinned version tags (no `latest`, no bare image names)

---

## Check 11 -- Shellcheck Sweep (All Scripts)

Run shellcheck across the entire repo, not just staged files. This catches
regressions in scripts nobody has recently touched.

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

---

## Check 12 -- UPSTREAM-ISSUES.md Staleness

If `UPSTREAM-ISSUES.md` exists, entries older than 7 days with no
corresponding upstream issue filed should be promoted or removed.

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

---

## Summary

After running all checks, record findings:

```
Check 1  -- Lean policy:         [ ] clean  [ ] items found
Check 2  -- Mirror parity:       [ ] clean  [ ] mismatch
Check 3  -- Broken links:        [ ] clean  [ ] broken
Check 4  -- Branch hygiene:      [ ] clean  [ ] stale branches / fork drift
Check 5  -- Issue/PR hygiene:    [ ] clean  [ ] missing labels/assignees
Check 6  -- Pre-commit sanity:   [ ] clean  [ ] failures
Check 7  -- Env file integrity:  [ ] clean  [ ] duplicates
Check 8  -- File permissions:    [ ] clean  [ ] overexposed
Check 9  -- Secret scanning:     [ ] clean  [ ] matches
Check 10 -- Image pin hygiene:   [ ] clean  [ ] unpinned
Check 11 -- Shellcheck sweep:    [ ] clean  [ ] warnings
Check 12 -- UPSTREAM-ISSUES.md:  [ ] clean  [ ] stale entries
```

Any `items found` result should become a follow-up issue before the next
release. Critical findings from checks 8 and 9 should be treated as P1.
