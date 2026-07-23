---
name: delegate-review
description: >
  Review delegation history from the JSONL delegation log: what was delegated,
  how often, success rates, duration stats, and what else could be delegated.
  Use when asked to review delegations, check delegation stats, or tune the
  delegation workflow. Triggers on "delegation review", "delegation stats",
  "what have we delegated".
argument-hint: <timeframe, e.g. 'last week', 'today', or blank for all>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.1"
---

# Delegation Review

Analyze the delegation log and produce a review. The log lives at
`.opencode/delegation-log.jsonl` in the repository root.

## Step 1: Read the log

```bash
cat .opencode/delegation-log.jsonl 2>/dev/null
```

If the file is missing or empty, report that no delegations have been
recorded yet and stop.

## Step 2: Produce analytics

Parse the JSONL entries (filter to the requested timeframe if given) and
report:

### Usage Summary
- Total delegations (completed entries only -- ignore "started" entries with
  no matching completion; flag them as interrupted runs)
- Success rate (successful / total)
- Date range covered and delegations per day

### Duration Stats
- Average duration; fastest and slowest tasks
- Tasks over 60 seconds (candidates for a tighter prompt or a cloud model)

### Task Breakdown
- Group tasks by type (search, lint, test, edit, check, ...)
- Most common task types and success rate per type

### Quality Assessment
For each completed delegation: did it succeed, was it appropriately scoped
for the delegate model, and do failures suggest the task was too complex to
delegate?

### By Provider/Model
Entries logged before the `provider_model`/`fallback_position` fields
existed (delegate skill pre-1.3) won't have them -- report those separately
as "unattributed" rather than dropping them silently. For entries that do:
- Delegations and success rate per `provider_model`
- Distribution of `fallback_position` (how often the primary model in the
  delegate skill's Step 2 chain actually served the request, vs falling
  through to a fallback -- a rising fallback rate signals the primary
  model or endpoint needs attention)
- Whether the last-resort model (Ollama) ever fired, and why if so

## Step 3: Recommendations

Based on the history, suggest:

1. **More delegation candidates** -- recurring primary-agent tasks that fit
   the delegate skill's tier rubric
2. **Tasks to stop delegating** -- patterns with high failure rates
3. **Prompt improvements** -- failures that point at missing context in the
   delegation prompts

Present as a markdown report: tables for stats, bullets for recommendations.
