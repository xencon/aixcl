---
description: Pick up the next issue from the agent work queue
agent: agent-context
---

Your next task -- this is the only issue you are assigned; there is no
choice to make. If the line below is empty, report that the queue is empty
and stop:

!`gh issue list --repo xencon/aixcl --label agent --state open --json number,title,labels --jq 'sort_by(.number) | .[0] // empty | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"'`

Open PRs on issue branches -- if one of these carries the issue number
above (branch `issue-<N>/...`), the issue is IN FLIGHT:

!`gh pr list --repo xencon/aixcl --state open --json number,title,headRefName --jq '.[] | select(.headRefName | test("^issue-[0-9]+/")) | "PR #\(.number) on \(.headRefName) -- \(.title)"'`

Your current git state:

!`git status --short --branch`

## If the issue is IN FLIGHT (a PR above matches its number)

You are RESUMING existing work, not starting it:

1. Do NOT create a branch, do NOT create a PR, and do NOT redo the work
2. Read the issue body in full -- it may carry a STATUS section with
   exact resume instructions: `gh issue view <N> --repo xencon/aixcl`
3. Read the PR and ALL of its review comments:
   `gh pr view <PR> --repo xencon/aixcl --comments`
4. Do exactly what the most recent review or STATUS section asks --
   nothing more
5. Only if the fix requires file changes: fetch and check out the
   EXISTING PR branch, then follow steps 5-7 of the fresh-start path.
   Metadata-only fixes (PR body, labels) need no checkout

## If it is a fresh start (no matching PR above)

Work the issue end to end:

1. Read the issue body in full: `gh issue view <N> --repo xencon/aixcl`
2. If the working tree is not clean or you are not on `dev`, stop and report instead of proceeding
3. Create the branch: `git checkout -b issue-<N>/<short-description> dev`
4. Make the changes exactly as specified in the issue Deliverables -- no scope creep
5. Validate: `./aixcl checks all`, plus `shellcheck` and `bash -n` on any shell files you touched
6. If you edited anything under `.claude/` or `.opencode/`, run `bash scripts/utils/sync-mirrors.sh`
7. Stage the changes and show the human the exact `git commit` command to run (GPG signing needs their terminal -- never commit with --no-verify)

If the issue body is ambiguous, post a clarifying comment on the issue (with your agent identification block) and stop.
