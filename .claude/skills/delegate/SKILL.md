---
name: delegate
description: >
  Delegate a mechanistic sub-task to the OpenCode peer agent via opencode run,
  logging every delegation. Use for search/grep, read-and-summarize, lint and
  check runs, git/gh status queries, and simple mechanical edits that do not
  need the primary model's reasoning. Invoke with /delegate <task>, or
  proactively when a sub-task fits the tier rubric. For delegating a whole
  GitHub issue to the peer agent, use the agent label instead (AGENTS.md).
argument-hint: <task description or instructions>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.8"
---

# Delegate to OpenCode

Delegate the given task to the OpenCode peer agent and log it for tracking.

**Full detail (bounded parallelism, tier rubric, model-selection chain,
server-cache gotcha, logging edge cases, exact commands):**
[references/delegation-guide.md](references/delegation-guide.md)

## Step 1: Assess the task

Confirm the task fits Tier 1 (read-only), Tier 2 (side-effect-free analysis),
or Tier 3 (reviewable file writes) in the reference guide, and clears its
30-second cost floor.

Do NOT delegate:
- Multi-file or architectural changes; anything security-sensitive
- Stack state changes (start/stop/restart/purge) -- operator territory
- git commit/push/merge, or any GitHub write (issues, PRs, comments) --
  workflow rules and the agent identification block stay with the primary agent
- Complex debugging needing deep reasoning or conversation context
- Interactive commands

If the task does not fit, say so and handle it directly.

## Step 2: Ensure the shared server, then pick the model

Every delegation attaches to one persistent `opencode serve` process
instead of spawning its own instance:

    URL=$(bash scripts/utils/ensure-opencode-server.sh)

This is idempotent and near-instant if the server is already running --
call it before every delegation (or once per batch of parallel
delegations). See the reference guide for the model-selection fallback
chain and the server config-cache gotcha.

## Step 3: Prepare the prompt

Write a self-contained prompt -- the delegate has none of your conversation
context. Include absolute file paths, the exact commands or edits wanted, and
the expected output format. Concrete ("in /path/file.sh change X to Y"), not
vague ("fix the bug").

## Step 4: Log and execute

Log the start in the JSONL log before running, execute with `opencode run`
(bounded by `timeout`), then log completion. Exact command lines, the
parallel-batch pattern, and the required `flock` wrapping are all in the
reference guide -- follow them precisely, since malformed JSONL breaks
delegate-review's analytics.

## Step 5: Log the result

Record which provider/model actually served the request and its fallback
position. See the reference guide for the exact log-line format and the
"503 after visible tool output" / "every model in the chain failed" edge
cases.

## Step 6: Report

Return the result to the user. If output is long (over 200 lines), extract the
key findings. If files were modified (Tier 3), list them, summarize the
changes, and review the diff before anything is staged.
