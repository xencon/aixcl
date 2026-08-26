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
  version: "1.7"
---

# Delegate to OpenCode

Delegate the given task to the OpenCode peer agent and log it for tracking.

**BOUNDED PARALLEL -- cap 3 concurrent.** Independent delegatable tasks
(no shared file target, no ordering dependency between them) may run
concurrently, up to 3 in flight at once. Every invocation attaches to the
same shared server (Step 2), so the old model-instance corruption risk is
gone by construction -- only the server process ever writes to
`opencode.db`. What remains is the JSONL log: redirect each concurrent
invocation's output to its own `mktemp` file, background with `&`, collect
PIDs, `wait` for all of them, then process each result in turn. Wrap every
JSONL append (both start and completion, Steps 4 and 5) in
`flock -x .opencode/delegation-log.jsonl.lock -c '...'` so concurrent
completions can't interleave. Tasks with a real dependency (task B needs
task A's output) still run sequentially.

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
- Repo-wide grep to confirm a just-fixed pattern has no other live instances
  (e.g. before ticking a remediation checklist's "confirm no other path has
  this issue" item -- caught a second live instance of #2003's plaintext-
  password logging bug in a separate compose overlay file, 2026-07-23)
- Repo-wide grep for a stale identifier after a rename or config-default
  change (e.g. confirming no doc or skill file still names an old model,
  env var, or file path after the live value changed -- used to sweep
  `.claude/`, `.opencode/`, and `config/` for a dead default-model name
  after #2024's fix, 2026-08-10)

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

## Step 2: Ensure the shared server, then pick the model

Every delegation attaches to one persistent `opencode serve` process
instead of spawning its own instance:

    URL=$(bash scripts/utils/ensure-opencode-server.sh)

This is idempotent and near-instant if the server is already running --
call it before every delegation (or once per batch of parallel
delegations). Routing everything through one server means only that one
process ever writes to `~/.local/share/opencode/opencode.db`, which is the
actual fix for the sqlite-contention risk that used to justify running
delegations one at a time.

**The running server caches `opencode.json` at startup.** Editing
`model`, `small_model`, or the `provider` block does not take effect on a
live server -- `ensure-opencode-server.sh` reuses any process that is
still healthy, so a config change silently keeps serving the old values
until the process is restarted. Confirmed live 2026-08-10: after fixing
a dead default model in `opencode.json`, the first delegation still hit
the old (dead) model because the server had started before the edit.
Fix: `kill <pid>; rm -f .opencode/server-state.json`, then re-run
`ensure-opencode-server.sh` to start a fresh process with the new config.
Do this any time you change `opencode.json` and delegation doesn't
reflect it.

Cloud is always preferred, regardless of whether the local stack is up --
Ollama is last resort only, since it needs a stack the operator may not want
running just for delegation. Every invocation adds `--attach "$URL"` and
`--variant medium` (reasoning effort). Try in this order, falling through
on failure. Each position is numbered (1-2) -- record whichever position
actually succeeds as `fallback_position` in Step 5's completion log entry,
so delegate-review can report how often the default model serves requests
versus falling through.

1. **Default -- omit `-m` entirely.** Inherits whatever `opencode.json`'s
   `model` key configures (currently `nvidia/moonshotai/kimi-k3`),
   so delegation always tracks OpenCode's actual configured default rather
   than a separately hardcoded model. A `503` with a body like
   `"ResourceExhausted: Worker local total request limit reached"` is
   shared-endpoint saturation, not an auth or quota failure -- confirmed
   transient (2026-07-23: a retry 8s later succeeded). Retry up to 2 times
   with a short backoff (5s, then 10s) before falling through to position 2.
2. **`-m aixcl-local/qwen3-coder:30b-32k`** (Ollama) -- LAST RESORT ONLY,
   and only if `./aixcl stack status` shows Ollama healthy. Never start the
   stack just to delegate.

If both fail, handle the task directly (see Step 5's failure handling).

## Step 3: Prepare the prompt

Write a self-contained prompt -- the delegate has none of your conversation
context. Include absolute file paths, the exact commands or edits wanted, and
the expected output format. Concrete ("in /path/file.sh change X to Y"), not
vague ("fix the bug").

## Step 4: Log and execute

**Log the start BEFORE running `opencode run` -- never skip this, even for a
quick call.** A completion entry with no matching start (found 2026-07-23:
3 of 11 entries in one session) breaks pairing-based analytics in
delegate-review and leaves no record that the delegation was even
attempted if it never finishes. Wrap the append in `flock` so concurrent
delegations (bounded-parallel rule above) can't interleave lines:

    flock -x .opencode/delegation-log.jsonl.lock -c "echo '{\"ts\":\"'\$(date -u +%Y-%m-%dT%H:%M:%SZ)'\",\"task\":\"<TASK_SUMMARY_50_CHARS>\",\"dir\":\"<WORKING_DIR>\",\"status\":\"started\"}' >> .opencode/delegation-log.jsonl"

Execute (bound the runtime; omit `-m` for the default tier, add it only for
the Ollama fallback tier):

    URL=$(bash scripts/utils/ensure-opencode-server.sh)
    START_MS=$(date +%s%3N)
    timeout -k 10 600 opencode run --attach "$URL" --auto --dir <WORKING_DIR> --variant medium "<PROMPT>"
    END_MS=$(date +%s%3N)

For up to 3 independent tasks at once, background each with `&` (own
`mktemp` output file), then `wait`:

    T1=$(mktemp); T2=$(mktemp); T3=$(mktemp)
    ( timeout -k 10 600 opencode run --attach "$URL" --auto --dir <DIR1> --variant medium "<PROMPT1>" > "$T1" 2>&1 ) &
    ( timeout -k 10 600 opencode run --attach "$URL" --auto --dir <DIR2> --variant medium "<PROMPT2>" > "$T2" 2>&1 ) &
    ( timeout -k 10 600 opencode run --attach "$URL" --auto --dir <DIR3> --variant medium "<PROMPT3>" > "$T3" 2>&1 ) &
    wait

## Step 5: Log the result

Record which provider/model actually served the request (`<provider/model>`,
e.g. `nvidia/moonshotai/kimi-k3`) and its position in Step 2's
chain (`<fallback_position>`, 1-2), again through `flock`:

    flock -x .opencode/delegation-log.jsonl.lock -c "echo '{\"ts\":\"'\$(date -u +%Y-%m-%dT%H:%M:%SZ)'\",\"task\":\"<TASK_SUMMARY_50_CHARS>\",\"dir\":\"<WORKING_DIR>\",\"status\":\"completed\",\"success\":<true|false>,\"duration_ms\":$((END_MS - START_MS)),\"provider_model\":\"<provider/model>\",\"fallback_position\":<fallback_position>,\"result_summary\":\"<ONE_LINE_SUMMARY>\"}' >> .opencode/delegation-log.jsonl"

On failure set `"status":"failed"` and `"success":false`; still record
`provider_model` and `fallback_position` for whichever model the failing
attempt was on.

**A `503` that arrives AFTER visible tool-execution output is not a
failure.** The delegate model can hit the same shared-endpoint saturation
(Step 2) while generating its final summary, after the underlying command
already ran and printed real output -- confirmed live 2026-07-24 (a
gitleaks and a shellcheck delegation both hit `Error: "ResourceExhausted:
..."` with the tool's actual output visible just above it). In that case
log `"status":"completed"`, `"success":true`, and use the visible tool
output as `result_summary` directly -- do not retry or fall through, since
a retry would just re-run the tool for no benefit. This is distinct from
Step 2's 503 retry-with-backoff, which covers a 503 on the *initial*
request, before any tool output exists.

**If delegation fails** at every model in Step 2's fallback chain (a genuine
opencode-level error exits non-zero with output like `Error: "Streaming
response failed"` -- distinct from a permission-hook denial, which never
reaches opencode at all): handle the task directly and log the completion
entry with `"status":"fallback-primary"`.

## Step 6: Report

Return the result to the user. If output is long (over 200 lines), extract the
key findings. If files were modified (Tier 3), list them, summarize the
changes, and review the diff before anything is staged.
