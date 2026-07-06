---
description: Post-merge cleanup -- verify merge state, sync dev, delete branch, close issue
---

The human says a PR is merged. VERIFY IT FIRST -- humans are sometimes mistaken, and a PR can be CLOSED without being merged:

!`gh pr list --repo xencon/aixcl --state all --limit 5 --json number,state,title --jq '.[] | "#\(.number) \(.state) \(.title)"'`

For the PR in question (ask which one if ambiguous, or take it from $ARGUMENTS):

1. Confirm the state is exactly `MERGED`: `gh pr view <N> --repo xencon/aixcl --json state`
   - If it is `OPEN` or `CLOSED`, STOP and report -- do not delete anything
2. Sync: `git checkout dev && git pull upstream dev && git push origin dev`
3. Delete the branch locally (`git branch -D <branch>`) and on the fork (`git push origin --delete <branch>`) -- the fork copy may already be auto-deleted, which is fine
4. Close the linked issue with a comment referencing the PR, ending with your agent identification block:
   `gh issue close <N> --repo xencon/aixcl --comment "Resolved by PR #<PR>, merged to dev. ..."`
5. Verify final state: clean working tree, `dev` in sync, no leftover branches

Report what was done and the final state.
