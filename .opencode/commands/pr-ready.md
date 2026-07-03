---
description: Pre-PR checklist -- validate the branch before pushing and opening a PR
agent: agent-context
---

Current branch state:

!`git status --short --branch`

Commits on this branch that are NOT in dev (this is what your PR will contain):

!`git fetch upstream --quiet 2>/dev/null; git log --format="%h sig=%G? %s" upstream/dev..HEAD`

## HARD GATE -- read before doing anything

If the commit list above is EMPTY, STOP HERE. Your work is only staged, not
committed, and a PR opened now would contain nothing. Do NOT push. Do NOT
create a PR. Instead: confirm the staged changes are complete, then give the
human the exact `git commit` command to run (GPG signing needs their
terminal) and END YOUR TURN. Run /pr-ready again after the human commits.

If the list is non-empty, every commit must show `sig=G` (good signature).
If any shows `sig=N` or `sig=E`, stop and report -- do not push unsigned
commits.

## Steps (only after the gate passes)

1. Confirm the branch name matches `issue-<N>/<short-description>` and the
   commit message references the issue (`Fixes #<N>`)
2. Run `./aixcl checks all` and report the summary table
3. Write the PR body to /tmp (never into the repo), ending with your agent
   identification block, then validate it:
   `bash scripts/checks/check-pr-references.sh < /tmp/<body-file>`
4. Push to the fork: `git push origin <branch>`
5. Create the PR with the helper script -- it targets base `dev` and sets
   assignee and labels at creation time. The title is
   `<description> (#<N>)` -- NO colons anywhere in the title:
   `./scripts/utils/create-pr.sh "<description> (#<N>)" "<body>" "component:<name>" "<assignee>" dev`
   Never use `gh pr create` directly -- it defaults the base to main.

Report the PR URL when done. Do not merge the PR yourself -- merging is a
human decision.
