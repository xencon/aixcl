---
name: check-updates
description: >
  Audit all versioned platform components (stack images, pre-commit hooks,
  GitHub Actions, CLI tools) and manage updates through the issue-first
  workflow. Use before a release cycle, after a long gap, or when asked to
  "check updates", "audit versions", "what's outdated", "bump components".
argument-hint: <optional: category to audit, or blank for all>
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "1.1"
---

# Skill: check-updates

## Purpose

Audit every versioned component in the AIXCL platform and produce an
actionable update report. For each outdated component, open a GitHub issue
and apply the update following the issue-first workflow.

The component inventory, version lookup commands, per-category update
locations, and the issue body template live in
[references/update-reference.md](references/update-reference.md).

## When to Run

Before a release cycle or after a long gap between releases.

## Step 1 -- Check Latest Versions

Run the lookup commands from the reference (GitHub releases first, Docker Hub
fallback) against all four categories: stack services, pre-commit hooks,
GitHub Actions, developer CLI tools.

## Step 2 -- Build the Update Table

Produce a table: Component, Category, Pinned, Latest, Status. Status is one
of `current` (pinned == latest), `UPDATE` (newer available), `check` (could
not determine -- verify manually).

## Step 3 -- Triage Updates

**Routine (open one issue per component):**
- Patch bumps (x.y.Z -> x.y.Z+1)
- Minor bumps with no breaking changes in the release notes

**Review required (open issue, flag for human review):**
- Major version bumps
- Any bump for a runtime core invariant component (currently: Ollama --
  see `docs/architecture/governance/00_invariants.md`)
- Release notes mentioning breaking API changes or schema migrations

**Skip (no issue):**
- Pre-release tags (alpha, beta, rc, dev)
- Architecture-specific tags (rocm, cuda, distroless suffixes)
- Tags differing only in suffix from the pinned version

## Step 4 -- Open Issues (issue-first)

One issue per component needing an update, using the template in the
reference. Batch minor patch bumps in the same category into a single issue
if there are more than three. Ollama updates get the runtime-core warning
block.

## Step 5 -- Apply Updates

Branch per issue from `dev`: `issue-<N>/update-<component>-<new-version>`.
Edit the locations listed in the reference for that category -- some tools
are pinned in two places that must change atomically (README.md + CI
workflow).

## Step 6 -- Validate and Commit

```bash
bash scripts/checks/check-ai-elisions.sh --staged
shellcheck --severity=warning --exclude=SC1091 $(find . -name "*.sh" -not -path "./.git/*")
yamllint -c .yamllint.yml .
docker compose -f services/docker-compose.yml config > /dev/null
```

Stage the changes and hand the GPG commit command to the operator
(`chore: update <component> from <old> to <new>` + `Fixes #<issue>`).

## Step 7 -- PR and CI

Push to origin, create the PR against upstream `dev` with title
`Update <component> from <old> to <new> (#<N>)`, assignee and labels at
creation time. Validate the body with `check-pr-references.sh` first.

## Dependabot Coverage Note

`.github/dependabot.yml` automatically opens PRs for Docker images in
`/services` and GitHub Actions (weekly, Mondays). This skill covers the gaps:
pre-commit hook versions, CLI tool versions in README.md, tool versions
hard-coded in CI `run:` steps, and cross-checking that Dependabot PRs have
not stalled. When Dependabot opens a PR for a component in this inventory,
close the corresponding issue from this skill if one was opened for the same
bump.

## Common Mistakes

- Updating docker-compose.yml but not README.md for the same tool version
- Updating a pre-commit rev but not the matching CI workflow pin (yamllint,
  gitleaks)
- Pulling an RC or architecture-specific tag (`-rc`, `-rocm`, `-cuda`)
- Updating Ollama without testing model inference after restart
- Batching too many updates in one PR -- prefer one component per PR so
  regressions are easy to bisect
