---
description: Pick up the next issue from the agent:qwen work queue
agent: agent-context
---

Your next task -- this is the only issue you are assigned; there is no
choice to make. If the line below is empty, report that the queue is empty
and stop:

!`gh issue list --repo xencon/aixcl --label agent:qwen --state open --json number,title,labels --jq 'sort_by(.number) | .[0] // empty | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"'`

Your current git state:

!`git status --short --branch`

Work the issue above end to end:

1. Read the issue body in full: `gh issue view <N> --repo xencon/aixcl`
2. If the working tree is not clean or you are not on `dev`, stop and report instead of proceeding
3. Create the branch: `git checkout -b issue-<N>/<short-description> dev`
4. Make the changes exactly as specified in the issue Deliverables -- no scope creep
5. Validate: `./aixcl checks all`, plus `shellcheck` and `bash -n` on any shell files you touched
6. If you edited anything under `.claude/` or `.opencode/`, run `bash scripts/utils/sync-mirrors.sh`
7. Stage the changes and show the human the exact `git commit` command to run (GPG signing needs their terminal -- never commit with --no-verify)

If the issue body is ambiguous, post a clarifying comment on the issue (with your agent identification block) and stop.
