---
name: cut-release
description: Guided checklist for cutting a new AIXCL release following the versioning cadence
version: 1.1
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

## Step 2 -- Pre-Release Retrospective

Before updating the CHANGELOG, open a dedicated discussion thread and post
agent observations. This step is advisory -- the human may proceed once
formal CI and review checks are complete, even if one agent has nothing
material to add.

Open the thread (substitute the computed `$NEXT` version):

```bash
gh api graphql -f query='
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOMOfaEA",
    categoryId: "DIC_kwDOMOfaEM4C_SO-",
    title: "Release v1.1.N retrospective",
    body: "Pre-release retrospective for v1.1.N.\n\nBoth agents post observations below: what landed, what was deferred, and any open concerns before the tag goes out."
  }) {
    discussion { url number }
  }
}'
```

- [ ] New discussion thread opened titled "Release vX.Y.Z retrospective"
- [ ] This agent has posted its retrospective (what landed, what was deferred, open concerns)
- [ ] Kimi has posted its retrospective, or confirmed nothing material to add
- [ ] Human has reviewed both posts and confirmed readiness to proceed

Each agent post must include the standard agent identification block
(AGENTS.md Section 9.5). Link the thread URL in the release PR body.

## Step 3 -- Update CHANGELOG.md

Generate a draft from conventional commits using git-cliff (if installed),
then edit to match the required format:

```bash
# Generate draft for commits since the last tag
git cliff --unreleased --tag "$NEXT" 2>/dev/null \
  || echo "git-cliff not installed -- write entry manually"
```

The draft pre-fills Added/Fixed/Changed/Documentation sections from commit
messages. You MUST still:
- Write the `### Summary` line (cliff leaves a placeholder)
- Verify and tighten every entry -- commit bodies rarely read as release notes
- Confirm all `Closes #N` references are present and correct

Read `CHANGELOG.md` first to confirm the current format, then prepend the
edited entry under `## [Unreleased]`:

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

## Step 4 -- Merge dev to main

```bash
# Ensure dev is up to date
git checkout dev && git pull origin dev

# Create release branch from dev
git checkout -b issue-<N>/release-v1-1-<N>

# Commit CHANGELOG update
git add CHANGELOG.md
git commit -m "chore: update changelog for v1.1.<N>

Fixes #<issue-number>"

# Push to fork
git push origin issue-<N>/release-v1-1-<N>

# Verify PR body passes reference check BEFORE creating
cat /tmp/release-pr-body.md | bash scripts/checks/check-pr-references.sh

# Create PR targeting main (not dev)
gh pr create \
  --repo xencon/aixcl \
  --base main \
  --title "Release v1.1.<N> (#<N>)" \
  --body-file /tmp/release-pr-body.md \
  --assignee <assignee> \
  --label "Task,component:infrastructure,Maintenance"
```

- [ ] PR body verified with `check-pr-references.sh` before creation
- [ ] PR targets `main` (not `dev`) -- releases go to main
- [ ] If the release branch is force-pushed after PR creation, confirm the PR HEAD SHA matches before the human merges:
  ```bash
  gh pr view <N> --repo xencon/aixcl --json headRefOid --jq '.headRefOid[:8]'
  # must match: git log --oneline -1
  ```
- [ ] CI is green before merging

## Step 5 -- Tag the Release

After the PR is merged to `main`:

```bash
git checkout main && git pull origin main
git tag v1.1.<N> -m "Release v1.1.<N>"
git push origin v1.1.<N>
```

- [ ] Tag format is exactly `v1.1.<N>` (no `release/` prefix)
- [ ] Tag is pushed to `origin` (upstream), not just `fork`
- [ ] The `release.yml` workflow fires within 30 seconds of tag push

## Step 6 -- Verify GitHub Release

```bash
# Check workflow status
gh run list --repo xencon/aixcl --limit 5

# Check release page
gh release view v1.1.<N> --repo xencon/aixcl
```

- [ ] Release page exists at `https://github.com/xencon/aixcl/releases/tag/v1.1.<N>`
- [ ] Release notes are populated (from CHANGELOG or release template)
- [ ] No draft status -- release is published

## Step 7 -- Sync dev with main

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

## Step 8 -- Close Release Issue

- [ ] Close the GitHub issue that tracked this release
- [ ] Update any MEMORY.md entries referencing the previous version

## Common Mistakes

- Tagging before the PR is merged (tag points to wrong commit)
- Pushing tag to `fork` instead of `origin` (release workflow does not fire)
- Forgetting to sync `dev` after release (dev diverges from main)
- Using `latest` in CHANGELOG date instead of actual ISO date
- Non-ASCII punctuation in CHANGELOG (CI fails the ASCII check)
- Comma-packed PR body references -- always pipe the body through `check-pr-references.sh` before `gh pr create` and before `gh pr edit`
- Force-push race: if a branch is force-pushed while the PR is open, GitHub may merge the pre-push HEAD if the human acts quickly. Always confirm `gh pr view <N> --json headRefOid` matches `git log --oneline -1` before asking the human to merge
- Pre-commit trailing whitespace: if a commit fails with `trailing-whitespace`, the hook already fixed the files in the working tree. Run `git add <files>` to re-stage the linter's fixes and retry the commit -- never use `--no-verify`
