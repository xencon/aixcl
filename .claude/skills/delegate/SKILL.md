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
  version: "1.2"
---

# Delegate to OpenCode

Delegate the given task to the OpenCode peer agent and log it for tracking.

**SEQUENTIAL ONLY -- HARD RULE**: run at most one `opencode run` at a time.
Never launch delegations in parallel: concurrent appends corrupt ordering in
the shared JSONL log. Queue multiple tasks and run them one after another.

`LOGFILE` is `.opencode/delegation-log.jsonl` at the repository root
(gitignored; create with `mkdir -p .opencode` if missing).

## Step 1: Assess the task

Confirm the task fits delegation. Good candidates:

**Tier 1 -- read-only, zero risk:**
- File search, grep, symbol lookup; read and summarize files
- Line/file counts, directory stats
- `git status`, `git log`, branch info; `gh pr list`, `gh issue list` (read-only)
- Check env var presence (name/length/prefix only -- never full values)
- Probe an HTTP endpoint and report status (e.g. `curl` against Ollama's API)
- Parse config schemas or JSON and report structure

**Tier 2 -- side-effect-free analysis:**
- Individual `./aixcl checks <name>` runs (paths, ascii, yaml, pins, ...)
- `./aixcl test lib` (shell library unit tests, no stack needed)
- `shellcheck --severity=warning --exclude=SC1091 <files>`; `bash -n <file>`
- `yamllint -c .yamllint.yml <file>`
- `./aixcl stack status` (read-only health report)

**Tier 3 -- writes files, reviewable:**
- Simple single-file mechanical edits (rename, ASCII conversion, import sort)
- Mechanical find-replace across explicitly listed files
- Generate boilerplate from an existing template in the repo

**Cost floor**: do not delegate tasks whose direct cost is under about 30
seconds -- the delegation round trip alone runs about 45 seconds (measured
2026-07-23), so quick greps, single-file reads, and fast checks are negative
leverage. Delegation pays off for long-running or blocking work: CI watches,
full check sweeps, bulk mechanical conversions.

Do NOT delegate:
- Multi-file or architectural changes; anything security-sensitive
- Stack state changes (start/stop/restart/purge) -- operator territory
- git commit/push/merge, or any GitHub write (issues, PRs, comments) --
  workflow rules and the agent identification block stay with the primary agent
- Complex debugging needing deep reasoning or conversation context
- Interactive commands

If the task does not fit, say so and handle it directly.

## Step 2: Pick the model

Cloud is always preferred, regardless of whether the local stack is up --
Ollama is last resort only, since it needs a stack the operator may not want
running just for delegation. Every invocation adds `--variant medium`
(reasoning effort). Try in this order, falling through on failure:

1. **`nvidia/deepseek-ai/deepseek-v4-flash`** (primary, credentialed via
   `opencode.json`). A `503` with a body like `"ResourceExhausted: Worker
   local total request limit reached"` is shared-endpoint saturation, not an
   auth or quota failure -- confirmed transient (2026-07-23: a retry 8s later
   succeeded). Retry this model up to 2 times with a short backoff (5s, then
   10s) before falling through to step 2.
2. **`opencode/deepseek-v4-flash-free`** (OpenCode Zen -- built into the
   `opencode` CLI itself, zero config, no credential needed). One attempt.
3. **`opencode/nemotron-3-ultra-free`** (OpenCode Zen, zero config). One
   attempt. Both Zen models are picked from `opencode.db`'s
   `session.model` recency data, not arbitrarily -- re-derive with
   `sqlite3 ~/.local/share/opencode/opencode.db "SELECT model, MAX(time_updated) FROM session WHERE model IS NOT NULL GROUP BY model ORDER BY 2 DESC LIMIT 5;"`
   if these stop being reachable.
4. **`aixcl-local/qwen3-coder:30b-32k`** (Ollama) -- LAST RESORT ONLY, and
   only if `./aixcl stack status` shows Ollama healthy. Never start the
   stack just to delegate.

If all four fail, handle the task directly (see Step 5's failure handling).

## Step 3: Prepare the prompt

Write a self-contained prompt -- the delegate has none of your conversation
context. Include absolute file paths, the exact commands or edits wanted, and
the expected output format. Concrete ("in /path/file.sh change X to Y"), not
vague ("fix the bug").

## Step 4: Log and execute

Log the start:

    echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","task":"<TASK_SUMMARY_50_CHARS>","dir":"<WORKING_DIR>","status":"started"}' >> .opencode/delegation-log.jsonl

Execute (one at a time; bound the runtime):

    START_MS=$(date +%s%3N)
    timeout -k 10 600 opencode run --auto --dir <WORKING_DIR> -m <provider/model> --variant medium "<PROMPT>"
    END_MS=$(date +%s%3N)

## Step 5: Log the result

    echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","task":"<TASK_SUMMARY_50_CHARS>","dir":"<WORKING_DIR>","status":"completed","success":<true|false>,"duration_ms":'$((END_MS - START_MS))',"result_summary":"<ONE_LINE_SUMMARY>"}' >> .opencode/delegation-log.jsonl

On failure set `"status":"failed"` and `"success":false`.

**If delegation fails** at every model in Step 2's fallback chain (a genuine
opencode-level error exits non-zero with output like `Error: "Streaming
response failed"` -- distinct from a permission-hook denial, which never
reaches opencode at all): handle the task directly and log the completion
entry with `"status":"fallback-primary"`.

## Step 6: Report

Return the result to the user. If output is long (over 200 lines), extract the
key findings. If files were modified (Tier 3), list them, summarize the
changes, and review the diff before anything is staged.
