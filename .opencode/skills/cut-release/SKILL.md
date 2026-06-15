---
name: cut-release
description: Guided checklist for cutting a new AIXCL release following the versioning cadence
version: 1.0
---

# Skill: cut-release

Use this skill when cutting a new AIXCL release. Covers everything from
pre-release housekeeping through tag push and GitHub release verification.

## Versioning Cadence

AIXCL uses sequential patch bumps only: `v1.1.N+1`. Never increment minor or
major versions without explicit maintainer decision.

Determine the current and next version at runtime:
```bash
CURRENT=$(git tag --sort=-v:refname | head -1)          # e.g. v1.1.28
PATCH=$(echo "$CURRENT" | sed 's/v1\.1\.//')             # e.g. 28
NEXT="v1.1.$((PATCH + 1))"                              # e.g. v1.1.29
echo "Current: $CURRENT  Next: $NEXT"
```

Always run this at the start of a release session -- never assume a version
number from a previous session or document.

## Step 1 -- Pre-Release Housekeeping

- [ ] All PRs for this release are merged to `dev`
- [ ] All linked issues are closed
- [ ] No open PRs targeting `dev` that are intended for this release
- [ ] Run CI locally:
  ```bash
  bash scripts/checks/check-paths.sh
  bash scripts/checks/check-generated-files.sh
  yamllint -c .yamllint.yml .
  ./aixcl utils check-env
  ```
- [ ] Check last 30 issues/PRs for unchecked boxes:
  ```bash
  gh issue list --state closed --limit 30
  gh pr list --state merged --limit 30
  ```

## Step 2 -- Update CHANGELOG.md

Read `CHANGELOG.md` first to confirm the current format, then add a new entry:

```markdown
## [v1.1.N] - YYYY-MM-DD

### Summary
<one sentence description of the release>

### Added
- [x] **Feature**: Description. Closes #N.

### Changed
- [x] **Change**: Description. Closes #N.

### Fixed
- [x] **Fix**: Description. Closes #N.

### Documentation
- [x] **Doc**: Description.
```

Rules:
- [ ] Version follows `v1.1.N` pattern
- [ ] Date is today's date (ISO 8601: YYYY-MM-DD)
- [ ] All entries reference closed issues
- [ ] No non-ASCII punctuation (plain ASCII only -- CI enforces this)
- [ ] `[Unreleased]` section is cleared (contents moved to new version entry)

## Step 3 -- Merge dev to main

```bash
# Ensure dev is up to date
git checkout dev && git pull origin dev

# Create release branch from dev
git checkout -b issue-<N>/release-v1-1-<N>

# Commit CHANGELOG update
git add CHANGELOG.md
git commit -m "chore: update changelog for v1.1.<N>

Fixes #<issue-number>"

# Push to fork and create PR targeting main (not dev)
git push fork issue-<N>/release-v1-1-<N>
gh pr create \
  --repo xencon/aixcl \
  --base main \
  --title "Release v1.1.<N> (#<N>)" \
  --body-file /tmp/release-pr-body.md \
  --assignee <assignee> \
  --label "Task,component:infrastructure,Maintenance"
```

- [ ] PR targets `main` (not `dev`) -- releases go to main
- [ ] CI is green before merging

## Step 4 -- Tag the Release

After the PR is merged to `main`:

```bash
git checkout main && git pull origin main
git tag v1.1.<N> -m "Release v1.1.<N>"
git push origin v1.1.<N>
```

- [ ] Tag format is exactly `v1.1.<N>` (no `release/` prefix)
- [ ] Tag is pushed to `origin` (upstream), not just `fork`
- [ ] The `release.yml` workflow fires within 30 seconds of tag push

## Step 5 -- Verify GitHub Release

```bash
# Check workflow status
gh run list --repo xencon/aixcl --limit 5

# Check release page
gh release view v1.1.<N> --repo xencon/aixcl
```

- [ ] Release page exists at `https://github.com/xencon/aixcl/releases/tag/v1.1.<N>`
- [ ] Release notes are populated (from CHANGELOG or release template)
- [ ] No draft status -- release is published

## Step 6 -- Sync dev with main

After release, sync `dev` to include the merge commit from `main`:

```bash
# Create a sync PR: main -> dev
gh pr create \
  --repo xencon/aixcl \
  --base dev \
  --head main \
  --title "Sync main into dev after v1.1.<N> release (#<N>)" \
  --body "Reconcile release history. Fixes #<sync-issue-number>" \
  --assignee <assignee> \
  --label "Task,component:infrastructure,Maintenance"
```

- [ ] Sync PR merged to `dev`
- [ ] No divergence between `main` and `dev`

## Step 7 -- Close Release Issue

- [ ] Close the GitHub issue that tracked this release
- [ ] Update any MEMORY.md entries referencing the previous version

## Common Mistakes

- Tagging before the PR is merged (tag points to wrong commit)
- Pushing tag to `fork` instead of `origin` (release workflow does not fire)
- Forgetting to sync `dev` after release (dev diverges from main)
- Using `latest` in CHANGELOG date instead of actual ISO date
- Non-ASCII punctuation in CHANGELOG (CI fails the ASCII check)
