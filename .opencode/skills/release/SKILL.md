---
name: release
description: Guided workflow for cutting an AIXCL release, fronting the aixcl release command
version: 2.0
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "2.0"
---

# Skill: release

## Purpose

Cut an AIXCL release. The mechanics live in `./aixcl release` -- this skill
supplies the judgment steps around them (retrospective content, changelog
editing, announcement) and the order in which everything runs. GPG commits
and merge decisions always stay with the human operator.

## When to Run

When the maintainer asks to cut a release, or when accumulated dev work is
ready to promote to main.

## Versioning Cadence

AIXCL uses sequential patch bumps only: `v1.1.N+1`. Never increment minor or
major versions without explicit maintainer decision. `./aixcl release`
computes versions from upstream tags at runtime -- never assume a version
number from a previous session or document.

## Preconditions

- [ ] `gh` authenticated (`gh auth status`)
- [ ] All PRs intended for this release merged to `dev`, linked issues closed
- [ ] `./aixcl checks all` is green
- [ ] `./aixcl release status` shows a clean starting state

## Steps

### Step 1 -- Orient

```bash
./aixcl release status
```

Shows the latest tag, next version, changelog state, and any in-flight
release or sync PRs. Resolve anything unexpected before continuing.

### Step 2 -- Pre-Release Retrospective (judgment)

Open a dedicated discussion thread and post agent observations. This step is
advisory -- the human may proceed once formal CI and review checks are
complete, even if one agent has nothing material to add.

```bash
gh api graphql -f query='
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOMOfaEA",
    categoryId: "DIC_kwDOMOfaEM4C_SO-",
    title: "Release v1.1.N retrospective",
    body: "Pre-release retrospective for v1.1.N.\n\nBoth agents post observations below: what landed, what was deferred, and any open concerns before the tag goes out."
  }) {
    discussion { url number id }
  }
}'
```

- [ ] This agent has posted its retrospective (what landed, what was deferred, open concerns)
- [ ] Kimi has posted its retrospective, or confirmed nothing material to add
- [ ] Human has reviewed and confirmed readiness to proceed

Each agent post must include the standard agent identification block
(AGENTS.md Section 9.5). Link the thread URL in the release PR body.

### Step 3 -- Prep

```bash
./aixcl release prep
```

This verifies preconditions, syncs dev from upstream, inserts a changelog
draft under `[Unreleased]`, creates the release issue and branch, and stages
CHANGELOG.md. It stops and prints the next commands.

Then (judgment): review the drafted entry -- write the `### Summary` line,
tighten every bullet, confirm `Closes #N` references. Plain ASCII only. Then
follow the printed commands: `git add CHANGELOG.md`, GPG commit, push, and
create the PR to `main` with `./scripts/utils/create-pr.sh`.

- [ ] CI is green on the release PR before the human merges

### Step 4 -- Tag

After the release PR merges to main:

```bash
./aixcl release tag
```

Pulls upstream main, verifies the changelog entry landed, creates the
annotated tag, pushes it to upstream (where the release workflow fires),
and waits for the GitHub release to publish.

### Step 5 -- Announcement (judgment)

Post a release announcement in the Announcements discussion category:

```bash
gh api graphql -f query='
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOMOfaEA",
    categoryId: "DIC_kwDOMOfaEM4C_R_w",
    title: "AIXCL v1.1.N -- <headline>",
    body: "<what shipped, what users need to know, migration notes, changelog link>"
  }) {
    discussion { url number }
  }
}'
```

Cover: the headline change, what users must do (if anything), anything
removed or deprecated, and a link to the release page and CHANGELOG. Include
the agent identification block.

### Step 6 -- Finish

```bash
./aixcl release finish
```

First run creates the sync issue and main-to-dev PR, then stops. After the
human merges the sync PR, run it again: it syncs both fork branches, deletes
release branches, and closes any lingering release/sync issues.

## Verification

- [ ] Release page published at `https://github.com/xencon/aixcl/releases/tag/v1.1.N`
- [ ] `./aixcl release status` shows: tag current, no open release or sync PRs, dev contains main
- [ ] Release and sync issues closed
- [ ] Announcement posted

## Common Mistakes

- Tagging before the release PR is merged (`release tag` guards this by
  checking the changelog on upstream main -- do not bypass it)
- Editing CHANGELOG.md with non-ASCII punctuation (CI fails the ASCII check)
- Comma-packed references in the PR body -- `create-pr.sh` validates this,
  raw `gh pr create` does not
- Force-push race: if the release branch is force-pushed while the PR is
  open, confirm `gh pr view <N> --json headRefOid` matches `git log
  --oneline -1` before the human merges. A PR merged seconds before an
  amend lands cannot be fixed afterward
- Closing a PR instead of merging it -- check `state=MERGED`, not just
  "the PR is no longer open," before cleaning up branches
- Pre-commit trailing whitespace: the hook already fixed the files; re-run
  `git add` and retry the commit -- never use `--no-verify`
