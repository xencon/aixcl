---
name: session-review
description: >
  Review the work done this session and identify tasks that could have been
  delegated to the OpenCode peer instead of running on the primary model.
  Builds the delegation feedback loop: surfaces missed opportunities and grows
  the always-delegate list over time. Use at the end of a session or when
  asked to review the session's work. Triggers on "session review", "what did
  we do today", "review this session".
argument-hint: <optional focus area or timeframe>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.1"
---

# Session Review

Review the current session's work to identify delegation opportunities.

## Step 1: Self-report task list

List every distinct task performed this session:

| # | Task description | Category | Ran on | Could delegate? | Why / why not |
|---|-----------------|----------|--------|-----------------|---------------|

Categories: search, read, edit, test, lint, check, git, gh, ci, plan, debug,
review, scaffold, other. "Ran on" is "primary" or "delegated".

"Could delegate?" applies the delegate skill's tier rubric:
- YES: read-only search/grep, file stats, git/gh status queries, lint, check
  runs, simple mechanical edits, boilerplate
- NO: needed conversation context, multi-file reasoning, security judgment,
  stack or GitHub writes, interactive back-and-forth, planning/design

## Step 2: Score the session

- Total tasks; tasks on primary; tasks delegated
- Missed opportunities (ran on primary but delegable)
- Delegation rate: delegated / (delegated + missed)
- Efficiency: tasks-that-needed-primary / total-primary-tasks (higher is
  better use of the primary model)

## Step 3: Identify new patterns

For recurring missed opportunities, draft an always-delegate entry: pattern
name, tier (1 read-only / 2 analysis / 3 writes), example delegation prompt,
why it is safe.

## Step 4: Cross-check the log

Read `.opencode/delegation-log.jsonl` and confirm every delegated task from
Step 1 is logged (delegations run sequentially, so entries should be ordered).
Also note any whole issues delegated via the `agent` label this session --
they count as delegated work but live in GitHub, not the log. If project
memory contains delegation-candidate notes, check whether any known pattern
was missed.

## Step 5: Report

- **Session summary**: date, total tasks, delegation rate, efficiency score
  -- present as a small table, one row per metric, with a `Status` column
  (`clean`/`warning`/`critical`) for the delegation rate and efficiency
  score against your own judgment of whether they're healthy
- **What was delegated**: table with duration and success
- **Missed opportunities**: table with suggested delegation prompts
- **New patterns**: recurring misses that should become standard candidates
- **Recommendations**: what to delegate next session; patterns to drop
  (failed delegations); suggested updates to the delegate skill

Render `Status` values as a colored indicator (green/yellow/red) in the live
report. This file stays ASCII (no skill file uses emoji); the color exists
only in the report you render, never in this source.
