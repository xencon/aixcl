---
name: release
description: >
  Guided workflow for cutting an AIXCL release, fronting the aixcl release
  command: retrospective, changelog judgment, tag, announcement, and sync.
  Operator-gated (disable-model-invocation) -- run only when the maintainer
  explicitly asks to cut a release.
compatibility: OpenCode, Claude Code
disable-model-invocation: true
metadata:
  category: workflow
  version: "2.2"
---

# Skill: release

## Purpose

Cut an AIXCL release. The mechanics live in `./aixcl release` -- this skill
supplies the judgment steps around them (retrospective content, changelog
editing, announcement) and the order in which everything runs. GPG commits
and merge decisions always stay with the human operator.

**Discussion post templates and common mistakes:**
[references/release-templates.md](references/release-templates.md)

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

Open a dedicated discussion thread and post agent observations before
proceeding. Template and checklist in the reference.

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

Post a release announcement in the Announcements discussion category.
Template in the reference. Cover: the headline change, what users must do
(if anything), anything removed or deprecated, and a link to the release
page and CHANGELOG. Include the agent identification block.

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

See the reference for common mistakes to avoid at each step.
