---
description: Pre-PR checklist -- validate the branch before pushing and opening a PR
agent: agent-context
---

Current branch and staged state:

!`git status --short --branch`

!`git log --oneline -3`

Run the pre-PR checklist against this branch:

1. Confirm the branch name matches `issue-<N>/<short-description>` and the commit message references the issue (`Fixes #<N>`)
2. Confirm the commit is GPG signed: `git log -1 --format='%G?'` must print `G` (if not, the human must commit)
3. Run `./aixcl checks all` and report the summary table
4. Write the PR body to /tmp (never into the repo), ending with your agent identification block, then validate it: `bash scripts/checks/check-pr-references.sh < /tmp/<body-file>`
5. Push to the fork: `git push origin <branch>`
6. Create the PR with everything set at creation time (title `<description> (#<N>)` with no colons, assignee, at least one `component:*` label), targeting `xencon/aixcl` base `dev`:
   `./scripts/utils/create-pr.sh "<title> (#<N>)" "<body>" "component:<name>" "<assignee>" dev`

Report the PR URL when done. Do not merge the PR yourself -- merging is a human decision.
