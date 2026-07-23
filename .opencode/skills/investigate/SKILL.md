---
name: investigate
description: >
  Investigate a bug or platform issue before jumping to a fix. Establish root
  cause from git history, releases, and running-stack state. Use when a bug is
  reported, a service breaks, a check starts failing, or asked to
  "investigate", "debug", "what changed", "why is this broken". Triggers on
  bug reports, failing CI links, error output, unhealthy services.
argument-hint: <description of the issue or a GitHub issue link>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.0"
---

# Investigate

Run these steps **in order**. Do NOT start fixing until the investigation is
complete. Investigation is read-only: never restart, stop, or purge the stack
as part of diagnosis unless the operator explicitly asks.

## Step 1: Understand the report

What is the symptom? Who reported it, when? Every boot or intermittent? All
services or one? Exact error text, log excerpt, or failing check name?

## Step 2: Identify the affected code

Map the symptom to a code path: `lib/` (CLI logic), `scripts/` (checks,
runtime entrypoints), `services/docker-compose.yml` (service definitions),
`config/profiles/` (what runs), `.github/workflows/` (CI). Read the
directory's `CONTEXT.md` if it has one.

## Step 3: What changed? (MOST IMPORTANT)

Before forming any theory, check history against the canonical remote:

```bash
git fetch upstream
git log --oneline upstream/dev -- <affected-path> | head -10
gh pr list --repo xencon/aixcl --state merged --search "<component>" --limit 5
```

For each recent commit: when merged, what changed, which issue drove it.

## Step 4: When did it break?

Correlate the report timeline with merge times, release tags
(`git tag --sort=-creatordate | head -5`), and stack restarts. "Worked before
X, broke after Y" narrows the suspect list fast.

## Step 5: What is actually running?

The running stack can lag the repo (compose changes need a full stack
restart; volumes persist state across image bumps):

```bash
./aixcl stack status
./aixcl stack logs <service>
podman inspect <container> --format '{{.ImageName}}'   # vs the compose pin
```

Could the issue be stale state rather than code -- an old container, a volume
carrying data from before a fix, an `.env` regenerated with different
permissions?

## Step 6: Reproduce

Trigger it in the smallest read-only way possible: `./aixcl test lib`, a
single `./aixcl checks <name>`, a `curl` probe against the service endpoint,
or `podman exec --user <uid>` to test permissions as the real service user.

## Step 7: Root cause analysis

Form a theory: one change or an interaction? Regression or latent bug only
now exposed (e.g. by a fresh volume)? Environment-specific? Blast radius?

If the theory does not explain ALL symptoms, return to Step 3 with a wider
time range or adjacent code paths. Do not settle for a partial explanation.

Present findings before proposing a fix: what changed, when it broke, why,
what is affected.

## Step 8: Fix strategy

Only after the investigation is complete, and issue-first: file or update the
GitHub issue with the findings before any code changes. Then choose:

1. **Immediate mitigation** -- disable or bypass the broken piece minimally
2. **Proper fix** -- address the root cause, with a test or check that would
   have caught it
3. **Revert** -- if the fix is complex and the platform is degraded

## Step 9: Document

Record on the issue: symptoms, root cause, timeline, offending commits/PRs,
chosen strategy. Include the agent identification block (AGENTS.md 9.5).

## Step 10: Lessons

What gap let this land? Should it become a new `./aixcl checks` check, a
housekeeping step, or a memory note? File a follow-up issue if so.
