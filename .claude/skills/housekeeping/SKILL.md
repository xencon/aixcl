---
name: housekeeping
description: >
  Repository health check and session-startup status sweep: memory recall,
  hygiene, security, code quality, and open-work triage, ending in a status
  report with priorities. Use at session start, periodically, or before a
  release. Triggers on "housekeeping", "start day", "what's the status",
  "where did we leave off", "repo health check".
argument-hint: <optional: 'all' or specific step numbers>
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "3.1"
---

# Skill: housekeeping

## Purpose

Catch accumulated debt across the repository and orient the session: broken
links, mirror drift, stale branches, permission problems, secrets, unpinned
images, shell regressions, and open-work state. Report findings and wait for
direction -- take no corrective action until directed.

## When to Run

At session start, periodically, or before a release. Each check is
independent -- a failure in one does not block the others.

## Preconditions

- [ ] On branch `dev` or a dedicated housekeeping branch
- [ ] `gh` authenticated (`gh auth status`)
- [ ] No uncommitted changes that would pollute diff checks

## Delegation

The mechanical steps (4, 5, 9, 10, 11) fit the delegate skill's tier rubric
and may be delegated to the OpenCode peer -- strictly one at a time, per the
delegate skill's sequential-only rule. If delegation fails, run the commands
directly. Steps needing GitHub state or judgment (0, 2, 3, 12) stay with the
primary agent.

Command blocks for every step: [references/step-commands.md](references/step-commands.md).

## Steps

### Step 0 -- Read Memory

Read project memory (MEMORY.md index plus files relevant to open work). Note
what was in progress, what was blocked, and what the last session
recommended.

- [ ] In-progress work, blockers, and last-session recommendations noted

### Step 1 -- Mechanical Sweep

`./aixcl checks all` -- covers documentation paths, mirror parity, elision
guard, generated and dated files (lean policy), ASCII markdown, image pins,
profile-vs-contract reconciliation, yamllint, compose validation, and
environment prerequisites. Fix anything red before continuing.

- [ ] All checks green

### Step 2 -- Branch Hygiene

Stale merged branches; fork sync between `origin/dev` and `upstream/dev`.

- [ ] No merged remote branches outstanding, or owner notified to delete
- [ ] `origin/dev` in sync with `upstream/dev`, or sync performed

### Step 3 -- Issue and PR Hygiene

Open issues missing a `component:*` label; open PRs missing an assignee.

- [ ] All open issues labeled, all open PRs assigned, or flagged for triage

### Step 4 -- Line Endings

- [ ] No CRLF line endings

### Step 5 -- Env File Integrity

Duplicate keys in env files indicate an append bug.

- [ ] No duplicate keys in any env file

### Step 6 -- File Permissions (Sensitive Files)

Runtime env files, keys, and certs must be mode `600`.

- [ ] No sensitive runtime files world-readable or world-writable
- [ ] Files under `vault/` or `security/` paths checked specifically

### Step 7 -- Secret Scanning

gitleaks if installed, grep baseline otherwise.

- [ ] No secrets detected (gitleaks absence noted as a tooling gap)

### Step 8 -- Container Image Pin Hygiene

`./aixcl checks pins` -- covers compose files AND shell code under `lib/`
and `scripts/` (unpinned references have hidden in shell code before, #1726).

- [ ] All image references pinned or carrying a `pin-waiver:` comment

### Step 9 -- Shellcheck Sweep

- [ ] No warnings at severity `warning` or above across all scripts

### Step 10 -- UPSTREAM-ISSUES.md Staleness

- [ ] No entries older than 7 days without a filed upstream issue
- [ ] Filed entries removed from the file

### Step 11 -- Agent Scratch/Temp File Hygiene

Stray `/tmp` harness directories, lingering podman test containers/volumes,
stale scratchpad drafts. Detection only -- review before deleting anything.

- [ ] No stray harness artifacts or stale scratchpad drafts

### Step 12 -- Status Report and Priorities

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
