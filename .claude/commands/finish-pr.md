---
description: Post-merge cleanup -- verify merge state, sync dev, delete branch, close issue
---

The human says a PR is merged. VERIFY IT FIRST -- a PR can be CLOSED
without being merged, and humans are sometimes mistaken:

!`gh pr list --repo xencon/aixcl --state all --limit 5 --json number,state,title --jq '.[] | "#\(.number) \(.state) \(.title)"'`

For the PR in question (from $ARGUMENTS, or ask if ambiguous):

1. Confirm state is exactly `MERGED`: `gh pr view <N> --repo xencon/aixcl --json state`
   - If `OPEN` or `CLOSED`, STOP and report -- do not delete anything
2. Sync: `git checkout dev && git pull upstream dev && git push origin dev`
3. Delete the branch locally and on the fork (fork copy may already be auto-deleted)
4. Close the linked issue with a comment referencing the PR, ending with the agent identification block
5. Verify final state: clean tree, dev in sync, no leftover branches
