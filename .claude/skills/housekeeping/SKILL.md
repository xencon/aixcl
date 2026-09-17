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
  version: "3.2"
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

**Command blocks for every step, the Step 12 report template, and common
mistakes:** [references/step-commands.md](references/step-commands.md).

## Steps

| # | Step | What it checks | Checklist |
|---|------|-----------------|-----------|
| 0 | Read memory | MEMORY.md index + files relevant to open work | in-progress work, blockers, last-session recommendations noted |
| 1 | Mechanical sweep | `./aixcl checks all` -- paths, mirror parity, elisions, generated/dated files, ascii, pins, profiles, yaml, compose, env | all checks green |
| 2 | Branch hygiene | Stale merged branches; `origin/dev` vs `upstream/dev` sync | no stale branches; forks in sync |
| 3 | Issue/PR hygiene | Open issues missing `component:*`; open PRs missing an assignee | all labeled/assigned or flagged |
| 4 | Line endings | CRLF in tracked files | none found |
| 5 | Env file integrity | Duplicate keys in `.env*` files (append-bug signal) | none found |
| 6 | File permissions | Runtime env/key/cert files must be mode `600` | none world-readable/writable; `vault/`/`security/` checked |
| 7 | Secret scanning | gitleaks if installed, grep baseline otherwise | none detected; tooling gap noted if gitleaks absent |
| 8 | Image pin hygiene | `./aixcl checks pins` -- compose files and shell code | all pinned or carrying `pin-waiver:` |
| 9 | Shellcheck sweep | All scripts at severity `warning`+ | no warnings |
| 10 | UPSTREAM-ISSUES.md | Entries older than 7 days without a filed issue | none stale; filed entries removed |
| 11 | Scratch/temp hygiene | Stray `/tmp` harness dirs, podman test containers/volumes, stale scratchpad drafts (detection only) | none, or reviewed before any deletion |
| 12 | Status report | Compile findings into one table and a priority order | see reference for the exact template |

## Verification

Report using the exact table format in the reference (columns `#`, `Step`,
`Status`, `Findings`), then recommend a priority order and **wait for
direction** -- critical findings from steps 6-7 are P1.
